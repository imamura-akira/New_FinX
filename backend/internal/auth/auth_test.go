package auth

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"
)

// ---------- 内存仓储 ----------

type memRepo struct {
	mu       sync.Mutex
	users    map[string]string // email -> id
	sessions map[string]memSession
}

type memSession struct {
	uid     string
	exp     time.Time
	revoked bool
}

func newMemRepo() *memRepo {
	return &memRepo{users: map[string]string{}, sessions: map[string]memSession{}}
}

func (m *memRepo) UpsertEmailUser(_ context.Context, email string) (string, bool, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if id, ok := m.users[email]; ok {
		return id, false, nil
	}
	id := fmt.Sprintf("u-%d", len(m.users)+1)
	m.users[email] = id
	return id, true, nil
}

func (m *memRepo) CreateSession(_ context.Context, h, uid string, exp time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.sessions[h] = memSession{uid: uid, exp: exp}
	return nil
}

func (m *memRepo) SessionUser(_ context.Context, h string, now time.Time) (string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	s, ok := m.sessions[h]
	if !ok || s.revoked || !now.Before(s.exp) {
		return "", ErrNoSession
	}
	return s.uid, nil
}

func (m *memRepo) RevokeSession(_ context.Context, h string, _ time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if s, ok := m.sessions[h]; ok {
		s.revoked = true
		m.sessions[h] = s
	}
	return nil
}

func (m *memRepo) Me(_ context.Context, uid string) (Me, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	for e, id := range m.users {
		if id == uid {
			return Me{Email: e, LoginProvider: "EMAIL", AccountStatus: "NONE"}, nil
		}
	}
	return Me{}, fmt.Errorf("not found")
}

// captureSender 记录最后一次发送的验证码。
type captureSender struct {
	mu    sync.Mutex
	codes map[string]string
	fail  bool
}

func (c *captureSender) Send(_ context.Context, email, code string) error {
	if c.fail {
		return fmt.Errorf("smtp down")
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.codes[email] = code
	return nil
}

type harness struct {
	svc    *Service
	mux    *http.ServeMux
	sender *captureSender
	clock  *time.Time
}

var testSecret = bytes.Repeat([]byte("k"), 48)

func newHarness() *harness {
	now := time.Date(2026, 11, 19, 10, 0, 0, 0, time.UTC)
	h := &harness{sender: &captureSender{codes: map[string]string{}}, clock: &now}
	h.svc = New(newMemRepo(), h.sender, testSecret, 24*time.Hour, slog.New(slog.NewTextHandler(io.Discard, nil)))
	h.svc.now = func() time.Time { return *h.clock }
	h.mux = http.NewServeMux()
	h.svc.Routes(h.mux, "/api/v1")
	return h
}

type resp struct {
	status int
	Code   int             `json:"code"`
	Msg    string          `json:"message"`
	Data   json.RawMessage `json:"data"`
}

func (h *harness) do(method, path, token string, body any) resp {
	var rd io.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		rd = bytes.NewReader(b)
	}
	req := httptest.NewRequest(method, path, rd)
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	rec := httptest.NewRecorder()
	h.mux.ServeHTTP(rec, req)
	var r resp
	_ = json.Unmarshal(rec.Body.Bytes(), &r)
	r.status = rec.Code
	return r
}

func (h *harness) login(t *testing.T, email string) (string, bool) {
	t.Helper()
	if r := h.do("POST", "/api/v1/auth/otp/request", "", map[string]string{"email": email}); r.Code != 0 {
		t.Fatalf("request otp: %+v", r)
	}
	r := h.do("POST", "/api/v1/auth/otp/verify", "", map[string]string{"email": email, "code": h.sender.codes[strings.ToLower(email)]})
	if r.Code != 0 {
		t.Fatalf("verify otp: %+v", r)
	}
	var d struct {
		SessionToken string `json:"sessionToken"`
		IsNewUser    bool   `json:"isNewUser"`
	}
	_ = json.Unmarshal(r.Data, &d)
	return d.SessionToken, d.IsNewUser
}

// ---------- 测试 ----------

func TestRequestOTP(t *testing.T) {
	cases := []struct {
		name     string
		body     any
		wantHTTP int
		wantCode int
	}{
		{"合法邮箱", map[string]string{"email": "Alex@Example.com"}, 200, 0},
		{"邮箱格式错误", map[string]string{"email": "not-an-email"}, 422, 42200},
		{"缺少邮箱", map[string]string{}, 422, 42200},
		{"未知字段", map[string]any{"email": "a@b.co", "x": 1}, 422, 42200},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			h := newHarness()
			r := h.do("POST", "/api/v1/auth/otp/request", "", tc.body)
			if r.status != tc.wantHTTP || r.Code != tc.wantCode {
				t.Fatalf("got %d/%d want %d/%d (%s)", r.status, r.Code, tc.wantHTTP, tc.wantCode, r.Msg)
			}
		})
	}
}

func TestOTPRateLimits(t *testing.T) {
	h := newHarness()
	body := map[string]string{"email": "a@example.com"}
	if r := h.do("POST", "/api/v1/auth/otp/request", "", body); r.Code != 0 {
		t.Fatal(r)
	}
	// 60 秒内重发 → 42901
	if r := h.do("POST", "/api/v1/auth/otp/request", "", body); r.status != 429 || r.Code != 42901 {
		t.Fatalf("resend too soon: %+v", r)
	}
	// 每小时最多 5 次
	for i := 1; i < OTPMaxSendsPerHour; i++ {
		*h.clock = h.clock.Add(OTPResendAfter)
		if r := h.do("POST", "/api/v1/auth/otp/request", "", body); r.Code != 0 {
			t.Fatalf("send %d: %+v", i+1, r)
		}
	}
	*h.clock = h.clock.Add(OTPResendAfter)
	if r := h.do("POST", "/api/v1/auth/otp/request", "", body); r.Code != 42901 {
		t.Fatalf("hourly cap: %+v", r)
	}
	// 一小时后恢复
	*h.clock = h.clock.Add(time.Hour)
	if r := h.do("POST", "/api/v1/auth/otp/request", "", body); r.Code != 0 {
		t.Fatalf("after window: %+v", r)
	}
}

func TestSendFailureDoesNotBlockResend(t *testing.T) {
	h := newHarness()
	h.sender.fail = true
	if r := h.do("POST", "/api/v1/auth/otp/request", "", map[string]string{"email": "a@example.com"}); r.status != 500 || r.Code != 50000 {
		t.Fatalf("want 500/50000, got %+v", r)
	}
	h.sender.fail = false
	if r := h.do("POST", "/api/v1/auth/otp/request", "", map[string]string{"email": "a@example.com"}); r.Code != 0 {
		t.Fatalf("resend after failure should work: %+v", r)
	}
}

func TestVerifyOTP(t *testing.T) {
	cases := []struct {
		name     string
		mutate   func(h *harness, code string) string // 返回要提交的验证码
		wantCode int
	}{
		{"正确验证码", func(h *harness, c string) string { return c }, 0},
		{"错误验证码", func(h *harness, c string) string { return wrong(c) }, 42200},
		{"已过期", func(h *harness, c string) string { *h.clock = h.clock.Add(OTPTTL + time.Second); return c }, 42200},
		{"非 6 位", func(h *harness, c string) string { return "123" }, 42200},
		{"错误次数用尽后正确码也失效", func(h *harness, c string) string {
			for i := 0; i < OTPMaxAttempts; i++ {
				h.do("POST", "/api/v1/auth/otp/verify", "", map[string]string{"email": "a@example.com", "code": wrong(c)})
			}
			return c
		}, 42200},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			h := newHarness()
			h.do("POST", "/api/v1/auth/otp/request", "", map[string]string{"email": "a@example.com"})
			code := tc.mutate(h, h.sender.codes["a@example.com"])
			r := h.do("POST", "/api/v1/auth/otp/verify", "", map[string]string{"email": "a@example.com", "code": code})
			if r.Code != tc.wantCode {
				t.Fatalf("got %d (%s) want %d", r.Code, r.Msg, tc.wantCode)
			}
		})
	}
}

func wrong(c string) string {
	if c == "000000" {
		return "000001"
	}
	return "000000"
}

func TestOTPSingleUse(t *testing.T) {
	h := newHarness()
	h.do("POST", "/api/v1/auth/otp/request", "", map[string]string{"email": "a@example.com"})
	code := h.sender.codes["a@example.com"]
	if r := h.do("POST", "/api/v1/auth/otp/verify", "", map[string]string{"email": "a@example.com", "code": code}); r.Code != 0 {
		t.Fatal(r)
	}
	if r := h.do("POST", "/api/v1/auth/otp/verify", "", map[string]string{"email": "a@example.com", "code": code}); r.Code != 42200 {
		t.Fatalf("code reused: %+v", r)
	}
}

func TestNewUserFlagAndCaseInsensitiveEmail(t *testing.T) {
	h := newHarness()
	_, isNew := h.login(t, "Alex@Example.com")
	if !isNew {
		t.Fatal("first login should be new user")
	}
	*h.clock = h.clock.Add(OTPResendAfter)
	_, isNew = h.login(t, "alex@example.com")
	if isNew {
		t.Fatal("second login (different case) should not be new user")
	}
}

func TestSessionLifecycle(t *testing.T) {
	h := newHarness()
	tok, _ := h.login(t, "a@example.com")

	cases := []struct {
		name     string
		token    string
		before   func()
		wantHTTP int
		wantCode int
	}{
		{"无 token", "", nil, 401, 40101},
		{"伪造 token", tok[:len(tok)-2] + "xx", nil, 401, 40101},
		{"有效 token", tok, nil, 200, 0},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			r := h.do("GET", "/api/v1/me", tc.token, nil)
			if r.status != tc.wantHTTP || r.Code != tc.wantCode {
				t.Fatalf("got %d/%d want %d/%d", r.status, r.Code, tc.wantHTTP, tc.wantCode)
			}
		})
	}

	var me Me
	_ = json.Unmarshal(h.do("GET", "/api/v1/me", tok, nil).Data, &me)
	if me.Email != "a@example.com" || me.AccountStatus != "NONE" || me.ApplicationID != nil {
		t.Fatalf("me = %+v", me)
	}

	// 注销后 token 失效（40102）
	if r := h.do("POST", "/api/v1/auth/logout", tok, nil); r.Code != 0 {
		t.Fatal(r)
	}
	if r := h.do("GET", "/api/v1/me", tok, nil); r.status != 401 || r.Code != 40102 {
		t.Fatalf("after logout: %+v", r)
	}
}

func TestSessionExpiry(t *testing.T) {
	h := newHarness()
	tok, _ := h.login(t, "a@example.com")
	*h.clock = h.clock.Add(24*time.Hour + time.Second)
	if r := h.do("GET", "/api/v1/me", tok, nil); r.status != 401 || r.Code != 40102 {
		t.Fatalf("expired: %+v", r)
	}
}

func TestTokenFromOtherSecretRejected(t *testing.T) {
	h := newHarness()
	now := *h.clock
	forged, _ := signJWT(bytes.Repeat([]byte("x"), 48), claims{Sub: "u-1", Sid: "s", Iat: now.Unix(), Exp: now.Add(time.Hour).Unix()})
	if r := h.do("GET", "/api/v1/me", forged, nil); r.Code != 40101 {
		t.Fatalf("forged token accepted: %+v", r)
	}
}

func TestOAuthNotEnabled(t *testing.T) {
	h := newHarness()
	r := h.do("POST", "/api/v1/auth/oauth", "", map[string]string{"provider": "GOOGLE", "idToken": "x"})
	if r.status != 501 || r.Code != 50003 {
		t.Fatalf("got %+v", r)
	}
}

func TestDevLogSenderMasksEmail(t *testing.T) {
	var buf bytes.Buffer
	s := DevLogSender{Logger: slog.New(slog.NewJSONHandler(&buf, nil))}
	_ = s.Send(context.Background(), "alex.chen@example.com", "123456")
	if strings.Contains(buf.String(), "alex.chen@") || !strings.Contains(buf.String(), "a***@example.com") {
		t.Fatalf("email not masked: %s", buf.String())
	}
}
