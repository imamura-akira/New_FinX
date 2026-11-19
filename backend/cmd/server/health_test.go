package main

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHealthz(t *testing.T) {
	cases := []struct {
		name       string
		deps       healthDeps
		wantStatus int
		wantDB     string
		wantDW     string
		wantState  string
	}{
		{"无数据库无凭据", healthDeps{env: "sandbox"}, 200, "not_configured", "not_configured", "ok"},
		{"数据库正常", healthDeps{env: "sandbox", dbPing: func(context.Context) error { return nil }, dwConfigured: true}, 200, "ok", "configured", "ok"},
		{"数据库异常", healthDeps{env: "sandbox", dbPing: func(context.Context) error { return errors.New("down") }}, 503, "error", "not_configured", "degraded"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			rec := httptest.NewRecorder()
			newMux(tc.deps).ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/healthz", nil))
			if rec.Code != tc.wantStatus {
				t.Fatalf("HTTP %d，期望 %d", rec.Code, tc.wantStatus)
			}
			var body struct {
				Code int        `json:"code"`
				Data healthData `json:"data"`
			}
			if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
				t.Fatal(err)
			}
			if body.Code != 0 || body.Data.DB != tc.wantDB || body.Data.DW != tc.wantDW || body.Data.Status != tc.wantState {
				t.Fatalf("响应不符: %+v", body)
			}
		})
	}
}

func TestHealthzMethodNotAllowed(t *testing.T) {
	rec := httptest.NewRecorder()
	newMux(healthDeps{}).ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/healthz", nil))
	if rec.Code != http.StatusMethodNotAllowed {
		t.Fatalf("POST /healthz 应返回 405，实际 %d", rec.Code)
	}
}
