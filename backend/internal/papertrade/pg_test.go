package papertrade

import (
	"context"
	"errors"
	"os"
	"sync"
	"testing"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/store"
)

func TestPGPaperRepo(t *testing.T) {
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
	if err := st.DB.QueryRow(`INSERT INTO users_app (email) VALUES ($1) RETURNING id`, "paper-"+time.Now().Format("150405.000000")+"@example.com").Scan(&uid); err != nil {
		t.Fatal(err)
	}
	r := PGRepo{DB: st.DB}
	now := time.Now().UTC()
	q := Quote{Bid: 99.9, Ask: 100, Last: 99.95}
	quote := func(string) (Quote, bool) { return q, true }
	qty := 3.0
	lqty, lim := 2.0, 90.0

	// 首次加载创建账户；下市价单 + 限价单
	var limitID string
	err = r.WithBook(ctx, uid, 10_000_00, func(b *Book) error {
		if !b.IsNew || b.Cash != 10_000_00 {
			t.Fatalf("新账户：%+v", b)
		}
		if _, err := b.Place(newUUID(), Request{Symbol: "AAPL", Side: "BUY", Type: "MARKET", Qty: &qty}, q, 100, now); err != nil {
			return err
		}
		o, err := b.Place(newUUID(), Request{Symbol: "AAPL", Side: "BUY", Type: "LIMIT", Qty: &lqty, Limit: &lim}, q, 100, now)
		limitID = o.ID
		return err
	})
	if err != nil {
		t.Fatal(err)
	}
	// 重新加载：现金、持仓、冻结一致
	_ = r.WithBook(ctx, uid, 10_000_00, func(b *Book) error {
		if b.IsNew || b.Cash != 9_700_00 || b.Pos["AAPL"].Qty != 3 || b.Pos["AAPL"].Cost != 300_00 || b.Reserved() != 180_00 || len(b.Open) != 1 {
			t.Fatalf("重新加载：cash %d pos %+v reserved %d open %d", b.Cash, b.Pos["AAPL"], b.Reserved(), len(b.Open))
		}
		return nil
	})
	// fn 出错时回滚
	boom := errors.New("boom")
	if err := r.WithBook(ctx, uid, 10_000_00, func(b *Book) error { b.Cash = 1; return boom }); !errors.Is(err, boom) {
		t.Fatal(err)
	}
	// 价格到达后撮合（并发两次，行锁保证只成交一次）
	q = Quote{Bid: 88, Ask: 89, Last: 88.5}
	var wg sync.WaitGroup
	for i := 0; i < 2; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			_ = r.WithBook(ctx, uid, 10_000_00, func(b *Book) error { b.Match(quote, now, time.UTC); return nil })
		}()
	}
	wg.Wait()
	o, err := r.GetOrder(ctx, uid, limitID)
	if err != nil || o.Status != StatusFilled || *o.AvgPrice != 89 || *o.Total != 178_00 || o.Reserved != 0 {
		t.Fatalf("撮合：%+v %v", o, err)
	}
	_ = r.WithBook(ctx, uid, 10_000_00, func(b *Book) error {
		if b.Cash != 9_522_00 || b.Pos["AAPL"].Qty != 5 {
			t.Fatalf("并发撮合只应扣款一次：cash %d qty %v", b.Cash, b.Pos["AAPL"].Qty)
		}
		return nil
	})
	if users, _ := r.UsersWithOpenOrders(ctx); contains(users, uid) {
		t.Fatal("已无未成交订单")
	}
	list, _ := r.ListOrders(ctx, uid, "CLOSED", nil, 50)
	if len(list) != 2 {
		t.Fatalf("CLOSED %d", len(list))
	}
	if _, err := r.GetOrder(ctx, uid, "not-a-uuid"); !errors.Is(err, ErrNotFound) {
		t.Fatal(err)
	}
	// 重置
	_ = r.WithBook(ctx, uid, 10_000_00, func(b *Book) error { b.Reset(now); return nil })
	_ = r.WithBook(ctx, uid, 10_000_00, func(b *Book) error {
		if b.Cash != 10_000_00 || len(b.Pos) != 0 || b.ResetAt == nil {
			t.Fatalf("重置：%+v", b)
		}
		return nil
	})
	if list, _ := r.ListOrders(ctx, uid, "", nil, 50); len(list) != 0 {
		t.Fatal("重置后订单清空")
	}
}

func contains(list []string, s string) bool {
	for _, x := range list {
		if x == s {
			return true
		}
	}
	return false
}
