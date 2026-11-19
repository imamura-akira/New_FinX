package account

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/store"
)

func TestPGAccountRepo(t *testing.T) {
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
	var uid, appID string
	_ = st.DB.QueryRow(`INSERT INTO users_app (email) VALUES ($1) RETURNING id`, "acc-"+sfx+"@example.com").Scan(&uid)
	_ = st.DB.QueryRow(`INSERT INTO applications (user_id, status) VALUES ($1, 'APPROVED') RETURNING id`, uid).Scan(&appID)
	dwUser := "it-acc-u-" + sfx
	if _, err := st.DB.Exec(`INSERT INTO dw_users (application_id, dw_user_id, kyc_status, kyc_updated_at) VALUES ($1, $2, 'KYC_APPROVED', now())`, appID, dwUser); err != nil {
		t.Fatal(err)
	}
	r := PGRepo{DB: st.DB}
	find := func() bool {
		list, _ := r.NeedAccount(ctx, 1000)
		for _, p := range list {
			if p.AppID == appID {
				return true
			}
		}
		return false
	}
	if find() {
		t.Fatal("编排未完成（披露未提交）时不应开户")
	}
	_, _ = st.DB.Exec(`UPDATE applications SET orchestration_state = 'DOCS_DONE' WHERE id = $1`, appID)
	find = func() bool {
		list, _ := r.NeedAccount(ctx, 1000)
		for _, p := range list {
			if p.AppID == appID {
				return true
			}
		}
		return false
	}
	if !find() {
		t.Fatal("KYC 通过且无账户时应待开户")
	}
	if err := r.RecordAttempt(ctx, appID, "DW HTTP 500"); err != nil {
		t.Fatal(err)
	}
	if a, _ := r.ForUser(ctx, uid); a != nil {
		t.Fatal("开户前不应有账户")
	}
	dwAcc := "it-acc-" + sfx
	if err := r.SaveAccount(ctx, Account{DWAccountID: dwAcc, DWUserID: dwUser, AccountNo: "IT" + sfx, Status: "PENDING"}, time.Now()); err != nil {
		t.Fatal(err)
	}
	if err := r.SaveAccount(ctx, Account{DWAccountID: dwAcc, DWUserID: dwUser, Status: "PENDING"}, time.Now()); err != nil {
		t.Fatal("重复保存应幂等:", err)
	}
	if find() {
		t.Fatal("已有账户不应再待开户")
	}
	a, err := r.ForUser(ctx, uid)
	if err != nil || a == nil || a.Status != "PENDING" || a.AccountType != "LIVE" || a.Management != "SELF" {
		t.Fatalf("ForUser: %+v %v", a, err)
	}
	now := time.Now().UTC()
	if err := r.UpdateStatus(ctx, dwAcc, "OPEN", &now, now); err != nil {
		t.Fatal(err)
	}
	a, _ = r.ForUser(ctx, uid)
	if a.Status != "OPEN" || a.OpenedAt == nil {
		t.Fatalf("应为 OPEN: %+v", a)
	}
	list, _ := r.NotOpen(ctx, 1000)
	for _, x := range list {
		if x.DWAccountID == dwAcc {
			t.Fatal("OPEN 账户不应在待刷新列表")
		}
	}
}
