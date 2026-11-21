package trading

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"testing"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/store"
)

func TestPGTradingRepo(t *testing.T) {
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
	var uid, appID, accID string
	_ = st.DB.QueryRow(`INSERT INTO users_app (email) VALUES ($1) RETURNING id`, "trade-"+sfx+"@example.com").Scan(&uid)
	_ = st.DB.QueryRow(`INSERT INTO applications (user_id, status) VALUES ($1, 'APPROVED') RETURNING id`, uid).Scan(&appID)
	dwUser := "it-trade-u-" + sfx
	_, _ = st.DB.Exec(`INSERT INTO dw_users (application_id, dw_user_id, kyc_status) VALUES ($1, $2, 'KYC_APPROVED')`, appID, dwUser)
	if err := st.DB.QueryRow(`INSERT INTO accounts (dw_user_id, dw_account_id, account_no, status) VALUES ($1, $2, $3, 'OPEN') RETURNING id`,
		dwUser, "it-trade-acc-"+sfx, "ITT"+sfx).Scan(&accID); err != nil {
		t.Fatal(err)
	}
	r := PGRepo{DB: st.DB}
	now := time.Now().UTC()
	key := func(n string) string {
		return "22222222-2222-4222-8222-" + n + time.Now().Format("150405000000")[:12-len(n)]
	}

	amt := json.Number("100.50")
	o1 := Order{AccountID: accID, Symbol: "AAPL", Side: "BUY", OrderType: "MARKET", Amount: &amt, Status: StatusSubmitting, IdempotencyKey: key("1"), CreatedBy: uid}
	id1, err := r.InsertOrder(ctx, o1)
	if err != nil {
		t.Fatal(err)
	}
	if got, err := r.OrderByIdemKey(ctx, accID, o1.IdempotencyKey); err != nil || got.ID != id1 || got.Symbol != "AAPL" {
		t.Fatalf("OrderByIdemKey: %+v %v", got, err)
	}
	if _, err := r.OrderByIdemKey(ctx, "00000000-0000-4000-8000-000000000000", o1.IdempotencyKey); !errors.Is(err, ErrNotFound) {
		t.Fatalf("其他账户不应取到: %v", err)
	}
	qty := json.Number("0.123456")
	o2 := Order{AccountID: accID, Symbol: "TSLA", Side: "SELL", OrderType: "MARKET", Quantity: &qty, Status: StatusSubmitting, IdempotencyKey: key("2")}
	id2, err := r.InsertOrder(ctx, o2)
	if err != nil {
		t.Fatal(err)
	}
	if dup, _ := r.RecentDuplicate(ctx, o1, now.Add(-time.Minute)); !dup {
		t.Fatal("应识别为重复提交")
	}
	other := json.Number("100.51")
	o1b := o1
	o1b.Amount = &other
	if dup, _ := r.RecentDuplicate(ctx, o1b, now.Add(-time.Minute)); dup {
		t.Fatal("金额不同不算重复")
	}
	if dup, _ := r.RecentDuplicate(ctx, o2, now.Add(-time.Minute)); !dup {
		t.Fatal("按股数的重复也应识别")
	}

	// 幂等键约束：同一键不能写两次
	if _, err := r.InsertOrder(ctx, o1); err == nil {
		t.Fatal("幂等键应唯一")
	}
	// 金额与股数必须二选一
	if _, err := r.InsertOrder(ctx, Order{AccountID: accID, Symbol: "AAPL", Side: "BUY", OrderType: "MARKET", Status: StatusSubmitting, IdempotencyKey: key("3")}); err == nil {
		t.Fatal("金额与股数都为空应被拒绝")
	}

	due, _ := r.DueOrders(ctx, now.Add(time.Minute), 1000)
	found := false
	for _, d := range due {
		if d.ID == id1 {
			found = d.DWAccountNo == "ITT"+sfx && d.IdempotencyKey == o1.IdempotencyKey && d.Amount != nil && d.Amount.String() == "100.5"
		}
	}
	if !found {
		t.Fatal("待对账列表应包含 SUBMITTING 订单并带出账户号、幂等键与金额")
	}

	// 未提交成功的可删除；已有 DW 编号的不删
	if err := r.DeleteOrder(ctx, id2); err != nil {
		t.Fatal(err)
	}
	if _, err := r.GetOrder(ctx, accID, id2); !errors.Is(err, ErrNotFound) {
		t.Fatal("被拒绝的订单应已删除")
	}
	if err := r.SetSubmitted(ctx, id1, "DWO-IT-"+sfx, "ITNO"+sfx, now); err != nil {
		t.Fatal(err)
	}
	_ = r.DeleteOrder(ctx, id1)
	got, err := r.GetOrder(ctx, accID, id1)
	if err != nil || got.Status != StatusNew || got.DWOrderID != "DWO-IT-"+sfx || got.OrderNo == nil {
		t.Fatalf("SetSubmitted 后：%+v %v", got, err)
	}
	if _, err := r.GetOrder(ctx, "00000000-0000-0000-0000-000000000000", id1); !errors.Is(err, ErrNotFound) {
		t.Fatal("他人账户下不应查到")
	}
	if _, err := r.GetOrder(ctx, accID, "not-a-uuid"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("非法 id 应视为不存在：%v", err)
	}

	if open, _ := r.ListOrders(ctx, accID, "OPEN", nil, 50); len(open) != 1 {
		t.Fatalf("OPEN 应有 1 条，实际 %d", len(open))
	}
	filled, avg, total, fees := "0.502513", "199.9", "100.45", "0"
	done := now
	if err := r.UpdateOrder(ctx, id1, Fill{Status: StatusFilled, FilledQty: &filled, AvgPrice: &avg, TotalAmount: &total, Fees: &fees, DoneAt: &done}, now); err != nil {
		t.Fatal(err)
	}
	if open, _ := r.ListOrders(ctx, accID, "OPEN", nil, 50); len(open) != 0 {
		t.Fatal("已成交不应在 OPEN 中")
	}
	closed, _ := r.ListOrders(ctx, accID, "CLOSED", nil, 50)
	if len(closed) != 1 {
		t.Fatalf("CLOSED 应有 1 条，实际 %d", len(closed))
	}
	c := closed[0]
	if c.FilledQty.String() != "0.502513" || c.AvgPrice.String() != "199.9" || c.TotalAmount.String() != "100.45" || c.Fees.String() != "0" || c.DoneAt == nil || *c.OrderNo != "ITNO"+sfx {
		t.Fatalf("UpdateOrder：%+v", c)
	}
	raw, _ := json.Marshal(c)
	var m map[string]any
	_ = json.Unmarshal(raw, &m)
	if m["amount"] != 100.5 || m["quantity"] != nil || m["filledQty"] != 0.502513 {
		t.Fatalf("JSON 视图：%s", raw)
	}
	if all, _ := r.ListOrders(ctx, accID, "", &c.SubmittedAt, 50); len(all) != 0 {
		t.Fatal("游标之前没有更早的订单")
	}
	// 限价单字段（F14 扩展，迁移 000007）
	lq, lp, tif := json.Number("3"), json.Number("150.25"), "DAY"
	o3 := Order{AccountID: accID, Symbol: "AAPL", Side: "BUY", OrderType: "LIMIT", Quantity: &lq, LimitPrice: &lp, TimeInForce: &tif,
		Status: StatusSubmitting, IdempotencyKey: key("4")}
	id3, err := r.InsertOrder(ctx, o3)
	if err != nil {
		t.Fatal(err)
	}
	if g, _ := r.GetOrder(ctx, accID, id3); g == nil || g.OrderType != "LIMIT" || g.LimitPrice.String() != "150.25" || *g.TimeInForce != "DAY" {
		t.Fatalf("限价单读取：%+v", g)
	}
	if dup, _ := r.RecentDuplicate(ctx, o3, now.Add(-time.Minute)); !dup {
		t.Fatal("同价限价单应识别为重复")
	}
	other3 := o3
	lp2 := json.Number("150.26")
	other3.LimitPrice = &lp2
	if dup, _ := r.RecentDuplicate(ctx, other3, now.Add(-time.Minute)); dup {
		t.Fatal("限价不同不算重复")
	}
	if _, err := r.InsertOrder(ctx, Order{AccountID: accID, Symbol: "AAPL", Side: "BUY", OrderType: "LIMIT", Quantity: &lq, Status: StatusSubmitting, IdempotencyKey: key("5")}); err == nil {
		t.Fatal("限价单缺少限价应被约束拒绝")
	}
	if err := r.Audit(ctx, "system", "order.status", "order:"+id1, map[string]any{"to": "FILLED"}); err != nil {
		t.Fatal(err)
	}
}
