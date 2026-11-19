package config

import (
	"encoding/base64"
	"strings"
	"testing"
	"time"
)

func env(m map[string]string) Getenv { return func(k string) string { return m[k] } }

func TestDefaults(t *testing.T) {
	c, err := LoadFrom(env(nil))
	if err != nil {
		t.Fatalf("默认配置应合法: %v", err)
	}
	if c.KYCMode != KYCModeDoKYC || c.BankLinkMethod != BankLinkDirect || c.UserSubmitMode != SubmitPostPatch {
		t.Fatalf("开关默认值不符: %+v", c)
	}
	if c.SeasoningDays != 30 || c.SeasoningStart != SeasoningFromCleared {
		t.Fatalf("观察期默认值不符: %d %s", c.SeasoningDays, c.SeasoningStart)
	}
	if c.Limits.MinDeposit != 10 || c.Limits.MaxDeposit != 50000 || c.Limits.DailyDeposit != 50000 ||
		c.Limits.MinWithdrawal != 1 || c.Limits.MaxWithdrawal != 50000 || c.Limits.MinWire != 100 || c.Limits.MaxBanks != 2 {
		t.Fatalf("限额默认值不符: %+v", c.Limits)
	}
	if c.DW.BaseURL != DefaultDWBaseURL || c.DW.HTTPTimeout != 10*time.Second || c.DW.TokenRequestsPerHour != 6 {
		t.Fatalf("DW 默认值不符: %+v", c.DW)
	}
	if c.DWConfigured() {
		t.Fatal("无凭据时 DWConfigured 应为 false")
	}
	if len(c.AllowedEmailSuffixes) != 0 {
		t.Fatal("登录白名单默认为空（本机开发不受影响）")
	}
	c2, err := LoadFrom(env(map[string]string{"ALLOWED_EMAIL_SUFFIXES": " @Example.com ,@demo.test"}))
	if err != nil || len(c2.AllowedEmailSuffixes) != 2 || c2.AllowedEmailSuffixes[0] != "@example.com" {
		t.Fatalf("白名单解析不符: %v %v", c2.AllowedEmailSuffixes, err)
	}
}

func TestValidation(t *testing.T) {
	key := base64.StdEncoding.EncodeToString(make([]byte, 32))
	cases := []struct {
		name    string
		env     map[string]string
		wantErr string
	}{
		{"合法覆盖", map[string]string{"KYC_MODE": "PARTNER_KYC", "BANK_LINK_METHOD": "PLAID", "USER_SUBMIT_MODE": "SINGLE_POST", "PII_ENCRYPTION_KEY": key}, ""},
		{"KYC 模式非法", map[string]string{"KYC_MODE": "NO_KYC"}, "KYC_MODE"},
		{"绑卡方式非法", map[string]string{"BANK_LINK_METHOD": "PAYPAL"}, "BANK_LINK_METHOD"},
		{"提交模式非法", map[string]string{"USER_SUBMIT_MODE": "X"}, "USER_SUBMIT_MODE"},
		{"观察期非数字", map[string]string{"SEASONING_DAYS": "thirty"}, "SEASONING_DAYS"},
		{"观察期起算点非法", map[string]string{"SEASONING_START": "TODAY"}, "SEASONING_START"},
		{"token 预算越界", map[string]string{"DW_TOKEN_REQUESTS_PER_HOUR": "0"}, "DW_TOKEN_REQUESTS_PER_HOUR"},
		{"base URL 非 https", map[string]string{"DW_BASE_URL": "http://example.com"}, "DW_BASE_URL"},
		{"base URL 误填 token 完整路径", map[string]string{"DW_BASE_URL": "https://bo-api.drivewealth.io/back-office/auth/tokens"}, "不要包含 /auth/tokens"},
		{"密钥长度错误", map[string]string{"PII_ENCRYPTION_KEY": base64.StdEncoding.EncodeToString(make([]byte, 16))}, "32 字节"},
		{"密钥非 base64", map[string]string{"PII_ENCRYPTION_KEY": "%%%"}, "base64"},
		{"限额倒挂", map[string]string{"LIMIT_MIN_DEPOSIT": "100", "LIMIT_MAX_DEPOSIT": "50"}, "入金限额"},
		{"截止时间格式", map[string]string{"LIMIT_ACH_CUTOFF_ET": "4pm"}, "LIMIT_ACH_CUTOFF_ET"},
		{"环境非法", map[string]string{"APP_ENV": "prod"}, "APP_ENV"},
		{"JWT 密钥过短", map[string]string{"JWT_SECRET": base64.StdEncoding.EncodeToString(make([]byte, 16))}, "JWT_SECRET"},
		{"JWT 密钥非 base64", map[string]string{"JWT_SECRET": "%%%"}, "JWT_SECRET"},
		{"会话时长越界", map[string]string{"SESSION_TTL": "10s"}, "SESSION_TTL"},
		{"OTP 开关非布尔", map[string]string{"OTP_DEV_LOG": "yes"}, "OTP_DEV_LOG"},
		{"生产环境禁止打印验证码", map[string]string{"APP_ENV": "production", "OTP_DEV_LOG": "true"}, "OTP_DEV_LOG"},
		{"生产环境禁止记录 DW 响应体", map[string]string{"APP_ENV": "production", "DW_LOG_BODIES": "true"}, "DW_LOG_BODIES"},
		{"行情模式非法", map[string]string{"MARKET_DATA_MODE": "FAKE"}, "MARKET_DATA_MODE"},
		{"行情 tick 过短", map[string]string{"MARKET_TICK": "10ms"}, "MARKET_TICK"},
		{"对账周期过短", map[string]string{"KYC_POLL_INTERVAL": "1s"}, "KYC_POLL_INTERVAL"},
		{"生产环境 CORS 不能为 *", map[string]string{"APP_ENV": "production", "CORS_ALLOWED_ORIGINS": "*"}, "CORS_ALLOWED_ORIGINS"},
		{"登录白名单缺 @", map[string]string{"ALLOWED_EMAIL_SUFFIXES": "example.com"}, "ALLOWED_EMAIL_SUFFIXES"},
		{"登录白名单合法", map[string]string{"ALLOWED_EMAIL_SUFFIXES": "@example.com, @demo.test"}, ""},
		{"开发环境允许打印验证码", map[string]string{"OTP_DEV_LOG": "true", "JWT_SECRET": base64.StdEncoding.EncodeToString(make([]byte, 48))}, ""},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			_, err := LoadFrom(env(tc.env))
			if tc.wantErr == "" && err != nil {
				t.Fatalf("不应报错: %v", err)
			}
			if tc.wantErr != "" && (err == nil || !strings.Contains(err.Error(), tc.wantErr)) {
				t.Fatalf("应报含 %q 的错误，实际: %v", tc.wantErr, err)
			}
		})
	}
}

func TestPartnerKYCNotImplemented(t *testing.T) {
	c, err := LoadFrom(env(map[string]string{"KYC_MODE": "PARTNER_KYC"}))
	if err != nil {
		t.Fatal(err)
	}
	if c.RequireDoKYC() != ErrPartnerKYCNotImplemented {
		t.Fatal("PARTNER_KYC 应返回未实现错误")
	}
}

func TestErrorDoesNotLeakSecret(t *testing.T) {
	_, err := LoadFrom(env(map[string]string{"DW_CLIENT_SECRET": "super-secret-value", "KYC_MODE": "BAD"}))
	if err == nil || strings.Contains(err.Error(), "super-secret-value") {
		t.Fatalf("错误信息不得包含凭据: %v", err)
	}
}
