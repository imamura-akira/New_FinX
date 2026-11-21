package rewards

import (
	"context"
	"database/sql"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"sort"
	"testing"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/httpx"
	"github.com/imamura-akira/New_FinX/backend/internal/store"
)

type memRepo struct {
	ledger map[string]int
	days   map[string]map[time.Time]bool
}

func newMem() *memRepo {
	return &memRepo{ledger: map[string]int{}, days: map[string]map[time.Time]bool{}}
}

func (m *memRepo) Balance(_ context.Context, uid string) (int, error) { return m.ledger[uid], nil }

func (m *memRepo) CheckIn(_ context.Context, uid string, day time.Time, xp int) (bool, error) {
	if m.days[uid] == nil {
		m.days[uid] = map[time.Time]bool{}
	}
	if m.days[uid][day] {
		return false, nil
	}
	m.days[uid][day] = true
	m.ledger[uid] += xp
	return true, nil
}

func (m *memRepo) CheckinDays(_ context.Context, uid string, since time.Time) ([]time.Time, error) {
	var out []time.Time
	for d := range m.days[uid] {
		if !d.Before(since) {
			out = append(out, d)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].After(out[j]) })
	return out, nil
}

func day(s string) time.Time { d, _ := time.Parse("2006-01-02", s); return d }

type fixture struct {
	svc   *Service
	repo  *memRepo
	clock time.Time
}

func newFixture(t *testing.T) *fixture {
	t.Helper()
	f := &fixture{repo: newMem()}
	svc, err := New(f.repo, slog.New(slog.NewTextHandler(io.Discard, nil)))
	if err != nil {
		t.Fatal(err)
	}
	f.svc = svc
	f.clock = time.Date(2026, 11, 21, 15, 0, 0, 0, time.UTC) // 周六美东 10:00
	svc.now = func() time.Time { return f.clock }
	return f
}

func (f *fixture) call(t *testing.T, method, path string) (int, map[string]any) {
	t.Helper()
	mux := http.NewServeMux()
	f.svc.Routes(mux, "/api/v1", func(h http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			h.ServeHTTP(w, r.WithContext(httpx.WithUser(r.Context(), "u1")))
		})
	})
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, httptest.NewRequest(method, path, nil))
	var env struct {
		Code int            `json:"code"`
		Data map[string]any `json:"data"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &env)
	return env.Code, env.Data
}

func TestCatalogSeed(t *testing.T) {
	c, err := LoadCatalog()
	if err != nil {
		t.Fatal(err)
	}
	if len(c.Items) != 4 || len(c.Bundles) != 1 || len(c.ComingSoon) != 4 || len(c.Tasks) != 5 {
		t.Fatalf("seed 数量: %+v", c)
	}
	want := map[string]int{"jacket": 800, "vest": 1200, "bag": 950, "phones": 2200}
	for _, it := range c.Items {
		if want[it.ID] != it.XP || it.Name.Zh == "" || it.Name.En == "" {
			t.Fatalf("商品 %+v", it)
		}
	}
	if c.Bundles[0].XP != 2600 || !c.Bundles[0].Placeholder {
		t.Fatalf("套装 %+v", c.Bundles[0])
	}
	enabled := 0
	for _, tk := range c.Tasks {
		if tk.Enabled {
			enabled++
			if tk.ID != "checkin" || tk.XP != 10 {
				t.Fatalf("只有签到开放 +10: %+v", tk)
			}
		}
		if tk.ID == "savings" && !tk.ComplianceReview {
			t.Fatal("储蓄目标（入金类）须标注合规审核")
		}
	}
	if enabled != 1 {
		t.Fatalf("开放任务 %d", enabled)
	}
	for _, w := range []struct{ bal, tier, next, nextMin int }{
		{0, 1, 2, 500}, {499, 1, 2, 500}, {500, 2, 3, 1000}, {1493, 3, 4, 4500}, {12000, 6, 0, 0},
	} {
		tier, next, nextMin := c.TierOf(w.bal)
		if [3]int{tier, next, nextMin} != [3]int{w.tier, w.next, w.nextMin} {
			t.Fatalf("TierOf(%d) = %d %d %d", w.bal, tier, next, nextMin)
		}
	}
}

func TestXPAndCatalogEndpoints(t *testing.T) {
	f := newFixture(t)
	code, d := f.call(t, "GET", "/api/v1/rewards/xp")
	if code != 0 || d["balance"].(float64) != 0 || d["tier"].(float64) != 1 || d["nextTierMinXp"].(float64) != 500 {
		t.Fatalf("初始 XP: %d %v", code, d)
	}
	f.repo.ledger["u1"] = 1493
	_, d = f.call(t, "GET", "/api/v1/rewards/xp")
	if d["balance"].(float64) != 1493 || d["tier"].(float64) != 3 {
		t.Fatalf("%v", d)
	}
	code, d = f.call(t, "GET", "/api/v1/rewards/catalog")
	if code != 0 || len(d["items"].([]any)) != 4 || len(d["tasks"].([]any)) != 5 {
		t.Fatalf("catalog %v", d)
	}
}

// 签到：每美东日一次（美东零点切换）；入账走账本；连续天数与本周七圆点。
func TestCheckin(t *testing.T) {
	f := newFixture(t)
	code, d := f.call(t, "GET", "/api/v1/rewards/checkin")
	if code != 0 || d["checkedIn"].(bool) || d["streak"].(float64) != 0 || d["today"] != "2026-11-21" || d["xp"].(float64) != 10 {
		t.Fatalf("初始: %v", d)
	}
	if d["resetAt"] != "2026-11-22T05:00:00Z" {
		t.Fatalf("重置时刻应为美东零点: %v", d["resetAt"])
	}
	_, d = f.call(t, "POST", "/api/v1/rewards/checkin")
	if d["granted"].(float64) != 10 || d["balance"].(float64) != 10 || !d["checkedIn"].(bool) || d["streak"].(float64) != 1 {
		t.Fatalf("首签: %v", d)
	}
	_, d = f.call(t, "POST", "/api/v1/rewards/checkin")
	if _, has := d["granted"]; has || d["balance"].(float64) != 10 {
		t.Fatalf("同日重复不入账: %v", d)
	}
	// 美东 23:59（UTC 次日 04:59）仍是同一天
	f.clock = time.Date(2026, 11, 22, 4, 59, 0, 0, time.UTC)
	if _, d = f.call(t, "POST", "/api/v1/rewards/checkin"); d["balance"].(float64) != 10 {
		t.Fatal("美东零点前仍为同日")
	}
	// 美东零点后：新的一天
	f.clock = time.Date(2026, 11, 22, 5, 1, 0, 0, time.UTC)
	_, d = f.call(t, "GET", "/api/v1/rewards/checkin")
	if d["checkedIn"].(bool) || d["streak"].(float64) != 1 {
		t.Fatalf("新一天未签时连续天数截至昨日: %v", d)
	}
	_, d = f.call(t, "POST", "/api/v1/rewards/checkin")
	if d["streak"].(float64) != 2 || d["balance"].(float64) != 20 {
		t.Fatalf("连续 2 天: %v", d)
	}
	week := d["week"].([]any)
	if len(week) != 7 || !week[5].(bool) || !week[6].(bool) || week[4].(bool) {
		t.Fatalf("本周（周一起）周六、周日已签: %v", week)
	}
	// 新一周：周一，本周圆点清空，连续天数延续
	f.clock = time.Date(2026, 11, 23, 15, 0, 0, 0, time.UTC)
	_, d = f.call(t, "POST", "/api/v1/rewards/checkin")
	week = d["week"].([]any)
	if !week[0].(bool) || week[6].(bool) || d["streak"].(float64) != 3 {
		t.Fatalf("新一周: %v", d)
	}
	// 断签一天：连续天数从 1 重新计
	f.clock = time.Date(2026, 11, 25, 15, 0, 0, 0, time.UTC)
	_, d = f.call(t, "POST", "/api/v1/rewards/checkin")
	if d["streak"].(float64) != 1 || d["balance"].(float64) != 40 {
		t.Fatalf("断签: %v", d)
	}
}

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
	var uid string
	if err := st.DB.QueryRow(`INSERT INTO users_app (email) VALUES ($1) RETURNING id`, "xp-"+time.Now().Format("150405.000000")+"@example.com").Scan(&uid); err != nil {
		t.Fatal(err)
	}
	defer cleanup(st.DB, uid)
	r := PGRepo{DB: st.DB}
	if b, _ := r.Balance(ctx, uid); b != 0 {
		t.Fatalf("初始 %d", b)
	}
	if ok, err := r.CheckIn(ctx, uid, day("2026-11-21"), 10); err != nil || !ok {
		t.Fatal(ok, err)
	}
	if ok, err := r.CheckIn(ctx, uid, day("2026-11-21"), 10); err != nil || ok {
		t.Fatal("同日第二次应返回 false", ok, err)
	}
	_, _ = r.CheckIn(ctx, uid, day("2026-11-22"), 10)
	if err := GrantDemo(ctx, st.DB, uid, 1000); err != nil {
		t.Fatal(err)
	}
	if err := GrantDemo(ctx, st.DB, uid, 1493); err != nil { // 重复执行改为新值，不叠加
		t.Fatal(err)
	}
	if b, _ := r.Balance(ctx, uid); b != 1513 {
		t.Fatalf("余额 %d，期望 1493 + 2×10", b)
	}
	days, err := r.CheckinDays(ctx, uid, day("2026-11-22"))
	if err != nil || len(days) != 1 || !days[0].Equal(day("2026-11-22")) {
		t.Fatalf("%v %v", days, err)
	}
	// 账本不接受 0 / 负数
	if _, err := st.DB.Exec(`INSERT INTO xp_ledger (user_id, delta, reason, ref) VALUES ($1, -5, 'CHECKIN', 'x')`, uid); err == nil {
		t.Fatal("负数应被拒绝")
	}
}

func cleanup(db *sql.DB, uid string) {
	_, _ = db.Exec(`DELETE FROM xp_ledger WHERE user_id = $1`, uid)
	_, _ = db.Exec(`DELETE FROM xp_checkins WHERE user_id = $1`, uid)
	_, _ = db.Exec(`DELETE FROM users_app WHERE id = $1`, uid)
}
