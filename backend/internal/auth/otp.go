package auth

import (
	"context"
	"crypto/hmac"
	"crypto/rand"
	"fmt"
	"log/slog"
	"math/big"
	"strings"
	"sync"
	"time"
)

// OTP 策略（第一阶段，单实例进程内存储；多实例部署前需改为共享存储）。
const (
	OTPTTL             = 5 * time.Minute // 验证码有效期
	OTPResendAfter     = 60 * time.Second
	OTPMaxAttempts     = 5 // 单个验证码最多校验次数，超过作废
	OTPMaxSendsPerHour = 5 // 同一邮箱每小时最多发送次数
	OTPMaxSendsPerIP   = 20
)

// Sender 发送验证码邮件。
type Sender interface {
	Send(ctx context.Context, email, code string) error
}

// DevLogSender：开发联调用，把验证码写日志（config.OTPDevLog=true 时才使用；production 禁止）。
type DevLogSender struct{ Logger *slog.Logger }

func (s DevLogSender) Send(ctx context.Context, email, code string) error {
	s.Logger.WarnContext(ctx, "DEV ONLY otp code", slog.String("email", MaskEmail(email)), slog.String("code", code))
	return nil
}

// DisabledSender：未接入邮件服务时使用，发送一律失败。
type DisabledSender struct{}

func (DisabledSender) Send(context.Context, string, string) error {
	return fmt.Errorf("auth: 邮件服务未配置")
}

// MaskEmail：a***@example.com。
func MaskEmail(e string) string {
	at := strings.IndexByte(e, '@')
	if at <= 0 {
		return "***"
	}
	return e[:1] + "***" + e[at:]
}

type otpEntry struct {
	mac      []byte
	expires  time.Time
	sentAt   time.Time
	attempts int
}

type otpStore struct {
	mu      sync.Mutex
	secret  []byte
	codes   map[string]*otpEntry
	byEmail map[string][]time.Time
	byIP    map[string][]time.Time
}

func newOTPStore(secret []byte) *otpStore {
	return &otpStore{secret: secret, codes: map[string]*otpEntry{}, byEmail: map[string][]time.Time{}, byIP: map[string][]time.Time{}}
}

type otpLimitErr struct{ retryAfter int }

func (e otpLimitErr) Error() string { return "otp rate limited" }

// issue 生成新验证码；受重发间隔与每小时次数限制。
func (s *otpStore) issue(email, ip string, now time.Time) (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if e, ok := s.codes[email]; ok && now.Sub(e.sentAt) < OTPResendAfter {
		return "", otpLimitErr{int((OTPResendAfter - now.Sub(e.sentAt)).Seconds()) + 1}
	}
	s.byEmail[email] = prune(s.byEmail[email], now)
	s.byIP[ip] = prune(s.byIP[ip], now)
	if len(s.byEmail[email]) >= OTPMaxSendsPerHour {
		return "", otpLimitErr{int(time.Hour.Seconds()) - int(now.Sub(s.byEmail[email][0]).Seconds())}
	}
	if len(s.byIP[ip]) >= OTPMaxSendsPerIP {
		return "", otpLimitErr{int(time.Hour.Seconds()) - int(now.Sub(s.byIP[ip][0]).Seconds())}
	}
	n, err := rand.Int(rand.Reader, big.NewInt(1_000_000))
	if err != nil {
		return "", err
	}
	code := fmt.Sprintf("%06d", n.Int64())
	s.codes[email] = &otpEntry{mac: mac(s.secret, email+":"+code), expires: now.Add(OTPTTL), sentAt: now}
	s.byEmail[email] = append(s.byEmail[email], now)
	s.byIP[ip] = append(s.byIP[ip], now)
	return code, nil
}

// cancel 发送失败时撤销，不占用重发间隔。
func (s *otpStore) cancel(email string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.codes, email)
}

// verify 校验；成功后验证码立即作废（一次性）。
func (s *otpStore) verify(email, code string, now time.Time) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	e, ok := s.codes[email]
	if !ok {
		return false
	}
	if now.After(e.expires) || e.attempts >= OTPMaxAttempts {
		delete(s.codes, email)
		return false
	}
	e.attempts++
	if !hmac.Equal(e.mac, mac(s.secret, email+":"+code)) {
		if e.attempts >= OTPMaxAttempts {
			delete(s.codes, email)
		}
		return false
	}
	delete(s.codes, email)
	return true
}

func prune(ts []time.Time, now time.Time) []time.Time {
	i := 0
	for i < len(ts) && now.Sub(ts[i]) >= time.Hour {
		i++
	}
	return ts[i:]
}
