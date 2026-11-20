package trading

import (
	"context"
	"log/slog"
	"time"
)

// idempotencyWindow：DW 幂等键保存 4 天；超过后重放会被当作新订单，只能人工核对。
const idempotencyWindow = 96 * time.Hour

// Sync 对账未完结订单（由 events.Reconciler 周期调用）：
//   - SUBMITTING（结果不明）：在幂等键有效期内用原键重放创建请求，确认 DW 是否已受理；
//   - 其余未完结订单：GET 最新状态。
func (s *Service) Sync(ctx context.Context, every time.Duration) {
	now := s.now().UTC()
	list, err := s.Repo.DueOrders(ctx, now.Add(-every/2), 50)
	if err != nil {
		s.Logger.ErrorContext(ctx, "list due orders failed", slog.String("error", err.Error()))
		return
	}
	for _, o := range list {
		switch {
		case o.DWOrderID == "" && now.Sub(o.SubmittedAt) < idempotencyWindow-time.Hour:
			if _, err := s.submit(ctx, o); err != nil {
				_ = s.Repo.TouchOrder(ctx, o.ID, now)
			}
		case o.DWOrderID == "":
			s.Logger.ErrorContext(ctx, "order outcome unknown past idempotency window, manual check required", slog.String("order_id", o.ID))
			_ = s.Repo.TouchOrder(ctx, o.ID, now)
		default:
			s.refresh(ctx, o, now)
		}
	}
}
