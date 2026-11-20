package trading

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"sort"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/account"
	"github.com/imamura-akira/New_FinX/backend/internal/dwclient"
	"github.com/imamura-akira/New_FinX/backend/internal/httpx"
)

// ---------- 内存仓储 ----------

type memRepo struct {
	mu     sync.Mutex
	orders []Order
	seq    int
}

func (m *memRepo) find(id string) *Order {
	for i := range m.orders {
		if m.orders[i].ID == id {
			return &m.orders[i]
		}
	}
	return nil
}

func (m *memRepo) InsertOrder(_ context.Context, o Order) (string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.seq++
	o.ID = fmt.Sprintf("ord-%d", m.seq)
	o.SubmittedAt = time.Now().Add(time.Duration(m.seq) * time.Millisecond)
	o.UpdatedAt = o.SubmittedAt
	m.orders = append(m.orders, o)
	return o.ID, nil
}

func (m *memRepo) SetSubmitted(_ context.Context, id, dwID, dwNo string, now time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	o := m.find(id)
	o.DWOrderID, o.Status, o.UpdatedAt = dwID, StatusNew, now
	if dwNo != "" {
		o.OrderNo = &dwNo
	}
	return nil
}

func (m *memRepo) DeleteOrder(_ context.Context, id string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	for i, o := range m.orders {
		if o.ID == id && o.DWOrderID == "" {
			m.orders = append(m.orders[:i], m.orders[i+1:]...)
			break
		}
	}
	return nil
}

func eqNum(a, b *json.Number) bool {
	return (a == nil && b == nil) || (a != nil && b != nil && *a == *b)
}

func (m *memRepo) RecentDuplicate(_ context.Context, o Order, since time.Time) (bool, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, x := range m.orders {
		if x.AccountID == o.AccountID && x.Symbol == o.Symbol && x.Side == o.Side && eqNum(x.Quantity, o.Quantity) && eqNum(x.Amount, o.Amount) && !x.SubmittedAt.Before(since) {
			return true, nil
		}
	}
	return false, nil
}

func (m *memRepo) ListOrders(_ context.Context, acc, filter string, before *time.Time, limit int) ([]Order, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := []Order{}
	for _, o := range m.orders {
		if o.AccountID != acc || (before != nil && !o.SubmittedAt.Before(*before)) {
			continue
		}
		if filter != "" && (filter == "OPEN") != IsOpen(o.Status) {
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

func (m *memRepo) GetOrder(_ context.Context, acc, id string) (*Order, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	o := m.find(id)
	if o == nil || o.AccountID != acc {
		return nil, ErrNotFound
	}
	c := *o
	return &c, nil
}

func ptrNum(s *string) *json.Number {
	if s == nil {
		return nil
	}
	n := json.Number(*s)
	return &n
}

func (m *memRepo) UpdateOrder(_ context.Context, id string, f Fill, now time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	o := m.find(id)
	o.Status, o.FilledQty, o.AvgPrice, o.TotalAmount, o.Fees = f.Status, ptrNum(f.FilledQty), ptrNum(f.AvgPrice), ptrNum(f.TotalAmount), ptrNum(f.Fees)
	o.RejectReason, o.DWReason, o.UpdatedAt = f.RejectReason, f.DWReason, now
	if f.OrderNo != "" {
		no := f.OrderNo
		o.OrderNo = &no
	}
	if o.DoneAt == nil {
		o.DoneAt = f.DoneAt
	}
	return nil
}

func (m *memRepo) DueOrders(_ context.Context, _ time.Time, _ int) ([]Order, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var out []Order
	for _, o := range m.orders {
		if IsOpen(o.Status) {
			out = append(out, o)
		}
	}
	return out, nil
}

func (m *memRepo) TouchOrder(context.Context, string, time.Time) error { return nil }
func (m *memRepo) Audit(context.Context, string, string, string, map[string]any) error {
	return nil
}

// ---------- 假 DW ----------

type dwCall struct {
	method, path, idem string
	body               map[string]any
}

type fakeDW struct {
	mu    sync.Mutex
	calls []dwCall
	fail  map[string][]error  // "METHOD /path-prefix" → 依次返回的错误
	resp  map[string][]string // "METHOD /path-prefix" → 依次返回的 JSON（最后一个重复使用）
}

func (f *fakeDW) Do(ctx context.Context, method, path string, body, out any) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	var m map[string]any
	raw, _ := json.Marshal(body)
	_ = json.Unmarshal(raw, &m)
	f.calls = append(f.calls, dwCall{method, path, dwclient.IdempotencyKey(ctx), m})
	key := method + " " + path
	for k, errs := range f.fail {
		if strings.HasPrefix(key, k) && len(errs) > 0 {
			f.fail[k] = errs[1:]
			if errs[0] != nil {
				return errs[0]
			}
		}
	}
	// 最长前缀优先
	best := ""
	for k := range f.resp {
		if strings.HasPrefix(key, k) && len(k) > len(best) {
			best = k
		}
	}
	if best != "" && out != nil {
		list := f.resp[best]
		js := list[0]
		if len(list) > 1 {
			f.resp[best] = list[1:]
		}
		return json.Unmarshal([]byte(js), out)
	}
	return nil
}

func (f *fakeDW) count(prefix string) int {
	f.mu.Lock()
	defer f.mu.Unlock()
	n := 0
	for _, c := range f.calls {
		if strings.HasPrefix(c.method+" "+c.path, prefix) {
			n++
		}
	}
	return n
}

func (f *fakeDW) last(prefix string) *dwCall {
	f.mu.Lock()
	defer f.mu.Unlock()
	for i := len(f.calls) - 1; i >= 0; i-- {
		if strings.HasPrefix(f.calls[i].method+" "+f.calls[i].path, prefix) {
			return &f.calls[i]
		}
	}
	return nil
}

// ---------- 夹具 ----------

const (
	moneyJSON     = `{"cash":{"cashAvailableForTrade":500.25,"cashBalance":1000}}`
	positionsJSON = `{"accountID":"dwacc-1","updated":"2026-11-23T15:00:00Z","equityValue":1500.5,"equityPositions":[
		{"symbol":"AAPL","openQty":10.5,"availableForTradingQty":8.25,"avgPrice":100,"costBasis":1050,"mktPrice":120,"marketValue":1260,"unrealizedPL":210,"unrealizedDayPL":-5.5},
		{"symbol":"ZERO","openQty":0,"availableForTradingQty":0}]}`
	orderFilledJSON = `{"id":"DWO-1","orderNo":"FEAB000001","status":"FILLED","cumulativeQuantity":0.5,"averagePrice":199.9,"totalOrderAmount":99.95,"fees":0}`
)

type fx struct {
	svc  *Service
	repo *memRepo
	dw   *fakeDW
	mux  *http.ServeMux
	acct *account.Account
	now  time.Time
}

func newFx(t *testing.T) *fx {
	t.Helper()
	f := &fx{repo: &memRepo{}, dw: &fakeDW{fail: map[string][]error{}, resp: map[string][]string{
		"GET /accounts/dwacc-1/summary/money":     {moneyJSON},
		"GET /accounts/dwacc-1/summary/positions": {positionsJSON},
		"POST /orders":      {`{"orderId":"DWO-1","orderNo":"FEAB000001"}`},
		"GET /orders/DWO-1": {orderFilledJSON},
	}}}
	f.acct = &account.Account{ID: "acc-1", DWAccountID: "dwacc-1", DWUserID: "dwuser-1", AccountNo: "TEST000001", Status: "OPEN"}
	f.svc = New(Deps{
		Repo: f.repo, DW: f.dw, MinOrder: 1,
		Account: func(context.Context, string) (*account.Account, error) { return f.acct, nil },
		Price: func(sym string) (float64, bool) {
			p, ok := map[string]float64{"AAPL": 200, "TSLA": 250}[sym]
			return p, ok
		},
		Logger: slog.New(slog.NewTextHandler(io.Discard, nil)),
	})
	f.now = time.Date(2026, 11, 23, 15, 0, 0, 0, time.UTC)
	f.svc.now = func() time.Time { return time.Now() }
	f.mux = http.NewServeMux()
	f.svc.Routes(f.mux, "/api/v1", func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			next.ServeHTTP(w, r.WithContext(httpx.WithUser(r.Context(), "u1")))
		})
	})
	return f
}

type res struct {
	HTTP   int
	Header http.Header
	Code   int             `json:"code"`
	Msg    string          `json:"message"`
	Data   json.RawMessage `json:"data"`
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
	r.HTTP, r.Header = rec.Code, rec.Header()
	return r
}

func (r res) field(t *testing.T, k string) any {
	t.Helper()
	var m map[string]any
	_ = json.Unmarshal(r.Data, &m)
	return m[k]
}

// ---------- 下单校验（表驱动） ----------

func TestCreateOrderValidation(t *testing.T) {
	cases := []struct {
		name     string
		acct     string
		body     string
		wantHTTP int
		wantCode int
		wantMsg  string
		wantDW   bool // 是否调用了 DW POST /orders
	}{
		{"按金额买入（碎股）", "OPEN", `{"symbol":"aapl","side":"BUY","orderType":"MARKET","amount":100}`, 200, 0, "", true},
		{"按股数买入（小数股）", "OPEN", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","quantity":0.5}`, 200, 0, "", true},
		{"按股数卖出", "OPEN", `{"symbol":"AAPL","side":"SELL","orderType":"MARKET","quantity":8.25}`, 200, 0, "", true},
		{"按金额卖出", "OPEN", `{"symbol":"AAPL","side":"SELL","orderType":"MARKET","amount":990}`, 200, 0, "", true},
		{"限价单不支持", "OPEN", `{"symbol":"AAPL","side":"BUY","orderType":"LIMIT","amount":100}`, 422, 42200, "", false},
		{"金额与股数同时填写", "OPEN", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","amount":100,"quantity":1}`, 422, 42200, "", false},
		{"都不填", "OPEN", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET"}`, 422, 42200, "", false},
		{"股数超过 6 位小数", "OPEN", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","quantity":0.1234567}`, 422, 42200, "", false},
		{"金额为字符串", "OPEN", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","amount":"100"}`, 422, 42200, "", false},
		{"方向无效", "OPEN", `{"symbol":"AAPL","side":"SHORT","orderType":"MARKET","amount":100}`, 422, 42200, "", false},
		{"代码无效", "OPEN", `{"symbol":"$$","side":"BUY","orderType":"MARKET","amount":100}`, 422, 42200, "", false},
		{"低于单笔最低 $1", "OPEN", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","amount":0.5}`, 422, 42201, "单笔最低 $1.00（示例值，以券商为准）", false},
		{"按股数估算低于最低", "OPEN", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","quantity":0.001}`, 422, 42201, "单笔最低", false},
		{"超过购买力（金额）", "OPEN", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","amount":500.26}`, 422, 42201, "超过可用购买力 $500.25", false},
		{"等于购买力", "OPEN", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","amount":500.25}`, 200, 0, "", true},
		{"超过购买力（股数 × 演示价）", "OPEN", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","quantity":3}`, 422, 42201, "超过可用购买力", false},
		{"按股数买入无报价", "OPEN", `{"symbol":"XYZ","side":"BUY","orderType":"MARKET","quantity":1}`, 422, 42200, "", false},
		{"卖出超过可卖数量", "OPEN", `{"symbol":"AAPL","side":"SELL","orderType":"MARKET","quantity":8.26}`, 422, 42201, "超过可卖数量 8.25 股", false},
		{"按金额卖出超过可卖市值", "OPEN", `{"symbol":"AAPL","side":"SELL","orderType":"MARKET","amount":990.01}`, 422, 42201, "超过可卖市值 $990.00", false},
		{"未持有", "OPEN", `{"symbol":"TSLA","side":"SELL","orderType":"MARKET","quantity":1}`, 422, 42201, "没有可卖出的 TSLA 持仓", false},
		{"仅可卖出账户买入", "OPEN_NO_NEW_TRADES", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","amount":100}`, 403, 40301, "账户当前仅可卖出，暂不能买入", false},
		{"仅可卖出账户卖出", "OPEN_NO_NEW_TRADES", `{"symbol":"AAPL","side":"SELL","orderType":"MARKET","quantity":1}`, 200, 0, "", true},
		{"冻结账户", "FROZEN", `{"symbol":"AAPL","side":"SELL","orderType":"MARKET","quantity":1}`, 403, 40301, "", false},
		{"未开通账户", "PENDING", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","amount":100}`, 409, 40901, "", false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			f := newFx(t)
			f.acct.Status = tc.acct
			r := f.call("POST", "/api/v1/orders", tc.body)
			if r.HTTP != tc.wantHTTP || r.Code != tc.wantCode {
				t.Fatalf("HTTP %d code %d（%s），期望 %d / %d", r.HTTP, r.Code, r.Msg, tc.wantHTTP, tc.wantCode)
			}
			if tc.wantMsg != "" && !strings.Contains(r.Msg, tc.wantMsg) {
				t.Fatalf("message %q，期望包含 %q", r.Msg, tc.wantMsg)
			}
			if got := f.dw.count("POST /orders") > 0; got != tc.wantDW {
				t.Fatalf("调用 DW 下单 = %v，期望 %v", got, tc.wantDW)
			}
		})
	}
}

func TestCreateOrderSendsDWBodyAndRefreshes(t *testing.T) {
	f := newFx(t)
	r := f.call("POST", "/api/v1/orders", `{"symbol":"aapl","side":"BUY","orderType":"MARKET","amount":100}`)
	if r.Code != 0 || r.field(t, "status") != StatusFilled {
		t.Fatalf("应返回 DW 查询后的 FILLED：%+v %s", r, r.Data)
	}
	c := f.dw.last("POST /orders")
	if c.idem == "" {
		t.Fatal("下单必须附带 Idempotency-Key")
	}
	want := map[string]any{"accountNo": "TEST000001", "orderType": "MARKET", "symbol": "AAPL", "side": "BUY", "amountCash": float64(100)}
	for k, v := range want {
		if c.body[k] != v {
			t.Fatalf("DW 请求 %s = %v，期望 %v（%v）", k, c.body[k], v, c.body)
		}
	}
	if _, ok := c.body["quantity"]; ok {
		t.Fatal("按金额下单不应带 quantity")
	}
	if _, ok := c.body["preventQueuing"]; ok {
		t.Fatal("默认不传 preventQueuing")
	}
	// 订单详情为 DW 返回的成交数据
	g := f.call("GET", "/api/v1/orders/ord-1", "")
	var o map[string]any
	_ = json.Unmarshal(g.Data, &o)
	if o["orderNo"] != "FEAB000001" || o["filledQty"] != 0.5 || o["avgPrice"] != 199.9 || o["amount"] != float64(100) || o["quantity"] != nil || o["doneAt"] == nil {
		t.Fatalf("订单视图不正确：%s", g.Data)
	}
}

func TestCreateOrderQuantityBody(t *testing.T) {
	f := newFx(t)
	f.svc.PreventQueuing = true
	f.call("POST", "/api/v1/orders", `{"symbol":"AAPL","side":"SELL","orderType":"MARKET","quantity":1.25}`)
	c := f.dw.last("POST /orders")
	if c.body["quantity"] != 1.25 || c.body["side"] != "SELL" || c.body["preventQueuing"] != true {
		t.Fatalf("DW 请求不正确：%v", c.body)
	}
	if _, ok := c.body["amountCash"]; ok {
		t.Fatal("按股数下单不应带 amountCash")
	}
}

func TestCreateOrderDuplicate(t *testing.T) {
	f := newFx(t)
	body := `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","amount":100}`
	if r := f.call("POST", "/api/v1/orders", body); r.Code != 0 {
		t.Fatalf("首次下单失败：%+v", r)
	}
	if r := f.call("POST", "/api/v1/orders", body); r.Code != 40901 {
		t.Fatalf("10 秒内重复提交应 40901：%+v", r)
	}
	if r := f.call("POST", "/api/v1/orders", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","amount":101}`); r.Code != 0 {
		t.Fatalf("金额不同不算重复：%+v", r)
	}
}

func TestCreateOrderDWOutcomes(t *testing.T) {
	t.Run("DW 明确拒绝：撤销本地记录", func(t *testing.T) {
		f := newFx(t)
		f.dw.fail["POST /orders"] = []error{&dwclient.APIError{Status: 400, DWCode: "O012"}}
		r := f.call("POST", "/api/v1/orders", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","amount":100}`)
		if r.HTTP != 422 || r.Code != 42200 || !strings.Contains(r.Msg, "券商未受理") {
			t.Fatalf("%+v", r)
		}
		if len(f.repo.orders) != 0 {
			t.Fatal("被拒绝的订单不应保留")
		}
	})
	t.Run("账户不可下单 O098", func(t *testing.T) {
		f := newFx(t)
		f.dw.fail["POST /orders"] = []error{&dwclient.APIError{Status: 400, DWCode: "O098"}}
		r := f.call("POST", "/api/v1/orders", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","amount":100}`)
		if !strings.Contains(r.Msg, "交易账户当前不可下单") {
			t.Fatalf("%+v", r)
		}
	})
	t.Run("结果不明：保留 SUBMITTING，Sync 用原键重放", func(t *testing.T) {
		f := newFx(t)
		f.dw.fail["POST /orders"] = []error{&dwclient.APIError{Status: 503}}
		r := f.call("POST", "/api/v1/orders", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","amount":100}`)
		if r.HTTP != 502 || r.Code != 50001 || r.field(t, "orderId") != "ord-1" {
			t.Fatalf("%+v %s", r, r.Data)
		}
		first := f.dw.last("POST /orders").idem
		if o := f.repo.find("ord-1"); o.Status != StatusSubmitting {
			t.Fatalf("状态 %s", o.Status)
		}
		f.svc.Sync(context.Background(), time.Minute)
		if f.dw.last("POST /orders").idem != first {
			t.Fatal("重放必须使用原 Idempotency-Key")
		}
		if o := f.repo.find("ord-1"); o.Status != StatusFilled || o.DWOrderID != "DWO-1" {
			t.Fatalf("重放后状态 %s / %s", o.Status, o.DWOrderID)
		}
	})
	t.Run("响应缺少订单号：50002", func(t *testing.T) {
		f := newFx(t)
		f.dw.resp["POST /orders"] = []string{`{}`}
		r := f.call("POST", "/api/v1/orders", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","amount":100}`)
		if r.Code != 50002 {
			t.Fatalf("%+v", r)
		}
	})
	t.Run("响应只有 id（旧格式）", func(t *testing.T) {
		f := newFx(t)
		f.dw.resp["POST /orders"] = []string{`{"id":"DWO-1"}`}
		if r := f.call("POST", "/api/v1/orders", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","amount":100}`); r.Code != 0 {
			t.Fatalf("%+v", r)
		}
	})
	t.Run("查询购买力失败：50001，不下单", func(t *testing.T) {
		f := newFx(t)
		f.dw.fail["GET /accounts/dwacc-1/summary/money"] = []error{&dwclient.APIError{Status: 500}}
		r := f.call("POST", "/api/v1/orders", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","amount":100}`)
		if r.Code != 50001 || f.dw.count("POST /orders") != 0 {
			t.Fatalf("%+v", r)
		}
	})
}

func TestRejectedOrderReason(t *testing.T) {
	f := newFx(t)
	f.dw.resp["GET /orders/DWO-1"] = []string{`{"id":"DWO-1","status":"REJECTED","cumulativeQuantity":0,"statusMessage":{"message":"Insufficient buying power","reason":"BP"}}`}
	r := f.call("POST", "/api/v1/orders", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","amount":100}`)
	if r.field(t, "status") != StatusRejected {
		t.Fatalf("%s", r.Data)
	}
	g := f.call("GET", "/api/v1/orders/ord-1", "")
	if !strings.Contains(string(g.Data), "购买力不足，券商已拒绝该订单") || strings.Contains(string(g.Data), "Insufficient") {
		t.Fatalf("拒单原因应为中文且不透出 DW 原文：%s", g.Data)
	}
}

// ---------- 列表与详情 ----------

func TestListOrders(t *testing.T) {
	f := newFx(t)
	f.dw.resp["GET /orders/DWO-1"] = []string{`{"id":"DWO-1","status":"NEW"}`}
	f.call("POST", "/api/v1/orders", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","amount":100}`)
	f.dw.resp["GET /orders/DWO-1"] = []string{orderFilledJSON}
	cases := []struct {
		query string
		want  int
		code  int
	}{
		{"", 1, 0}, {"?status=CLOSED", 1, 0}, {"?status=OPEN", 0, 0}, {"?status=X", 0, 42200}, {"?cursor=not-base64!", 0, 42200},
	}
	for _, tc := range cases {
		r := f.call("GET", "/api/v1/orders"+tc.query, "")
		var list []Order
		_ = json.Unmarshal(r.Data, &list)
		if r.Code != tc.code || (tc.code == 0 && len(list) != tc.want) {
			t.Fatalf("%s：code %d，%d 条（%s）", tc.query, r.Code, len(list), r.Data)
		}
	}
	// 未开户：空数组
	f.acct = nil
	if r := f.call("GET", "/api/v1/orders", ""); r.Code != 0 || string(r.Data) != "[]" {
		t.Fatalf("%+v %s", r, r.Data)
	}
}

func TestGetOrderOwnership(t *testing.T) {
	f := newFx(t)
	f.call("POST", "/api/v1/orders", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","amount":100}`)
	f.acct = &account.Account{ID: "acc-2", DWAccountID: "dwacc-2", AccountNo: "TEST000002", Status: "OPEN"}
	if r := f.call("GET", "/api/v1/orders/ord-1", ""); r.Code != 40901 {
		t.Fatalf("不能读取他人订单：%+v", r)
	}
	if r := f.call("POST", "/api/v1/orders/ord-1/cancel", ""); r.Code != 40901 {
		t.Fatalf("不能撤他人订单：%+v", r)
	}
}

// ---------- 撤单 ----------

func TestCancelOrder(t *testing.T) {
	cases := []struct {
		name       string
		dwAfter    string // 撤单后 GET 返回
		cancelErr  error
		wantCode   int
		wantStatus string
	}{
		{"DW 已撤", `{"id":"DWO-1","status":"CANCELED"}`, nil, 0, StatusCanceled},
		{"DW 仍为 NEW：撤单中", `{"id":"DWO-1","status":"NEW"}`, nil, 0, StatusPendingCancel},
		{"DW 拒绝撤单（已成交）", orderFilledJSON, &dwclient.APIError{Status: 400, DWCode: "O050"}, 40901, StatusFilled},
		{"DW 故障", `{"id":"DWO-1","status":"NEW"}`, &dwclient.APIError{Status: 500}, 50001, StatusNew},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			f := newFx(t)
			f.dw.resp["GET /orders/DWO-1"] = []string{`{"id":"DWO-1","status":"NEW"}`}
			f.call("POST", "/api/v1/orders", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","amount":100}`)
			f.dw.resp["GET /orders/DWO-1"] = []string{tc.dwAfter}
			if tc.cancelErr != nil {
				f.dw.fail["PATCH /orders/DWO-1"] = []error{tc.cancelErr}
			}
			r := f.call("POST", "/api/v1/orders/ord-1/cancel", "")
			if r.Code != tc.wantCode {
				t.Fatalf("code %d（%s），期望 %d", r.Code, r.Msg, tc.wantCode)
			}
			if c := f.dw.last("PATCH /orders/DWO-1"); c == nil || c.body["method"] != "CANCEL" {
				t.Fatal("应向 DW 发送 method=CANCEL")
			}
			if o := f.repo.find("ord-1"); o.Status != tc.wantStatus {
				t.Fatalf("状态 %s，期望 %s", o.Status, tc.wantStatus)
			}
		})
	}
	t.Run("已成交不可撤", func(t *testing.T) {
		f := newFx(t)
		f.call("POST", "/api/v1/orders", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","amount":100}`)
		if r := f.call("POST", "/api/v1/orders/ord-1/cancel", ""); r.Code != 40901 || f.dw.count("PATCH") != 0 {
			t.Fatalf("%+v", r)
		}
	})
}

// ---------- 持仓 ----------

func TestPositions(t *testing.T) {
	f := newFx(t)
	r := f.call("GET", "/api/v1/positions", "")
	var p struct {
		UpdatedAt   string           `json:"updatedAt"`
		EquityValue float64          `json:"equityValue"`
		Positions   []map[string]any `json:"positions"`
	}
	_ = json.Unmarshal(r.Data, &p)
	if r.Code != 0 || len(p.Positions) != 1 || p.EquityValue != 1500.5 || p.UpdatedAt == "" {
		t.Fatalf("%s", r.Data)
	}
	want := map[string]any{"symbol": "AAPL", "quantity": 10.5, "sellableQty": 8.25, "avgPrice": float64(100), "costBasis": float64(1050),
		"marketPrice": float64(120), "marketValue": float64(1260), "unrealizedPL": float64(210), "unrealizedDayPL": -5.5}
	for k, v := range want {
		if p.Positions[0][k] != v {
			t.Fatalf("%s = %v，期望 %v", k, p.Positions[0][k], v)
		}
	}
	f.acct = &account.Account{ID: "acc-1", Status: "PENDING"}
	if r := f.call("GET", "/api/v1/positions", ""); r.Code != 40901 {
		t.Fatalf("未开户应 40901：%+v", r)
	}
}

// ---------- 对账 ----------

func TestSyncRefreshesOpenOrders(t *testing.T) {
	f := newFx(t)
	f.dw.resp["GET /orders/DWO-1"] = []string{`{"id":"DWO-1","status":"NEW"}`}
	f.call("POST", "/api/v1/orders", `{"symbol":"AAPL","side":"BUY","orderType":"MARKET","amount":100}`)
	f.dw.resp["GET /orders/DWO-1"] = []string{`{"id":"DWO-1","status":"PARTIAL_FILL","cumulativeQuantity":0.2}`, orderFilledJSON}
	f.svc.Sync(context.Background(), time.Minute)
	if o := f.repo.find("ord-1"); o.Status != StatusPartialFill || o.DoneAt != nil {
		t.Fatalf("%s", o.Status)
	}
	f.svc.Sync(context.Background(), time.Minute)
	if o := f.repo.find("ord-1"); o.Status != StatusFilled || o.DoneAt == nil {
		t.Fatalf("%s", o.Status)
	}
	n := f.dw.count("GET /orders/")
	f.svc.Sync(context.Background(), time.Minute)
	if f.dw.count("GET /orders/") != n {
		t.Fatal("已完结订单不再刷新")
	}
}

func TestStatusOf(t *testing.T) {
	for in, want := range map[any]string{"FILLED": "FILLED", "Partial_Fill": "PARTIAL_FILL", "CANCELLED": "CANCELED", "weird": ""} {
		if got := statusOf(in); got != want {
			t.Errorf("%v → %q，期望 %q", in, got, want)
		}
	}
	if statusOf(map[string]any{"name": "NEW"}) != "NEW" {
		t.Error("对象形式")
	}
}
