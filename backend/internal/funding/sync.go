package funding

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/crypto"
)

// returnWindow：ACH 入金成功后仍可能被退回（RETURNED），在此期间继续对账。
const returnWindow = 10 * 24 * time.Hour

// submitGrace：新建的"提交中"入金在此时长内不重放——首次提交可能仍在等 DW 响应（超时 10 秒 + 一次重试），
// 并发重放同一幂等键会得到 IK075（2026-11-21 沙盒实测）。
const submitGrace = time.Minute

// idempotencyWindow：DW 幂等键保存 4 天；超过后重放会被当作新入金（重复扣款），因此只在 [submitGrace, 95 小时) 内重放，
// 之后只按账户反查，查不到则写错误日志转人工（审计 FUND-P0-2）。
const idempotencyWindow = 96 * time.Hour

// lookupAfter：重放仍拿不到结果（如 IK075 持续、网络错误）超过此时长，按账户列出 DW 入金反查并关联。
const lookupAfter = 10 * time.Minute

// lookupSpan：反查时，DW 创建时间须落在本地提交时间 [-1 分钟, +lookupSpan] 内。
const lookupSpan = 30 * time.Minute

// Sync 对账在途出入金（由 events.Reconciler 周期调用）：
//   - SUBMITTING 的入金：提交满 submitGrace 后用原 Idempotency-Key 重放创建请求以确认结果（DW 保存 4 天）；
//     超过 lookupAfter 仍无结果时按账户列出入金反查（同金额、同银行账户、时间吻合且未被关联的唯一一笔）；
//   - SUBMITTING 的出金：与入金相同，带原幂等键重放（DW 文档：Create Withdrawal 支持幂等键）并按账户反查；
//   - UNCONFIRMED：只反查，不重放；对账路径一律不删除记录；
//   - 已有 DW 编号的：GET 最新状态。
func (s *Service) Sync(ctx context.Context, every time.Duration) {
	now := s.now().UTC()
	list, err := s.Repo.DueTransfers(ctx, now.Add(-every/2), now.Add(-returnWindow), 50)
	if err != nil {
		s.Logger.ErrorContext(ctx, "list due transfers failed", slog.String("error", err.Error()))
		return
	}
	for _, t := range list {
		if t.DWRef != "" {
			s.refresh(ctx, t, now)
			continue
		}
		s.settleUnknown(ctx, t, now)
	}
}

// settleUnknown：没有 DW 编号的出入金（提交中 / 结果不明 / 未确认）。对账路径一律不删除记录（审计 FUND-P1-4）。
//   - 提交未满 submitGrace：跳过（首次提交可能仍在进行中）；
//   - UNCONFIRMED：只按账户反查，不再重放；
//   - 幂等有效期内：用原键重放（入金、出金都带键，DW 返回原响应）；满 lookupAfter 后重放失败再反查；
//   - 超过有效期（95 小时）：只反查，查不到标为 UNCONFIRMED 转人工（重放会被当作新申请，审计 FUND-P0-2）。
func (s *Service) settleUnknown(ctx context.Context, t Transfer, now time.Time) {
	age := now.Sub(t.SubmittedAt)
	switch {
	case age < submitGrace:
		return
	case t.Status == StatusUnconfirmed:
		if !s.lookupTransfer(ctx, t, now) {
			_ = s.Repo.TouchTransfer(ctx, t.ID, now)
		}
		return
	case age >= idempotencyWindow-time.Hour:
		if !s.lookupTransfer(ctx, t, now) {
			s.markUnconfirmed(ctx, t, now, "超过券商幂等有效期仍未查到结果，待人工核对")
		}
		return
	}
	if _, err := s.replay(ctx, t); err != nil {
		if errors.Is(err, errReplayRejected) {
			return // 已标为 UNCONFIRMED
		}
		if age >= lookupAfter && s.lookupTransfer(ctx, t, now) {
			return
		}
		_ = s.Repo.TouchTransfer(ctx, t.ID, now)
	}
}

// replay：用原幂等键重放创建请求。出金需要开户姓名与（WIRE）解密后的收款信息。
func (s *Service) replay(ctx context.Context, t Transfer) (string, error) {
	if t.Type == "DEPOSIT" {
		return s.submitDeposit(ctx, t, true)
	}
	if s.LegalName == nil {
		return "", errors.New("funding: legal name resolver not configured")
	}
	owner, err := s.LegalName(ctx, t.CreatedBy)
	if err != nil || owner == "" {
		s.Logger.ErrorContext(ctx, "withdrawal replay: legal name unavailable", slog.String("transfer_id", t.ID))
		return "", errors.New("funding: legal name unavailable")
	}
	var wire *Wire
	if t.Method == "WIRE" {
		raw, err := s.Cipher.Decrypt(t.WireEnc, crypto.AAD("transfers", "wire_enc", t.IdempotencyKey))
		if err != nil {
			s.Logger.ErrorContext(ctx, "withdrawal replay: decrypt wire failed", slog.String("transfer_id", t.ID))
			return "", err
		}
		wire = &Wire{}
		if err := json.Unmarshal(raw, wire); err != nil {
			return "", err
		}
	}
	return s.submitWithdrawal(ctx, t, owner, wire, true)
}

func (s *Service) markUnconfirmed(ctx context.Context, t Transfer, now time.Time, reason string) {
	if t.Status == StatusUnconfirmed {
		_ = s.Repo.TouchTransfer(ctx, t.ID, now)
		return
	}
	if err := s.Repo.UpdateTransfer(ctx, t.ID, StatusUnconfirmed, &reason, nil, now); err != nil {
		s.Logger.ErrorContext(ctx, "mark unconfirmed failed", slog.String("transfer_id", t.ID), slog.String("error", err.Error()))
		return
	}
	_ = s.Repo.Audit(ctx, "system", "transfer.unconfirmed", "transfer:"+t.ID, map[string]any{"from": t.Status, "reason": reason})
	s.Logger.ErrorContext(ctx, "transfer outcome unconfirmed, manual check required", slog.String("transfer_id", t.ID), slog.String("type", t.Type))
}

func (s *Service) refresh(ctx context.Context, t Transfer, now time.Time) {
	path := pathDeposits + "/" + t.DWRef
	if t.Type == "WITHDRAWAL" {
		path = pathRedemptions + "/" + t.DWRef
	}
	var res dwTransferRes
	if err := s.DW.Do(ctx, http.MethodGet, path, nil, &res); err != nil {
		s.Logger.WarnContext(ctx, "refresh transfer failed", slog.String("transfer_id", t.ID), slog.String("error", err.Error()))
		_ = s.Repo.TouchTransfer(ctx, t.ID, now)
		return
	}
	if bp, wd := res.availability(); (bp != nil || wd != nil) && (!sameTime(bp, t.BuyingPowerAt) || !sameTime(wd, t.WithdrawableAt)) {
		_ = s.Repo.SetAvailability(ctx, t.ID, bp, wd)
	}
	st := statusOf(res.Status)
	if st == "" || st == t.Status {
		_ = s.Repo.TouchTransfer(ctx, t.ID, now)
		return
	}
	var done *time.Time
	if st == "SUCCESSFUL" || Terminal(st) {
		done = &now
	}
	if err := s.Repo.UpdateTransfer(ctx, t.ID, st, failureText(st), done, now); err != nil {
		s.Logger.ErrorContext(ctx, "update transfer failed", slog.String("error", err.Error()))
		return
	}
	_ = s.Repo.Audit(ctx, "system", "transfer.status", "transfer:"+t.ID, map[string]any{"from": t.Status, "to": st})
	s.Logger.InfoContext(ctx, "transfer status changed", slog.String("transfer_id", t.ID), slog.String("type", t.Type), slog.String("from", t.Status), slog.String("to", st))
}

func sameTime(a, b *time.Time) bool {
	if a == nil || b == nil {
		return a == b
	}
	return a.Equal(*b)
}

// lookupTransfer：按账户列出 DW 入金或出金（GET /accounts/{accountID}/funding/deposits | redemptions），
// 找出与本地记录对应的那一笔并关联（找到返回 true）。匹配条件：金额相同（出金列表金额可能为负，取绝对值）、
// 银行账户相同（列表带该字段时）、创建时间吻合、未被其他记录关联。只有唯一匹配才关联；多笔写错误日志转人工。
func (s *Service) lookupTransfer(ctx context.Context, t Transfer, now time.Time) bool {
	if t.DWAccountID == "" {
		return false
	}
	path, kind := pathAccountDeposits(t.DWAccountID), "deposit"
	if t.Type == "WITHDRAWAL" {
		path, kind = pathAccountRedemptions(t.DWAccountID), "redemption"
	}
	var list []dwDepositItem
	if err := s.DW.Do(ctx, http.MethodGet, path, nil, &list); err != nil {
		s.Logger.WarnContext(ctx, "dw "+kind+" lookup failed", slog.String("transfer_id", t.ID), slog.String("error", err.Error()))
		return false
	}
	want := parseCents(t.Amount)
	var hits []dwDepositItem
	for _, d := range list {
		if c, err := ParseAmount(json.Number(strings.TrimPrefix(d.Amount.String(), "-"))); err != nil || c != want {
			continue
		}
		if d.BankAccountID != "" && t.DWBankID != "" && d.BankAccountID != t.DWBankID {
			continue
		}
		at, ok := d.createdAt()
		if !ok || at.Before(t.SubmittedAt.Add(-time.Minute)) || at.After(t.SubmittedAt.Add(lookupSpan)) {
			continue
		}
		if used, err := s.Repo.DWRefUsed(ctx, d.ID); err != nil || used {
			continue
		}
		hits = append(hits, d)
	}
	switch len(hits) {
	case 0:
		return false
	case 1:
		status := statusOf(hits[0].Status)
		if status == "" {
			status = "PENDING"
		}
		if err := s.Repo.SetSubmitted(ctx, t.ID, hits[0].ID, status, now); err != nil {
			return false
		}
		s.Logger.WarnContext(ctx, "dw "+kind+" matched by lookup", slog.String("transfer_id", t.ID), slog.String("dw_ref", hits[0].ID))
		return true
	default:
		s.Logger.ErrorContext(ctx, "dw "+kind+" lookup ambiguous, manual check required", slog.String("transfer_id", t.ID), slog.Int("matches", len(hits)))
		return false
	}
}
