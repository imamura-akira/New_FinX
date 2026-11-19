package dwclient

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// 测试用的假凭据（非真实值）
const (
	testAppKey = "test-app-key-0000"
	testID     = "test-client-id"
	testSecret = "test-client-secret-DO-NOT-LOG"
)

type fakeClock struct {
	mu sync.Mutex
	t  time.Time
}

func (c *fakeClock) Now() time.Time { c.mu.Lock(); defer c.mu.Unlock(); return c.t }
func (c *fakeClock) Add(d time.Duration) {
	c.mu.Lock()
	c.t = c.t.Add(d)
	c.mu.Unlock()
}

// fakeDW 模拟 DW：/auth/tokens 发 token；其余路径按 handler 处理。
type fakeDW struct {
	t           *testing.T
	tokenCalls  atomic.Int32
	expiresIn   int
	tokenStatus int
	handler     func(w http.ResponseWriter, r *http.Request)
}

func (f *fakeDW) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path == "/back-office/auth/tokens" {
		n := f.tokenCalls.Add(1)
		if r.Method != http.MethodPost {
			f.t.Errorf("token 请求方法应为 POST，实际 %s", r.Method)
		}
		if got := r.Header.Get("dw-client-app-key"); got != testAppKey {
			f.t.Errorf("token 请求缺少 dw-client-app-key 头")
		}
		var body map[string]string
		_ = json.NewDecoder(r.Body).Decode(&body)
		if body["clientID"] != testID || body["clientSecret"] != testSecret {
			f.t.Errorf("token 请求体不正确")
		}
		if f.tokenStatus != 0 {
			w.WriteHeader(f.tokenStatus)
			_, _ = w.Write([]byte(`{"errorCode":"A001","message":"invalid credentials"}`))
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]any{
			"access_token": "tok-" + string(rune('0'+n)),
			"expires_in":   f.expiresIn,
			"token_type":   "Bearer",
		})
		return
	}
	if f.handler != nil {
		f.handler(w, r)
		return
	}
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(`{}`))
}

type logBuf struct {
	mu  sync.Mutex
	buf bytes.Buffer
}

func (l *logBuf) Write(p []byte) (int, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.buf.Write(p)
}
func (l *logBuf) String() string { l.mu.Lock(); defer l.mu.Unlock(); return l.buf.String() }

func newTestClient(t *testing.T, f *fakeDW, perHour int) (*Client, *fakeClock, *logBuf) {
	t.Helper()
	srv := httptest.NewServer(f)
	t.Cleanup(srv.Close)
	clk := &fakeClock{t: time.Date(2026, 11, 19, 10, 0, 0, 0, time.UTC)}
	logs := &logBuf{}
	c, err := New(Config{
		BaseURL: srv.URL + "/back-office", AppKey: testAppKey, ClientID: testID, ClientSecret: testSecret,
		TokenRequestsPerHour: perHour, TokenRefreshSkew: 5 * time.Minute, RetryBackoff: time.Millisecond,
	},
		WithClock(clk.Now),
		WithLogger(slog.New(slog.NewJSONHandler(logs, &slog.HandlerOptions{Level: slog.LevelDebug}))),
		WithSleep(func(context.Context, time.Duration) error { return nil }),
	)
	if err != nil {
		t.Fatal(err)
	}
	return c, clk, logs
}

func TestNewRequiresCredentials(t *testing.T) {
	cases := []Config{
		{BaseURL: "https://x", ClientID: "a", ClientSecret: "b"},
		{BaseURL: "https://x", AppKey: "k", ClientSecret: "b"},
		{BaseURL: "https://x", AppKey: "k", ClientID: "a"},
		{AppKey: "k", ClientID: "a", ClientSecret: "b"},
	}
	for i, cfg := range cases {
		if _, err := New(cfg); !errors.Is(err, ErrNotConfigured) {
			t.Errorf("case %d: 应返回 ErrNotConfigured，实际 %v", i, err)
		}
	}
}

func TestTokenCachedAndHeaders(t *testing.T) {
	var gotAuth, gotKey atomic.Value
	f := &fakeDW{t: t, expiresIn: 3600, handler: func(w http.ResponseWriter, r *http.Request) {
		gotAuth.Store(r.Header.Get("Authorization"))
		gotKey.Store(r.Header.Get("dw-client-app-key"))
		_, _ = w.Write([]byte(`{"ok":true}`))
	}}
	c, clk, _ := newTestClient(t, f, 6)
	ctx := context.Background()
	for i := 0; i < 5; i++ {
		var out map[string]bool
		if err := c.Do(ctx, http.MethodGet, "/users/u1", nil, &out); err != nil || !out["ok"] {
			t.Fatalf("调用失败: %v %v", err, out)
		}
		clk.Add(10 * time.Minute) // 50 分钟内，未进入刷新窗口
	}
	if n := f.tokenCalls.Load(); n != 1 {
		t.Fatalf("token 应只申请 1 次，实际 %d", n)
	}
	if gotAuth.Load() != "Bearer tok-1" || gotKey.Load() != testAppKey {
		t.Fatalf("业务请求头不正确: %v %v", gotAuth.Load(), gotKey.Load())
	}
}

func TestTokenRefreshBeforeExpiry(t *testing.T) {
	f := &fakeDW{t: t, expiresIn: 3600}
	c, clk, _ := newTestClient(t, f, 6)
	ctx := context.Background()
	tok1, _ := c.Token(ctx)
	clk.Add(54 * time.Minute) // 距到期 6 分钟 > skew 5 分钟：仍用缓存
	tok2, _ := c.Token(ctx)
	clk.Add(2 * time.Minute) // 距到期 4 分钟 < skew：刷新
	tok3, _ := c.Token(ctx)
	if tok1 != tok2 || tok3 == tok2 || f.tokenCalls.Load() != 2 {
		t.Fatalf("刷新时机不正确: %s %s %s calls=%d", tok1, tok2, tok3, f.tokenCalls.Load())
	}
}

func TestTokenRateLimit(t *testing.T) {
	f := &fakeDW{t: t, expiresIn: 60} // 1 分钟有效：每次都在刷新窗口内，逼出限流
	c, clk, _ := newTestClient(t, f, 2)
	ctx := context.Background()
	if _, err := c.Token(ctx); err != nil {
		t.Fatal(err)
	}
	clk.Add(2 * time.Minute)
	if _, err := c.Token(ctx); err != nil {
		t.Fatal(err)
	}
	clk.Add(2 * time.Minute) // 第 3 次超出预算，且旧 token 已真正过期
	if _, err := c.Token(ctx); !errors.Is(err, ErrTokenRateLimited) {
		t.Fatalf("应返回 ErrTokenRateLimited，实际 %v", err)
	}
	if f.tokenCalls.Load() != 2 {
		t.Fatalf("超预算后不应再请求 DW，实际 %d 次", f.tokenCalls.Load())
	}
	clk.Add(61 * time.Minute) // 窗口滑过，预算恢复
	if _, err := c.Token(ctx); err != nil {
		t.Fatalf("窗口滑过后应恢复: %v", err)
	}
}

func TestRateLimitedFallsBackToUnexpiredToken(t *testing.T) {
	f := &fakeDW{t: t, expiresIn: 3600}
	c, clk, _ := newTestClient(t, f, 1)
	ctx := context.Background()
	tok1, _ := c.Token(ctx)
	clk.Add(57 * time.Minute) // 进入刷新窗口，但预算已用完、旧 token 尚未过期
	tok2, err := c.Token(ctx)
	if err != nil || tok2 != tok1 {
		t.Fatalf("应继续使用未过期的旧 token: %v %s", err, tok2)
	}
}

func TestTokenConcurrentSingleRequest(t *testing.T) {
	f := &fakeDW{t: t, expiresIn: 3600}
	c, _, _ := newTestClient(t, f, 6)
	var wg sync.WaitGroup
	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func() { defer wg.Done(); _, _ = c.Token(context.Background()) }()
	}
	wg.Wait()
	if n := f.tokenCalls.Load(); n != 1 {
		t.Fatalf("并发时 token 应只申请 1 次，实际 %d", n)
	}
}

func TestTokenRejected(t *testing.T) {
	f := &fakeDW{t: t, tokenStatus: http.StatusUnauthorized}
	c, _, logs := newTestClient(t, f, 6)
	_, err := c.Token(context.Background())
	var apiErr *APIError
	if !errors.As(err, &apiErr) || apiErr.Status != 401 || apiErr.DWCode != "A001" {
		t.Fatalf("应返回 401 APIError，实际 %v", err)
	}
	if strings.Contains(logs.String(), testSecret) {
		t.Fatal("日志中出现了 clientSecret")
	}
}

func TestReauthOn401(t *testing.T) {
	var calls atomic.Int32
	f := &fakeDW{t: t, expiresIn: 3600}
	f.handler = func(w http.ResponseWriter, r *http.Request) {
		if calls.Add(1) == 1 {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		if r.Header.Get("Authorization") != "Bearer tok-2" {
			t.Errorf("重放应使用新 token，实际 %s", r.Header.Get("Authorization"))
		}
		_, _ = w.Write([]byte(`{}`))
	}
	c, _, _ := newTestClient(t, f, 6)
	if err := c.Do(context.Background(), http.MethodPost, "/users", map[string]string{"a": "b"}, nil); err != nil {
		t.Fatal(err)
	}
	if calls.Load() != 2 || f.tokenCalls.Load() != 2 {
		t.Fatalf("401 后应刷新 token 并重放一次: api=%d token=%d", calls.Load(), f.tokenCalls.Load())
	}
}

func TestRetryPolicy(t *testing.T) {
	cases := []struct {
		name      string
		method    string
		statuses  []int
		wantCalls int32
		wantErr   bool
		idemKey   string
	}{
		{"GET 503 后成功", http.MethodGet, []int{503, 503, 200}, 3, false, ""},
		{"GET 一直 503：1+3 次后失败", http.MethodGet, []int{503, 503, 503, 503, 503}, 4, true, ""},
		{"GET 429 后成功", http.MethodGet, []int{429, 200}, 2, false, ""},
		{"GET 400 不重试", http.MethodGet, []int{400, 200}, 1, true, ""},
		{"POST 503 不重试（防重复入金）", http.MethodPost, []int{503, 200}, 1, true, ""},
		{"PATCH 500 不重试", http.MethodPatch, []int{500, 200}, 1, true, ""},
		{"POST 带幂等键 503 后重试成功", http.MethodPost, []int{503, 200}, 2, false, "idem-1"},
		{"POST 带幂等键 400 不重试", http.MethodPost, []int{400, 200}, 1, true, "idem-2"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			var calls atomic.Int32
			f := &fakeDW{t: t, expiresIn: 3600}
			f.handler = func(w http.ResponseWriter, r *http.Request) {
				if r.Header.Get("Idempotency-Key") != tc.idemKey {
					t.Errorf("Idempotency-Key = %q，期望 %q", r.Header.Get("Idempotency-Key"), tc.idemKey)
				}
				n := int(calls.Add(1)) - 1
				st := tc.statuses[len(tc.statuses)-1]
				if n < len(tc.statuses) {
					st = tc.statuses[n]
				}
				w.WriteHeader(st)
				_, _ = w.Write([]byte(`{"message":"x"}`))
			}
			c, _, _ := newTestClient(t, f, 6)
			ctx := context.Background()
			if tc.idemKey != "" {
				ctx = WithIdempotencyKey(ctx, tc.idemKey)
			}
			err := c.Do(ctx, tc.method, "/funding/deposits", map[string]any{"amount": 1}, nil)
			if (err != nil) != tc.wantErr {
				t.Fatalf("err=%v wantErr=%v", err, tc.wantErr)
			}
			if calls.Load() != tc.wantCalls {
				t.Fatalf("调用次数 %d，期望 %d", calls.Load(), tc.wantCalls)
			}
		})
	}
}

func TestAPIErrorAndRequestIDLogged(t *testing.T) {
	f := &fakeDW{t: t, expiresIn: 3600}
	f.handler = func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("dw-request-id", "req-abc-123")
		w.WriteHeader(http.StatusUnprocessableEntity)
		_, _ = w.Write([]byte(`{"errorCode":"U057","message":"invalid field"}`))
	}
	c, _, logs := newTestClient(t, f, 6)
	err := c.Do(context.Background(), http.MethodPost, "/users", map[string]any{"x": 1}, nil)
	var apiErr *APIError
	if !errors.As(err, &apiErr) || apiErr.Status != 422 || apiErr.DWCode != "U057" || apiErr.RequestID != "req-abc-123" {
		t.Fatalf("APIError 字段不正确: %+v", err)
	}
	for _, want := range []string{`"method":"POST"`, `"path":"/users"`, `"status":422`, `"dw_request_id":"req-abc-123"`, `"duration_ms"`} {
		if !strings.Contains(logs.String(), want) {
			t.Errorf("审计日志缺少 %s", want)
		}
	}
}

// 关键安全测试：凭据、token、SSN、账号、生日、地址不得出现在日志中。
func TestLogsAreRedacted(t *testing.T) {
	f := &fakeDW{t: t, expiresIn: 3600}
	f.handler = func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.Copy(io.Discard, r.Body)
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte(`{"message":"bad","echo":{"value":"123456789"}}`))
	}
	c, _, logs := newTestClient(t, f, 6)
	body := map[string]any{
		"userType": "INDIVIDUAL_TRADER", "username": "u", "password": "P@ssw0rd-SECRET",
		"documents": []any{
			map[string]any{"type": "IDENTIFICATION_INFO", "data": map[string]any{"value": "123456789", "type": "SSN"}},
			map[string]any{"type": "PERSONAL_INFO", "data": map[string]any{"birthDay": 14, "birthMonth": 6, "birthYear": 1990}},
			map[string]any{"type": "ADDRESS_INFO", "data": map[string]any{"street1": "200 Market Street"}},
			map[string]any{"type": "BASIC_INFO", "data": map[string]any{"firstName": "Alex", "emailAddress": "alex@example.com", "phone": "14155550142"}},
		},
		"bankAccountNumber": "000123456789", "bankRoutingNumber": "021000021",
	}
	_ = c.Do(context.Background(), http.MethodPost, "/users", body, nil)
	out := logs.String()
	for _, leak := range []string{testSecret, testAppKey, "tok-1", "P@ssw0rd-SECRET", "123456789", "1990", "200 Market", "alex@example.com", "Alex", "14155550142", "000123456789", "021000021"} {
		if strings.Contains(out, leak) {
			t.Errorf("日志泄露了 %q", leak)
		}
	}
	// request_body 以字符串形式嵌在 JSON 日志中，引号会被转义，这里只匹配内容
	for _, want := range []string{"*****6789", `[REDACTED]`, "A***", "a***@example.com", "*******0142"} {
		if !strings.Contains(out, want) {
			t.Errorf("日志应包含脱敏后的 %q", want)
		}
	}
}

func TestRedactJSON(t *testing.T) {
	cases := []struct{ in, want string }{
		{`{"value":"402724321","type":"SSN"}`, `{"type":"SSN","value":"*****4321"}`},
		{`{"clientSecret":"s","clientID":"id"}`, `{"clientID":"id","clientSecret":"[REDACTED]"}`},
		{`{"accountNo":"AB12"}`, `{"accountNo":"****"}`},
		{`{"emailAddress":"jane@example.com"}`, `{"emailAddress":"j***@example.com"}`},
		{`{"list":[{"ssn":"123456789"}]}`, `{"list":[{"ssn":"*****6789"}]}`},
		{`{"amount":250.5,"currency":"USD"}`, `{"amount":250.5,"currency":"USD"}`},
		{`{"addressLine1":"200 Market Street","displayName":"DTester","idNo":"****1173"}`, `{"addressLine1":"[REDACTED]","displayName":"D***","idNo":"****1173"}`},
		{`{"account_number":"TEST000001","username":"fxabc"}`, `{"account_number":"******0001","username":"[REDACTED]"}`},
		{`not json`, `[non-json body, 8 bytes]`},
		{``, ``},
	}
	for _, tc := range cases {
		if got := RedactJSON([]byte(tc.in)); got != tc.want {
			t.Errorf("RedactJSON(%s) = %s，期望 %s", tc.in, got, tc.want)
		}
	}
}

func TestContextCancelDuringBackoff(t *testing.T) {
	f := &fakeDW{t: t, expiresIn: 3600}
	f.handler = func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(503) }
	c, _, _ := newTestClient(t, f, 6)
	c.sleep = sleepCtx
	c.cfg.RetryBackoff = time.Hour
	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()
	if err := c.Do(ctx, http.MethodGet, "/x", nil, nil); !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("退避期间应响应 ctx 取消，实际 %v", err)
	}
}
