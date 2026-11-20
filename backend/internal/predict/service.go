package predict

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/httpx"
)

// Deps：外部依赖。Price 返回虚拟行情最新价（BTC / SOL）。
type Deps struct {
	Repo   Repo
	Price  func(symbol string) (float64, bool)
	Logger *slog.Logger
}

// Service：预测板块。
type Service struct {
	Deps
	now func() time.Time
}

// New 创建模块。
func New(d Deps) *Service {
	if d.Logger == nil {
		d.Logger = slog.Default()
	}
	return &Service{Deps: d, now: time.Now}
}

// Routes 注册 /predict/*（均需登录）。
func (s *Service) Routes(mux *http.ServeMux, prefix string, auth func(http.Handler) http.Handler) {
	h := func(f http.HandlerFunc) http.Handler { return auth(f) }
	mux.Handle("GET "+prefix+"/predict/account", h(s.handleAccount))
	mux.Handle("GET "+prefix+"/predict/markets", h(s.handleMarkets))
	mux.Handle("GET "+prefix+"/predict/markets/{id}", h(s.handleMarket))
	mux.Handle("POST "+prefix+"/predict/bets", h(s.handleBet))
	mux.Handle("GET "+prefix+"/predict/bets", h(s.handleBets))
	mux.Handle("POST "+prefix+"/predict/claim", h(s.handleClaim))
}

// ---------- 视图 ----------

// Text：双语文案（App 按当前语言取用）。
type Text struct {
	Zh string `json:"zh"`
	En string `json:"en"`
}

// OutcomeView：一个选项。
type OutcomeView struct {
	Key     string `json:"key"` // YES / NO（涨跌市场：YES = 上涨，NO = 下跌）
	Label   Text   `json:"label"`
	Percent int    `json:"percent"` // 概率百分比整数，两边合计 100
	Pool    int64  `json:"pool"`    // 该方向池（含种子流动性）
}

// MarketView：市场。
type MarketView struct {
	ID          string        `json:"id"`
	Kind        string        `json:"kind"`
	Category    string        `json:"category"`
	Symbol      *string       `json:"symbol"`
	Title       Text          `json:"title"`
	Subtitle    Text          `json:"subtitle"`
	Outcomes    []OutcomeView `json:"outcomes"`
	OpensAt     time.Time     `json:"opensAt"`
	ClosesAt    time.Time     `json:"closesAt"`
	TargetPrice *float64      `json:"targetPrice"`
	SettlePrice *float64      `json:"settlePrice"`
	Status      string        `json:"status"` // OPEN / CLOSED（待结算）/ SETTLED
	Result      *string       `json:"result"`
}

func (s *Service) view(m Market) MarketView {
	py := PercentYes(m.PoolYes, m.PoolNo)
	st := "OPEN"
	switch {
	case m.Result != nil:
		st = "SETTLED"
	case !s.now().Before(m.ClosesAt):
		st = "CLOSED"
	}
	return MarketView{ID: m.ID, Kind: m.Kind, Category: m.Category, Symbol: m.Symbol,
		Title: Text{m.TitleZh, m.TitleEn}, Subtitle: Text{m.SubtitleZh, m.SubtitleEn},
		Outcomes: []OutcomeView{
			{Key: Yes, Label: Text{m.YesZh, m.YesEn}, Percent: py, Pool: m.PoolYes},
			{Key: No, Label: Text{m.NoZh, m.NoEn}, Percent: 100 - py, Pool: m.PoolNo},
		},
		OpensAt: m.OpensAt, ClosesAt: m.ClosesAt, TargetPrice: m.TargetPrice, SettlePrice: m.SettlePrice, Status: st, Result: m.Result}
}

// BetView：下注（附市场摘要）。
type BetView struct {
	ID              string      `json:"id"`
	MarketID        string      `json:"marketId"`
	Outcome         string      `json:"outcome"`
	Stake           int64       `json:"stake"`
	Probability     float64     `json:"probability"`
	PotentialPayout int64       `json:"potentialPayout"`
	Status          string      `json:"status"`
	Payout          int64       `json:"payout"`
	Claimed         bool        `json:"claimed"`
	CreatedAt       time.Time   `json:"createdAt"`
	SettledAt       *time.Time  `json:"settledAt"`
	Market          *MarketView `json:"market"`
}

func betView(b Bet, m *MarketView) BetView {
	return BetView{ID: b.ID, MarketID: b.MarketID, Outcome: b.Outcome, Stake: b.Stake, Probability: b.Probability,
		PotentialPayout: b.PotentialPayout, Status: b.Status, Payout: b.Payout, Claimed: b.ClaimedAt != nil,
		CreatedAt: b.CreatedAt, SettledAt: b.SettledAt, Market: m}
}

// ---------- 15 分钟市场 ----------

// EnsureWindows 为每个标的创建当前 15 分钟窗口的涨跌市场（目标价 = 创建时的虚拟行情价）。
func (s *Service) EnsureWindows(ctx context.Context) {
	if s.Price == nil {
		return
	}
	start := WindowStart(s.now())
	for _, sym := range UpDownSymbols {
		p, ok := s.Price(sym)
		if !ok {
			continue
		}
		if err := s.Repo.EnsureUpDown(ctx, sym, start, round2(p)); err != nil {
			s.Logger.WarnContext(ctx, "predict ensure window failed", slog.String("symbol", sym), slog.String("error", err.Error()))
		}
	}
}

// lateVoid：到期超过该时长才结算（如服务停机）则作废退回，避免用事后价格结算。
const lateVoid = 2 * time.Minute

// SettleDue 结算已到期的涨跌市场：收盘价 > 目标价为上涨，< 为下跌，相等或结算过迟作废。
func (s *Service) SettleDue(ctx context.Context) {
	now := s.now()
	due, err := s.Repo.DueUpDown(ctx, now)
	if err != nil {
		s.Logger.WarnContext(ctx, "predict due query failed", slog.String("error", err.Error()))
		return
	}
	for _, m := range due {
		res := Void
		var sp *float64
		if p, ok := s.Price(*m.Symbol); ok && now.Sub(m.ClosesAt) <= lateVoid && m.TargetPrice != nil {
			v := round2(p)
			sp = &v
			res = UpDownResult(*m.TargetPrice, v)
		}
		n, err := s.Repo.Settle(ctx, m.ID, res, sp, now)
		if err != nil && !errors.Is(err, ErrSettled) {
			s.Logger.WarnContext(ctx, "predict settle failed", slog.String("market", m.ID), slog.String("error", err.Error()))
			continue
		}
		s.Logger.InfoContext(ctx, "predict market settled", slog.String("market", m.ID), slog.String("result", res), slog.Int("bets", n))
	}
}

// Run 周期创建窗口并结算到期市场。
func (s *Service) Run(ctx context.Context, every time.Duration) {
	t := time.NewTicker(every)
	defer t.Stop()
	for {
		s.SettleDue(ctx)
		s.EnsureWindows(ctx)
		select {
		case <-ctx.Done():
			return
		case <-t.C:
		}
	}
}

// ---------- 接口 ----------

func (s *Service) fail(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, ErrStake):
		httpx.Fail(w, r, httpx.Validation("", httpx.FieldError{Field: "stake", Reason: "下注积分须在 10–5,000 分之间"}))
	case errors.Is(err, ErrBadOutcome):
		httpx.Fail(w, r, httpx.Validation("", httpx.FieldError{Field: "outcome", Reason: "请选择预测方向"}))
	case errors.Is(err, ErrInsufficient):
		httpx.Fail(w, r, &httpx.Error{HTTP: http.StatusUnprocessableEntity, Code: httpx.CodeLimit, Message: "预测积分不足"})
	case errors.Is(err, ErrMarketClosed):
		httpx.Fail(w, r, httpx.Conflict("该预测市场已截止"))
	case errors.Is(err, ErrNotFound):
		httpx.Fail(w, r, httpx.Conflict("预测市场不存在"))
	default:
		httpx.Fail(w, r, err)
	}
}

func (s *Service) handleAccount(w http.ResponseWriter, r *http.Request) {
	ctx, uid := r.Context(), httpx.UserID(r.Context())
	pts, err := s.Repo.EnsureAccount(ctx, uid)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	bets, err := s.Repo.ListBets(ctx, uid)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	httpx.OK(w, map[string]any{"simulated": true, "points": pts, "initialPoints": InitialPoints, "stats": ComputeStats(bets)})
}

func (s *Service) handleMarkets(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	s.EnsureWindows(ctx) // 首次请求兜底：后台任务未运行时也有当前窗口
	ms, err := s.Repo.ListOpenMarkets(ctx, s.now())
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	cat := strings.ToUpper(strings.TrimSpace(r.URL.Query().Get("category")))
	updown, events := []MarketView{}, []MarketView{}
	for _, m := range ms {
		if cat != "" && cat != "ALL" && m.Category != cat {
			continue
		}
		if m.Kind == KindUpDown {
			updown = append(updown, s.view(m))
		} else {
			events = append(events, s.view(m))
		}
	}
	httpx.OK(w, map[string]any{"simulated": true, "serverTime": s.now().UTC(), "updown": updown, "events": events})
}

func (s *Service) handleMarket(w http.ResponseWriter, r *http.Request) {
	m, err := s.Repo.GetMarket(r.Context(), r.PathValue("id"))
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	if m == nil {
		s.fail(w, r, ErrNotFound)
		return
	}
	httpx.OK(w, s.view(*m))
}

func (s *Service) handleBet(w http.ResponseWriter, r *http.Request) {
	var req struct {
		MarketID string          `json:"marketId"`
		Outcome  string          `json:"outcome"`
		Stake    json.RawMessage `json:"stake"`
	}
	if err := httpx.Decode(w, r, 4<<10, &req); err != nil {
		httpx.Fail(w, r, err)
		return
	}
	var stake int64
	if err := json.Unmarshal(req.Stake, &stake); err != nil {
		s.fail(w, r, ErrStake)
		return
	}
	ctx := r.Context()
	b, pts, m, err := s.Repo.PlaceBet(ctx, httpx.UserID(ctx), strings.TrimSpace(req.MarketID), strings.ToUpper(strings.TrimSpace(req.Outcome)), stake, s.now())
	if err != nil {
		s.fail(w, r, err)
		return
	}
	mv := s.view(m)
	httpx.OK(w, map[string]any{"simulated": true, "bet": betView(b, &mv), "points": pts, "market": mv})
}

func (s *Service) handleBets(w http.ResponseWriter, r *http.Request) {
	ctx, uid := r.Context(), httpx.UserID(r.Context())
	bets, err := s.Repo.ListBets(ctx, uid)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	cache := map[string]*MarketView{}
	out := make([]BetView, 0, len(bets))
	for _, b := range bets {
		mv, ok := cache[b.MarketID]
		if !ok {
			if m, err := s.Repo.GetMarket(ctx, b.MarketID); err == nil && m != nil {
				v := s.view(*m)
				mv = &v
			}
			cache[b.MarketID] = mv
		}
		out = append(out, betView(b, mv))
	}
	httpx.OK(w, map[string]any{"simulated": true, "bets": out, "stats": ComputeStats(bets)})
}

func (s *Service) handleClaim(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	amt, pts, err := s.Repo.Claim(ctx, httpx.UserID(ctx), s.now())
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	httpx.OK(w, map[string]any{"simulated": true, "claimed": amt, "points": pts})
}

func round2(f float64) float64 { return float64(int64(f*100+0.5)) / 100 }
