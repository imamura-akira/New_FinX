package store

import (
	"context"
	"io/fs"
	"os"
	"regexp"
	"strings"
	"testing"
)

// 11 张表必须都在首版迁移中（backend-design.md 第 6 节）。
var wantTables = []string{
	"users_app", "sessions", "applications", "dw_users", "kyc_issues", "accounts",
	"bank_accounts", "transfers", "documents_meta", "dw_events", "audit_log",
}

func TestMigrationsEmbeddedAndPaired(t *testing.T) {
	files, err := fs.Glob(migrationsFS, "migrations/*.sql")
	if err != nil || len(files) == 0 {
		t.Fatalf("未找到内嵌迁移文件: %v", err)
	}
	ups, downs := map[string]bool{}, map[string]bool{}
	re := regexp.MustCompile(`^migrations/(\d+_[a-z0-9_]+)\.(up|down)\.sql$`)
	for _, f := range files {
		m := re.FindStringSubmatch(f)
		if m == nil {
			t.Fatalf("迁移文件命名不规范: %s", f)
		}
		if m[2] == "up" {
			ups[m[1]] = true
		} else {
			downs[m[1]] = true
		}
	}
	for v := range ups {
		if !downs[v] {
			t.Fatalf("迁移 %s 缺少 down 文件", v)
		}
	}
}

func TestInitMigrationCreatesAllTables(t *testing.T) {
	up, err := migrationsFS.ReadFile("migrations/000001_init.up.sql")
	if err != nil {
		t.Fatal(err)
	}
	down, _ := migrationsFS.ReadFile("migrations/000001_init.down.sql")
	for _, tbl := range wantTables {
		if !strings.Contains(string(up), "CREATE TABLE "+tbl+" (") {
			t.Errorf("up 迁移缺少表 %s", tbl)
		}
		if !strings.Contains(string(down), "DROP TABLE IF EXISTS "+tbl+";") {
			t.Errorf("down 迁移缺少表 %s", tbl)
		}
	}
	if n := strings.Count(string(up), "CREATE TABLE "); n != len(wantTables) {
		t.Errorf("期望 %d 张表，实际 %d", len(wantTables), n)
	}
}

func TestOpenWithoutDSN(t *testing.T) {
	if _, err := Open(context.Background(), ""); err != ErrNoDatabaseURL {
		t.Fatalf("应返回 ErrNoDatabaseURL，实际 %v", err)
	}
}

// 集成测试：设置 TEST_DATABASE_URL 时在真实 Postgres 上执行 up → down → up。
func TestMigrateIntegration(t *testing.T) {
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("未设置 TEST_DATABASE_URL，跳过数据库集成测试")
	}
	s, err := Open(context.Background(), dsn)
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()
	if err := s.MigrateUp(); err != nil {
		t.Fatal(err)
	}
	for _, tbl := range wantTables {
		var exists bool
		if err := s.DB.QueryRow(`SELECT to_regclass($1) IS NOT NULL`, tbl).Scan(&exists); err != nil || !exists {
			t.Fatalf("表 %s 未创建: %v", tbl, err)
		}
	}
	// 000002：提交编排字段与证件暂存表
	var docs bool
	if err := s.DB.QueryRow(`SELECT to_regclass('application_documents') IS NOT NULL`).Scan(&docs); err != nil || !docs {
		t.Fatalf("application_documents 未创建: %v", err)
	}
	var nullable string
	if err := s.DB.QueryRow(`SELECT is_nullable FROM information_schema.columns WHERE table_name = 'dw_users' AND column_name = 'dw_user_id'`).Scan(&nullable); err != nil || nullable != "YES" {
		t.Fatalf("dw_users.dw_user_id 应可空: %q %v", nullable, err)
	}
	// 每一步都能回滚再重放
	for i := 0; i < 2; i++ {
		if err := s.MigrateDown(); err != nil {
			t.Fatal(err)
		}
	}
	if err := s.MigrateUp(); err != nil {
		t.Fatal(err)
	}
}
