package main

import (
	"context"
	"encoding/json"
	"net/http"
	"time"
)

// envelope 是 api-spec.md 约定的统一响应包装。
type envelope struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    any    `json:"data,omitempty"`
}

type healthDeps struct {
	env          string
	version      string
	dbPing       func(context.Context) error // nil 表示未配置数据库
	dwConfigured bool
}

type healthData struct {
	Status  string `json:"status"` // ok | degraded
	Env     string `json:"env"`
	Version string `json:"version"`
	DB      string `json:"db"` // ok | error | not_configured
	DW      string `json:"dw"` // configured | not_configured（不调用 DW，避免消耗 token 预算）
	Time    string `json:"time"`
}

// apiPrefix：api-spec.md 的 Base URL。
const apiPrefix = "/api/v1"

// newMux 注册路由。/healthz 为运维接口，不属于 /api/v1 契约；业务路由由 register 挂载（可为 nil）。
func newMux(d healthDeps, register ...func(*http.ServeMux)) http.Handler {
	mux := http.NewServeMux()
	for _, reg := range register {
		reg(mux)
	}
	defer registerPending(mux) // 契约中尚未实现的接口统一返回 50003
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		h := healthData{Status: "ok", Env: d.env, Version: d.version, DB: "not_configured", DW: "not_configured", Time: time.Now().UTC().Format(time.RFC3339)}
		if d.dwConfigured {
			h.DW = "configured"
		}
		status := http.StatusOK
		if d.dbPing != nil {
			ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
			defer cancel()
			if err := d.dbPing(ctx); err != nil {
				h.DB, h.Status, status = "error", "degraded", http.StatusServiceUnavailable
			} else {
				h.DB = "ok"
			}
		}
		writeJSON(w, status, envelope{Code: 0, Message: "ok", Data: h})
	})
	return mux
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
