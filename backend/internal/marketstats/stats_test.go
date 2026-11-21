package marketstats

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/httpx"
	"github.com/imamura-akira/New_FinX/backend/internal/store"
)

func TestBucketBoundaries(t *testing.T) {
	for _, c := range []struct {
		chg  float64
		want int
	}{
		{-9, 0}, {-7, 0}, {-6.99, 1}, {-5, 1}, {-4, 2}, {-3, 2}, {-2.99, 3}, {-0.01, 3},
		{-0.004, 4}, {0, 4}, {0.004, 4},
		{0.01, 5}, {2.99, 5}, {3, 6}, {4.99, 6}, {5, 7}, {6.99, 7}, {7, 8}, {12, 8},
	} {
		if got := Bucket(c.chg); got != c.want {
			t.Fatalf("Bucket(%v) = %d，期望 %d", c.chg, got, c.want)
		}
	}
}

func TestDistribute(t *testing.T) {
	d := Distribute([]float64{-8, -1, 0, 0.001, 1, 2, 3.5, 9})
	if d.Counts != [9]int{1, 0, 0, 1, 2, 2, 1, 0, 1} || d.Up != 4 || d.Down != 2 || d.Flat != 2 || d.Total != 8 {
		t.Fatalf("%+v", d)
	}
}

type memRepo struct {
	closes []Close
}

func (m *memRepo) SaveCloses(_ context.Context, cs []Close) error {
	for _, c := range cs {
		replaced := false
		for i, x := range m.closes {
			if x.Symbol == c.Symbol && x.Day.Equal(c.Day) {
				m.closes[i], replaced = c, true
			}
		}
		if !replaced {
			m.closes = append(m.closes, c)
		}
	}
	return nil
}

func (m *memRepo) BaseCloses(_ context.Context, on time.Time) (map[string]float64, error) {
	best := map[string]Close{}
	for _, c := range m.closes {
		if c.Day.After(on) {
			continue
		}
		if b, ok := best[c.Symbol]; !ok || c.Day.After(b.Day) {
			best[c.Symbol] = c
		}
	}
	out := map[string]float64{}
	for s, c := range best {
		out[s] = c.Close
	}
	return out, nil
}

func (m *memRepo) FirstDay(context.Context) (time.Time, bool, error) {
	var first time.Time
	for _, c := range m.closes {
		if first.IsZero() || c.Day.Before(first) {
			first = c.Day
		}
	}
	return first, !first.IsZero(), nil
}

type fixture struct {
	svc    *Service
	repo   *memRepo
	quotes []Quote
	clock  time.Time
}

func newFixture() *fixture {
	f := &fixture{repo: &memRepo{}, quotes: []Quote{{"AAPL", 110, 1.2}, {"SPY", 90, -0.5}, {"KO", 50, 0}}}
	f.svc = New(Deps{Repo: f.repo, Quotes: func() []Quote { return f.quotes }, Logger: slog.New(slog.NewTextHandler(io.Discard, nil))})
	f.clock = time.Date(2026, 11, 20, 15, 0, 0, 0, time.UTC) // 周五美东 10:00
	f.svc.now = func() time.Time { return f.clock }
	return f
}

func (f *fixture) get(t *testing.T, q string) (int, View) {
	t.Helper()
	mux := http.NewServeMux()
	f.svc.Routes(mux, "/api/v1")
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, httptest.NewRequest("GET", "/api/v1/market/stats"+q, nil))
	var env struct {
		Code int  `json:"code"`
		Data View `json:"data"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &env)
	return env.Code, env.Data
}

func TestTodayStats(t *testing.T) {
	f := newFixture()
	code, v := f.get(t, "")
	if code != 0 || v.Period != "TODAY" || v.Up != 1 || v.Down != 1 || v.Flat != 1 || v.Total != 3 || !v.Simulated || v.Insufficient {
		t.Fatalf("%d %+v", code, v)
	}
	if len(v.Buckets) != 9 || v.Buckets[0].Label != ">7%" || v.Buckets[4].Count != 1 || v.Buckets[5].Count != 1 || v.Buckets[3].Count != 1 {
		t.Fatalf("buckets %+v", v.Buckets)
	}
	if code, _ := f.get(t, "?period=7D"); code != httpx.CodeValidation {
		t.Fatalf("非法 period 应 42200，得 %d", code)
	}
}

// 近 30 日：没有 30 天前的快照 → 数据积累中；有则按当前价相对基准收盘价统计。
func Test30DStats(t *testing.T) {
	f := newFixture()
	ctx := context.Background()
	_, v := f.get(t, "?period=30D")
	if !v.Insufficient || v.Total != 0 || v.Since != "" || len(v.Buckets) != 9 {
		t.Fatalf("无快照应为积累中: %+v", v)
	}
	// 只有 10 天前的快照：仍不足
	_ = f.repo.SaveCloses(ctx, []Close{{"AAPL", day("2026-11-10"), 100, 0}, {"SPY", day("2026-11-10"), 100, 0}, {"KO", day("2026-11-10"), 50, 0}})
	_, v = f.get(t, "?period=30D")
	if !v.Insufficient || v.Since != "2026-11-10" {
		t.Fatalf("不足 30 天: %+v", v)
	}
	// 30 天前（2026-10-21）及更早的快照：取 ≤ 当日的最近一个
	_ = f.repo.SaveCloses(ctx, []Close{
		{"AAPL", day("2026-10-21"), 100, 0}, {"SPY", day("2026-10-15"), 100, 0}, {"KO", day("2026-10-21"), 40, 0},
		{"KO", day("2026-10-01"), 1, 0},
	})
	_, v = f.get(t, "?period=30D")
	// AAPL 110/100 = +10%（≥7）；SPY 90/100 = -10%（≤-7）；KO 50/40 = +25%
	if v.Insufficient || v.Up != 2 || v.Down != 1 || v.Buckets[8].Count != 2 || v.Buckets[0].Count != 1 {
		t.Fatalf("30D: %+v", v)
	}
	// 新上市标的缺基准：整体视为不足（不部分统计）
	f.quotes = append(f.quotes, Quote{"NEW", 10, 0})
	if _, v = f.get(t, "?period=30D"); !v.Insufficient {
		t.Fatal("缺基准应为积累中")
	}
}

func TestCloseTick(t *testing.T) {
	f := newFixture()
	ctx := context.Background()
	f.svc.Tick(ctx) // 10:00 盘中
	if len(f.repo.closes) != 0 {
		t.Fatal("盘中不记录")
	}
	f.clock = time.Date(2026, 11, 20, 21, 6, 0, 0, time.UTC) // 16:06
	f.svc.Tick(ctx)
	f.quotes[0].Last = 999
	f.svc.Tick(ctx) // 当日已完成
	if len(f.repo.closes) != 3 || f.repo.closes[0].Close != 110 || !f.repo.closes[0].Day.Equal(day("2026-11-20")) {
		t.Fatalf("%+v", f.repo.closes)
	}
	f.clock = time.Date(2026, 11, 21, 21, 6, 0, 0, time.UTC) // 周六
	f.svc.Tick(ctx)
	if len(f.repo.closes) != 3 {
		t.Fatal("周末不记录")
	}
	f.clock = time.Date(2026, 11, 23, 21, 6, 0, 0, time.UTC) // 周一
	f.svc.Tick(ctx)
	if len(f.repo.closes) != 6 {
		t.Fatalf("周一应新增，得 %d", len(f.repo.closes))
	}
}

func day(s string) time.Time { d, _ := time.Parse("2006-01-02", s); return d }

func TestPGRepo(t *testing.T) {
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("未设置 TEST_DATABASE_URL，跳过数据库集成测试")
	}
	st, err := store.Open(context.Background(), dsn)
	if err != nil {
		t.Fatal(err)
	}
	defer st.Close()
	if err := st.MigrateUp(); err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	_, _ = st.DB.Exec(`DELETE FROM instrument_daily_close WHERE symbol LIKE 'T\_%'`)
	r := PGRepo{DB: st.DB}
	if err := r.SaveCloses(ctx, []Close{{"T_A", day("2026-10-01"), 10, 1}, {"T_A", day("2026-10-20"), 20, 1}, {"T_B", day("2026-10-25"), 30, -1}}); err != nil {
		t.Fatal(err)
	}
	if err := r.SaveCloses(ctx, []Close{{"T_A", day("2026-10-20"), 21.5, 2}}); err != nil { // 同日覆盖
		t.Fatal(err)
	}
	b, err := r.BaseCloses(ctx, day("2026-10-21"))
	if err != nil || b["T_A"] != 21.5 || b["T_B"] != 0 {
		t.Fatalf("%v %v", b, err)
	}
	if b, _ := r.BaseCloses(ctx, day("2026-10-30")); b["T_B"] != 30 {
		t.Fatalf("%v", b)
	}
	if first, ok, err := r.FirstDay(ctx); err != nil || !ok || first.After(day("2026-10-01")) {
		t.Fatalf("%v %v %v", first, ok, err)
	}
	_, _ = st.DB.Exec(`DELETE FROM instrument_daily_close WHERE symbol LIKE 'T\_%'`)
}
