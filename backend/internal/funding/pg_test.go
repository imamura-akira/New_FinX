package funding

import (
	"context"
	"errors"
	"os"
	"testing"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/store"
)

func TestPGFundingRepo(t *testing.T) {
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
	_ = st.DB.QueryRow(`INSERT INTO users_app (email) VALUES ($1) RETURNING id`, "fund-"+sfx+"@example.com").Scan(&uid)
	_ = st.DB.QueryRow(`INSERT INTO applications (user_id, status) VALUES ($1, 'APPROVED') RETURNING id`, uid).Scan(&appID)
	dwUser := "it-fund-u-" + sfx
	_, _ = st.DB.Exec(`INSERT INTO dw_users (application_id, dw_user_id, kyc_status) VALUES ($1, $2, 'KYC_APPROVED')`, appID, dwUser)
	if err := st.DB.QueryRow(`INSERT INTO accounts (dw_user_id, dw_account_id, account_no, status) VALUES ($1, $2, $3, 'OPEN') RETURNING id`,
		dwUser, "it-fund-acc-"+sfx, "ITF"+sfx).Scan(&accID); err != nil {
		t.Fatal(err)
	}
	r := PGRepo{DB: st.DB}

	bankID, err := r.InsertBank(ctx, Bank{AccountID: accID, DWBankID: "bank_it_" + sfx, BankName: "Test Bank", Mask: "6789", Type: "CHECKING", OwnerName: "Demo Tester", Status: "ACTIVE", Nickname: "Main"})
	if err != nil {
		t.Fatal(err)
	}
	if b, err := r.GetBank(ctx, accID, bankID); err != nil || b.Mask != "6789" || b.DWBankID == "" {
		t.Fatalf("GetBank: %+v %v", b, err)
	}
	if _, err := r.GetBank(ctx, "00000000-0000-0000-0000-000000000000", bankID); !errors.Is(err, ErrNotFound) {
		t.Fatal("他人账户下不应查到")
	}
	if _, err := r.GetBank(ctx, accID, "not-a-uuid"); !errors.Is(err, ErrNotFound) {
		t.Fatalf("非法 id 应视为不存在: %v", err)
	}

	now := time.Now().UTC()
	tr := Transfer{AccountID: accID, BankAccountID: &bankID, Type: "DEPOSIT", Method: "ACH", Amount: "100.25", Status: StatusSubmitting, IdempotencyKey: "11111111-1111-4111-8111-" + time.Now().Format("150405000000")[:12], CreatedBy: uid}
	tid, err := r.InsertTransfer(ctx, tr)
	if err != nil {
		t.Fatal(err)
	}
	if busy, _ := r.HasInFlight(ctx, bankID); !busy {
		t.Fatal("提交中的入金应视为在途")
	}
	if dup, _ := r.RecentDuplicate(ctx, accID, "DEPOSIT", "100.25", &bankID, now.Add(-time.Minute)); !dup {
		t.Fatal("应识别为重复提交")
	}
	if dup, _ := r.RecentDuplicate(ctx, accID, "DEPOSIT", "100.26", &bankID, now.Add(-time.Minute)); dup {
		t.Fatal("金额不同不算重复")
	}
	if sum, _ := r.SumDeposits(ctx, accID, now.Add(-time.Hour)); sum != "100.25" {
		t.Fatalf("SumDeposits = %s", sum)
	}
	due, _ := r.DueTransfers(ctx, now.Add(time.Minute), now.Add(-240*time.Hour), 1000)
	found := false
	for _, d := range due {
		if d.ID == tid {
			found = d.DWAccountNo == "ITF"+sfx && d.DWBankID == "bank_it_"+sfx && d.IdempotencyKey != ""
		}
	}
	if !found {
		t.Fatal("待对账列表应包含该笔且带出账户号、DW 银行 id、幂等键")
	}
	if err := r.SetSubmitted(ctx, tid, "DEP-IT-"+sfx, "PENDING", now); err != nil {
		t.Fatal(err)
	}
	if err := r.DeleteTransfer(ctx, tid); err != nil {
		t.Fatal(err)
	}
	list, _ := r.ListTransfers(ctx, accID, "", nil, 50)
	if len(list) != 1 {
		t.Fatal("已有 DW 编号的记录不应被删除")
	}
	done := now
	reason := "银行已退回"
	if err := r.UpdateTransfer(ctx, tid, "RETURNED", &reason, &done, now); err != nil {
		t.Fatal(err)
	}
	list, _ = r.ListTransfers(ctx, accID, "DEPOSIT", nil, 50)
	if list[0].Status != "RETURNED" || list[0].FailureReason == nil || list[0].AmountJSON != "100.25" || list[0].DoneAt == nil {
		t.Fatalf("UpdateTransfer: %+v", list[0])
	}
	if sum, _ := r.SumDeposits(ctx, accID, now.Add(-time.Hour)); sum != "0" {
		t.Fatalf("被退回的入金不计入每日额度: %s", sum)
	}
	if busy, _ := r.HasInFlight(ctx, bankID); busy {
		t.Fatal("终态不算在途")
	}
	if err := r.DeleteBank(ctx, bankID, now); err != nil {
		t.Fatal(err)
	}
	if banks, _ := r.ListBanks(ctx, accID); len(banks) != 0 {
		t.Fatal("解绑后不应再列出")
	}
}
