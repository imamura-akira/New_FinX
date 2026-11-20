package papertrade

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"sort"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/httpx"
)

// ---------- 内存仓储（WithBook 深拷贝，模拟事务：fn 出错不保存） ----------

type memRepo struct {
	mu     sync.Mutex
	books  map[string]*Book
	orders map[string][]Order // userID → 全部订单
}

func newMem() *memRepo { return &memRepo{books: map[string]*Book{}, orders: map[string][]Order{}} }

func cloneOrder(o *Order) *Order { c := *o; return &c }

func (m *memRepo) WithBook(_ context.Context, uid string, initial int64, fn func(*Book) error) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	src := m.books[uid]
	b := NewBook(uid, initial)
	if src != nil {
		b.IsNew = false
		b.Initial, b.Cash, b.ResetAt = src.Initial, src.Cash, src.ResetAt
		for k, p := range src.Pos {
			c := *p
			b.Pos[k] = &c
		}
	}
	for _, o := range m.orders[uid] {
		if o.Status == StatusNew {
			b.Open = append(b.Open, cloneOrder(&o))
		}
	}
	if err := fn(b); err != nil {
		return err
	}
	if b.WasReset {
		m.orders[uid] = nil
	}
	m.books[uid] = &Book{Initial: b.Initial, Cash: b.Cash, ResetAt: b.ResetAt, Pos: b.Pos}
	for _, o := range b.Added {
		m.orders[uid] = append(m.orders[uid], *o)
	}
	for id, o := range b.Touched {
		for i := range m.orders[uid] {
			if m.orders[uid][i].ID == id {
				m.orders[uid][i] = *o
			}
		}
	}
	return nil
}

func (m *memRepo) ListOrders(_ context.Context, uid, filter string, before *time.Time, limit int) ([]Order, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := []Order{}
	for _, o := range m.orders[uid] {
		if filter != "" && (filter == "OPEN") != (o.Status == StatusNew) {
			continue
		}
		if before != nil && !o.SubmittedAt.Before(*before) {
			continue
		}
		out = append(out, o)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].SubmittedAt.After(out[j].SubmittedAt) })
	if len(out) > limit {
		out = out[:limit]
	}
	return out, nil
}

func (m *memRepo) GetOrder(_ context.Context, uid, id string) (*Order, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, o := range m.orders[uid] {
		if o.ID == id {
			return &o, nil
		}
	}
	return nil, ErrNotFound
}

func (m *memRepo) UsersWithOpenOrders(context.Context) ([]string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var out []string
	for uid, list := range m.orders {
		for _, o := range list {
			if o.Status == StatusNew {
				out = append(out, uid)
				break
			}
		}
	}
	return out, nil
}

// ---------- 夹具 ----------

type fx struct {
	svc    *Service
	repo   *memRepo
	mux    *http.ServeMux
	quotes map[string]Quote
	now    time.Time
	user   string
}

func newFx(t *testing.T) *fx {
	t.Helper()
	f := &fx{repo: newMem(), user: "u1", now: time.Date(2026, 11, 20, 15, 0, 0, 0, time.UTC), quotes: map[string]Quote{
		"AAPL": {Bid: 199.9, Ask: 200, Last: 199.95},
		"TSLA": {Bid: 249.5, Ask: 250.5, Last: 250},
	}}
	f.svc = New(Deps{
		Repo: f.repo, InitialCash: 100000, MinOrder: 1, Logger: slog.New(slog.NewTextHandler(io.Discard, nil)),
		Quote:     func(s string) (Quote, bool) { q, ok := f.quotes[s]; return q, ok },
		PrevClose: func(s string) float64 { return map[string]float64{"AAPL": 190}[s] },
	})
	f.svc.now = func() time.Time { return f.now }
	f.mux = http.NewServeMux()
	f.svc.Routes(f.mux, "/api/v1", func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			next.ServeHTTP(w, r.WithContext(httpx.WithUser(r.Context(), f.user)))
		})
	})
	return f
}

type res struct {
	HTTP int
	Code int             `json:"code"`
	Msg  string          `json:"message"`
	Data json.RawMessage `json:"data"`
}

func (f *fx) call(method, path, body string) res {
	var rd io.Reader
	if body != "" {
		rd = strings.NewReader(body)
	}
	req := httptest.NewRequest(method, path, rd)
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	f.mux.ServeHTTP(rec, req)
	var r res
	_ = json.Unmarshal(rec.Body.Bytes(), &r)
	r.HTTP = rec.Code
	return r
}

func (r res) m() map[string]any {
	var m map[string]any
	_ = json.Unmarshal(r.Data, &m)
	return m
}

func (f *fx) account(t *testing.T) map[string]any {
	t.Helper()
	r := f.call("GET", "/api/v1/paper/account", "")
	if r.Code != 0 {
		t.Fatalf("account: %+v", r)
	}
	return r.m()
}

// ---------- 账户 ----------

func TestAccountCreatedWithInitialCash(t *testing.T) {
	f := newFx(t)
	a := f.account(t)
	want := map[string]any{"simulated": true, "initialCash": 100000.0, "cash": 100000.0, "buyingPower": 100000.0, "reservedCash": 0.0,
		"positionsValue": 0.0, "totalValue": 100000.0, "totalPL": 0.0}
	for k, v := range want {
		if a[k] != v {
			t.Fatalf("%s = %v，期望 %v", k, a[k], v)
		}
	}
}

// ---------- 下单校验（表驱动） ----------

func TestCreateValidation(t *testing.T) {
	cases := []struct {
		name string
		body string
		code int
		msg  string
	}{
		{"市价按金额买入", `{"symbol":"aapl","side":"BUY","orderType":"MARKET","amount":1000}`, 0, ""},
		{"市价按股数买入", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","quantity":2.5}`, 0, ""},
		{"限价买入", `{"symbol":"AAPL","side":"BUY","orderType":"LIMIT","quantity":1,"limitPrice":195,"timeInForce":"DAY"}`, 0, ""},
		{"无演示行情", `{"symbol":"XYZ","side":"BUY","orderType":"MARKET","amount":10}`, 42200, ""},
		{"类型无效", `{"symbol":"AAPL","side":"BUY","orderType":"STOP","amount":10}`, 42200, ""},
		{"金额与股数同时", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","amount":10,"quantity":1}`, 42200, ""},
		{"限价单按金额", `{"symbol":"AAPL","side":"BUY","orderType":"LIMIT","amount":10,"quantity":1,"limitPrice":10}`, 42200, ""},
		{"限价为 0", `{"symbol":"AAPL","side":"BUY","orderType":"LIMIT","quantity":1,"limitPrice":0}`, 42200, ""},
		{"限价缺失", `{"symbol":"AAPL","side":"BUY","orderType":"LIMIT","quantity":1}`, 42200, ""},
		{"限价 $1 以上三位小数", `{"symbol":"AAPL","side":"BUY","orderType":"LIMIT","quantity":1,"limitPrice":195.123}`, 42200, ""},
		{"有效期 GTC 暂不支持", `{"symbol":"AAPL","side":"BUY","orderType":"LIMIT","quantity":1,"limitPrice":195,"timeInForce":"GTC"}`, 42200, ""},
		{"低于最低金额", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","amount":0.5}`, 42201, "单笔最低"},
		{"超过可用资金（市价）", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","quantity":501}`, 42201, "超过模拟账户可用资金 $100000.00"},
		{"超过可用资金（限价冻结按限价）", `{"symbol":"AAPL","side":"BUY","orderType":"LIMIT","quantity":1000,"limitPrice":100.01}`, 42201, "超过模拟账户可用资金"},
		{"无持仓卖出", `{"symbol":"AAPL","side":"SELL","orderType":"MARKET","quantity":1}`, 42201, "没有可卖出的 AAPL 持仓"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			f := newFx(t)
			r := f.call("POST", "/api/v1/paper/orders", tc.body)
			if r.Code != tc.code || !strings.Contains(r.Msg, tc.msg) {
				t.Fatalf("code %d（%s %s），期望 %d / %q", r.Code, r.Msg, r.Data, tc.code, tc.msg)
			}
		})
	}
}

// ---------- 市价单即时撮合 ----------

func TestMarketBuySellRoundTrip(t *testing.T) {
	f := newFx(t)
	r := f.call("POST", "/api/v1/paper/orders", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","quantity":10}`)
	if r.Code != 0 || r.m()["status"] != StatusFilled {
		t.Fatalf("%+v %s", r, r.Data)
	}
	a := f.account(t)
	if a["cash"] != 98000.0 || a["positionsValue"] != 1999.5 || a["totalValue"] != 99999.5 || a["totalPL"] != -0.5 {
		t.Fatalf("买入后账户：%v", a)
	}
	// 订单视图：按卖一价成交
	var list []map[string]any
	_ = json.Unmarshal(f.call("GET", "/api/v1/paper/orders", "").Data, &list)
	if len(list) != 1 || list[0]["avgPrice"] != 200.0 || list[0]["filledQty"] != 10.0 || list[0]["totalAmount"] != 2000.0 || list[0]["simulated"] != true {
		t.Fatalf("订单：%v", list)
	}
	// 持仓
	var pos struct {
		EquityValue float64          `json:"equityValue"`
		Positions   []map[string]any `json:"positions"`
	}
	_ = json.Unmarshal(f.call("GET", "/api/v1/paper/positions", "").Data, &pos)
	p := pos.Positions[0]
	if p["quantity"] != 10.0 || p["costBasis"] != 2000.0 || p["marketValue"] != 1999.5 || p["unrealizedPL"] != -0.5 || p["unrealizedDayPL"] != 99.5 {
		t.Fatalf("持仓：%v", p)
	}
	// 涨价后卖出一半（按买一价）
	f.quotes["AAPL"] = Quote{Bid: 210, Ask: 210.1, Last: 210.05}
	r = f.call("POST", "/api/v1/paper/orders", `{"symbol":"AAPL","side":"SELL","orderType":"MARKET","quantity":5}`)
	if r.Code != 0 {
		t.Fatalf("%+v", r)
	}
	a = f.account(t)
	if a["cash"] != 99050.0 {
		t.Fatalf("卖出后现金：%v", a["cash"])
	}
	_ = json.Unmarshal(f.call("GET", "/api/v1/paper/positions", "").Data, &pos)
	if pos.Positions[0]["quantity"] != 5.0 || pos.Positions[0]["costBasis"] != 1000.0 {
		t.Fatalf("剩余持仓：%v", pos.Positions[0])
	}
	// 卖出超过持仓
	if r := f.call("POST", "/api/v1/paper/orders", `{"symbol":"AAPL","side":"SELL","orderType":"MARKET","quantity":5.1}`); r.Code != 42201 {
		t.Fatalf("%+v", r)
	}
	// 全部卖出后持仓清空
	f.call("POST", "/api/v1/paper/orders", `{"symbol":"AAPL","side":"SELL","orderType":"MARKET","quantity":5}`)
	_ = json.Unmarshal(f.call("GET", "/api/v1/paper/positions", "").Data, &pos)
	if len(pos.Positions) != 0 {
		t.Fatalf("应无持仓：%v", pos.Positions)
	}
}

func TestMarketBuyByAmountFractional(t *testing.T) {
	f := newFx(t)
	f.call("POST", "/api/v1/paper/orders", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","amount":100}`)
	var list []map[string]any
	_ = json.Unmarshal(f.call("GET", "/api/v1/paper/orders", "").Data, &list)
	if list[0]["filledQty"] != 0.5 || list[0]["amount"] != 100.0 || list[0]["quantity"] != nil {
		t.Fatalf("%v", list[0])
	}
}

// ---------- 限价单 ----------

func TestLimitOrderRestsReservesAndFills(t *testing.T) {
	f := newFx(t)
	r := f.call("POST", "/api/v1/paper/orders", `{"symbol":"AAPL","side":"BUY","orderType":"LIMIT","quantity":10,"limitPrice":195}`)
	if r.m()["status"] != StatusNew {
		t.Fatalf("未到价应挂单：%s", r.Data)
	}
	id := r.m()["orderId"].(string)
	a := f.account(t)
	if a["reservedCash"] != 1950.0 || a["buyingPower"] != 98050.0 || a["cash"] != 100000.0 {
		t.Fatalf("冻结按限价计算：%v", a)
	}
	// 价格未到：不成交
	f.svc.MatchAll(context.Background())
	if o := f.call("GET", "/api/v1/paper/orders/"+id, "").m(); o["status"] != StatusNew {
		t.Fatalf("%v", o)
	}
	// 卖一价跌到限价以下：按卖一价成交，释放冻结
	f.quotes["AAPL"] = Quote{Bid: 194, Ask: 194.5, Last: 194.2}
	f.svc.MatchAll(context.Background())
	o := f.call("GET", "/api/v1/paper/orders/"+id, "").m()
	if o["status"] != StatusFilled || o["avgPrice"] != 194.5 || o["limitPrice"] != 195.0 || o["timeInForce"] != "DAY" {
		t.Fatalf("应按卖一价成交：%v", o)
	}
	a = f.account(t)
	if a["reservedCash"] != 0.0 || a["cash"] != 98055.0 {
		t.Fatalf("成交后：%v", a)
	}
}

func TestLimitMarketableFillsImmediately(t *testing.T) {
	f := newFx(t)
	r := f.call("POST", "/api/v1/paper/orders", `{"symbol":"AAPL","side":"BUY","orderType":"LIMIT","quantity":1,"limitPrice":205}`)
	o := f.call("GET", "/api/v1/paper/orders/"+r.m()["orderId"].(string), "").m()
	if o["status"] != StatusFilled || o["avgPrice"] != 200.0 {
		t.Fatalf("限价高于卖一价应立即按卖一价成交：%v", o)
	}
}

func TestLimitSellReservesShares(t *testing.T) {
	f := newFx(t)
	f.call("POST", "/api/v1/paper/orders", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","quantity":10}`)
	r := f.call("POST", "/api/v1/paper/orders", `{"symbol":"AAPL","side":"SELL","orderType":"LIMIT","quantity":6,"limitPrice":220}`)
	if r.m()["status"] != StatusNew {
		t.Fatalf("%s", r.Data)
	}
	// 冻结 6 股后只能再卖 4 股
	if r := f.call("POST", "/api/v1/paper/orders", `{"symbol":"AAPL","side":"SELL","orderType":"MARKET","quantity":5}`); r.Code != 42201 || !strings.Contains(r.Msg, "4 股") {
		t.Fatalf("%+v", r)
	}
	var pos struct{ Positions []map[string]any }
	_ = json.Unmarshal(f.call("GET", "/api/v1/paper/positions", "").Data, &pos)
	if pos.Positions[0]["sellableQty"] != 4.0 {
		t.Fatalf("%v", pos.Positions[0])
	}
	f.quotes["AAPL"] = Quote{Bid: 221, Ask: 221.2, Last: 221.1}
	f.svc.MatchAll(context.Background())
	o := f.call("GET", "/api/v1/paper/orders/"+r.m()["orderId"].(string), "").m()
	if o["status"] != StatusFilled || o["avgPrice"] != 221.0 {
		t.Fatalf("%v", o)
	}
}

func TestCancelAndDayExpiry(t *testing.T) {
	f := newFx(t)
	r := f.call("POST", "/api/v1/paper/orders", `{"symbol":"AAPL","side":"BUY","orderType":"LIMIT","quantity":10,"limitPrice":195}`)
	id := r.m()["orderId"].(string)
	if c := f.call("POST", "/api/v1/paper/orders/"+id+"/cancel", ""); c.Code != 0 || c.m()["status"] != StatusCanceled {
		t.Fatalf("%+v", c)
	}
	if a := f.account(t); a["reservedCash"] != 0.0 || a["buyingPower"] != 100000.0 {
		t.Fatalf("撤单释放冻结：%v", a)
	}
	if c := f.call("POST", "/api/v1/paper/orders/"+id+"/cancel", ""); c.Code != 40901 {
		t.Fatalf("已撤销不可再撤：%+v", c)
	}
	// 当日有效：美东跨日后过期
	r = f.call("POST", "/api/v1/paper/orders", `{"symbol":"AAPL","side":"BUY","orderType":"LIMIT","quantity":1,"limitPrice":150}`)
	id2 := r.m()["orderId"].(string)
	f.now = f.now.Add(24 * time.Hour)
	o := f.call("GET", "/api/v1/paper/orders/"+id2, "").m()
	if o["status"] != StatusCanceled || !strings.Contains(o["rejectReason"].(string), "当日有效") {
		t.Fatalf("应过期：%v", o)
	}
}

func TestResetRestoresInitialCash(t *testing.T) {
	f := newFx(t)
	f.call("POST", "/api/v1/paper/orders", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","quantity":10}`)
	f.call("POST", "/api/v1/paper/orders", `{"symbol":"AAPL","side":"BUY","orderType":"LIMIT","quantity":1,"limitPrice":150}`)
	r := f.call("POST", "/api/v1/paper/account/reset", "")
	a := r.m()
	if r.Code != 0 || a["cash"] != 100000.0 || a["positionsValue"] != 0.0 || a["reservedCash"] != 0.0 || a["resetAt"] == nil {
		t.Fatalf("%+v %s", r, r.Data)
	}
	var list []any
	_ = json.Unmarshal(f.call("GET", "/api/v1/paper/orders", "").Data, &list)
	if len(list) != 0 {
		t.Fatal("重置后订单清空")
	}
}

func TestUsersAreIsolated(t *testing.T) {
	f := newFx(t)
	r := f.call("POST", "/api/v1/paper/orders", `{"symbol":"AAPL","side":"BUY","orderType":"LIMIT","quantity":1,"limitPrice":150}`)
	id := r.m()["orderId"].(string)
	f.user = "u2"
	if g := f.call("GET", "/api/v1/paper/orders/"+id, ""); g.Code != 40901 {
		t.Fatalf("不能读取他人模拟订单：%+v", g)
	}
	if c := f.call("POST", "/api/v1/paper/orders/"+id+"/cancel", ""); c.Code != 40901 {
		t.Fatalf("不能撤他人模拟订单：%+v", c)
	}
	if a := f.account(t); a["cash"] != 100000.0 {
		t.Fatalf("u2 独立账户：%v", a)
	}
}

func TestListFilter(t *testing.T) {
	f := newFx(t)
	f.call("POST", "/api/v1/paper/orders", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","quantity":1}`)
	f.now = f.now.Add(time.Second)
	f.call("POST", "/api/v1/paper/orders", `{"symbol":"AAPL","side":"BUY","orderType":"LIMIT","quantity":1,"limitPrice":150}`)
	for q, n := range map[string]int{"": 2, "?status=OPEN": 1, "?status=CLOSED": 1} {
		var list []any
		r := f.call("GET", "/api/v1/paper/orders"+q, "")
		_ = json.Unmarshal(r.Data, &list)
		if len(list) != n {
			t.Fatalf("%s：%d 条，期望 %d", q, len(list), n)
		}
	}
	if r := f.call("GET", "/api/v1/paper/orders?status=X", ""); r.Code != 42200 {
		t.Fatalf("%+v", r)
	}
}

func TestParseLimitPrice(t *testing.T) {
	ok := map[string]float64{"195": 195, "195.5": 195.5, "0.1234": 0.1234, "1.25": 1.25}
	for in, want := range ok {
		if got, err := ParseLimitPrice(json.RawMessage(in)); err != nil || got != want {
			t.Errorf("%s → %v %v", in, got, err)
		}
	}
	for _, in := range []string{"0", "-1", `"10"`, "null", "1.234", "0.12345"} {
		if _, err := ParseLimitPrice(json.RawMessage(in)); err == nil {
			t.Errorf("%s 应被拒绝", in)
		}
	}
}
