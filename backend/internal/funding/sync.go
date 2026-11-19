package funding

import (
	"context"
	"log/slog"
	"net/http"
	"time"
)

// returnWindow：ACH 入金成功后仍可能被退回（RETURNED），在此期间继续对账。
const returnWindow = 10 * 24 * time.Hour

// Sync 对账在途出入金（由 events.Reconciler 周期调用）：
//   - SUBMITTING 的入金：用原 Idempotency-Key 重放创建请求以确认结果（DW 保存 4 天）；
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
			if _, err := s.submitDeposit(ctx, t); err != nil {
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
