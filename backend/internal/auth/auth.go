// Package auth：邮箱 OTP 登录/注册、会话 JWT、/me（api-spec.md 第 1 节，F1）。
package auth

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"errors"
	"log/slog"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/httpx"
)

// Me：GET /me 的数据。
type Me struct {
	Email         string  `json:"email"`
	LoginProvider string  `json:"loginProvider"`
	ApplicationID *string `json:"applicationId"`
	AccountStatus string  `json:"accountStatus"` // ApplicationStatus：NONE/DRAFT/SUBMITTED/APPROVED/DENIED
}

// Repo：持久化接口（生产为 Postgres，测试为内存实现）。
type Repo interface {
	UpsertEmailUser(ctx context.Context, email string) (userID string, isNew bool, err error)
	CreateSession(ctx context.Context, hash, userID string, expires time.Time) error
	SessionUser(ctx context.Context, hash string, now time.Time) (userID string, err error) // 无效时返回 ErrNoSession
	RevokeSession(ctx context.Context, hash string, now time.Time) error
	Me(ctx context.Context, userID string) (Me, error)
}

// ErrNoSession：会话不存在、已过期或已注销。
var ErrNoSession = errors.New("auth: 会话无效")

// Service 组合 OTP、会话与仓储。
type Service struct {
	repo   Repo
	sender Sender
	otp    *otpStore
	secret []byte
	ttl    time.Duration
	now    func() time.Time
	logger *slog.Logger
	// fixedCode：演示模式下所有验证码固定为 DevFixedCode（见 EnableDemoCode）。
	fixedCode string
}

// EnableDemoCode 开启演示固定验证码 000000。调用方须确保仅在 config.OTPDevLog=true 时调用
// （config 已禁止 production 开启 OTP_DEV_LOG）。限频、有效期、一次性规则照常生效。
func (s *Service) EnableDemoCode() { s.fixedCode = DevFixedCode }

// New：secret 为 JWT 签名密钥（同时用于 OTP 的 HMAC 存储）。
func New(repo Repo, sender Sender, secret []byte, ttl time.Duration, logger *slog.Logger) *Service {
	if logger == nil {
		logger = slog.Default()
	}
	return &Service{repo: repo, sender: sender, otp: newOTPStore(secret), secret: secret, ttl: ttl, now: time.Now, logger: logger}
}

var emailRE = regexp.MustCompile(`^[^\s@]+@[^\s@]+\.[^\s@]+$`)

func normEmail(s string) string { return strings.ToLower(strings.TrimSpace(s)) }

// Routes 注册 /auth/* 与 /me。mw 为鉴权中间件（/auth/logout、/me 需要会话）。
func (s *Service) Routes(mux *http.ServeMux, prefix string) {
	mux.HandleFunc("POST "+prefix+"/auth/otp/request", s.handleRequestOTP)
	mux.HandleFunc("POST "+prefix+"/auth/otp/verify", s.handleVerifyOTP)
	mux.HandleFunc("POST "+prefix+"/auth/oauth", func(w http.ResponseWriter, r *http.Request) {
		httpx.Fail(w, r, httpx.NotEnabled("Google / Apple 登录将在后续版本开通，请先使用邮箱验证码登录"))
	})
	mux.Handle("POST "+prefix+"/auth/logout", s.RequireAuth(http.HandlerFunc(s.handleLogout)))
	mux.Handle("GET "+prefix+"/me", s.RequireAuth(http.HandlerFunc(s.handleMe)))
}

func (s *Service) handleRequestOTP(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Email string `json:"email"`
	}
	if err := httpx.Decode(w, r, 0, &in); err != nil {
		httpx.Fail(w, r, err)
		return
	}
	email := normEmail(in.Email)
	if !emailRE.MatchString(email) || len(email) > 254 {
		httpx.Fail(w, r, httpx.Validation("", httpx.FieldError{Field: "email", Reason: "请输入有效的邮箱地址"}))
		return
	}
	code, err := s.otp.issue(email, httpx.ClientIP(r), s.fixedCode, s.now())
	if err != nil {
		var le otpLimitErr
		if errors.As(err, &le) {
			httpx.Fail(w, r, httpx.RateLimited("请求过于频繁，请稍后再试", le.retryAfter))
			return
		}
		httpx.Fail(w, r, err)
		return
	}
	if err := s.sender.Send(r.Context(), email, code); err != nil {
		s.otp.cancel(email)
		s.logger.ErrorContext(r.Context(), "otp send failed", slog.String("email", MaskEmail(email)), slog.String("error", err.Error()))
		httpx.Fail(w, r, httpx.Internal())
		return
	}
	httpx.OK(w, map[string]int{"ttl": int(OTPTTL.Seconds()), "resendAfter": int(OTPResendAfter.Seconds())})
}

func (s *Service) handleVerifyOTP(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Email string `json:"email"`
		Code  string `json:"code"`
	}
	if err := httpx.Decode(w, r, 0, &in); err != nil {
		httpx.Fail(w, r, err)
		return
	}
	email := normEmail(in.Email)
	code := strings.TrimSpace(in.Code)
	if !emailRE.MatchString(email) {
		httpx.Fail(w, r, httpx.Validation("", httpx.FieldError{Field: "email", Reason: "请输入有效的邮箱地址"}))
		return
	}
	if len(code) != 6 || !s.otp.verify(email, code, s.now()) {
		httpx.Fail(w, r, httpx.Validation("验证码不正确或已过期", httpx.FieldError{Field: "code", Reason: "验证码不正确或已过期，请重新获取"}))
		return
	}
	userID, isNew, err := s.repo.UpsertEmailUser(r.Context(), email)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	token, err := s.issueSession(r.Context(), userID)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	s.logger.InfoContext(r.Context(), "login", slog.String("user_id", userID), slog.Bool("new_user", isNew))
	httpx.OK(w, map[string]any{"sessionToken": token, "isNewUser": isNew})
}

func (s *Service) issueSession(ctx context.Context, userID string) (string, error) {
	sid := make([]byte, 16)
	if _, err := rand.Read(sid); err != nil {
		return "", err
	}
	now := s.now()
	exp := now.Add(s.ttl)
	token, err := signJWT(s.secret, claims{Sub: userID, Sid: hex.EncodeToString(sid), Iat: now.Unix(), Exp: exp.Unix()})
	if err != nil {
		return "", err
	}
	if err := s.repo.CreateSession(ctx, tokenHash(token), userID, exp); err != nil {
		return "", err
	}
	return token, nil
}

func (s *Service) handleLogout(w http.ResponseWriter, r *http.Request) {
	if err := s.repo.RevokeSession(r.Context(), tokenHash(bearer(r)), s.now()); err != nil {
		httpx.Fail(w, r, err)
		return
	}
	httpx.OK(w, nil)
}

func (s *Service) handleMe(w http.ResponseWriter, r *http.Request) {
	me, err := s.repo.Me(r.Context(), httpx.UserID(r.Context()))
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	httpx.OK(w, me)
}

// RequireAuth 校验 Bearer token：签名与有效期（JWT）+ 会话未注销（数据库）。
func (s *Service) RequireAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		tok := bearer(r)
		if tok == "" {
			httpx.Fail(w, r, httpx.Unauthorized())
			return
		}
		now := s.now()
		c, err := verifyJWT(s.secret, tok, now)
		if errors.Is(err, errTokenExpired) {
			httpx.Fail(w, r, httpx.SessionExpired())
			return
		}
		if err != nil {
			httpx.Fail(w, r, httpx.Unauthorized())
			return
		}
		uid, err := s.repo.SessionUser(r.Context(), tokenHash(tok), now)
		if errors.Is(err, ErrNoSession) || (err == nil && uid != c.Sub) {
			httpx.Fail(w, r, httpx.SessionExpired())
			return
		}
		if err != nil {
			httpx.Fail(w, r, err)
			return
		}
		next.ServeHTTP(w, r.WithContext(httpx.WithUser(r.Context(), uid)))
	})
}

func bearer(r *http.Request) string {
	h := r.Header.Get("Authorization")
	if len(h) > 7 && strings.EqualFold(h[:7], "Bearer ") {
		return strings.TrimSpace(h[7:])
	}
	return ""
}

// ---------------- Postgres 实现 ----------------

// PGRepo 基于 database/sql（pgx 驱动）。
type PGRepo struct{ DB *sql.DB }

func (p PGRepo) UpsertEmailUser(ctx context.Context, email string) (string, bool, error) {
	var id string
	var inserted bool
	err := p.DB.QueryRowContext(ctx, `SELECT id FROM users_app WHERE lower(email) = $1 AND deleted_at IS NULL`, email).Scan(&id)
	if err == nil {
		return id, false, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return "", false, err
	}
	err = p.DB.QueryRowContext(ctx,
		`INSERT INTO users_app (email, login_provider) VALUES ($1, 'EMAIL')
		 ON CONFLICT (lower(email)) WHERE deleted_at IS NULL DO UPDATE SET updated_at = now()
		 RETURNING id, (xmax = 0)`, email).Scan(&id, &inserted)
	if err != nil {
		return "", false, err
	}
	return id, inserted, nil
}

func (p PGRepo) CreateSession(ctx context.Context, hash, userID string, expires time.Time) error {
	_, err := p.DB.ExecContext(ctx, `INSERT INTO sessions (token_hash, user_id, expires_at) VALUES ($1, $2, $3)`, hash, userID, expires)
	return err
}

func (p PGRepo) SessionUser(ctx context.Context, hash string, now time.Time) (string, error) {
	var uid string
	err := p.DB.QueryRowContext(ctx,
		`SELECT user_id FROM sessions WHERE token_hash = $1 AND revoked_at IS NULL AND expires_at > $2`, hash, now).Scan(&uid)
	if errors.Is(err, sql.ErrNoRows) {
		return "", ErrNoSession
	}
	return uid, err
}

func (p PGRepo) RevokeSession(ctx context.Context, hash string, now time.Time) error {
	_, err := p.DB.ExecContext(ctx, `UPDATE sessions SET revoked_at = $2 WHERE token_hash = $1 AND revoked_at IS NULL`, hash, now)
	return err
}

func (p PGRepo) Me(ctx context.Context, userID string) (Me, error) {
	var m Me
	var appID sql.NullString
	var status sql.NullString
	err := p.DB.QueryRowContext(ctx,
		`SELECT u.email, u.login_provider, a.id, a.status
		   FROM users_app u LEFT JOIN applications a ON a.user_id = u.id AND a.deleted_at IS NULL
		  WHERE u.id = $1`, userID).Scan(&m.Email, &m.LoginProvider, &appID, &status)
	if err != nil {
		return m, err
	}
	m.AccountStatus = "NONE"
	if appID.Valid {
		m.ApplicationID = &appID.String
		m.AccountStatus = status.String
	}
	return m, nil
}
