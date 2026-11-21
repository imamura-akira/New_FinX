package funding

import (
	"context"
	"log/slog"
	"net/http"
	"time"
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
//   - SUBMITTING 的出金：不重放（文档未说明支持幂等键），超过 10 分钟仍无结果写日志供人工核对；
//   - 已有 DW 编号的：GET 最新状态。
func (s *Service) Sync(ctx context.Context, every time.Duration) {
	now := s.now().UTC()
	list, err := s.Repo.DueTransfers(ctx, now.Add(-every/2), now.Add(-returnWindow), 50)
	if err != nil {
		s.Logger.ErrorContext(ctx, "list due transfers failed", slog.String("error", err.Error()))
		return
	}
	for _, t := range list {
		switch {
		case t.DWRef == "" && t.Type == "DEPOSIT":
			age := now.Sub(t.SubmittedAt)
			if age < submitGrace {
				continue // 首次提交可能仍在进行中
			}
			if age >= idempotencyWindow-time.Hour {
				if !s.lookupDeposit(ctx, t, now) {
					s.Logger.ErrorContext(ctx, "deposit outcome unknown past idempotency window, manual check required", slog.String("transfer_id", t.ID))
					_ = s.Repo.TouchTransfer(ctx, t.ID, now)
				}
				continue
			}
			if _, err := s.submitDeposit(ctx, t); err != nil {
				if age >= lookupAfter && s.lookupDeposit(ctx, t, now) {
					continue
				}
				_ = s.Repo.TouchTransfer(ctx, t.ID, now)
			}
		case t.DWRef == "":
			if now.Sub(t.SubmittedAt) > 10*time.Minute {
				s.Logger.ErrorContext(ctx, "withdrawal outcome unknown, manual check required", slog.String("transfer_id", t.ID))
			}
			_ = s.Repo.TouchTransfer(ctx, t.ID, now)
		default:
			s.refresh(ctx, t, now)
		}
	}
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

// lookupDeposit：按账户列出 DW 入金，找出与本地"提交中"记录对应的那一笔并关联（找到返回 true）。
// 只有唯一匹配才关联；多笔匹配写错误日志转人工核对，避免关联错。
func (s *Service) lookupDeposit(ctx context.Context, t Transfer, now time.Time) bool {
	if t.DWAccountID == "" {
		return false
	}
	var list []dwDepositItem
	if err := s.DW.Do(ctx, http.MethodGet, pathAccountDeposits(t.DWAccountID), nil, &list); err != nil {
		s.Logger.WarnContext(ctx, "dw deposit lookup failed", slog.String("transfer_id", t.ID), slog.String("error", err.Error()))
		return false
	}
	want := parseCents(t.Amount)
	var hits []dwDepositItem
	for _, d := range list {
		if c, err := ParseAmount(d.Amount); err != nil || c != want {
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
		s.Logger.WarnContext(ctx, "dw deposit matched by lookup", slog.String("transfer_id", t.ID), slog.String("dw_ref", hits[0].ID))
		return true
	default:
		s.Logger.ErrorContext(ctx, "dw deposit lookup ambiguous, manual check required", slog.String("transfer_id", t.ID), slog.Int("matches", len(hits)))
		return false
	}
}
