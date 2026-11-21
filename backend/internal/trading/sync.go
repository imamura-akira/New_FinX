package trading

import (
	"context"
	"errors"
	"log/slog"
	"time"
)

// idempotencyWindow：DW 幂等键保存 4 天；超过后重放会被当作新订单，只能人工核对。
const idempotencyWindow = 96 * time.Hour

// submitGrace：新建的 SUBMITTING 订单在此时长内不重放——首次提交可能仍在等 DW 响应，
// 并发重放同一幂等键会得到 IK075（2026-11-21 沙盒入金实测，同一机制）。
const submitGrace = time.Minute

// replayWindow：结果不明的订单只在提交后 15 分钟内、且同一美东交易日内重放（审计 FUND-P1-1）。
// 超出后再重放会在完全不同的价格 / 交易时段成交（且重放不重新检查购买力），因此标为 UNCONFIRMED 转人工核对。
const replayWindow = 15 * time.Minute

var nyLoc = func() *time.Location {
	if l, err := time.LoadLocation("America/New_York"); err == nil {
		return l
	}
	return time.UTC
}()

func sameTradingDay(a, b time.Time) bool {
	ay, am, ad := a.In(nyLoc).Date()
	by, bm, bd := b.In(nyLoc).Date()
	return ay == by && am == bm && ad == bd
}

// Sync 对账未完结订单（由 events.Reconciler 周期调用）：
//   - SUBMITTING（结果不明）：提交满 submitGrace 后、15 分钟内且同一美东交易日内用原键重放创建请求，确认 DW 是否已受理；
//     超出窗口标为 UNCONFIRMED 转人工核对（不再重放）；
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
		case o.DWOrderID == "" && now.Sub(o.SubmittedAt) < submitGrace:
			continue // 首次提交可能仍在进行中
		case o.Status == StatusUnconfirmed:
			_ = s.Repo.TouchOrder(ctx, o.ID, now) // 待人工核对：不重放
		case o.DWOrderID == "" && now.Sub(o.SubmittedAt) < replayWindow && sameTradingDay(o.SubmittedAt, now):
			if _, err := s.submit(ctx, o, true); err != nil && !errors.Is(err, errReplayRejected) {
				_ = s.Repo.TouchOrder(ctx, o.ID, now)
			}
		case o.DWOrderID == "":
			s.markUnconfirmed(ctx, o, now, "超出重放窗口（同一交易日、15 分钟内）仍未确认，待人工核对")
		default:
			s.refresh(ctx, o, now)
		}
	}
}
