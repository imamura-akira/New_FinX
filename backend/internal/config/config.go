// Package config 集中管理后端配置与"待 DW 确认"开关（backend-design.md 第 7 节、ui-signoff.md 第 2 节）。
// 规则（CLAUDE.md 硬性规则 3）：标注 Q-DW-x 的行为一律读这里的开关，不许写死。
// 凭据只从环境变量读取，不设默认值，不写日志。
package config

import (
	"encoding/base64"
	"errors"
	"fmt"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// KYCMode：Q-DW-1。
type KYCMode string

const (
	KYCModeDoKYC      KYCMode = "DO_KYC"      // DW 执行 KYC（当前实现）
	KYCModePartnerKYC KYCMode = "PARTNER_KYC" // 我方 KYC + KYC_VERIFICATION_INFO（本阶段不实现，只留开关与报错）
)

// BankLinkMethod：Q-DW-2。
type BankLinkMethod string

const (
	BankLinkDirect BankLinkMethod = "DIRECT" // 方案 A：直接录入账号/路由号 → POST /back-office/bank-accounts
	BankLinkPlaid  BankLinkMethod = "PLAID"  // 方案 B：Plaid processor token
)

// UserSubmitMode：Q-DW-3。
type UserSubmitMode string

const (
	SubmitPostPatch  UserSubmitMode = "POST_PATCH"  // POST 四类核心 documents + PATCH 其余
	SubmitSinglePost UserSubmitMode = "SINGLE_POST" // 一次 POST 全部 documents
)

// SeasoningStart：Q-DW-8e 观察期起算点。
type SeasoningStart string

const (
	SeasoningFromCleared   SeasoningStart = "CLEARED"   // 到账（清算）日起算（当前实现）
	SeasoningFromInitiated SeasoningStart = "INITIATED" // 发起日起算
)

// MarketDataMode：F11 行情来源。
type MarketDataMode string

const (
	MarketSim  MarketDataMode = "SIM"  // 后端虚拟行情（第一阶段）
	MarketReal MarketDataMode = "REAL" // 二期接真实行情源的挂载点（当前未实现，接口返回 50003）
)

// ErrPartnerKYCNotImplemented：kyc_mode=PARTNER_KYC 时业务层应返回此错误（backend-design.md 第 4 节）。
var ErrPartnerKYCNotImplemented = errors.New("kyc_mode=PARTNER_KYC 本阶段未实现（Q-DW-1）")

// Limits：示例值，待业务与 DW 确认（Q-DW-8）。金额单位 USD。
type Limits struct {
	MinDeposit    float64
	MaxDeposit    float64
	DailyDeposit  float64
	MinWithdrawal float64
	MaxWithdrawal float64
	MinWire       float64
	MaxBanks      int
	ACHCutoffET   string  // 示例 "16:00"，美东时间，待 DW 确认
	WireCutoffET  string  // 示例 "15:00"，美东时间，待 DW 确认
	MinOrder      float64 // F14 单笔最低下单金额（示例 $1，以券商为准；sandbox-log T-4）
}

// DW：DriveWealth 客户端配置。凭据字段只从环境变量读取。
type DW struct {
	BaseURL      string // 沙盒 https://bo-api.drivewealth.io/back-office
	AppKey       string // 请求头 dw-client-app-key
	ClientID     string
	ClientSecret string

	HTTPTimeout          time.Duration // 默认 10s
	TokenRequestsPerHour int           // token 请求预算，约 5–10 次/小时
	TokenRefreshSkew     time.Duration // 到期前多久刷新
	LogBodies            bool          // DW_LOG_BODIES：成功响应也记录脱敏响应体（仅沙盒）
}

// Config：全部配置。
type Config struct {
	Env         string // sandbox | production（沙盒与生产配置完全隔离）
	HTTPAddr    string
	DatabaseURL string

	// PIIKey：AES-256-GCM 字段级加密密钥（32 字节，环境变量中为 base64）。
	PIIKey []byte

	// JWTSecret：会话 JWT（HS256）签名密钥，至少 32 字节，环境变量中为 base64。
	JWTSecret  []byte
	SessionTTL time.Duration // 会话有效期，默认 24h（契约暂无刷新接口）
	// OTPDevLog：把邮箱验证码打印到日志，并启用演示固定验证码 000000（仅开发/演示；production 禁止开启）。
	OTPDevLog bool
	// MarketDataMode / MarketTick：F11 虚拟行情（backend-design.md 6.5）。
	MarketDataMode MarketDataMode
	MarketTick     time.Duration
	// KYCPollInterval：KYC / 账户状态对账周期（第一阶段不接 SQS，以轮询为准；演示可调短）。
	KYCPollInterval time.Duration
	// CORSAllowedOrigins：允许跨域的来源（逗号分隔；空 = 不启用 CORS；iOS 原生 App 不需要）。
	CORSAllowedOrigins []string
	// AllowedEmails：登录邮箱白名单（ALLOWED_EMAILS，逗号分隔）。以 @ 开头的条目按域名后缀放行（如 "@example.com"），
	// 完整邮箱按精确匹配（忽略大小写）。非空时 /auth/otp/request 只接受名单内的邮箱（公网演示部署用）；空 = 不限制。
	AllowedEmails []string
	// AllowedEmailSuffixes：旧变量 ALLOWED_EMAIL_SUFFIXES（仅后缀，每项以 @ 开头），兼容保留；
	// 其条目合并进 AllowedEmails 生效。新部署请用 ALLOWED_EMAILS。
	AllowedEmailSuffixes []string

	DW DW

	// —— 待 DW 确认的开关 ——
	KYCMode        KYCMode
	BankLinkMethod BankLinkMethod
	UserSubmitMode UserSubmitMode
	SeasoningDays  int // 展示用；可提现以 DW 返回为准
	SeasoningStart SeasoningStart
	Limits         Limits
	// F14：DW preventQueuing——休市时市价单拒绝而非排队到开盘（待沙盒实测，sandbox-log T-3）
	TradePreventQueuing bool
}

// 默认值（backend-design.md 第 7 节）。
const (
	DefaultDWBaseURL = "https://bo-api.drivewealth.io/back-office"
	DefaultHTTPAddr  = ":8080"
)

// Getenv 抽象，便于测试。
type Getenv func(string) string

// Load 从进程环境变量加载并校验。
func Load() (*Config, error) { return LoadFrom(os.Getenv) }

// LoadFrom 从给定的 getenv 加载并校验。
func LoadFrom(get Getenv) (*Config, error) {
	p := parser{get: get}
	c := &Config{
		Env:         p.str("APP_ENV", "sandbox"),
		HTTPAddr:    p.str("HTTP_ADDR", DefaultHTTPAddr),
		DatabaseURL: p.str("DATABASE_URL", ""),
		DW: DW{
			BaseURL:              strings.TrimRight(p.str("DW_BASE_URL", DefaultDWBaseURL), "/"),
			AppKey:               get("DW_APP_KEY"),
			ClientID:             get("DW_CLIENT_ID"),
			ClientSecret:         get("DW_CLIENT_SECRET"),
			HTTPTimeout:          p.dur("DW_HTTP_TIMEOUT", 10*time.Second),
			TokenRequestsPerHour: p.int("DW_TOKEN_REQUESTS_PER_HOUR", 6),
			TokenRefreshSkew:     p.dur("DW_TOKEN_REFRESH_SKEW", 5*time.Minute),
			LogBodies:            p.bool("DW_LOG_BODIES", false),
		},
		SessionTTL:           p.dur("SESSION_TTL", 24*time.Hour),
		OTPDevLog:            p.bool("OTP_DEV_LOG", false),
		CORSAllowedOrigins:   splitList(get("CORS_ALLOWED_ORIGINS")),
		AllowedEmails:        splitList(strings.ToLower(get("ALLOWED_EMAILS"))),
		AllowedEmailSuffixes: splitList(strings.ToLower(get("ALLOWED_EMAIL_SUFFIXES"))),
		KYCPollInterval:      p.dur("KYC_POLL_INTERVAL", time.Minute),
		MarketDataMode:       MarketDataMode(p.str("MARKET_DATA_MODE", string(MarketSim))),
		MarketTick:           p.dur("MARKET_TICK", 2*time.Second),
		KYCMode:              KYCMode(p.str("KYC_MODE", string(KYCModeDoKYC))),
		BankLinkMethod:       BankLinkMethod(p.str("BANK_LINK_METHOD", string(BankLinkDirect))),
		UserSubmitMode:       UserSubmitMode(p.str("USER_SUBMIT_MODE", string(SubmitPostPatch))),
		SeasoningDays:        p.int("SEASONING_DAYS", 30),
		SeasoningStart:       SeasoningStart(p.str("SEASONING_START", string(SeasoningFromCleared))),
		Limits: Limits{
			MinDeposit:    p.float("LIMIT_MIN_DEPOSIT", 10),
			MaxDeposit:    p.float("LIMIT_MAX_DEPOSIT", 50000),
			DailyDeposit:  p.float("LIMIT_DAILY_DEPOSIT", 50000),
			MinWithdrawal: p.float("LIMIT_MIN_WITHDRAWAL", 1),
			MaxWithdrawal: p.float("LIMIT_MAX_WITHDRAWAL", 50000),
			MinWire:       p.float("LIMIT_MIN_WIRE", 100),
			MaxBanks:      p.int("LIMIT_MAX_BANKS", 2),
			ACHCutoffET:   p.str("LIMIT_ACH_CUTOFF_ET", "16:00"),
			WireCutoffET:  p.str("LIMIT_WIRE_CUTOFF_ET", "15:00"),
			MinOrder:      p.float("LIMIT_MIN_ORDER", 1),
		},
		TradePreventQueuing: p.bool("TRADE_PREVENT_QUEUING", false),
	}
	if raw := get("PII_ENCRYPTION_KEY"); raw != "" {
		key, err := base64.StdEncoding.DecodeString(raw)
		if err != nil {
			p.errs = append(p.errs, "PII_ENCRYPTION_KEY 不是合法的 base64")
		} else {
			c.PIIKey = key
		}
	}
	if raw := get("JWT_SECRET"); raw != "" {
		key, err := base64.StdEncoding.DecodeString(raw)
		if err != nil {
			p.errs = append(p.errs, "JWT_SECRET 不是合法的 base64")
		} else {
			c.JWTSecret = key
		}
	}
	if len(p.errs) > 0 {
		return nil, fmt.Errorf("配置错误: %s", strings.Join(p.errs, "; "))
	}
	if err := c.Validate(); err != nil {
		return nil, err
	}
	return c, nil
}

// Validate 校验枚举与取值范围。凭据缺失不在此报错（允许无凭据启动 health），
// 由 DWConfigured() / dwclient 在实际调用时报错。
func (c *Config) Validate() error {
	var errs []string
	if c.Env != "sandbox" && c.Env != "production" {
		errs = append(errs, "APP_ENV 只能是 sandbox 或 production")
	}
	switch c.KYCMode {
	case KYCModeDoKYC, KYCModePartnerKYC:
	default:
		errs = append(errs, "KYC_MODE 只能是 DO_KYC 或 PARTNER_KYC")
	}
	switch c.BankLinkMethod {
	case BankLinkDirect, BankLinkPlaid:
	default:
		errs = append(errs, "BANK_LINK_METHOD 只能是 DIRECT 或 PLAID")
	}
	switch c.UserSubmitMode {
	case SubmitPostPatch, SubmitSinglePost:
	default:
		errs = append(errs, "USER_SUBMIT_MODE 只能是 POST_PATCH 或 SINGLE_POST")
	}
	switch c.SeasoningStart {
	case SeasoningFromCleared, SeasoningFromInitiated:
	default:
		errs = append(errs, "SEASONING_START 只能是 CLEARED 或 INITIATED")
	}
	if c.SeasoningDays < 0 || c.SeasoningDays > 365 {
		errs = append(errs, "SEASONING_DAYS 超出范围 0–365")
	}
	if c.DW.TokenRequestsPerHour < 1 || c.DW.TokenRequestsPerHour > 60 {
		errs = append(errs, "DW_TOKEN_REQUESTS_PER_HOUR 超出范围 1–60（建议 5–10）")
	}
	if c.DW.HTTPTimeout <= 0 {
		errs = append(errs, "DW_HTTP_TIMEOUT 必须大于 0")
	}
	if !strings.HasPrefix(c.DW.BaseURL, "https://") && !strings.HasPrefix(c.DW.BaseURL, "http://127.0.0.1") && !strings.HasPrefix(c.DW.BaseURL, "http://localhost") {
		errs = append(errs, "DW_BASE_URL 必须使用 https")
	}
	if strings.Contains(c.DW.BaseURL, "/auth/tokens") {
		errs = append(errs, "DW_BASE_URL 只填基础地址（如 https://bo-api.drivewealth.io/back-office），不要包含 /auth/tokens")
	}
	if c.PIIKey != nil && len(c.PIIKey) != 32 {
		errs = append(errs, "PII_ENCRYPTION_KEY 解码后必须是 32 字节（AES-256）")
	}
	if c.JWTSecret != nil && len(c.JWTSecret) < 32 {
		errs = append(errs, "JWT_SECRET 解码后至少 32 字节")
	}
	if c.SessionTTL < time.Minute || c.SessionTTL > 30*24*time.Hour {
		errs = append(errs, "SESSION_TTL 超出范围 1m–720h")
	}
	switch c.MarketDataMode {
	case MarketSim, MarketReal:
	default:
		errs = append(errs, "MARKET_DATA_MODE 只能是 SIM 或 REAL")
	}
	if c.MarketTick < 500*time.Millisecond || c.MarketTick > time.Minute {
		errs = append(errs, "MARKET_TICK 超出范围 500ms–1m")
	}
	if c.KYCPollInterval < 5*time.Second || c.KYCPollInterval > time.Hour {
		errs = append(errs, "KYC_POLL_INTERVAL 超出范围 5s–1h")
	}
	if c.DW.LogBodies && c.Env == "production" {
		errs = append(errs, "production 环境禁止开启 DW_LOG_BODIES")
	}
	if c.OTPDevLog && c.Env == "production" {
		errs = append(errs, "production 环境禁止开启 OTP_DEV_LOG")
	}
	for _, sfx := range c.AllowedEmailSuffixes {
		if !strings.HasPrefix(sfx, "@") || len(sfx) < 4 || strings.Count(sfx, "@") != 1 {
			errs = append(errs, "ALLOWED_EMAIL_SUFFIXES 每项须以 @ 开头，如 @example.com")
			break
		}
	}
	c.AllowedEmails = append(c.AllowedEmails, c.AllowedEmailSuffixes...) // 旧变量兼容：合并到同一名单
	for _, e := range c.AllowedEmails {
		if !allowedEmailEntryRE.MatchString(e) {
			errs = append(errs, "ALLOWED_EMAILS 每项须为 @域名（如 @example.com）或完整邮箱")
			break
		}
	}
	for _, o := range c.CORSAllowedOrigins {
		if o == "*" && c.Env == "production" {
			errs = append(errs, "production 环境 CORS_ALLOWED_ORIGINS 不能为 *")
		}
	}
	l := c.Limits
	if l.MinDeposit <= 0 || l.MaxDeposit < l.MinDeposit || l.DailyDeposit < l.MaxDeposit {
		errs = append(errs, "入金限额不合理（需 0 < 最低 ≤ 最高 ≤ 每日）")
	}
	if l.MinWithdrawal <= 0 || l.MaxWithdrawal < l.MinWithdrawal || l.MinWire <= 0 {
		errs = append(errs, "出金限额不合理")
	}
	if l.MinOrder <= 0 {
		errs = append(errs, "LIMIT_MIN_ORDER 须大于 0")
	}
	if l.MaxBanks < 1 {
		errs = append(errs, "LIMIT_MAX_BANKS 至少为 1")
	}
	for name, v := range map[string]string{"LIMIT_ACH_CUTOFF_ET": l.ACHCutoffET, "LIMIT_WIRE_CUTOFF_ET": l.WireCutoffET} {
		if _, err := time.Parse("15:04", v); err != nil {
			errs = append(errs, name+" 格式应为 HH:MM")
		}
	}
	if len(errs) > 0 {
		return fmt.Errorf("配置错误: %s", strings.Join(errs, "; "))
	}
	return nil
}

// DWConfigured：DW 凭据是否齐全（不返回任何凭据内容）。
// allowedEmailEntryRE：白名单条目，"@域名" 或 "本地部分@域名"。
var allowedEmailEntryRE = regexp.MustCompile(`^[^\s@,]*@[^\s@,]+\.[^\s@,]+$`)

func (c *Config) DWConfigured() bool {
	return c.DW.AppKey != "" && c.DW.ClientID != "" && c.DW.ClientSecret != ""
}

// APIReady：业务接口所需的数据库、PII 密钥、JWT 密钥是否齐全。
func (c *Config) APIReady() bool {
	return c.DatabaseURL != "" && len(c.PIIKey) == 32 && len(c.JWTSecret) >= 32
}

// RequireDoKYC：PARTNER_KYC 时返回未实现错误。
func (c *Config) RequireDoKYC() error {
	if c.KYCMode == KYCModePartnerKYC {
		return ErrPartnerKYCNotImplemented
	}
	return nil
}

func splitList(v string) []string {
	var out []string
	for _, s := range strings.Split(v, ",") {
		if s = strings.TrimSpace(s); s != "" {
			out = append(out, s)
		}
	}
	return out
}

type parser struct {
	get  Getenv
	errs []string
}

func (p *parser) str(key, def string) string {
	if v := strings.TrimSpace(p.get(key)); v != "" {
		return v
	}
	return def
}

func (p *parser) int(key string, def int) int {
	v := strings.TrimSpace(p.get(key))
	if v == "" {
		return def
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		p.errs = append(p.errs, key+" 必须是整数")
		return def
	}
	return n
}

func (p *parser) bool(key string, def bool) bool {
	v := strings.TrimSpace(p.get(key))
	if v == "" {
		return def
	}
	b, err := strconv.ParseBool(v)
	if err != nil {
		p.errs = append(p.errs, key+" 必须是 true 或 false")
		return def
	}
	return b
}

func (p *parser) float(key string, def float64) float64 {
	v := strings.TrimSpace(p.get(key))
	if v == "" {
		return def
	}
	f, err := strconv.ParseFloat(v, 64)
	if err != nil {
		p.errs = append(p.errs, key+" 必须是数字")
		return def
	}
	return f
}

func (p *parser) dur(key string, def time.Duration) time.Duration {
	v := strings.TrimSpace(p.get(key))
	if v == "" {
		return def
	}
	d, err := time.ParseDuration(v)
	if err != nil {
		p.errs = append(p.errs, key+" 必须是时长（如 10s、5m）")
		return def
	}
	return d
}
