package application

import (
	"context"
	"errors"
	"os"
	"testing"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/store"
)

// pgRepo：TEST_DATABASE_URL 已设置时返回一个迁移到最新版本的 PGRepo 与一个新建的 App 用户。
func pgRepo(t *testing.T) (PGRepo, string) {
	t.Helper()
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("未设置 TEST_DATABASE_URL，跳过数据库集成测试")
	}
	st, err := store.Open(context.Background(), dsn)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { st.Close() })
	if err := st.MigrateUp(); err != nil {
		t.Fatal(err)
	}
	var uid string
	email := "it-" + time.Now().Format("150405.000000") + "@example.com"
	if err := st.DB.QueryRow(`INSERT INTO users_app (email) VALUES ($1) RETURNING id`, email).Scan(&uid); err != nil {
		t.Fatal(err)
	}
	return PGRepo{DB: st.DB}, uid
}

func TestPGDraftRepo(t *testing.T) {
	r, uid := pgRepo(t)
	ctx := context.Background()

	if a, err := r.GetByUser(ctx, uid); err != nil || a != nil {
		t.Fatalf("新用户不应有申请: %v %v", a, err)
	}
	a, err := r.EnsureDraft(ctx, uid)
	if err != nil || a == nil || a.Status != "DRAFT" {
		t.Fatalf("EnsureDraft: %+v %v", a, err)
	}
	again, _ := r.EnsureDraft(ctx, uid)
	if again.ID != a.ID {
		t.Fatal("EnsureDraft 应幂等")
	}
	if err := r.SaveDraft(ctx, a.ID, "c", []byte{1, 2, 3}, time.Now()); err != nil {
		t.Fatal(err)
	}
	got, _ := r.GetByUser(ctx, uid)
	if got.Step != "c" || len(got.DataEnc) != 3 {
		t.Fatalf("SaveDraft 未生效: %+v", got)
	}

	// 证件：同一面替换
	if _, err := r.PutDocument(ctx, a.ID, "NATIONAL_ID_CARD", "FRONT", "image/jpeg", []byte{9}); err != nil {
		t.Fatal(err)
	}
	id2, err := r.PutDocument(ctx, a.ID, "NATIONAL_ID_CARD", "FRONT", "image/png", []byte{8})
	if err != nil {
		t.Fatal(err)
	}
	docs, _ := r.ListDocuments(ctx, a.ID)
	if len(docs) != 1 || docs[0].ID != id2 {
		t.Fatalf("同一面应只保留最新一份: %+v", docs)
	}

	if k, err := r.KYC(ctx, a.ID); err != nil || k != nil {
		t.Fatalf("尚无 DW User 时 KYC 应为 nil: %v %v", k, err)
	}

	// 非草稿不可保存
	if _, err := r.DB.Exec(`UPDATE applications SET status = 'SUBMITTED' WHERE id = $1`, a.ID); err != nil {
		t.Fatal(err)
	}
	if err := r.SaveDraft(ctx, a.ID, "c", []byte{1}, time.Now()); !errors.Is(err, ErrNotDraft) {
		t.Fatalf("非草稿应返回 ErrNotDraft，实际 %v", err)
	}
}

func TestPGOrchRepo(t *testing.T) {
	r, uid := pgRepo(t)
	ctx := context.Background()
	now := time.Now().UTC().Truncate(time.Millisecond)
	a, _ := r.EnsureDraft(ctx, uid)
	if _, err := r.PutDocument(ctx, a.ID, "PASSPORT", "FRONT", "image/jpeg", []byte{1}); err != nil {
		t.Fatal(err)
	}

	if err := r.MarkSubmitted(ctx, a.ID, "FX261119-TEST"+a.ID[:4], []byte{5}, []byte{6}, []byte{7}, now); err != nil {
		t.Fatal(err)
	}
	if err := r.MarkSubmitted(ctx, a.ID, "FX261119-AGAIN", nil, nil, nil, now); !errors.Is(err, ErrNotDraft) {
		t.Fatalf("重复提交应 ErrNotDraft: %v", err)
	}
	o, err := r.LoadOrch(ctx, a.ID)
	if err != nil || o == nil || o.Status != "SUBMITTED" || o.DWUserID != "" || len(o.UsernameEnc) != 1 {
		t.Fatalf("LoadOrch: %+v %v", o, err)
	}
	if o.LoginEmail == "" {
		t.Fatal("应带出登录邮箱")
	}
	if k, _ := r.KYC(ctx, a.ID); k == nil || k.Status != "KYC_NOT_READY" || k.DWUserID != "" {
		t.Fatalf("提交后应有 dw_users 影子行: %+v", k)
	}

	ids, _ := r.PendingSubmissions(ctx, now.Add(time.Minute), 100)
	if !containsID(ids, a.ID) {
		t.Fatal("新提交应在待续传列表中")
	}
	if err := r.RecordAttempt(ctx, a.ID, "DW HTTP 503", false, now); err != nil {
		t.Fatal(err)
	}
	if ids, _ := r.PendingSubmissions(ctx, now.Add(-time.Second), 100); containsID(ids, a.ID) {
		t.Fatal("刚尝试过的不应立即重试")
	}

	dwID := "it-dw-" + a.ID[:8]
	if err := r.SetDWUser(ctx, a.ID, dwID, StateCreated, now); err != nil {
		t.Fatal(err)
	}
	if err := r.SetOrchState(ctx, a.ID, StatePatched); err != nil {
		t.Fatal(err)
	}
	docs, _ := r.StagedDocuments(ctx, a.ID)
	if len(docs) != 1 {
		t.Fatalf("应有 1 份待上传证件: %d", len(docs))
	}
	if err := r.MarkDocumentUploaded(ctx, docs[0].ID, "dw-doc-1", now); err != nil {
		t.Fatal(err)
	}
	if docs, _ := r.StagedDocuments(ctx, a.ID); len(docs) != 0 {
		t.Fatal("已上传证件不应再出现")
	}
	if err := r.SetOrchState(ctx, a.ID, StateDocsDone); err != nil {
		t.Fatal(err)
	}
	o, _ = r.LoadOrch(ctx, a.ID)
	if o.DWUserID != dwID || o.OrchState != StateDocsDone || o.SubmitAttempts != 1 {
		t.Fatalf("最终状态不正确: %+v", o)
	}
	if ids, _ := r.PendingSubmissions(ctx, now.Add(time.Hour), 100); containsID(ids, a.ID) {
		t.Fatal("已完成的不应在待续传列表中")
	}
	if err := r.RecordAttempt(ctx, a.ID, "DW HTTP 400", true, now); err != nil {
		t.Fatal(err)
	}
	if o, _ = r.LoadOrch(ctx, a.ID); !o.SubmitBlocked {
		t.Fatal("blocked 应被记录")
	}
	if err := r.Audit(ctx, "system", "test.event", "application:"+a.ID, map[string]any{"k": "v"}); err != nil {
		t.Fatal(err)
	}
}

func containsID(ids []string, id string) bool {
	for _, x := range ids {
		if x == id {
			return true
		}
	}
	return false
}

func TestPGProgress(t *testing.T) {
	r, uid := pgRepo(t)
	ctx := context.Background()
	if p, err := r.Progress(ctx, uid); err != nil || p != nil {
		t.Fatalf("无申请应 nil: %v %v", p, err)
	}
	a, _ := r.EnsureDraft(ctx, uid)
	now := time.Now().UTC()
	_ = r.MarkSubmitted(ctx, a.ID, "FXIT-"+a.ID[:8], []byte{1}, []byte{2}, []byte{3}, now)
	p, err := r.Progress(ctx, uid)
	if err != nil || p.AppStatus != "SUBMITTED" || p.HasDWUser || p.KYCStatus != "KYC_NOT_READY" {
		t.Fatalf("提交后进度: %+v %v", p, err)
	}
	dw := "it-prog-" + a.ID[:8]
	_ = r.SetDWUser(ctx, a.ID, dw, StateDocsDone, now)
	_, _ = r.DB.Exec(`UPDATE dw_users SET kyc_status = 'KYC_APPROVED' WHERE application_id = $1`, a.ID)
	_, _ = r.DB.Exec(`INSERT INTO kyc_issues (dw_user_id, code, field, user_message) VALUES ($1, 'X', 'tin', 'm')`, dw)
	_, _ = r.DB.Exec(`INSERT INTO accounts (dw_user_id, dw_account_id, account_no, status) VALUES ($1, $2, $3, 'OPEN')`, dw, "it-prog-acc-"+a.ID[:8], "ITP"+a.ID[:8])
	p, _ = r.Progress(ctx, uid)
	if !p.HasDWUser || p.KYCStatus != "KYC_APPROVED" || p.AccountStatus == nil || *p.AccountStatus != "OPEN" || len(p.Issues) != 1 || *p.Issues[0].Field != "tin" {
		t.Fatalf("完整进度不正确: %+v", p)
	}
}
