package account

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/dwclient"
	"github.com/imamura-akira/New_FinX/backend/internal/httpx"
)

type memRepo struct {
	mu       sync.Mutex
	pending  []Pending
	accounts []Account
	attempts map[string]string
	byUser   map[string]*Account
}

func (m *memRepo) NeedAccount(context.Context, int) ([]Pending, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var out []Pending
	for _, p := range m.pending {
		has := false
		for _, a := range m.accounts {
			if a.DWUserID == p.DWUserID {
				has = true
			}
		}
		if !has {
			out = append(out, p)
		}
	}
	return out, nil
}

func (m *memRepo) SaveAccount(_ context.Context, a Account, _ time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	a.ID = "acc-" + a.DWAccountID
	m.accounts = append(m.accounts, a)
	return nil
}

func (m *memRepo) RecordAttempt(_ context.Context, appID, msg string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.attempts[appID] = msg
	return nil
}

func (m *memRepo) NotOpen(context.Context, int) ([]Account, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var out []Account
	for _, a := range m.accounts {
		if a.Status == "PENDING" {
			out = append(out, a)
		}
	}
	return out, nil
}

func (m *memRepo) UpdateStatus(_ context.Context, dwID, st string, opened *time.Time, _ time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	for i := range m.accounts {
		if m.accounts[i].DWAccountID == dwID {
			m.accounts[i].Status = st
			if opened != nil {
				m.accounts[i].OpenedAt = opened
			}
		}
	}
	return nil
}

func (m *memRepo) ForUser(_ context.Context, uid string) (*Account, error) {
	if a := m.byUser[uid]; a != nil {
		cp := *a
		return &cp, nil
	}
	return nil, nil
}

var syncTime = time.Date(2026, 11, 20, 1, 2, 3, 0, time.UTC)

func (m *memRepo) SyncInfo(context.Context, string) (string, *time.Time, error) {
	return "KYC_APPROVED", &syncTime, nil
}
func (m *memRepo) Audit(context.Context, string, string, string, map[string]any) error {
	return nil
}

type call struct {
	method, path string
	body         map[string]any
}

type fakeDW struct {
	calls    []call
	existing []map[string]any
	created  map[string]any
	get      map[string]any
	err      map[string]error
}

func (f *fakeDW) Do(_ context.Context, method, path string, body, out any) error {
	var m map[string]any
	raw, _ := json.Marshal(body)
	_ = json.Unmarshal(raw, &m)
	f.calls = append(f.calls, call{method, path, m})
	key := method + " " + path
	if e := f.err[key]; e != nil {
		return e
	}
	var resp any
	switch {
	case method == "GET" && strings.HasSuffix(path, "/accounts"):
		resp = f.existing
		if resp == nil {
			resp = []any{}
		}
	case method == "POST" && path == "/accounts":
		resp = f.created
	case method == "GET" && strings.HasPrefix(path, "/accounts/"):
		resp = f.get
	}
	raw, _ = json.Marshal(resp)
	return json.Unmarshal(raw, out)
}

func newSvc(r *memRepo, dw *fakeDW) *Service {
	return New(r, dw, slog.New(slog.NewTextHandler(io.Discard, nil)))
}

func TestEnsureAccounts(t *testing.T) {
	cases := []struct {
		name       string
		dw         *fakeDW
		wantPost   bool
		wantStatus string
		wantNo     string
		wantErr    bool
	}{
		{"新开户（状态对象）", &fakeDW{created: map[string]any{"id": "dwacc-1", "accountNo": "TEST000001", "status": map[string]any{"name": "OPEN"}}}, true, "OPEN", "TEST000001", false},
		{"新开户（状态字符串、PENDING）", &fakeDW{created: map[string]any{"id": "dwacc-1", "accountNo": "TEST000001", "status": "pending"}}, true, "PENDING", "TEST000001", false},
		{"未知状态按 PENDING", &fakeDW{created: map[string]any{"id": "dwacc-1", "status": "WEIRD"}}, true, "PENDING", "", false},
		{"已有 LIVE 账户则采用（幂等）", &fakeDW{existing: []map[string]any{{"id": "dwacc-9", "accountNo": "TEST000009", "accountType": map[string]any{"name": "LIVE"}, "status": "OPEN"}}}, false, "OPEN", "TEST000009", false},
		{"开户失败记录尝试", &fakeDW{err: map[string]error{"POST /accounts": &dwclient.APIError{Status: 400, DWCode: "E1"}}}, true, "", "", true},
		{"响应缺 id", &fakeDW{created: map[string]any{"accountNo": "X"}}, true, "", "", true},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			r := &memRepo{pending: []Pending{{AppID: "app-1", DWUserID: "dwu-1"}}, attempts: map[string]string{}}
			newSvc(r, tc.dw).EnsureAccounts(context.Background())
			posted := false
			for _, c := range tc.dw.calls {
				if c.method == "POST" && c.path == "/accounts" {
					posted = true
					want := map[string]any{"userID": "dwu-1", "accountType": "LIVE", "accountManagementType": "SELF", "tradingType": "CASH"}
					if len(c.body) != len(want) {
						t.Fatalf("开户请求体应只含 4 个字段（不得带 RIA 字段）: %v", c.body)
					}
					for k, v := range want {
						if c.body[k] != v {
							t.Fatalf("%s=%v，期望 %v", k, c.body[k], v)
						}
					}
				}
			}
			if posted != tc.wantPost {
				t.Fatalf("POST /accounts 调用=%v，期望 %v", posted, tc.wantPost)
			}
			if tc.dw.calls[0].path != "/users/dwu-1/accounts" {
				t.Fatal("开户前应先查询已有账户")
			}
			if tc.wantErr {
				if r.attempts["app-1"] == "" || len(r.accounts) != 0 {
					t.Fatalf("失败应记录尝试且不落库: %v", r.attempts)
				}
				return
			}
			if len(r.accounts) != 1 || r.accounts[0].Status != tc.wantStatus || r.accounts[0].AccountNo != tc.wantNo {
				t.Fatalf("落库不正确: %+v", r.accounts)
			}
			if (tc.wantStatus == "OPEN") != (r.accounts[0].OpenedAt != nil) {
				t.Fatal("OPEN 时应记录开户时间")
			}
		})
	}
}

func TestRefreshStatuses(t *testing.T) {
	r := &memRepo{accounts: []Account{{ID: "a1", DWAccountID: "dwacc-1", Status: "PENDING"}}, attempts: map[string]string{}}
	dw := &fakeDW{get: map[string]any{"id": "dwacc-1", "status": map[string]any{"name": "OPEN"}}}
	newSvc(r, dw).RefreshStatuses(context.Background())
	if r.accounts[0].Status != "OPEN" || r.accounts[0].OpenedAt == nil {
		t.Fatalf("应刷新为 OPEN: %+v", r.accounts[0])
	}
	if dw.calls[0].path != "/accounts/dwacc-1" {
		t.Fatalf("路径: %s", dw.calls[0].path)
	}
	// DW 出错不影响其他账户、不改状态
	r2 := &memRepo{accounts: []Account{{ID: "a1", DWAccountID: "dwacc-1", Status: "PENDING"}}}
	newSvc(r2, &fakeDW{err: map[string]error{"GET /accounts/dwacc-1": errors.New("timeout")}}).RefreshStatuses(context.Background())
	if r2.accounts[0].Status != "PENDING" {
		t.Fatal("出错时不应改状态")
	}
}

func TestGetAccount(t *testing.T) {
	now := time.Now()
	r := &memRepo{byUser: map[string]*Account{"u1": {ID: "a1", AccountNo: "TEST000001", Status: "OPEN", AccountType: "LIVE", TradingType: "CASH", Management: "SELF", OpenedAt: &now, DWAccountID: "secret-dw-id"}}}
	s := newSvc(r, nil)
	mux := http.NewServeMux()
	auth := func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
			next.ServeHTTP(w, req.WithContext(httpx.WithUser(req.Context(), req.Header.Get("X-User"))))
		})
	}
	s.Routes(mux, "/api/v1", auth)
	cases := []struct {
		user     string
		wantCode int
	}{{"u1", 0}, {"u2", 40901}}
	for _, tc := range cases {
		req := httptest.NewRequest("GET", "/api/v1/account", nil)
		req.Header.Set("X-User", tc.user)
		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, req)
		var env struct {
			Code int            `json:"code"`
			Data map[string]any `json:"data"`
		}
		_ = json.Unmarshal(rec.Body.Bytes(), &env)
		if env.Code != tc.wantCode {
			t.Fatalf("%s: code %d", tc.user, env.Code)
		}
		if tc.wantCode == 0 {
			if env.Data["accountNo"] != "TEST000001" || env.Data["managementType"] != "SELF" {
				t.Fatalf("响应: %v", env.Data)
			}
			if strings.Contains(rec.Body.String(), "secret-dw-id") || env.Data["dw"] != nil {
				t.Fatal("默认不应返回 DW 内部 id")
			}
		}
	}
}

func TestGetAccountDemoExposesDWIdentifiers(t *testing.T) {
	r := &memRepo{byUser: map[string]*Account{"u1": {ID: "a1", AccountNo: "TEST000001", Status: "OPEN", AccountType: "LIVE", TradingType: "CASH", Management: "SELF", DWAccountID: "dw-acc-1", DWUserID: "dw-user-1"}}}
	s := newSvc(r, nil)
	s.SetExposeDWIdentifiers(true)
	mux := http.NewServeMux()
	auth := func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
			next.ServeHTTP(w, req.WithContext(httpx.WithUser(req.Context(), "u1")))
		})
	}
	s.Routes(mux, "/api/v1", auth)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, httptest.NewRequest("GET", "/api/v1/account", nil))
	var env struct {
		Code int `json:"code"`
		Data struct {
			DW map[string]any `json:"dw"`
		} `json:"data"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &env); err != nil || env.Code != 0 {
		t.Fatalf("%v %s", err, rec.Body.String())
	}
	want := map[string]any{"userId": "dw-user-1", "accountId": "dw-acc-1", "accountNo": "TEST000001", "kycStatus": "KYC_APPROVED", "syncedAt": "2026-11-20T01:02:03Z"}
	for k, v := range want {
		if env.Data.DW[k] != v {
			t.Fatalf("dw.%s = %v, want %v", k, env.Data.DW[k], v)
		}
	}
}
