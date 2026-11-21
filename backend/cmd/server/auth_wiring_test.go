package main

import (
	"context"
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"io"
	"log/slog"
	"net/http/httptest"
	"sort"
	"strings"
	"testing"

	_ "github.com/jackc/pgx/v5/stdlib"

	"github.com/imamura-akira/New_FinX/backend/internal/config"
	"github.com/imamura-akira/New_FinX/backend/internal/dwclient"
	"github.com/imamura-akira/New_FinX/backend/internal/store"
)

// 审计 TEST-P1-1：用真实的路由装配（buildRoutes）逐个检查契约中的接口——除公开接口外，不带 token 一律 401。
// 数据库与 DW 均为不可达的惰性连接：鉴权在访问数据库之前就拒绝，因此不需要真实依赖。
func TestContractRoutesRequireAuth(t *testing.T) {
	env := map[string]string{
		"DATABASE_URL":       "postgres://u:p@127.0.0.1:1/x?sslmode=disable&connect_timeout=1",
		"PII_ENCRYPTION_KEY": base64.StdEncoding.EncodeToString(make([]byte, 32)),
		"JWT_SECRET":         base64.StdEncoding.EncodeToString(make([]byte, 48)),
		"DW_BASE_URL":        "http://127.0.0.1:1",
		"DW_APP_KEY":         "k", "DW_CLIENT_ID": "c", "DW_CLIENT_SECRET": "s",
	}
	cfg, err := config.LoadFrom(func(k string) string { return env[k] })
	if err != nil {
		t.Fatal(err)
	}
	db, err := sql.Open("pgx", cfg.DatabaseURL)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = db.Close() })
	dw, err := dwclient.New(dwclient.Config{BaseURL: cfg.DW.BaseURL, AppKey: "k", ClientID: "c", ClientSecret: "s"})
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	routes, err := buildRoutes(ctx, cfg, &store.Store{DB: db}, dw, logger)
	if err != nil {
		t.Fatal(err)
	}
	h := newMux(healthDeps{}, routes...)

	public := map[string]bool{ // 契约规定无需登录
		"POST /api/v1/auth/otp/request": true, "POST /api/v1/auth/otp/verify": true, "POST /api/v1/auth/oauth": true,
	}
	var pending []string
	checked, skipped := 0, 0
	for _, op := range contractOps() {
		method, path, _ := strings.Cut(op, " ")
		if public[op] || strings.HasPrefix(path, apiPrefix+"/market/") {
			skipped++
			continue
		}
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, httptest.NewRequest(method, samplePath(path), strings.NewReader("{}")))
		var env struct{ Code int }
		_ = json.Unmarshal(rec.Body.Bytes(), &env)
		switch {
		case rec.Code == 401 && env.Code == 40101:
			checked++
		case rec.Code == 501 && env.Code == 50003:
			pending = append(pending, op) // 契约占位、尚未实现（审计 SEC-P2-3：实现时须挂 RequireAuth）
		default:
			t.Errorf("%s 未登录应返回 401/40101，实际 HTTP %d code %d", op, rec.Code, env.Code)
		}
	}
	sort.Strings(pending)
	wantPending := []string{"GET /api/v1/documents", "GET /api/v1/notifications", "PATCH /api/v1/application/remediate", "POST /api/v1/notifications/read"}
	sort.Strings(wantPending)
	if strings.Join(pending, ",") != strings.Join(wantPending, ",") {
		t.Errorf("占位接口变化：%v（期望 %v）——新实现的接口必须要求登录", pending, wantPending)
	}
	if total := len(contractOps()); checked+len(pending)+skipped != total || checked == 0 {
		t.Errorf("覆盖不完整：受保护 %d + 占位 %d + 公开 %d ≠ 契约 %d", checked, len(pending), skipped, total)
	}
	t.Logf("受保护接口 %d 个均要求登录；公开 %d；占位 %d", checked, skipped, len(pending))
}
