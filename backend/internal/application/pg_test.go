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
