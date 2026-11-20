// Package papertrade：模拟交易（F15，模拟盘，演示与练习用途；api-spec.md 5.7）。
//
// 全部在我方后端实现，不调用 DW；数据与真实账户、DW 资金数字完全分开（独立表 paper_*）。
// 撮合：按虚拟行情（F11）当前价即时撮合——市价买入按卖一价、卖出按买一价；限价单在价格到达时成交
// （买入：卖一价 ≤ 限价；卖出：买一价 ≥ 限价），未成交前冻结资金 / 股数，当日有效（美东日切后过期）。
//
// 金额以"分"为单位的整数计算，股数保留 6 位小数。
package papertrade

import (
	"errors"
	"math"
	"sort"
	"strconv"
	"time"
)

// 订单状态。
const (
	StatusNew      = "NEW"
	StatusFilled   = "FILLED"
	StatusCanceled = "CANCELED"
	StatusRejected = "REJECTED"
)

// Quote：撮合用报价（虚拟行情）。
type Quote struct{ Bid, Ask, Last float64 }

// Order：模拟订单。
type Order struct {
	ID          string
	UserID      string
	Symbol      string
	Side        string // BUY / SELL
	Type        string // MARKET / LIMIT
	Qty         *float64
	Notional    *int64 // 分
	Limit       *float64
	TIF         string
	Status      string
	Reserved    int64 // 限价买单冻结金额（分）
	FilledQty   *float64
	AvgPrice    *float64
	Total       *int64 // 成交金额（分）
	Reason      *string
	SubmittedAt time.Time
	DoneAt      *time.Time
	UpdatedAt   time.Time
}

// Position：模拟持仓。
type Position struct {
	Symbol string
	Qty    float64
	Cost   int64 // 成本（分）
}

// Book：一个用户的模拟账户（在仓储的锁内加载、修改、保存）。
type Book struct {
	UserID   string
	Initial  int64 // 初始资金（分）
	Cash     int64 // 现金（分，含冻结部分）
	ResetAt  *time.Time
	Pos      map[string]*Position
	Open     []*Order // 未成交（NEW）订单
	Added    []*Order // 本次新增的订单（保存时插入）
	Touched  map[string]*Order
	IsNew    bool // 账户首次创建
	WasReset bool
}

// NewBook 创建初始资金为 initial（分）的空账户。
func NewBook(userID string, initial int64) *Book {
	return &Book{UserID: userID, Initial: initial, Cash: initial, Pos: map[string]*Position{}, Touched: map[string]*Order{}, IsNew: true}
}

func (b *Book) touch(o *Order) {
	if b.Touched == nil {
		b.Touched = map[string]*Order{}
	}
	b.Touched[o.ID] = o
}

// Reserved：限价买单冻结的资金（分）。
func (b *Book) Reserved() int64 {
	var n int64
	for _, o := range b.Open {
		if o.Side == "BUY" {
			n += o.Reserved
		}
	}
	return n
}

// Available：可用资金 = 现金 − 冻结。
func (b *Book) Available() int64 { return b.Cash - b.Reserved() }

// Sellable：可卖股数 = 持仓 − 限价卖单冻结。
func (b *Book) Sellable(symbol string) float64 {
	p := b.Pos[symbol]
	if p == nil {
		return 0
	}
	q := p.Qty
	for _, o := range b.Open {
		if o.Side == "SELL" && o.Symbol == symbol && o.Qty != nil {
			q -= *o.Qty
		}
	}
	return round6(math.Max(0, q))
}

// Reset 恢复初始资金，清空持仓与订单。
func (b *Book) Reset(now time.Time) {
	b.Cash = b.Initial
	b.Pos = map[string]*Position{}
	b.Open = nil
	b.Added = nil
	b.Touched = map[string]*Order{}
	b.ResetAt = &now
	b.WasReset = true
}

// ---------- 下单 ----------

// Request：下单请求（已通过格式校验）。
type Request struct {
	Symbol   string
	Side     string
	Type     string
	Qty      *float64
	Notional *int64
	Limit    *float64
}

// LimitError：超出可用资金 / 可卖数量 / 最低金额（对应 42201）。
type LimitError struct {
	Msg    string
	Limits map[string]string
}

func (e *LimitError) Error() string { return e.Msg }

// ErrNoQuote：没有该股票的演示行情。
var ErrNoQuote = errors.New("该股票暂无演示行情，无法模拟交易")

// Place 下单并立即尝试撮合。minOrder 为单笔最低金额（分）。
func (b *Book) Place(id string, r Request, q Quote, minOrder int64, now time.Time) (*Order, error) {
	o := &Order{ID: id, UserID: b.UserID, Symbol: r.Symbol, Side: r.Side, Type: r.Type, Qty: r.Qty, Notional: r.Notional, Limit: r.Limit,
		TIF: "DAY", Status: StatusNew, SubmittedAt: now, UpdatedAt: now}
	limits := map[string]string{"min": cents2(minOrder)}
	if r.Type == "LIMIT" {
		if r.Side == "BUY" {
			o.Reserved = ceilCents(*r.Qty * *r.Limit)
			if o.Reserved < minOrder {
				return nil, &LimitError{"单笔最低 $" + cents2(minOrder) + "（示例值）", limits}
			}
			if o.Reserved > b.Available() {
				limits["buyingPower"] = cents2(b.Available())
				return nil, &LimitError{"超过模拟账户可用资金 $" + cents2(b.Available()), limits}
			}
		} else if *r.Qty > b.Sellable(r.Symbol)+1e-9 {
			limits["sellableQty"] = fmtQty(b.Sellable(r.Symbol))
			return nil, &LimitError{sellMsg(r.Symbol, b.Sellable(r.Symbol)), limits}
		}
		b.Open = append(b.Open, o)
		b.Added = append(b.Added, o)
		b.tryFill(o, q, now)
		return o, nil
	}

	// 市价单：立即成交
	price := q.Ask
	if r.Side == "SELL" {
		price = q.Bid
	}
	if price <= 0 {
		price = q.Last
	}
	if price <= 0 {
		return nil, ErrNoQuote
	}
	var qty float64
	if r.Notional != nil {
		if *r.Notional < minOrder {
			return nil, &LimitError{"单笔最低 $" + cents2(minOrder) + "（示例值）", limits}
		}
		qty = floor6(float64(*r.Notional) / 100 / price)
		if qty <= 0 {
			return nil, &LimitError{"金额过小，不足以成交", limits}
		}
	} else {
		qty = *r.Qty
	}
	amount := roundCents(qty * price)
	if r.Side == "BUY" {
		if amount < minOrder {
			return nil, &LimitError{"单笔最低 $" + cents2(minOrder) + "（示例值）", limits}
		}
		if amount > b.Available() {
			limits["buyingPower"] = cents2(b.Available())
			return nil, &LimitError{"超过模拟账户可用资金 $" + cents2(b.Available()), limits}
		}
	} else if qty > b.Sellable(r.Symbol)+1e-9 {
		limits["sellableQty"] = fmtQty(b.Sellable(r.Symbol))
		return nil, &LimitError{sellMsg(r.Symbol, b.Sellable(r.Symbol)), limits}
	}
	b.Added = append(b.Added, o)
	b.fill(o, qty, price, amount, now)
	return o, nil
}

func sellMsg(sym string, sellable float64) string {
	if sellable <= 0 {
		return "模拟账户没有可卖出的 " + sym + " 持仓"
	}
	return "超过可卖数量 " + fmtQty(sellable) + " 股"
}

// fill 以 price 成交 qty 股，金额 amount（分），更新现金与持仓。
func (b *Book) fill(o *Order, qty, price float64, amount int64, now time.Time) {
	if o.Side == "BUY" {
		b.Cash -= amount
		p := b.Pos[o.Symbol]
		if p == nil {
			p = &Position{Symbol: o.Symbol}
			b.Pos[o.Symbol] = p
		}
		p.Qty = round6(p.Qty + qty)
		p.Cost += amount
	} else {
		b.Cash += amount
		p := b.Pos[o.Symbol]
		if p != nil {
			if qty >= p.Qty-1e-9 {
				delete(b.Pos, o.Symbol)
			} else {
				p.Cost -= roundCents(float64(p.Cost) / 100 * qty / p.Qty)
				p.Qty = round6(p.Qty - qty)
			}
		}
	}
	o.Status, o.Reserved = StatusFilled, 0
	o.FilledQty, o.AvgPrice, o.Total = &qty, &price, &amount
	o.DoneAt, o.UpdatedAt = &now, now
	b.removeOpen(o.ID)
	b.touch(o)
}

func (b *Book) removeOpen(id string) {
	for i, x := range b.Open {
		if x.ID == id {
			b.Open = append(b.Open[:i], b.Open[i+1:]...)
			return
		}
	}
}

// tryFill：限价单价格到达时成交（买入按卖一价、卖出按买一价，均不劣于限价）。返回是否成交。
func (b *Book) tryFill(o *Order, q Quote, now time.Time) bool {
	if o.Status != StatusNew || o.Type != "LIMIT" || o.Qty == nil || o.Limit == nil {
		return false
	}
	qty := *o.Qty
	if o.Side == "BUY" {
		if q.Ask <= 0 || q.Ask > *o.Limit {
			return false
		}
		o.Reserved = 0 // 先释放冻结，再按实际价格扣款（实际金额 ≤ 冻结金额）
		b.fill(o, qty, q.Ask, roundCents(qty*q.Ask), now)
		return true
	}
	if q.Bid <= 0 || q.Bid < *o.Limit {
		return false
	}
	b.fill(o, qty, q.Bid, roundCents(qty*q.Bid), now)
	return true
}

// Match 撮合全部未成交限价单；DAY 订单跨美东日后过期撤销。返回是否有变化。
func (b *Book) Match(quote func(string) (Quote, bool), now time.Time, et *time.Location) bool {
	changed := false
	for _, o := range append([]*Order(nil), b.Open...) {
		if o.TIF == "DAY" && !sameDay(o.SubmittedAt, now, et) {
			b.cancel(o, "当日有效订单已过期，未成交部分已撤销", now)
			changed = true
			continue
		}
		if q, ok := quote(o.Symbol); ok && b.tryFill(o, q, now) {
			changed = true
		}
	}
	return changed
}

// Cancel 撤销未成交订单；不存在或已结束返回 false。
func (b *Book) Cancel(id string, now time.Time) bool {
	for _, o := range b.Open {
		if o.ID == id {
			b.cancel(o, "", now)
			return true
		}
	}
	return false
}

func (b *Book) cancel(o *Order, reason string, now time.Time) {
	o.Status, o.Reserved, o.DoneAt, o.UpdatedAt = StatusCanceled, 0, &now, now
	if reason != "" {
		o.Reason = &reason
	}
	b.removeOpen(o.ID)
	b.touch(o)
}

// ---------- 估值 ----------

// Valuation：账户估值（按虚拟行情最新价）。
type Valuation struct {
	PositionsValue int64
	Positions      []PositionView
}

// PositionView：持仓视图。
type PositionView struct {
	Symbol          string
	Qty, Sellable   float64
	AvgPrice, Price float64
	Cost, Value, PL int64
	DayPL           int64
}

// Value 按 quote 估值；无报价的持仓按成本估值。
func (b *Book) Value(quote func(string) (Quote, bool), prevClose func(string) float64) Valuation {
	var v Valuation
	syms := make([]string, 0, len(b.Pos))
	for s := range b.Pos {
		syms = append(syms, s)
	}
	sort.Strings(syms)
	for _, s := range syms {
		p := b.Pos[s]
		price := float64(p.Cost) / 100 / p.Qty
		if q, ok := quote(s); ok && q.Last > 0 {
			price = q.Last
		}
		val := roundCents(p.Qty * price)
		pv := PositionView{Symbol: s, Qty: p.Qty, Sellable: b.Sellable(s), AvgPrice: round6(float64(p.Cost) / 100 / p.Qty), Price: price,
			Cost: p.Cost, Value: val, PL: val - p.Cost}
		if prevClose != nil {
			if pc := prevClose(s); pc > 0 {
				pv.DayPL = roundCents(p.Qty * (price - pc))
			}
		}
		v.PositionsValue += val
		v.Positions = append(v.Positions, pv)
	}
	return v
}

// ---------- 数值工具 ----------

func roundCents(usd float64) int64 { return int64(math.Round(usd * 100)) }
func ceilCents(usd float64) int64  { return int64(math.Ceil(usd*100 - 1e-6)) }
func floor6(f float64) float64     { return math.Floor(f*1e6+1e-6) / 1e6 }
func round6(f float64) float64     { return math.Round(f*1e6) / 1e6 }
func fmtQty(f float64) string      { return strconv.FormatFloat(round6(f), 'f', -1, 64) }

func cents2(c int64) string {
	neg := ""
	if c < 0 {
		neg, c = "-", -c
	}
	return neg + strconv.FormatInt(c/100, 10) + "." + pad2(c%100)
}

func pad2(n int64) string {
	if n < 10 {
		return "0" + strconv.FormatInt(n, 10)
	}
	return strconv.FormatInt(n, 10)
}

func sameDay(a, b time.Time, loc *time.Location) bool {
	ya, ma, da := a.In(loc).Date()
	yb, mb, db := b.In(loc).Date()
	return ya == yb && ma == mb && da == db
}
