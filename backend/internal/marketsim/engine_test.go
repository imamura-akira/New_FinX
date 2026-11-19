package marketsim

import (
	"encoding/json"
	"math"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"
)

type clock struct{ t time.Time }

func (c *clock) now() time.Time { return c.t }

func newTestEngine(t *testing.T) (*Engine, *clock) {
	t.Helper()
	c := &clock{t: time.Date(2026, 11, 19, 15, 0, 0, 0, time.UTC)}
	return New(DefaultInstruments, Params{}, c.now), c
}

func TestDefaultsFromSpec(t *testing.T) {
	e, _ := newTestEngine(t)
	if e.Tick() != 2*time.Second || e.p.Sigma != 0.0008 {
		t.Fatalf("默认参数应为 tick 2s、σ 0.0008（backend-design.md 6.5）: %v %v", e.Tick(), e.p.Sigma)
	}
	syms := e.Symbols()
	for _, must := range []string{"QQQ", "SPY", "DIA", "AAPL"} {
		if !contains(syms, must) {
			t.Errorf("标的池缺少 %s", must)
		}
	}
	if len(syms) < 20 {
		t.Fatalf("标的池过小: %d", len(syms))
	}
}

func TestInitialQuoteMatchesDemoData(t *testing.T) {
	e, _ := newTestEngine(t)
	q := e.Quotes([]string{"aapl"})[0]
	if q.Last != 228.52 || q.PrevClos != 226.10 {
		t.Fatalf("初始价应与原型一致: %+v", q)
	}
	if math.Abs(q.ChgPct()-1.07) > 0.01 {
		t.Fatalf("涨跌幅应相对昨收: %.4f", q.ChgPct())
	}
}

func TestDeterministicSeedAndReset(t *testing.T) {
	a, ca := newTestEngine(t)
	b, cb := newTestEngine(t)
	for i := 0; i < 50; i++ {
		ca.t = ca.t.Add(2 * time.Second)
		cb.t = cb.t.Add(2 * time.Second)
		a.Step()
		b.Step()
	}
	qa, qb := a.Quotes(nil), b.Quotes(nil)
	for i := range qa {
		if qa[i].Last != qb[i].Last {
			t.Fatalf("同种子应得到相同价格序列: %s %v vs %v", qa[i].Symbol, qa[i].Last, qb[i].Last)
		}
	}
	a.Reset()
	if got := a.Quotes([]string{"AAPL"})[0].Last; got != 228.52 {
		t.Fatalf("Reset 后应回到初始价: %v", got)
	}
}

func TestPricesMoveBidAskAndReversion(t *testing.T) {
	e, c := newTestEngine(t)
	before := e.Quotes(nil)
	moved := 0
	maxDev := 0.0
	for i := 0; i < 20000; i++ {
		c.t = c.t.Add(2 * time.Second)
		e.Step()
		if i == 0 {
			for j, q := range e.Quotes(nil) {
				if q.Last != before[j].Last {
					moved++
				}
				if !(q.Bid < q.Last && q.Last < q.Ask) {
					t.Fatalf("bid < last < ask 不成立: %+v", q)
				}
				bp := (q.Ask - q.Bid) / q.Last * 10000 / 2
				if bp < 0.99 || bp > 2.01 {
					t.Fatalf("半价差应在 1–2 bp: %.3f", bp)
				}
			}
		}
		for _, q := range e.Quotes(nil) {
			maxDev = math.Max(maxDev, math.Abs(q.ChgPct()))
		}
	}
	if moved < len(before)/2 {
		t.Fatalf("一个 tick 后多数标的价格应变动，实际 %d/%d", moved, len(before))
	}
	// 均值回归：约 11 小时的模拟 tick 后，涨跌幅仍在合理范围（不会无限漂移）
	if maxDev > 10 {
		t.Fatalf("均值回归失效，最大涨跌幅 %.2f%%", maxDev)
	}
}

func TestCandlesAggregatePerMinute(t *testing.T) {
	e, c := newTestEngine(t)
	_, _, before, _ := e.Instrument("SPY")
	if len(before) != 60 {
		t.Fatalf("启动时应预生成 60 根分时: %d", len(before))
	}
	for i := 0; i < 30; i++ { // 同一分钟内 30 个 tick → 只新增 1 根
		c.t = c.t.Add(time.Second)
		e.Step()
	}
	_, q, after, _ := e.Instrument("SPY")
	if len(after) != 61 {
		t.Fatalf("同一分钟应聚合为 1 根: %d", len(after))
	}
	last := after[len(after)-1]
	if last.C != round2(q.Last) || last.H < last.C || last.L > last.C || last.H < last.O || last.L > last.O {
		t.Fatalf("K 线 OHLC 不一致: %+v last=%v", last, q.Last)
	}
	if q.DayHigh < q.Last || q.DayLow > q.Last {
		t.Fatalf("日内高低价不一致: %+v", q)
	}
	for i := 0; i < 500; i++ { // 超过 390 根时截断
		c.t = c.t.Add(time.Minute)
		e.Step()
	}
	if _, _, bars, _ := e.Instrument("SPY"); len(bars) != 390 {
		t.Fatalf("当日最多保留 390 根: %d", len(bars))
	}
}

func TestQuotesFilter(t *testing.T) {
	e, _ := newTestEngine(t)
	cases := []struct {
		in   []string
		want []string
	}{
		{[]string{"spy", " AAPL ", "NOPE", "SPY"}, []string{"SPY", "AAPL"}},
		{nil, nil}, // 全部
	}
	for _, tc := range cases {
		got := e.Quotes(tc.in)
		if tc.want == nil {
			if len(got) != len(DefaultInstruments) {
				t.Fatalf("空参数应返回全部: %d", len(got))
			}
			continue
		}
		if len(got) != len(tc.want) {
			t.Fatalf("got %d want %v", len(got), tc.want)
		}
		for i, s := range tc.want {
			if got[i].Symbol != s {
				t.Fatalf("顺序/去重不正确: %v", got)
			}
		}
	}
}

func TestHTTP(t *testing.T) {
	e, _ := newTestEngine(t)
	mux := http.NewServeMux()
	e.Routes(mux, "/api/v1")
	do := func(path string) (int, map[string]any) {
		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, httptest.NewRequest("GET", path, nil))
		var env map[string]any
		_ = json.Unmarshal(rec.Body.Bytes(), &env)
		return rec.Code, env
	}
	code, env := do("/api/v1/market/quotes?symbols=AAPL,SPY")
	d := env["data"].(map[string]any)
	qs := d["quotes"].([]any)
	if code != 200 || d["simulated"] != true || len(qs) != 2 || d["ts"] == nil {
		t.Fatalf("quotes: %d %v", code, env)
	}
	q := qs[0].(map[string]any)
	for _, k := range []string{"symbol", "last", "chg", "chgPct", "bid", "ask"} {
		if _, ok := q[k]; !ok {
			t.Fatalf("报价缺少字段 %s（api-spec.md 5.5）", k)
		}
	}
	code, env = do("/api/v1/market/instruments/qqq")
	d = env["data"].(map[string]any)
	if code != 200 || d["simulated"] != true || d["symbol"] != "QQQ" || len(d["candles"].([]any)) != 60 || d["prevClose"].(float64) != 508.70 {
		t.Fatalf("instrument: %d %v", code, d["symbol"])
	}
	c0 := d["candles"].([]any)[0].(map[string]any)
	for _, k := range []string{"t", "o", "h", "l", "c"} {
		if _, ok := c0[k]; !ok {
			t.Fatalf("K 线缺少字段 %s", k)
		}
	}
	if code, env = do("/api/v1/market/instruments/NOPE"); code != 422 || env["code"].(float64) != 42200 {
		t.Fatalf("未知代码应 42200: %d %v", code, env)
	}
	many := strings.Repeat("AAPL,", 51)
	if code, _ = do("/api/v1/market/quotes?symbols=" + many); code != 422 {
		t.Fatalf("超过 50 个代码应 422: %d", code)
	}
}

func TestConcurrentStepAndRead(t *testing.T) {
	e, _ := newTestEngine(t)
	var wg sync.WaitGroup
	for i := 0; i < 4; i++ {
		wg.Add(2)
		go func() {
			defer wg.Done()
			for j := 0; j < 200; j++ {
				e.Step()
			}
		}()
		go func() {
			defer wg.Done()
			for j := 0; j < 200; j++ {
				_ = e.Quotes(nil)
				_, _, _, _ = e.Instrument("AAPL")
			}
		}()
	}
	wg.Wait()
}

func contains(list []string, s string) bool {
	for _, x := range list {
		if x == s {
			return true
		}
	}
	return false
}
