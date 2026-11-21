package main

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestPendingRoutes(t *testing.T) {
	implemented := func(mux *http.ServeMux) {
		mux.HandleFunc("GET "+apiPrefix+"/me", func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusTeapot) })
	}
	h := newMux(healthDeps{}, implemented)
	cases := []struct {
		name, method, path string
		wantHTTP, wantCode int
	}{
		{"已实现的接口不被覆盖", "GET", "/api/v1/me", http.StatusTeapot, -1},
		{"未实现接口返回 50003", "POST", "/api/v1/funding/deposits", 501, 50003},
		{"带路径参数的未实现接口", "DELETE", "/api/v1/funding/bank-accounts/abc", 501, 50003},
		{"契约外路径 404", "GET", "/api/v1/nope", 404, -1},
		{"healthz 不受影响", "GET", "/healthz", 200, 0},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			rec := httptest.NewRecorder()
			h.ServeHTTP(rec, httptest.NewRequest(tc.method, tc.path, nil))
			if rec.Code != tc.wantHTTP {
				t.Fatalf("HTTP %d，期望 %d", rec.Code, tc.wantHTTP)
			}
			if tc.wantCode >= 0 {
				var env struct{ Code int }
				_ = json.Unmarshal(rec.Body.Bytes(), &env)
				if env.Code != tc.wantCode {
					t.Fatalf("code %d，期望 %d", env.Code, tc.wantCode)
				}
			}
		})
	}
	const wantOps = 50 // F22-b 新增 GET /market/stats；2026-11-21 新增 GET /funding/limits // F19 新增 6 个预测接口；v1.2：F14 新增 5 个交易接口；v1.3：F15 新增 7 个模拟盘接口；F11 扩展新增市场情绪；F17 新增 4 个资产分布 / 趋势接口
	if n := len(contractOps()); n != wantOps {
		t.Fatalf("契约接口数 %d，期望 %d", n, wantOps)
	}
}

func TestCORS(t *testing.T) {
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusOK) })
	cases := []struct {
		name, origin, method string
		origins              []string
		wantAllow            string
		wantHTTP             int
	}{
		{"未配置则不启用", "http://localhost:5000", "GET", nil, "", 200},
		{"允许的来源", "http://localhost:5000", "GET", []string{"http://localhost:5000"}, "http://localhost:5000", 200},
		{"未允许的来源", "http://evil.example", "GET", []string{"http://localhost:5000"}, "", 200},
		{"预检请求", "http://localhost:5000", "OPTIONS", []string{"*"}, "http://localhost:5000", 204},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest(tc.method, "/api/v1/me", nil)
			req.Header.Set("Origin", tc.origin)
			rec := httptest.NewRecorder()
			withCORS(tc.origins, next).ServeHTTP(rec, req)
			if got := rec.Header().Get("Access-Control-Allow-Origin"); got != tc.wantAllow || rec.Code != tc.wantHTTP {
				t.Fatalf("allow=%q http=%d，期望 %q %d", got, rec.Code, tc.wantAllow, tc.wantHTTP)
			}
		})
	}
}

func TestAccessLogOmitsSecrets(t *testing.T) {
	var logs strings.Builder
	h := withAccessLog(slog.New(slog.NewJSONHandler(&logs, nil)), newMux(healthDeps{}))
	req := httptest.NewRequest("POST", "/api/v1/funding/deposits?token=abc", nil)
	req.Header.Set("Authorization", "Bearer secret-token")
	h.ServeHTTP(httptest.NewRecorder(), req)
	for _, leak := range []string{"secret-token", "token=abc"} {
		if strings.Contains(logs.String(), leak) {
			t.Fatalf("访问日志泄露 %q: %s", leak, logs.String())
		}
	}
	if !strings.Contains(logs.String(), `"route":"POST /api/v1/funding/deposits"`) {
		t.Fatalf("访问日志缺少路由: %s", logs.String())
	}
}
