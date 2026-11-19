package events

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"os"
	"testing"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/store"
)

func TestParseKYC(t *testing.T) {
	cases := []struct {
		name       string
		json       string
		wantStatus string
		wantIssues int
	}{
		{"文档结构 kyc.status.name", `{"kyc":{"status":{"name":"KYC_APPROVED"}}}`, "KYC_APPROVED", 0},
		{"status 为字符串", `{"kyc":{"status":"KYC_PROCESSING"}}`, "KYC_PROCESSING", 0},
		{"顶层 status、无前缀小写", `{"status":{"name":"manual_review"}}`, "KYC_MANUAL_REVIEW", 0},
		{"带问题项", `{"kyc":{"status":{"name":"KYC_INFO_REQUIRED"},"errors":[{"code":"ADDRESS","description":"x"},{"description":"no code"}]}}`, "KYC_INFO_REQUIRED", 1},
		{"details 数组", `{"kyc":{"status":{"name":"KYC_DOC_REQUIRED"},"details":[{"name":"ID_DOC"}]}}`, "KYC_DOC_REQUIRED", 1},
		{"空响应", `{}`, "", 0},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			var m map[string]any
			_ = json.Unmarshal([]byte(tc.json), &m)
			st, is := ParseKYC(m)
			if st != tc.wantStatus || len(is) != tc.wantIssues {
				t.Fatalf("status=%q issues=%d，期望 %q %d", st, len(is), tc.wantStatus, tc.wantIssues)
			}
		})
	}
}

type memKYC struct {
	targets []KYCTarget
	saved   map[string]string
	issues  map[string]int
	touched map[string]bool
}

func (m *memKYC) DueKYC(context.Context, time.Time, int) ([]KYCTarget, error) { return m.targets, nil }
func (m *memKYC) KYCTargetFor(_ context.Context, appID string) (*KYCTarget, error) {
	for _, t := range m.targets {
		if t.AppID == appID {
			return &t, nil
		}
	}
	return nil, nil
}
func (m *memKYC) SaveKYC(_ context.Context, t KYCTarget, st string, is []Issue, _ time.Time) error {
	m.saved[t.AppID], m.issues[t.AppID] = st, len(is)
	return nil
}
func (m *memKYC) TouchKYC(_ context.Context, appID string, _ time.Time) error {
	m.touched[appID] = true
	return nil
}

type fakeDW struct {
	resp map[string]string // path → json
	err  map[string]error
}

func (f *fakeDW) Do(_ context.Context, _, path string, _, out any) error {
	if e := f.err[path]; e != nil {
		return e
	}
	return json.Unmarshal([]byte(f.resp[path]), out)
}

type fakeAccounts struct{ ensured, refreshed int }

func (f *fakeAccounts) EnsureAccounts(context.Context)  { f.ensured++ }
func (f *fakeAccounts) RefreshStatuses(context.Context) { f.refreshed++ }

func TestReconcilerTick(t *testing.T) {
	repo := &memKYC{
		targets: []KYCTarget{
			{AppID: "a1", DWUserID: "u1", Status: "KYC_NOT_READY"},
			{AppID: "a2", DWUserID: "u2", Status: "KYC_PROCESSING"},
			{AppID: "a3", DWUserID: "u3", Status: "KYC_PROCESSING"},
		},
		saved: map[string]string{}, issues: map[string]int{}, touched: map[string]bool{},
	}
	dw := &fakeDW{
		resp: map[string]string{
			"/users/u1/kyc-status": `{"kyc":{"status":{"name":"KYC_APPROVED"}}}`,
			"/users/u3/kyc-status": `{"kyc":{"status":{"name":"SOMETHING_NEW"}}}`,
		},
		err: map[string]error{"/users/u2/kyc-status": errors.New("timeout")},
	}
	acc := &fakeAccounts{}
	r := NewReconciler(repo, dw, acc, time.Minute, slog.New(slog.NewTextHandler(io.Discard, nil)))
	r.Tick(context.Background())
	if repo.saved["a1"] != "KYC_APPROVED" {
		t.Fatalf("a1 应保存 APPROVED: %v", repo.saved)
	}
	if _, ok := repo.saved["a2"]; ok || !repo.touched["a2"] {
		t.Fatal("DW 出错时只更新检查时间")
	}
	if _, ok := repo.saved["a3"]; ok || !repo.touched["a3"] {
		t.Fatal("无法识别的状态不应写入（违反 CHECK 约束）")
	}
	if acc.ensured != 1 || acc.refreshed != 1 {
		t.Fatal("每轮应触发开户与账户状态刷新")
	}
	r.RefreshApp(context.Background(), "a1")
	if acc.ensured != 2 {
		t.Fatal("RefreshApp 后应尝试开户")
	}
}

func TestTerminal(t *testing.T) {
	for st, want := range map[string]bool{"KYC_APPROVED": true, "KYC_DENIED": true, "KYC_PROCESSING": false, "KYC_INFO_REQUIRED": false} {
		if Terminal(st) != want {
			t.Errorf("Terminal(%s) != %v", st, want)
		}
	}
}

// 数据库集成：DueKYC → SaveKYC（含问题项、申请状态联动）。
func TestPGKYCRepo(t *testing.T) {
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
	suffix := time.Now().Format("150405.000000")
	var uid, appID string
	_ = st.DB.QueryRow(`INSERT INTO users_app (email) VALUES ($1) RETURNING id`, "kyc-"+suffix+"@example.com").Scan(&uid)
	_ = st.DB.QueryRow(`INSERT INTO applications (user_id, status) VALUES ($1, 'SUBMITTED') RETURNING id`, uid).Scan(&appID)
	dwID := "it-kyc-" + suffix
	if _, err := st.DB.Exec(`INSERT INTO dw_users (application_id, dw_user_id) VALUES ($1, $2)`, appID, dwID); err != nil {
		t.Fatal(err)
	}
	r := PGRepo{DB: st.DB}
	now := time.Now().UTC()
	due, _ := r.DueKYC(ctx, now, 1000)
	var tgt *KYCTarget
	for i := range due {
		if due[i].AppID == appID {
			tgt = &due[i]
		}
	}
	if tgt == nil || tgt.Status != "KYC_NOT_READY" {
		t.Fatalf("新 DW User 应在待对账列表: %+v", due)
	}
	if err := r.SaveKYC(ctx, *tgt, "KYC_INFO_REQUIRED", []Issue{{Code: "ADDR", UserMessage: "请核对此项信息", Raw: json.RawMessage(`{"code":"ADDR"}`)}}, now); err != nil {
		t.Fatal(err)
	}
	var n int
	_ = st.DB.QueryRow(`SELECT count(*) FROM kyc_issues WHERE dw_user_id = $1 AND resolved_at IS NULL`, dwID).Scan(&n)
	if n != 1 {
		t.Fatalf("应有 1 条未解决问题项，实际 %d", n)
	}
	tgt.Status = "KYC_INFO_REQUIRED"
	if err := r.SaveKYC(ctx, *tgt, "KYC_APPROVED", nil, now.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	_ = st.DB.QueryRow(`SELECT count(*) FROM kyc_issues WHERE dw_user_id = $1 AND resolved_at IS NULL`, dwID).Scan(&n)
	var appStatus, kyc string
	_ = st.DB.QueryRow(`SELECT a.status, d.kyc_status FROM applications a JOIN dw_users d ON d.application_id = a.id WHERE a.id = $1`, appID).Scan(&appStatus, &kyc)
	if n != 0 || appStatus != "APPROVED" || kyc != "KYC_APPROVED" {
		t.Fatalf("通过后问题项应清空、申请 APPROVED: issues=%d app=%s kyc=%s", n, appStatus, kyc)
	}
	due, _ = r.DueKYC(ctx, now.Add(time.Hour), 1000)
	for _, d := range due {
		if d.AppID == appID {
			t.Fatal("终态不应再对账")
		}
	}
}
