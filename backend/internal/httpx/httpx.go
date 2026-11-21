// Package httpx 提供 api-spec.md 约定的统一响应包装、错误码与请求解析。
package httpx

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net"
	"net/http"
	"net/netip"
	"regexp"
	"strings"
)

// 业务错误码（api-spec.md 第 8 节）。
const (
	CodeOK             = 0
	CodeUnauthorized   = 40101 // 未登录 / token 无效
	CodeSessionExpired = 40102 // 会话过期或已注销
	CodeRestricted     = 40301
	CodeConflict       = 40901
	CodeValidation     = 42200 // 字段校验失败（附 fields[]）
	CodeLimit          = 42201 // 金额超限
	CodeRateLimited    = 42901 // 请求过于频繁
	CodeInternal       = 50000 // 服务器内部错误
	CodeDWFailed       = 50001
	CodeDWBadData      = 50002
	CodeNotEnabled     = 50003 // 功能暂未开通
)

// Envelope：{"code":0,"message":"ok","data":{...}}。
type Envelope struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    any    `json:"data,omitempty"`
}

// FieldError：422xx 的字段级错误，reason 为可直接展示的简体中文。
type FieldError struct {
	Field  string `json:"field"`
	Reason string `json:"reason"`
}

// Error 是可直接写回客户端的业务错误。Message 必须可展示给用户，不含内部细节。
type Error struct {
	HTTP    int
	Code    int
	Message string
	Data    any
}

func (e *Error) Error() string { return e.Message }

func Unauthorized() *Error {
	return &Error{HTTP: http.StatusUnauthorized, Code: CodeUnauthorized, Message: "请先登录"}
}

func SessionExpired() *Error {
	return &Error{HTTP: http.StatusUnauthorized, Code: CodeSessionExpired, Message: "登录已过期，请重新登录"}
}

// Restricted：40301 账户受限（附 restriction）。
func Restricted(restriction string) *Error {
	msg := map[string]string{"FROZEN": "账户已冻结，暂不能进行此操作", "CLOSED": "账户已关闭，暂不能进行此操作"}[restriction]
	if msg == "" {
		msg = "账户受限，暂不能进行此操作"
	}
	return &Error{HTTP: http.StatusForbidden, Code: CodeRestricted, Message: msg, Data: map[string]string{"restriction": restriction}}
}

func Conflict(msg string) *Error {
	return &Error{HTTP: http.StatusConflict, Code: CodeConflict, Message: msg}
}

func RateLimited(msg string, retryAfter int) *Error {
	return &Error{HTTP: http.StatusTooManyRequests, Code: CodeRateLimited, Message: msg, Data: map[string]int{"retryAfter": retryAfter}}
}

func NotEnabled(msg string) *Error {
	return &Error{HTTP: http.StatusNotImplemented, Code: CodeNotEnabled, Message: msg}
}

func DWFailed() *Error {
	return &Error{HTTP: http.StatusBadGateway, Code: CodeDWFailed, Message: "券商服务暂时不可用，请稍后重试"}
}

func Internal() *Error {
	return &Error{HTTP: http.StatusInternalServerError, Code: CodeInternal, Message: "服务暂时不可用，请稍后重试"}
}

// Validation 返回 42200；fields 为空时也合法（整体性错误）。
func Validation(msg string, fields ...FieldError) *Error {
	if msg == "" {
		msg = "请检查标红的字段"
	}
	return &Error{HTTP: http.StatusUnprocessableEntity, Code: CodeValidation, Message: msg, Data: map[string]any{"fields": nonNil(fields)}}
}

func nonNil(f []FieldError) []FieldError {
	if f == nil {
		return []FieldError{}
	}
	return f
}

// WriteJSON 写原始 JSON。
func WriteJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

// OK 写成功响应。
func OK(w http.ResponseWriter, data any) {
	WriteJSON(w, http.StatusOK, Envelope{Code: CodeOK, Message: "ok", Data: data})
}

// Fail 写错误响应。非 *Error 一律按 500 处理，原始错误只进日志。
func Fail(w http.ResponseWriter, r *http.Request, err error) {
	var e *Error
	if !errors.As(err, &e) {
		slog.ErrorContext(r.Context(), "unhandled error", slog.String("path", r.URL.Path), slog.String("error", err.Error()))
		e = Internal()
	}
	WriteJSON(w, e.HTTP, Envelope{Code: e.Code, Message: e.Message, Data: e.Data})
}

// MaxBody 默认请求体上限；证件上传另设。
const MaxBody = 256 << 10

// DecodeMessages：请求解析失败时的提示文案（开户与 KYC 模块用英文，其余模块用中文，见 pages.md 定稿说明）。
type DecodeMessages struct{ Invalid, TooLarge, Empty, ContentType string }

var (
	// DecodeZH：默认简体中文。
	DecodeZH = DecodeMessages{Invalid: "请求格式不正确", TooLarge: "提交的内容过大", Empty: "请求内容为空", ContentType: "请求格式不正确"}
	// DecodeEN：开户与 KYC 模块（P-03–P-06、P-30、P-34–P-36）。
	DecodeEN = DecodeMessages{Invalid: "Invalid request", TooLarge: "The request is too large", Empty: "The request is empty", ContentType: "Invalid request"}
)

// Decode 解析 JSON 请求体（限制大小、拒绝未知顶层字段），错误文案为中文。
func Decode(w http.ResponseWriter, r *http.Request, limit int64, v any) error {
	return DecodeWith(w, r, limit, v, DecodeZH)
}

// DecodeWith 同 Decode，使用指定语言的错误文案。
func DecodeWith(w http.ResponseWriter, r *http.Request, limit int64, v any, m DecodeMessages) error {
	if limit <= 0 {
		limit = MaxBody
	}
	if ct := r.Header.Get("Content-Type"); ct != "" && !strings.HasPrefix(ct, "application/json") {
		return Validation(m.ContentType)
	}
	dec := json.NewDecoder(http.MaxBytesReader(w, r.Body, limit))
	dec.DisallowUnknownFields()
	if err := dec.Decode(v); err != nil {
		var mbe *http.MaxBytesError
		if errors.As(err, &mbe) {
			return Validation(m.TooLarge)
		}
		if errors.Is(err, io.EOF) {
			return Validation(m.Empty)
		}
		return Validation(m.Invalid)
	}
	return nil
}

type ctxKey int

const userKey ctxKey = 1

// WithUser 把已认证的用户 id 放入 context。
func WithUser(ctx context.Context, userID string) context.Context {
	return context.WithValue(ctx, userKey, userID)
}

// UserID 读取已认证用户 id；未认证时为空。
func UserID(ctx context.Context) string {
	v, _ := ctx.Value(userKey).(string)
	return v
}

// trustedProxies：受信任的反向代理网段（TRUSTED_PROXIES）。为空时不信任任何代理头。
var trustedProxies []netip.Prefix

// SetTrustedProxies 设置受信任的反向代理网段（启动时调用一次）。
func SetTrustedProxies(p []netip.Prefix) { trustedProxies = p }

// ClientIP：真实客户端 IP（审计 SEC-P1-1）。
//   - 只有当连接来自受信代理网段时，才采用 X-Forwarded-For，并且只取最右侧一项（由最近一跳的受信代理写入；
//     客户端自带的伪造值在左侧，被忽略。共用 Caddy 默认会丢弃不受信来源的 X-Forwarded-For 并改写为真实 IP）；
//   - 其他情况（未配置代理、直连、代理头缺失或非法）一律取连接地址。
func ClientIP(r *http.Request) string {
	host := r.RemoteAddr
	if h, _, err := net.SplitHostPort(host); err == nil {
		host = h
	}
	host = strings.Trim(host, "[]")
	remote, err := netip.ParseAddr(host)
	if err != nil || !trusted(remote) {
		return host
	}
	xff := r.Header.Values("X-Forwarded-For")
	if len(xff) == 0 {
		return host
	}
	parts := strings.Split(xff[len(xff)-1], ",")
	if ip, err := netip.ParseAddr(strings.TrimSpace(parts[len(parts)-1])); err == nil {
		return ip.Unmap().String()
	}
	return host
}

func trusted(a netip.Addr) bool {
	a = a.Unmap()
	for _, p := range trustedProxies {
		if p.Contains(a) {
			return true
		}
	}
	return false
}

var idemKeyRE = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

// ClientIdempotencyKey 读取 App 提交资金类请求（入金、出金、下单）时附带的 Idempotency-Key 头（可选，UUID）。
// App 对同一笔申请的重试沿用同一个键，后端据此去重，避免超时后重试造成重复提交（审计 FUND-P0-1）。
// 未带时返回空字符串（兼容旧版 App）。
func ClientIdempotencyKey(r *http.Request) (string, error) {
	k := strings.TrimSpace(r.Header.Get("Idempotency-Key"))
	if k == "" {
		return "", nil
	}
	if !idemKeyRE.MatchString(k) {
		return "", Validation("", FieldError{Field: "Idempotency-Key", Reason: "请求编号格式不正确"})
	}
	return strings.ToLower(k), nil
}
