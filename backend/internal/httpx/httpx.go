// Package httpx 提供 api-spec.md 约定的统一响应包装、错误码与请求解析。
package httpx

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
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

// Decode 解析 JSON 请求体（限制大小、拒绝未知顶层字段）。
func Decode(w http.ResponseWriter, r *http.Request, limit int64, v any) error {
	if limit <= 0 {
		limit = MaxBody
	}
	if ct := r.Header.Get("Content-Type"); ct != "" && !strings.HasPrefix(ct, "application/json") {
		return Validation("请求格式不正确")
	}
	dec := json.NewDecoder(http.MaxBytesReader(w, r.Body, limit))
	dec.DisallowUnknownFields()
	if err := dec.Decode(v); err != nil {
		var mbe *http.MaxBytesError
		if errors.As(err, &mbe) {
			return Validation("提交的内容过大")
		}
		if errors.Is(err, io.EOF) {
			return Validation("请求内容为空")
		}
		return Validation("请求格式不正确")
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

// ClientIP：取连接地址（反向代理部署时需改为受信任的 X-Forwarded-For 解析）。
func ClientIP(r *http.Request) string {
	host := r.RemoteAddr
	if i := strings.LastIndex(host, ":"); i > 0 {
		host = host[:i]
	}
	return strings.Trim(host, "[]")
}
