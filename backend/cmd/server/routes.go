package main

import (
	"log/slog"
	"net/http"
	"net/http/httptest"
	"sort"
	"strings"
	"time"

	"gopkg.in/yaml.v3"

	"github.com/imamura-akira/New_FinX/backend/api"
	"github.com/imamura-akira/New_FinX/backend/internal/httpx"
)

// contractOps 读取 openapi.yaml 中的全部接口（"METHOD /path"，path 已带 apiPrefix）。
func contractOps() []string {
	var doc struct {
		Paths map[string]map[string]any `yaml:"paths"`
	}
	if err := yaml.Unmarshal(api.OpenAPI, &doc); err != nil {
		panic("openapi.yaml 无法解析: " + err.Error()) // 构建期内嵌文件，有契约测试保护
	}
	var ops []string
	for p, methods := range doc.Paths {
		for m := range methods {
			ops = append(ops, strings.ToUpper(m)+" "+apiPrefix+p)
		}
	}
	sort.Strings(ops)
	return ops
}

// registerPending 为契约中已定义、但尚未由业务模块挂载的接口返回 50003（HTTP 501），
// 保证 App 始终拿到统一的响应包装。业务模块挂载后自动不再走这里。
func registerPending(mux *http.ServeMux) []string {
	var pending []string
	for _, op := range contractOps() {
		method, path, _ := strings.Cut(op, " ")
		probe := httptest.NewRequest(method, samplePath(path), nil)
		if _, pattern := mux.Handler(probe); pattern != "" {
			continue
		}
		mux.HandleFunc(op, func(w http.ResponseWriter, r *http.Request) {
			httpx.Fail(w, r, httpx.NotEnabled("该功能正在开发中"))
		})
		pending = append(pending, op)
	}
	return pending
}

// samplePath 把 {id} 之类的路径参数替换为示例值，用于探测是否已注册。
func samplePath(p string) string {
	parts := strings.Split(p, "/")
	for i, s := range parts {
		if strings.HasPrefix(s, "{") {
			parts[i] = "x"
		}
	}
	return strings.Join(parts, "/")
}

// withCORS：仅在配置了 CORS_ALLOWED_ORIGINS 时生效（iOS 原生 App 不需要；为 Flutter Web 调试预留）。
func withCORS(origins []string, next http.Handler) http.Handler {
	if len(origins) == 0 {
		return next
	}
	allow := map[string]bool{}
	for _, o := range origins {
		allow[o] = true
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if o := r.Header.Get("Origin"); o != "" && (allow["*"] || allow[o]) {
			w.Header().Set("Access-Control-Allow-Origin", o)
			w.Header().Set("Vary", "Origin")
			w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type, Idempotency-Key")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
			w.Header().Set("Access-Control-Max-Age", "600")
			if r.Method == http.MethodOptions {
				w.WriteHeader(http.StatusNoContent)
				return
			}
		}
		next.ServeHTTP(w, r)
	})
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (s *statusRecorder) WriteHeader(code int) {
	s.status = code
	s.ResponseWriter.WriteHeader(code)
}

// withAccessLog：记录方法、路由模式、状态码与耗时；不记录请求体、查询串与 Authorization。
func withAccessLog(logger *slog.Logger, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rec, r)
		if r.URL.Path == "/healthz" {
			return
		}
		pattern := r.Pattern
		if pattern == "" {
			pattern = r.Method + " (unmatched)"
		}
		logger.Info("http", slog.String("route", pattern), slog.Int("status", rec.status), slog.Int64("duration_ms", time.Since(start).Milliseconds()))
	})
}
