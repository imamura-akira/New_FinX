package predict

import (
	"context"
	"os"
	"sync"
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
	var uid string
	if err := st.DB.QueryRow(`INSERT INTO users_app (email) VALUES ($1) RETURNING id`, "pred-"+time.Now().Format("150405.000000")+"@example.com").Scan(&uid); err != nil {
		t.Fatal(err)
	}
	r := PGRepo{DB: st.DB}
	now := time.Date(2026, 11, 21, 3, 1, 0, 0, time.UTC)
	start := WindowStart(now)
	if err := r.EnsureUpDown(ctx, "BTC", start, 61500); err != nil {
		t.Fatal(err)
	}
	if err := r.EnsureUpDown(ctx, "BTC", start, 99999); err != nil { // 幂等
		t.Fatal(err)
	}
	id := UpDownID("BTC", start)
	m, _ := r.GetMarket(ctx, id)
	if m == nil || *m.TargetPrice != 61500 {
		t.Fatalf("窗口 %+v", m)
	}
	if pts, _ := r.EnsureAccount(ctx, uid); pts != InitialPoints {
		t.Fatal("初始积分")
	}
	// 并发下注：总额不超过余额
	var wg sync.WaitGroup
	ok := make(chan bool, 4)
	for i := 0; i < 4; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			_, _, _, err := r.PlaceBet(ctx, uid, id, Yes, 3000, now)
			ok <- err == nil
		}()
	}
	wg.Wait()
	close(ok)
	n := 0
	for v := range ok {
		if v {
			n++
		}
	}
	if n != 3 {
		t.Fatalf("10,000 分只能下 3 笔 3,000，得 %d", n)
	}
	m, _ = r.GetMarket(ctx, id)
	if m.PoolYes != UpDownSeed+9000 {
		t.Fatalf("池子 %d", m.PoolYes)
	}
	if _, err := r.Settle(ctx, id, Yes, nil, now.Add(Window)); err != nil {
		t.Fatal(err)
	}
	if _, err := r.Settle(ctx, id, No, nil, now.Add(Window)); err != ErrSettled {
		t.Fatal("重复结算")
	}
	bets, _ := r.ListBets(ctx, uid)
	s := ComputeStats(bets)
	if s.Wins != 3 || s.Claimable <= 9000 {
		t.Fatalf("%+v", s)
	}
	amt, pts, err := r.Claim(ctx, uid, now.Add(Window))
	if err != nil || amt != s.Claimable || pts != 1000+amt {
		t.Fatalf("领取 %d %d %v", amt, pts, err)
	}
	// 种子事件市场存在
	if ms, _ := r.ListOpenMarkets(ctx, now); len(ms) < 7 {
		t.Fatalf("种子市场 %d", len(ms))
	}
	for _, q := range []string{`DELETE FROM predict_bets WHERE user_id = $1`, `DELETE FROM predict_accounts WHERE user_id = $1`, `DELETE FROM users_app WHERE id = $1`} {
		_, _ = st.DB.Exec(q, uid)
	}
	_, _ = st.DB.Exec(`DELETE FROM predict_markets WHERE id = $1`, id)
}
