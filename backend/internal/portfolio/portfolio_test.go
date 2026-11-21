package portfolio

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"sort"
	"strings"
	"testing"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/account"
	"github.com/imamura-akira/New_FinX/backend/internal/httpx"
)

// ---------- 内存仓库 ----------

type key struct {
	uid  string
	mode Mode
	day  string
}

type memRepo struct {
	snaps      map[key]Snapshot
	real, pape []string
	intra      []IntradaySnapshot
}

func (m *memRepo) SaveIntraday(_ context.Context, s IntradaySnapshot) error {
	for _, x := range m.intra {
		if x.UserID == s.UserID && x.Mode == s.Mode && x.At.Equal(s.At) {
			return nil
		}
	}
	m.intra = append(m.intra, s)
	sort.Slice(m.intra, func(i, j int) bool { return m.intra[i].At.Before(m.intra[j].At) })
	return nil
}

func (m *memRepo) ListIntraday(_ context.Context, uid string, mode Mode, since time.Time) ([]IntradaySnapshot, error) {
	var out []IntradaySnapshot
	for _, x := range m.intra {
		if x.UserID == uid && x.Mode == mode && !x.At.Before(since) {
			out = append(out, x)
		}
	}
	return out, nil
}

func newMem() *memRepo { return &memRepo{snaps: map[key]Snapshot{}} }

func (m *memRepo) Save(_ context.Context, s Snapshot, overwrite bool) (bool, error) {
	k := key{s.UserID, s.Mode, s.Day.Format("2006-01-02")}
	if _, ok := m.snaps[k]; ok && !overwrite {
		return false, nil
	}
	m.snaps[k] = s
	return true, nil
}

func (m *memRepo) Has(_ context.Context, uid string, mode Mode, day time.Time) (bool, error) {
	_, ok := m.snaps[key{uid, mode, day.Format("2006-01-02")}]
	return ok, nil
}

func (m *memRepo) List(_ context.Context, uid string, mode Mode, from time.Time) ([]Snapshot, error) {
	var out []Snapshot
	for k, s := range m.snaps {
		if k.uid == uid && k.mode == mode && !s.Day.Before(from) {
			out = append(out, s)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Day.Before(out[j].Day) })
	return out, nil
}

func (m *memRepo) RealUsers(context.Context) ([]string, error)  { return m.real, nil }
func (m *memRepo) PaperUsers(context.Context) ([]string, error) { return m.pape, nil }

func day(s string) time.Time { t, _ := time.Parse("2006-01-02", s); return t }

func classify(sym string) string {
	if map[string]bool{"SPY": true, "QQQ": true, "GLD": true}[sym] {
		return TypeETF
	}
	return TypeStock
}

// ---------- 分类归堆 ----------

func TestGroup(t *testing.T) {
	b := Group(163580, []Holding{{"AAPL", 100000}, {"spy", 120000}, {"NVDA", 194445}, {"QQQ", 76296}, {"ZZZZ", 0}}, classify)
	if b != (Breakdown{Cash: 163580, Stock: 294445, ETF: 196296}) {
		t.Fatalf("归堆错误: %+v", b)
	}
	if b.Total() != 654321 {
		t.Fatalf("总资产 %d", b.Total())
	}
	if g := Group(0, []Holding{{"XYZ", 500}}, classify); g.Stock != 500 {
		t.Fatal("标的列表外的代码应按股票计")
	}
}

// ---------- 占比 ----------

func TestPercents(t *testing.T) {
	cases := []struct {
		name string
		b    Breakdown
		want [3]int
	}{
		{"定稿示例", Breakdown{Cash: 163580, Stock: 294445, ETF: 196296}, [3]int{450, 300, 250}},
		{"三等分补足 100.0", Breakdown{Cash: 1, Stock: 1, ETF: 1}, [3]int{334, 333, 333}},
		{"只有现金", Breakdown{Cash: 100000}, [3]int{0, 0, 1000}},
		{"ETF 为 0", Breakdown{Cash: 50, Stock: 150}, [3]int{750, 0, 250}},
		{"全为 0", Breakdown{}, [3]int{0, 0, 0}},
		{"负现金按 0", Breakdown{Cash: -500, Stock: 1000}, [3]int{1000, 0, 0}},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := Percents(c.b); got != c.want {
				t.Fatalf("得 %v，期望 %v", got, c.want)
			}
		})
	}
	// 合计恒为 100.0
	for i := int64(1); i < 400; i++ {
		p := Percents(Breakdown{Cash: i * 7, Stock: i*13 + 1, ETF: 997 - i})
		if p[0]+p[1]+p[2] != 1000 {
			t.Fatalf("合计 %v", p)
		}
	}
}

func TestAllocateItems(t *testing.T) {
	items := Allocate(Breakdown{Cash: 163580, Stock: 294445, ETF: 196296})
	got := []string{}
	for _, it := range items {
		got = append(got, it.Type+":"+string(it.Amount)+":"+string(it.Pct))
	}
	want := "STOCK:2944.45:45.0 ETF:1962.96:30.0 CASH:1635.80:25.0"
	if strings.Join(got, " ") != want {
		t.Fatalf("得 %v", got)
	}
}

// ---------- 服务 ----------

type fixture struct {
	svc   *Service
	repo  *memRepo
	calls map[Mode]int
	real  map[string]Breakdown
	clock time.Time
}

func newFixture(t *testing.T) *fixture {
	t.Helper()
	f := &fixture{repo: newMem(), calls: map[Mode]int{}, real: map[string]Breakdown{
		"u1": {Cash: 163580, Stock: 294445, ETF: 196296},
	}}
	src := func(m Mode) Source {
		return func(_ context.Context, uid string) (Breakdown, error) {
			f.calls[m]++
			if m == Paper {
				return Breakdown{Cash: 10000000}, nil
			}
			b, ok := f.real[uid]
			if !ok {
				return Breakdown{}, ErrNotOpened
			}
			return b, nil
		}
	}
	f.svc = New(Deps{Repo: f.repo, Real: src(Real), Paper: src(Paper), Logger: slog.New(slog.NewTextHandler(io.Discard, nil))})
	f.clock = time.Date(2026, 11, 20, 15, 0, 0, 0, time.UTC) // 美东 10:00
	f.svc.now = func() time.Time { return f.clock }
	return f
}

func (f *fixture) call(t *testing.T, uid, path string) (int, map[string]any) {
	t.Helper()
	mux := http.NewServeMux()
	f.svc.Routes(mux, "/api/v1", func(h http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			h.ServeHTTP(w, r.WithContext(httpx.WithUser(r.Context(), uid)))
		})
	})
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, httptest.NewRequest("GET", path, nil))
	var env map[string]any
	_ = json.Unmarshal(rec.Body.Bytes(), &env)
	return int(env["code"].(float64)), env
}

func TestAllocationEndpoint(t *testing.T) {
	f := newFixture(t)
	code, env := f.call(t, "u1", "/api/v1/account/allocation")
	if code != 0 {
		t.Fatalf("code %d", code)
	}
	d := env["data"].(map[string]any)
	if d["total"].(float64) != 6543.21 || d["simulated"].(bool) {
		t.Fatalf("data %v", d)
	}
	items := d["items"].([]any)
	if len(items) != 3 || items[0].(map[string]any)["type"] != "STOCK" || items[0].(map[string]any)["pct"].(float64) != 45 {
		t.Fatalf("items %v", items)
	}
	// 当日首次请求兜底记录快照
	if ok, _ := f.repo.Has(context.Background(), "u1", Real, day("2026-11-20")); !ok {
		t.Fatal("首次请求应记录当日快照")
	}
	// 未开户
	if code, _ := f.call(t, "nobody", "/api/v1/account/allocation"); code != httpx.CodeConflict {
		t.Fatalf("未开户应返回 40901，得 %d", code)
	}
	if code, _ := f.call(t, "nobody", "/api/v1/account/history"); code != httpx.CodeConflict {
		t.Fatalf("未开户趋势应返回 40901，得 %d", code)
	}
	// 模拟盘
	code, env = f.call(t, "u1", "/api/v1/paper/account/allocation")
	if code != 0 || !env["data"].(map[string]any)["simulated"].(bool) {
		t.Fatalf("模拟盘 %v", env)
	}
}

// 快照去重：同一天兜底只写一次；收盘快照覆盖兜底；收盘后兜底不再覆盖。
func TestSnapshotDedup(t *testing.T) {
	f := newFixture(t)
	ctx := context.Background()
	f.call(t, "u1", "/api/v1/account/allocation")
	f.real["u1"] = Breakdown{Cash: 1}
	f.call(t, "u1", "/api/v1/account/allocation")
	if len(f.repo.snaps) != 1 {
		t.Fatalf("同日应只有 1 条，得 %d", len(f.repo.snaps))
	}
	s, _ := f.repo.List(ctx, "u1", Real, time.Time{})
	if s[0].Breakdown.Cash != 163580 || s[0].Source != SourceFirstRequest {
		t.Fatalf("兜底快照不应被同日后续请求覆盖: %+v", s[0])
	}
	// 历史请求：今日已有快照时不再读取数据源
	before := f.calls[Real]
	f.call(t, "u1", "/api/v1/account/history")
	if f.calls[Real] != before {
		t.Fatal("今日已有快照时趋势接口不应再调 DW")
	}
	// 收盘后（美东 16:30）覆盖为 CLOSE
	f.repo.real = []string{"u1"}
	f.clock = time.Date(2026, 11, 20, 21, 30, 0, 0, time.UTC)
	f.svc.Tick(ctx)
	s, _ = f.repo.List(ctx, "u1", Real, time.Time{})
	if len(s) != 1 || s[0].Source != SourceClose || s[0].Breakdown.Cash != 1 {
		t.Fatalf("收盘快照应覆盖兜底: %+v", s)
	}
	f.real["u1"] = Breakdown{Cash: 2}
	f.call(t, "u1", "/api/v1/account/allocation")
	s, _ = f.repo.List(ctx, "u1", Real, time.Time{})
	if s[0].Breakdown.Cash != 1 {
		t.Fatal("收盘后的兜底不应覆盖收盘快照")
	}
}

func TestCloseTick(t *testing.T) {
	f := newFixture(t)
	ctx := context.Background()
	f.repo.real, f.repo.pape = []string{"u1", "nobody"}, []string{"u1", "u2"}
	f.clock = time.Date(2026, 11, 20, 21, 5, 0, 0, time.UTC) // 美东 16:05：未到 16:10
	f.svc.Tick(ctx)
	if len(f.repo.snaps) != 0 {
		t.Fatal("16:10 前不记录收盘快照")
	}
	f.clock = time.Date(2026, 11, 20, 21, 15, 0, 0, time.UTC)
	f.svc.Tick(ctx)
	if len(f.repo.snaps) != 3 { // 实盘 u1（nobody 未开户跳过）+ 模拟 u1、u2
		t.Fatalf("得 %d 条", len(f.repo.snaps))
	}
	n := f.calls[Real] + f.calls[Paper]
	f.svc.Tick(ctx)
	if f.calls[Real]+f.calls[Paper] != n {
		t.Fatal("当日已完成后不应重复执行")
	}
	// 次日再执行
	f.clock = f.clock.Add(24 * time.Hour)
	f.svc.Tick(ctx)
	if len(f.repo.snaps) != 6 {
		t.Fatalf("次日应新增，得 %d", len(f.repo.snaps))
	}
}

func TestHistoryRanges(t *testing.T) {
	f := newFixture(t)
	ctx := context.Background()
	for i := 0; i < 40; i++ {
		d := day("2026-11-20").AddDate(0, 0, -i)
		_, _ = f.repo.Save(ctx, Snapshot{UserID: "u1", Mode: Real, Day: d, Breakdown: Breakdown{Cash: int64(100 + i)}, Source: SourceClose}, true)
	}
	for _, c := range []struct {
		q    string
		want int
	}{{"", 7}, {"?range=7D", 7}, {"?range=30D", 30}, {"?range=90D", 40}, {"?range=ALL", 40}} {
		code, env := f.call(t, "u1", "/api/v1/account/history"+c.q)
		pts := env["data"].(map[string]any)["points"].([]any)
		if code != 0 || len(pts) != c.want {
			t.Fatalf("%s：code %d，点数 %d，期望 %d", c.q, code, len(pts), c.want)
		}
		last := pts[len(pts)-1].(map[string]any)
		if last["date"] != "2026-11-20" {
			t.Fatalf("最后一点应为今日: %v", last)
		}
		if first := pts[0].(map[string]any)["date"].(string); first > last["date"].(string) {
			t.Fatal("应按日期升序")
		}
	}
	// F22-a 新区间：1W = 7 天、3M = 90 天（只有 40 天）、1Y、YTD（2026-01-01 起，40 天全在内）
	for _, c := range []struct {
		q    string
		want int
	}{{"?range=1W", 7}, {"?range=3M", 40}, {"?range=1Y", 40}, {"?range=YTD", 40}} {
		code, env := f.call(t, "u1", "/api/v1/account/history"+c.q)
		if pts := env["data"].(map[string]any)["points"].([]any); code != 0 || len(pts) != c.want {
			t.Fatalf("%s：code %d，点数 %d，期望 %d", c.q, code, len(pts), c.want)
		}
	}
	if code, _ := f.call(t, "u1", "/api/v1/account/history?range=2Y"); code != httpx.CodeValidation {
		t.Fatalf("非法 range 应 42200，得 %d", code)
	}
}

// 新用户：只有今日 1 个点（App 显示"记录积累中"），不补造历史。
func TestHistoryFirstDayOnePoint(t *testing.T) {
	f := newFixture(t)
	code, env := f.call(t, "u1", "/api/v1/account/history?range=ALL")
	pts := env["data"].(map[string]any)["points"].([]any)
	if code != 0 || len(pts) != 1 || pts[0].(map[string]any)["total"].(float64) != 6543.21 {
		t.Fatalf("首日应只有 1 个点: %v", env)
	}
}

// ---------- DW 数据源 ----------

type fakeDW map[string]string

func (f fakeDW) Do(_ context.Context, _, path string, _, out any) error {
	body, ok := f[path]
	if !ok {
		return errors.New("unexpected " + path)
	}
	return json.Unmarshal([]byte(body), out)
}

func TestDWSource(t *testing.T) {
	dw := fakeDW{
		"/accounts/acc-1/summary/money": `{"cash":{"cashBalance":1635.8,"cashAvailableForTrade":1635.8}}`,
		"/accounts/acc-1/summary/positions": `{"equityValue":4907.41,"equityPositions":[
			{"symbol":"AAPL","openQty":5,"marketValue":1132.7},
			{"symbol":"NVDA","openQty":12.5,"marketValue":1811.75},
			{"symbol":"SPY","openQty":3.3,"marketValue":1962.96},
			{"symbol":"OLD","openQty":0,"marketValue":0}]}`,
	}
	acct := func(_ context.Context, uid string) (*account.Account, error) {
		if uid == "u1" {
			return &account.Account{DWAccountID: "acc-1", Status: "OPEN"}, nil
		}
		return nil, nil
	}
	src := DWSource(dw, acct, classify, nil)
	b, err := src(context.Background(), "u1")
	if err != nil || b != (Breakdown{Cash: 163580, Stock: 294445, ETF: 196296}) {
		t.Fatalf("%+v %v", b, err)
	}
	if _, err := src(context.Background(), "u2"); !errors.Is(err, ErrNotOpened) {
		t.Fatalf("未开户应返回 ErrNotOpened，得 %v", err)
	}
}

// ---------- F22-a 日内快照 ----------

func TestIntradaySlot(t *testing.T) {
	et, _ := time.LoadLocation("America/New_York")
	for _, c := range []struct {
		at   time.Time
		want string // 美东 HH:MM；空 = 盘外
	}{
		{time.Date(2026, 11, 20, 14, 29, 0, 0, time.UTC), ""},       // 周五 09:29
		{time.Date(2026, 11, 20, 14, 30, 0, 0, time.UTC), "09:30"},  // 开盘档
		{time.Date(2026, 11, 20, 14, 59, 59, 0, time.UTC), "09:30"}, // 同一档
		{time.Date(2026, 11, 20, 15, 0, 0, 0, time.UTC), "10:00"},
		{time.Date(2026, 11, 20, 21, 0, 0, 0, time.UTC), "16:00"}, // 收盘档
		{time.Date(2026, 11, 20, 21, 1, 0, 0, time.UTC), ""},
		{time.Date(2026, 11, 21, 15, 0, 0, 0, time.UTC), ""},     // 周六
		{time.Date(2026, 7, 6, 13, 30, 0, 0, time.UTC), "09:30"}, // 夏令时（EDT，UTC-4）
	} {
		slot, ok := IntradaySlot(c.at, et)
		got := ""
		if ok {
			got = slot.In(et).Format("15:04")
		}
		if got != c.want {
			t.Fatalf("%v：得 %q，期望 %q", c.at, got, c.want)
		}
	}
}

// 盘中每档为实盘（已开户）与模拟盘用户各记一条；同档不重复；1D 返回最近一个有快照的美东日期。
func TestIntradayTickAnd1D(t *testing.T) {
	f := newFixture(t)
	ctx := context.Background()
	f.repo.real, f.repo.pape = []string{"u1", "nobody"}, []string{"u1"}
	// 1D 无数据：空数组（App 显示"日内数据积累中"）
	code, env := f.call(t, "u1", "/api/v1/account/history?range=1D")
	if pts := env["data"].(map[string]any)["points"].([]any); code != 0 || len(pts) != 0 {
		t.Fatalf("无日内快照应返回空: %v", env)
	}
	f.clock = time.Date(2026, 11, 20, 14, 35, 0, 0, time.UTC) // 美东 09:35
	f.svc.Tick(ctx)
	f.svc.Tick(ctx) // 同档不重复
	if len(f.repo.intra) != 2 {
		t.Fatalf("09:30 档应有实盘 u1 + 模拟 u1 两条，得 %d", len(f.repo.intra))
	}
	f.real["u1"] = Breakdown{Cash: 700000}
	f.clock = time.Date(2026, 11, 20, 15, 2, 0, 0, time.UTC) // 10:00 档
	f.svc.Tick(ctx)
	if len(f.repo.intra) != 4 {
		t.Fatalf("10:00 档后应为 4 条，得 %d", len(f.repo.intra))
	}
	code, env = f.call(t, "u1", "/api/v1/account/history?range=1D")
	d := env["data"].(map[string]any)
	pts := d["points"].([]any)
	if code != 0 || d["range"] != "1D" || len(pts) != 2 {
		t.Fatalf("1D: %v", env)
	}
	p0, p1 := pts[0].(map[string]any), pts[1].(map[string]any)
	if p0["at"] != "2026-11-20T14:30:00Z" || p1["at"] != "2026-11-20T15:00:00Z" || p1["total"].(float64) != 7000 || p0["date"] != "2026-11-20" {
		t.Fatalf("1D 点: %v %v", p0, p1)
	}
	// 周六：盘外不记录；1D 仍返回周五的日内走势
	f.clock = time.Date(2026, 11, 21, 15, 0, 0, 0, time.UTC)
	f.svc.Tick(ctx)
	if len(f.repo.intra) != 4 {
		t.Fatal("周末不记录日内快照")
	}
	_, env = f.call(t, "u1", "/api/v1/paper/account/history?range=1D")
	if pts := env["data"].(map[string]any)["points"].([]any); len(pts) != 2 {
		t.Fatalf("模拟盘 1D 应为周五 2 档: %v", env)
	}
	// 按日区间不带 at
	_, env = f.call(t, "u1", "/api/v1/account/history?range=1W")
	for _, p := range env["data"].(map[string]any)["points"].([]any) {
		if _, has := p.(map[string]any)["at"]; has {
			t.Fatal("按日区间不应返回 at")
		}
	}
}
