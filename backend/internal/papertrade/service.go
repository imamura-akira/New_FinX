package papertrade

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"math/big"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"
	_ "time/tzdata" // 美东日切（当日有效订单过期）

	"github.com/imamura-akira/New_FinX/backend/internal/funding"
	"github.com/imamura-akira/New_FinX/backend/internal/httpx"
)

// Deps：外部依赖（不含 DW）。
type Deps struct {
	Repo        Repo
	Quote       func(symbol string) (Quote, bool) // 虚拟行情报价
	PrevClose   func(symbol string) float64       // 昨收（当日盈亏）
	InitialCash float64                           // 模拟初始资金（USD，配置 PAPER_INITIAL_CASH）
	MinOrder    float64                           // 单笔最低金额（USD，与实盘 LIMIT_MIN_ORDER 一致）
	Logger      *slog.Logger
}

// Service：模拟盘模块。
type Service struct {
	Deps
	now func() time.Time
	et  *time.Location
}

// New 创建模块。
func New(d Deps) *Service {
	if d.Logger == nil {
		d.Logger = slog.Default()
	}
	if d.InitialCash <= 0 {
		d.InitialCash = 100000
	}
	if d.MinOrder <= 0 {
		d.MinOrder = 1
	}
	et, err := time.LoadLocation("America/New_York")
	if err != nil {
		et = time.UTC
	}
	return &Service{Deps: d, now: time.Now, et: et}
}

// Routes 注册接口（api-spec.md 5.7，均需登录；不要求已开立 DW 账户）。
func (s *Service) Routes(mux *http.ServeMux, prefix string, auth func(http.Handler) http.Handler) {
	h := func(f http.HandlerFunc) http.Handler { return auth(f) }
	mux.Handle("GET "+prefix+"/paper/account", h(s.handleAccount))
	mux.Handle("POST "+prefix+"/paper/account/reset", h(s.handleReset))
	mux.Handle("POST "+prefix+"/paper/orders", h(s.handleCreate))
	mux.Handle("GET "+prefix+"/paper/orders", h(s.handleList))
	mux.Handle("GET "+prefix+"/paper/orders/{id}", h(s.handleGet))
	mux.Handle("POST "+prefix+"/paper/orders/{id}/cancel", h(s.handleCancel))
	mux.Handle("GET "+prefix+"/paper/positions", h(s.handlePositions))
}

func (s *Service) initialCents() int64 { return funding.CentsOf(s.InitialCash) }

// withBook：加载（不存在则创建）当前用户的模拟账户，先撮合到期的限价单，再执行 fn。
func (s *Service) withBook(ctx context.Context, fn func(*Book) error) error {
	return s.Repo.WithBook(ctx, httpx.UserID(ctx), s.initialCents(), func(b *Book) error {
		b.Match(s.Quote, s.now().UTC(), s.et)
		if fn == nil {
			return nil
		}
		return fn(b)
	})
}

// RunMatcher 周期撮合所有用户的未成交限价单（虚拟行情变动后价格到达即成交）。
func (s *Service) RunMatcher(ctx context.Context, every time.Duration) {
	t := time.NewTicker(every)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			s.MatchAll(ctx)
		}
	}
}

// MatchAll 撮合一轮。
func (s *Service) MatchAll(ctx context.Context) {
	users, err := s.Repo.UsersWithOpenOrders(ctx)
	if err != nil {
		s.Logger.WarnContext(ctx, "paper matcher: list users failed", slog.String("error", err.Error()))
		return
	}
	for _, u := range users {
		err := s.Repo.WithBook(ctx, u, s.initialCents(), func(b *Book) error {
			b.Match(s.Quote, s.now().UTC(), s.et)
			return nil
		})
		if err != nil {
			s.Logger.WarnContext(ctx, "paper matcher: match failed", slog.String("error", err.Error()))
		}
	}
}

// ---------- 视图 ----------

func money(c int64) json.Number { return json.Number(cents2(c)) }

func num(f float64) json.Number { return json.Number(strconv.FormatFloat(f, 'f', -1, 64)) }

func optNum(f *float64) *json.Number {
	if f == nil {
		return nil
	}
	n := num(*f)
	return &n
}

func optMoney(c *int64) *json.Number {
	if c == nil {
		return nil
	}
	n := money(*c)
	return &n
}

// AccountView：GET /paper/account。
type AccountView struct {
	Simulated      bool        `json:"simulated"`
	InitialCash    json.Number `json:"initialCash"`
	Cash           json.Number `json:"cash"`
	ReservedCash   json.Number `json:"reservedCash"`
	BuyingPower    json.Number `json:"buyingPower"`
	PositionsValue json.Number `json:"positionsValue"`
	TotalValue     json.Number `json:"totalValue"`
	TotalPL        json.Number `json:"totalPL"`
	TotalPLPct     json.Number `json:"totalPLPct"`
	ResetAt        *time.Time  `json:"resetAt"`
	UpdatedAt      time.Time   `json:"updatedAt"`
}

func (s *Service) accountView(b *Book) AccountView {
	v := b.Value(s.Quote, s.PrevClose)
	total := b.Cash + v.PositionsValue
	pl := total - b.Initial
	pct := 0.0
	if b.Initial > 0 {
		pct = float64(pl) / float64(b.Initial) * 100
	}
	return AccountView{Simulated: true, InitialCash: money(b.Initial), Cash: money(b.Cash), ReservedCash: money(b.Reserved()),
		BuyingPower: money(b.Available()), PositionsValue: money(v.PositionsValue), TotalValue: money(total), TotalPL: money(pl),
		TotalPLPct: json.Number(strconv.FormatFloat(pct, 'f', 2, 64)), ResetAt: b.ResetAt, UpdatedAt: s.now().UTC()}
}

// OrderView：模拟订单（与实盘 Order 结构一致，另含 limitPrice、timeInForce、simulated）。
type OrderView struct {
	ID           string       `json:"orderId"`
	OrderNo      *string      `json:"orderNo"`
	Symbol       string       `json:"symbol"`
	Side         string       `json:"side"`
	OrderType    string       `json:"orderType"`
	Quantity     *json.Number `json:"quantity"`
	Amount       *json.Number `json:"amount"`
	LimitPrice   *json.Number `json:"limitPrice"`
	TimeInForce  string       `json:"timeInForce"`
	Status       string       `json:"status"`
	FilledQty    *json.Number `json:"filledQty"`
	AvgPrice     *json.Number `json:"avgPrice"`
	TotalAmount  *json.Number `json:"totalAmount"`
	Fees         json.Number  `json:"fees"`
	RejectReason *string      `json:"rejectReason"`
	SubmittedAt  time.Time    `json:"submittedAt"`
	UpdatedAt    time.Time    `json:"updatedAt"`
	DoneAt       *time.Time   `json:"doneAt"`
	Simulated    bool         `json:"simulated"`
}

func orderView(o Order) OrderView {
	return OrderView{ID: o.ID, Symbol: o.Symbol, Side: o.Side, OrderType: o.Type, Quantity: optNum(o.Qty), Amount: optMoney(o.Notional),
		LimitPrice: optNum(o.Limit), TimeInForce: o.TIF, Status: o.Status, FilledQty: optNum(o.FilledQty), AvgPrice: optNum(o.AvgPrice),
		TotalAmount: optMoney(o.Total), Fees: "0", RejectReason: o.Reason, SubmittedAt: o.SubmittedAt, UpdatedAt: o.UpdatedAt, DoneAt: o.DoneAt,
		Simulated: true}
}

// ---------- 账户 ----------

func (s *Service) handleAccount(w http.ResponseWriter, r *http.Request) {
	var v AccountView
	if err := s.withBook(r.Context(), func(b *Book) error { v = s.accountView(b); return nil }); err != nil {
		httpx.Fail(w, r, err)
		return
	}
	httpx.OK(w, v)
}

func (s *Service) handleReset(w http.ResponseWriter, r *http.Request) {
	var v AccountView
	err := s.Repo.WithBook(r.Context(), httpx.UserID(r.Context()), s.initialCents(), func(b *Book) error {
		b.Initial = s.initialCents() // 重置时按当前配置的初始资金
		b.Reset(s.now().UTC())
		v = s.accountView(b)
		return nil
	})
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	httpx.OK(w, v)
}

// ---------- 下单 ----------

var (
	symbolRE = regexp.MustCompile(`^[A-Z][A-Z0-9.]{0,9}$`)
	qtyRE    = regexp.MustCompile(`^\d{1,9}(\.\d{1,6})?$`)
)

func present(raw json.RawMessage) bool {
	t := strings.TrimSpace(string(raw))
	return t != "" && t != "null"
}

func parseQty(raw json.RawMessage) (float64, error) {
	t := strings.TrimSpace(string(raw))
	if !present(raw) || strings.HasPrefix(t, `"`) {
		return 0, errors.New("请输入股数")
	}
	if !qtyRE.MatchString(t) {
		return 0, errors.New("股数格式不正确（最多 6 位小数）")
	}
	r, ok := new(big.Rat).SetString(t)
	if !ok || r.Sign() <= 0 {
		return 0, errors.New("股数须大于 0")
	}
	f, _ := r.Float64()
	return f, nil
}

// ParseLimitPrice：限价 > 0；≥ $1 最多两位小数，< $1 最多四位小数（美股最小报价单位）。
func ParseLimitPrice(raw json.RawMessage) (float64, error) {
	t := strings.TrimSpace(string(raw))
	if !present(raw) || strings.HasPrefix(t, `"`) {
		return 0, errors.New("请输入限价")
	}
	if !regexp.MustCompile(`^\d{1,7}(\.\d{1,4})?$`).MatchString(t) {
		return 0, errors.New("限价格式不正确")
	}
	f, _ := strconv.ParseFloat(t, 64)
	if f <= 0 {
		return 0, errors.New("限价必须大于 0")
	}
	if dot := strings.IndexByte(t, '.'); f >= 1 && dot >= 0 && len(t)-dot-1 > 2 {
		return 0, errors.New("限价 $1 以上最多两位小数")
	}
	return f, nil
}

func newUUID() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:])
}

func (s *Service) handleCreate(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	var in struct {
		Symbol      string          `json:"symbol"`
		Side        string          `json:"side"`
		OrderType   string          `json:"orderType"`
		Amount      json.RawMessage `json:"amount"`
		Quantity    json.RawMessage `json:"quantity"`
		LimitPrice  json.RawMessage `json:"limitPrice"`
		TimeInForce string          `json:"timeInForce"`
	}
	if err := httpx.Decode(w, r, 0, &in); err != nil {
		httpx.Fail(w, r, err)
		return
	}
	req := Request{Symbol: strings.ToUpper(strings.TrimSpace(in.Symbol)), Side: in.Side, Type: in.OrderType}
	var fe []httpx.FieldError
	q, hasQuote := Quote{}, false
	if !symbolRE.MatchString(req.Symbol) {
		fe = append(fe, httpx.FieldError{Field: "symbol", Reason: "请选择要交易的股票"})
	} else if q, hasQuote = s.Quote(req.Symbol); !hasQuote {
		fe = append(fe, httpx.FieldError{Field: "symbol", Reason: ErrNoQuote.Error()})
	}
	if req.Side != "BUY" && req.Side != "SELL" {
		fe = append(fe, httpx.FieldError{Field: "side", Reason: "请选择买入或卖出"})
	}
	if in.TimeInForce != "" && in.TimeInForce != "DAY" {
		fe = append(fe, httpx.FieldError{Field: "timeInForce", Reason: "有效期目前只支持当日有效（DAY）"})
	}
	switch req.Type {
	case "MARKET":
		switch {
		case present(in.Amount) && present(in.Quantity):
			fe = append(fe, httpx.FieldError{Field: "amount", Reason: "金额与股数只能填写一项"})
		case present(in.Amount):
			c, err := funding.AmountFromJSON(in.Amount)
			if err != nil {
				fe = append(fe, httpx.FieldError{Field: "amount", Reason: err.Error()})
			}
			req.Notional = &c
		default:
			qty, err := parseQty(in.Quantity)
			if err != nil {
				fe = append(fe, httpx.FieldError{Field: "quantity", Reason: err.Error()})
			}
			req.Qty = &qty
		}
	case "LIMIT":
		if present(in.Amount) {
			fe = append(fe, httpx.FieldError{Field: "amount", Reason: "限价单请按股数下单"})
		}
		qty, err := parseQty(in.Quantity)
		if err != nil {
			fe = append(fe, httpx.FieldError{Field: "quantity", Reason: err.Error()})
		}
		lp, err := ParseLimitPrice(in.LimitPrice)
		if err != nil {
			fe = append(fe, httpx.FieldError{Field: "limitPrice", Reason: err.Error()})
		}
		req.Qty, req.Limit = &qty, &lp
	default:
		fe = append(fe, httpx.FieldError{Field: "orderType", Reason: "请选择市价单或限价单"})
	}
	if len(fe) > 0 {
		httpx.Fail(w, r, httpx.Validation("", fe...))
		return
	}

	var view OrderView
	err := s.withBook(ctx, func(b *Book) error {
		o, err := b.Place(newUUID(), req, q, funding.CentsOf(s.MinOrder), s.now().UTC())
		if err != nil {
			return err
		}
		view = orderView(*o)
		return nil
	})
	var le *LimitError
	switch {
	case errors.As(err, &le):
		httpx.Fail(w, r, &httpx.Error{HTTP: http.StatusUnprocessableEntity, Code: httpx.CodeLimit, Message: le.Msg, Data: map[string]any{"limits": le.Limits}})
		return
	case errors.Is(err, ErrNoQuote):
		httpx.Fail(w, r, httpx.Validation("", httpx.FieldError{Field: "symbol", Reason: err.Error()}))
		return
	case err != nil:
		httpx.Fail(w, r, err)
		return
	}
	httpx.OK(w, map[string]string{"orderId": view.ID, "status": view.Status})
}

// ---------- 订单 ----------

func (s *Service) handleList(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	filter := r.URL.Query().Get("status")
	if filter != "" && filter != "OPEN" && filter != "CLOSED" {
		httpx.Fail(w, r, httpx.Validation("", httpx.FieldError{Field: "status", Reason: "状态只能是 OPEN 或 CLOSED"}))
		return
	}
	var before *time.Time
	if c := r.URL.Query().Get("cursor"); c != "" {
		raw, err := base64.RawURLEncoding.DecodeString(c)
		t, perr := time.Parse(time.RFC3339Nano, string(raw))
		if err != nil || perr != nil {
			httpx.Fail(w, r, httpx.Validation("", httpx.FieldError{Field: "cursor", Reason: "翻页参数无效"}))
			return
		}
		before = &t
	}
	if err := s.withBook(ctx, nil); err != nil { // 先撮合，列表即为最新状态
		httpx.Fail(w, r, err)
		return
	}
	const page = 50
	list, err := s.Repo.ListOrders(ctx, httpx.UserID(ctx), filter, before, page)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	out := make([]OrderView, 0, len(list))
	for _, o := range list {
		out = append(out, orderView(o))
	}
	if len(list) == page {
		w.Header().Set("X-Next-Cursor", base64.RawURLEncoding.EncodeToString([]byte(list[len(list)-1].SubmittedAt.Format(time.RFC3339Nano))))
	}
	httpx.OK(w, out)
}

func (s *Service) handleGet(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if err := s.withBook(ctx, nil); err != nil {
		httpx.Fail(w, r, err)
		return
	}
	o, err := s.Repo.GetOrder(ctx, httpx.UserID(ctx), r.PathValue("id"))
	if errors.Is(err, ErrNotFound) {
		httpx.Fail(w, r, httpx.Conflict("订单不存在"))
		return
	}
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	httpx.OK(w, orderView(*o))
}

func (s *Service) handleCancel(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	id := r.PathValue("id")
	ok := false
	if err := s.withBook(ctx, func(b *Book) error { ok = b.Cancel(id, s.now().UTC()); return nil }); err != nil {
		httpx.Fail(w, r, err)
		return
	}
	if !ok {
		httpx.Fail(w, r, httpx.Conflict("该订单当前状态不可撤单"))
		return
	}
	httpx.OK(w, map[string]string{"orderId": id, "status": StatusCanceled})
}

// ---------- 持仓 ----------

// PositionOut：与实盘 Position 结构一致。
type PositionOut struct {
	Symbol          string      `json:"symbol"`
	Quantity        json.Number `json:"quantity"`
	SellableQty     json.Number `json:"sellableQty"`
	AvgPrice        json.Number `json:"avgPrice"`
	CostBasis       json.Number `json:"costBasis"`
	MarketPrice     json.Number `json:"marketPrice"`
	MarketValue     json.Number `json:"marketValue"`
	UnrealizedPL    json.Number `json:"unrealizedPL"`
	UnrealizedDayPL json.Number `json:"unrealizedDayPL"`
}

func (s *Service) handlePositions(w http.ResponseWriter, r *http.Request) {
	var out struct {
		Simulated   bool          `json:"simulated"`
		UpdatedAt   time.Time     `json:"updatedAt"`
		EquityValue json.Number   `json:"equityValue"`
		Positions   []PositionOut `json:"positions"`
	}
	err := s.withBook(r.Context(), func(b *Book) error {
		v := b.Value(s.Quote, s.PrevClose)
		out.Simulated, out.UpdatedAt, out.EquityValue, out.Positions = true, s.now().UTC(), money(v.PositionsValue), []PositionOut{}
		for _, p := range v.Positions {
			out.Positions = append(out.Positions, PositionOut{Symbol: p.Symbol, Quantity: num(p.Qty), SellableQty: num(p.Sellable),
				AvgPrice: num(p.AvgPrice), CostBasis: money(p.Cost), MarketPrice: num(p.Price), MarketValue: money(p.Value),
				UnrealizedPL: money(p.PL), UnrealizedDayPL: money(p.DayPL)})
		}
		return nil
	})
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	httpx.OK(w, out)
}
