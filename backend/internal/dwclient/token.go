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
	"strconv"
	"sync"
	"time"
)

// ErrTokenRateLimited：token 请求超过每小时预算，且没有可用的缓存 token。
var ErrTokenRateLimited = errors.New("dwclient: token 请求超过每小时预算")

// tokenRequest 是 POST /auth/tokens 的请求体。
type tokenRequest struct {
	ClientID     string `json:"clientID"`
	ClientSecret string `json:"clientSecret"`
}

// tokenResponse 兼容多种字段名（DW 实际返回字段待沙盒验证）。
type tokenResponse struct {
	AccessToken  string          `json:"access_token"`
	AccessToken2 string          `json:"accessToken"`
	Token        string          `json:"token"`
	ExpiresIn    json.RawMessage `json:"expires_in"`
	ExpiresIn2   json.RawMessage `json:"expiresIn"`
}

func (r tokenResponse) value() string {
	for _, v := range []string{r.AccessToken, r.AccessToken2, r.Token} {
		if v != "" {
			return v
		}
	}
	return ""
}

// lifetime 解析有效期（秒）；缺失时保守按 1 小时处理。
func (r tokenResponse) lifetime() time.Duration {
	for _, raw := range []json.RawMessage{r.ExpiresIn, r.ExpiresIn2} {
		if len(raw) == 0 {
			continue
		}
		var n float64
		if json.Unmarshal(raw, &n) == nil && n > 0 {
			return time.Duration(n) * time.Second
		}
		var s string
		if json.Unmarshal(raw, &s) == nil {
			if v, err := strconv.ParseFloat(s, 64); err == nil && v > 0 {
				return time.Duration(v) * time.Second
			}
		}
	}
	return time.Hour
}

// Token 返回可用的 access token：缓存有效（距到期大于 refresh skew）则直接返回，
// 否则在限流预算内向 DW 申请新 token。并发调用只会发出一次请求。
// 若预算用尽但旧 token 尚未真正到期，继续使用旧 token。
func (c *Client) Token(ctx context.Context) (string, error) {
	c.tokenMu.Lock()
	defer c.tokenMu.Unlock()

	now := c.now()
	if c.token != "" && now.Before(c.expiresAt.Add(-c.cfg.TokenRefreshSkew)) {
		return c.token, nil
	}
	if !c.limiter.allow() {
		if c.token != "" && now.Before(c.expiresAt) {
			c.logger.WarnContext(ctx, "dw token budget exhausted, using cached token until expiry")
			return c.token, nil
		}
		c.logger.ErrorContext(ctx, "dw token budget exhausted", slog.Int("per_hour", c.cfg.TokenRequestsPerHour))
		return "", ErrTokenRateLimited
	}
	tok, life, err := c.fetchToken(ctx)
	if err != nil {
		return "", err
	}
	c.token = tok
	c.expiresAt = c.now().Add(life)
	return tok, nil
}

// invalidate 作废指定 token（仅当它仍是当前缓存时），下次调用 Token 时刷新。
func (c *Client) invalidate(tok string) {
	c.tokenMu.Lock()
	defer c.tokenMu.Unlock()
	if c.token == tok {
		c.token = ""
		c.expiresAt = time.Time{}
	}
}

// fetchToken 调用 POST {base}/auth/tokens。日志中不出现 clientSecret 与 token。
func (c *Client) fetchToken(ctx context.Context) (string, time.Duration, error) {
	body, _ := json.Marshal(tokenRequest{ClientID: c.cfg.ClientID, ClientSecret: c.cfg.ClientSecret})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.cfg.BaseURL+"/auth/tokens", bytes.NewReader(body))
	if err != nil {
		return "", 0, fmt.Errorf("dwclient: 构造 token 请求失败: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("dw-client-app-key", c.cfg.AppKey)

	start := c.now()
	resp, err := c.http.Do(req)
	if err != nil {
		c.logger.WarnContext(ctx, "dw token request failed", slog.String("error", errorKind(err)))
		return "", 0, fmt.Errorf("dwclient: 获取 token 失败: %s", errorKind(err))
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	reqID := requestID(resp.Header)
	attrs := []any{
		slog.String("method", http.MethodPost),
		slog.String("path", "/auth/tokens"),
		slog.Int("status", resp.StatusCode),
		slog.String("dw_request_id", reqID),
		slog.Int64("duration_ms", c.now().Sub(start).Milliseconds()),
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		c.logger.WarnContext(ctx, "dw token request rejected", append(attrs, slog.String("response_body", RedactJSON(raw)))...)
		return "", 0, newAPIError(resp.StatusCode, raw, reqID)
	}
	var tr tokenResponse
	if err := json.Unmarshal(raw, &tr); err != nil || tr.value() == "" {
		c.logger.ErrorContext(ctx, "dw token response unrecognized", append(attrs, slog.String("response_body", RedactJSON(raw)))...)
		return "", 0, errors.New("dwclient: 无法识别 DW token 响应（字段名待沙盒验证）")
	}
	life := tr.lifetime()
	c.logger.InfoContext(ctx, "dw token issued", append(attrs, slog.Int64("expires_in_s", int64(life.Seconds())))...)
	return tr.value(), life, nil
}

// windowLimiter：滑动窗口计数器，窗口内最多 limit 次。
type windowLimiter struct {
	mu     sync.Mutex
	limit  int
	window time.Duration
	now    func() time.Time
	hits   []time.Time
}

func newWindowLimiter(limit int, window time.Duration, now func() time.Time) *windowLimiter {
	return &windowLimiter{limit: limit, window: window, now: now}
}

func (l *windowLimiter) allow() bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := l.now()
	cut := now.Add(-l.window)
	kept := l.hits[:0]
	for _, t := range l.hits {
		if t.After(cut) {
			kept = append(kept, t)
		}
	}
	l.hits = kept
	if len(l.hits) >= l.limit {
		return false
	}
	l.hits = append(l.hits, now)
	return true
}
