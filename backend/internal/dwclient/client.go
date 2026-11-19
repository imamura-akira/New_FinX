// Package dwclient 是后端访问 DriveWealth Back Office API 的唯一出口（CLAUDE.md 硬性规则 2）。
//
// 职责（backend-design.md 第 3 节）：
//   - 鉴权：POST {base}/auth/tokens，请求头 dw-client-app-key；token 进程内缓存，到期前刷新；
//     全局限流器约束 token 请求（预算约 5–10 次/小时，见 config.DW.TokenRequestsPerHour）。
//   - 可靠性：超时 10s；幂等 GET 失败退避重试 3 次；写操作不自动重试（防重复入金）。
//     收到 401 时作废缓存 token、刷新一次后重放一次（401 表示请求未被处理）。
//   - 审计：每次调用记录 method、path、DW request id、HTTP 码、耗时；请求体脱敏后记录。
//
// 待沙盒验证：token 响应字段名、DW request id 响应头名。解析做了兼容处理，见 token.go。
package dwclient

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"sync"
	"time"
)

// Config 是创建 Client 所需的参数。凭据由调用方从环境变量读入（internal/config），本包不读环境变量。
type Config struct {
	BaseURL      string // 如 https://bo-api.drivewealth.io/back-office
	AppKey       string
	ClientID     string
	ClientSecret string

	Timeout              time.Duration // 默认 10s
	TokenRequestsPerHour int           // 默认 6
	TokenRefreshSkew     time.Duration // 默认 5m
	GetRetries           int           // 默认 3
	RetryBackoff         time.Duration // 首次退避，默认 300ms，之后翻倍
	// LogBodies：成功响应也记录脱敏后的响应体（仅沙盒分析用；config 禁止 production 开启）。
	LogBodies bool
}

// ErrNotConfigured：凭据未配置。
var ErrNotConfigured = errors.New("dwclient: DW 凭据未配置")

// APIError 是 DW 返回的非 2xx 响应。Message 已脱敏、截断，可写日志；不要直接展示给用户
// （api-spec.md 第 8 节：对用户统一显示"稍后重试"）。
type APIError struct {
	Status    int
	DWCode    string
	Message   string
	RequestID string
}

func (e *APIError) Error() string {
	s := fmt.Sprintf("dwclient: DW 返回 HTTP %d", e.Status)
	if e.DWCode != "" {
		s += " (" + e.DWCode + ")"
	}
	if e.Message != "" {
		s += ": " + e.Message
	}
	return s
}

// Client 并发安全。
type Client struct {
	cfg    Config
	http   *http.Client
	logger *slog.Logger
	now    func() time.Time
	sleep  func(context.Context, time.Duration) error

	tokenMu   sync.Mutex
	token     string
	expiresAt time.Time
	limiter   *windowLimiter
}

// Option 用于测试注入。
type Option func(*Client)

// WithHTTPClient 替换底层 http.Client。
func WithHTTPClient(h *http.Client) Option { return func(c *Client) { c.http = h } }

// WithLogger 指定日志器。
func WithLogger(l *slog.Logger) Option { return func(c *Client) { c.logger = l } }

// WithClock 注入时钟（测试用）。
func WithClock(now func() time.Time) Option { return func(c *Client) { c.now = now } }

// WithSleep 注入退避等待（测试用）。
func WithSleep(s func(context.Context, time.Duration) error) Option {
	return func(c *Client) { c.sleep = s }
}

// New 创建客户端。凭据缺失返回 ErrNotConfigured。
func New(cfg Config, opts ...Option) (*Client, error) {
	if cfg.AppKey == "" || cfg.ClientID == "" || cfg.ClientSecret == "" || cfg.BaseURL == "" {
		return nil, ErrNotConfigured
	}
	cfg.BaseURL = strings.TrimRight(cfg.BaseURL, "/")
	if cfg.Timeout <= 0 {
		cfg.Timeout = 10 * time.Second
	}
	if cfg.TokenRequestsPerHour <= 0 {
		cfg.TokenRequestsPerHour = 6
	}
	if cfg.TokenRefreshSkew <= 0 {
		cfg.TokenRefreshSkew = 5 * time.Minute
	}
	if cfg.GetRetries < 0 {
		cfg.GetRetries = 0
	} else if cfg.GetRetries == 0 {
		cfg.GetRetries = 3
	}
	if cfg.RetryBackoff <= 0 {
		cfg.RetryBackoff = 300 * time.Millisecond
	}
	c := &Client{
		cfg:    cfg,
		http:   &http.Client{Timeout: cfg.Timeout},
		logger: slog.Default(),
		now:    time.Now,
		sleep:  sleepCtx,
	}
	for _, o := range opts {
		o(c)
	}
	c.limiter = newWindowLimiter(cfg.TokenRequestsPerHour, time.Hour, c.now)
	return c, nil
}

type ctxKey int

const idemKey ctxKey = 1

// WithIdempotencyKey 为该 context 内的 DW 写请求附加 Idempotency-Key 头（DW 文档：Create Deposit 支持，保存 4 天）。
// 带键的写请求在网络错误 / 5xx / 429 时会按 GET 的策略重试。
func WithIdempotencyKey(ctx context.Context, key string) context.Context {
	return context.WithValue(ctx, idemKey, key)
}

// IdempotencyKey 返回 context 中的幂等键（测试与日志用）。
func IdempotencyKey(ctx context.Context) string {
	k, _ := ctx.Value(idemKey).(string)
	return k
}

// Do 发送请求到 DW。path 相对 BaseURL（如 "/users"）。reqBody 为 nil 时不发请求体；
// out 非 nil 时把 2xx 响应 JSON 解码进去。
func (c *Client) Do(ctx context.Context, method, path string, reqBody, out any) error {
	var payload []byte
	if reqBody != nil {
		b, err := json.Marshal(reqBody)
		if err != nil {
			return fmt.Errorf("dwclient: 序列化请求失败: %w", err)
		}
		payload = b
	}

	// GET/HEAD 天然幂等；写操作只有带 Idempotency-Key（WithIdempotencyKey）时才允许重试（DW 保存 4 天，防重复入金）
	idempotent := method == http.MethodGet || method == http.MethodHead || IdempotencyKey(ctx) != ""
	maxAttempts := 1
	if idempotent {
		maxAttempts = 1 + c.cfg.GetRetries
	}
	reauthed := false
	backoff := c.cfg.RetryBackoff

	for attempt := 1; ; attempt++ {
		token, err := c.Token(ctx)
		if err != nil {
			return err
		}
		status, respBody, reqID, err := c.send(ctx, method, path, payload, token, attempt)
		switch {
		case err == nil && status == http.StatusUnauthorized && !reauthed:
			// token 失效：作废缓存并刷新一次后重放（不计入重试次数）
			c.invalidate(token)
			reauthed = true
			attempt--
			continue
		case err == nil && status >= 200 && status < 300:
			if out != nil && len(respBody) > 0 {
				if err := json.Unmarshal(respBody, out); err != nil {
					return fmt.Errorf("dwclient: 解析 DW 响应失败: %w", err)
				}
			}
			return nil
		}
		retryable := err != nil || status == http.StatusTooManyRequests || status >= 500
		if retryable && attempt < maxAttempts {
			if serr := c.sleep(ctx, backoff); serr != nil {
				return serr
			}
			backoff *= 2
			continue
		}
		if err != nil {
			return err
		}
		return newAPIError(status, respBody, reqID)
	}
}

// send 发送一次请求并记录审计日志。
func (c *Client) send(ctx context.Context, method, path string, payload []byte, token string, attempt int) (int, []byte, string, error) {
	var body io.Reader
	if payload != nil {
		body = bytes.NewReader(payload)
	}
	req, err := http.NewRequestWithContext(ctx, method, c.cfg.BaseURL+path, body)
	if err != nil {
		return 0, nil, "", fmt.Errorf("dwclient: 构造请求失败: %w", err)
	}
	req.Header.Set("Accept", "application/json")
	req.Header.Set("dw-client-app-key", c.cfg.AppKey)
	req.Header.Set("Authorization", "Bearer "+token)
	if payload != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if k := IdempotencyKey(ctx); k != "" {
		req.Header.Set("Idempotency-Key", k)
	}

	start := c.now()
	resp, err := c.http.Do(req)
	elapsed := c.now().Sub(start)
	attrs := []any{
		slog.String("method", method),
		slog.String("path", path),
		slog.Int("attempt", attempt),
		slog.Int64("duration_ms", elapsed.Milliseconds()),
	}
	if payload != nil {
		attrs = append(attrs, slog.String("request_body", RedactJSON(payload)))
	}
	if err != nil {
		c.logger.WarnContext(ctx, "dw request failed", append(attrs, slog.String("error", errorKind(err)))...)
		return 0, nil, "", fmt.Errorf("dwclient: 请求 DW 失败: %s", errorKind(err))
	}
	defer resp.Body.Close()
	respBody, _ := io.ReadAll(io.LimitReader(resp.Body, 10<<20))
	reqID := requestID(resp.Header)
	attrs = append(attrs, slog.Int("status", resp.StatusCode), slog.String("dw_request_id", reqID))
	level := slog.LevelInfo
	if resp.StatusCode >= 400 {
		level = slog.LevelWarn
	}
	if resp.StatusCode >= 400 || c.cfg.LogBodies {
		attrs = append(attrs, slog.String("response_body", RedactJSON(respBody)))
	}
	c.logger.Log(ctx, level, "dw request", attrs...)
	return resp.StatusCode, respBody, reqID, nil
}

// requestID 读取 DW 请求 id 响应头（头名待沙盒验证，兼容常见写法）。
func requestID(h http.Header) string {
	for _, k := range []string{"dw-request-id", "X-Request-Id", "X-Request-ID", "Request-Id"} {
		if v := h.Get(k); v != "" {
			return v
		}
	}
	return ""
}

func newAPIError(status int, body []byte, reqID string) *APIError {
	e := &APIError{Status: status, RequestID: reqID}
	var m map[string]any
	if json.Unmarshal(body, &m) == nil {
		for _, k := range []string{"errorCode", "code"} {
			if v, ok := m[k]; ok {
				e.DWCode = fmt.Sprint(v)
				break
			}
		}
		for _, k := range []string{"message", "errorMessage", "error"} {
			if v, ok := m[k].(string); ok {
				e.Message = truncate(v, 300)
				break
			}
		}
	}
	return e
}

// errorKind 把网络错误归类为不含 URL 细节的简短描述。
func errorKind(err error) string {
	switch {
	case errors.Is(err, context.Canceled):
		return "已取消"
	case errors.Is(err, context.DeadlineExceeded):
		return "超时"
	}
	var ne interface{ Timeout() bool }
	if errors.As(err, &ne) && ne.Timeout() {
		return "超时"
	}
	return "网络错误"
}

func truncate(s string, n int) string {
	if len([]rune(s)) <= n {
		return s
	}
	return string([]rune(s)[:n]) + "…"
}

func sleepCtx(ctx context.Context, d time.Duration) error {
	t := time.NewTimer(d)
	defer t.Stop()
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-t.C:
		return nil
	}
}
