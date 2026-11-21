package portfolio

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/store"
)

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
	sfx := time.Now().Format("150405.000000")
	var uid string
	if err := st.DB.QueryRow(`INSERT INTO users_app (email) VALUES ($1) RETURNING id`, "pf-"+sfx+"@example.com").Scan(&uid); err != nil {
		t.Fatal(err)
	}
	if _, err := st.DB.Exec(`INSERT INTO paper_accounts (user_id, initial_cash, cash) VALUES ($1, 100000, 100000)`, uid); err != nil {
		t.Fatal(err)
	}
	r := PGRepo{DB: st.DB}
	d1, d2 := day("2026-11-19"), day("2026-11-20")
	snap := func(d time.Time, cash int64, src string) Snapshot {
		return Snapshot{UserID: uid, Mode: Paper, Day: d, Breakdown: Breakdown{Cash: cash, Stock: 12345, ETF: -1}, Source: src, CapturedAt: time.Now().UTC()}
	}
	// 兜底：同日只写一次
	if ok, err := r.Save(ctx, snap(d2, 100, SourceFirstRequest), false); err != nil || !ok {
		t.Fatalf("首次写入 %v %v", ok, err)
	}
	if ok, _ := r.Save(ctx, snap(d2, 200, SourceFirstRequest), false); ok {
		t.Fatal("同日兜底不应重复写入")
	}
	// 收盘覆盖
	if ok, err := r.Save(ctx, snap(d2, 300, SourceClose), true); err != nil || !ok {
		t.Fatalf("收盘覆盖 %v %v", ok, err)
	}
	_, _ = r.Save(ctx, snap(d1, 50, SourceClose), true)
	if has, _ := r.Has(ctx, uid, Paper, d2); !has {
		t.Fatal("Has")
	}
	if has, _ := r.Has(ctx, uid, Real, d2); has {
		t.Fatal("实盘与模拟盘应分开")
	}
	all, err := r.List(ctx, uid, Paper, time.Time{})
	if err != nil || len(all) != 2 || !all[0].Day.Equal(d1) || all[1].Breakdown != (Breakdown{Cash: 300, Stock: 12345, ETF: -1}) || all[1].Source != SourceClose {
		t.Fatalf("List %+v %v", all, err)
	}
	if from, _ := r.List(ctx, uid, Paper, d2); len(from) != 1 {
		t.Fatalf("from 过滤 %d", len(from))
	}
	users, _ := r.PaperUsers(ctx)
	found := false
	for _, u := range users {
		found = found || u == uid
	}
	if !found {
		t.Fatal("PaperUsers 应包含该用户")
	}
	if _, err := r.RealUsers(ctx); err != nil {
		t.Fatal(err)
	}
	// F22-a 日内快照：同档忽略、since 过滤、升序
	at1 := time.Date(2026, 11, 20, 14, 30, 0, 0, time.UTC)
	at2 := at1.Add(30 * time.Minute)
	for _, s := range []IntradaySnapshot{
		{UserID: uid, Mode: Paper, At: at2, Breakdown: Breakdown{Cash: 200, Stock: 50}, CapturedAt: time.Now().UTC()},
		{UserID: uid, Mode: Paper, At: at1, Breakdown: Breakdown{Cash: 100}, CapturedAt: time.Now().UTC()},
		{UserID: uid, Mode: Paper, At: at1, Breakdown: Breakdown{Cash: 999}, CapturedAt: time.Now().UTC()},
	} {
		if err := r.SaveIntraday(ctx, s); err != nil {
			t.Fatal(err)
		}
	}
	in, err := r.ListIntraday(ctx, uid, Paper, at1)
	if err != nil || len(in) != 2 || !in[0].At.Equal(at1) || in[0].Breakdown.Cash != 100 || in[1].Breakdown.Total() != 250 {
		t.Fatalf("日内快照 %+v %v", in, err)
	}
	if in, _ := r.ListIntraday(ctx, uid, Paper, at2); len(in) != 1 {
		t.Fatalf("since 过滤 %d", len(in))
	}
	if in, _ := r.ListIntraday(ctx, uid, Real, at1); len(in) != 0 {
		t.Fatal("账户类型隔离")
	}
	_, _ = st.DB.Exec(`DELETE FROM asset_intraday WHERE user_id = $1`, uid)
	_, _ = st.DB.Exec(`DELETE FROM asset_snapshots WHERE user_id = $1`, uid)
	_, _ = st.DB.Exec(`DELETE FROM paper_accounts WHERE user_id = $1`, uid)
	_, _ = st.DB.Exec(`DELETE FROM users_app WHERE id = $1`, uid)
}
