package dwclient

import (
	"encoding/json"
	"fmt"
	"regexp"
	"strings"
)

// 脱敏规则（backend-design.md 第 3 节"请求体脱敏"、第 6 节 PII 规则）。键名不区分大小写。
var (
	// 整体隐藏：凭据、token、证件影像、出生日期、地址行
	redactFull = map[string]bool{
		"clientsecret": true, "client_secret": true, "password": true,
		"access_token": true, "accesstoken": true, "token": true, "refresh_token": true,
		"authorization": true, "dw-client-app-key": true, "appkey": true,
		"document": true, "image": true,
		"birthday": true, "birthmonth": true, "birthyear": true, "birthdate": true, "dob": true,
		"street1": true, "street2": true,
		// 审计 SEC-P1-3：地址的其余部分
		"city": true, "postalcode": true, "zipcode": true, "province": true,
		// 沙盒实测：DW User 对象的地址行、头像（邮箱哈希）字段名
		"addressline1": true, "addressline2": true, "avatarurl": true,
		"username": true, // 沙盒实测：绑卡响应 userDetails 回显后端生成的 DW 用户名
	}
	// 保留尾 4 位：税号、证件号、银行与账户号码、电话
	redactLast4 = map[string]bool{
		"value": true, "ssn": true, "tin": true, "taxid": true, "idnumber": true,
		"bankaccountnumber": true, "bankroutingnumber": true,
		"accountnumber": true, "routingnumber": true, "accountno": true,
		"beneficiaryaccountnumber": true, "beneficiaryroutingnumber": true, "beneficiaryswiftaba": true,
		"phone": true, "phonenumber": true,
		"idno":                  true, // 沙盒实测：DW User 对象中的证件号字段
		"intermediarybankswift": true, // 审计 SEC-P1-3
		"account_number":        true, // 沙盒实测：入金响应中的账户号（下划线写法）
	}
	// 保留首字符：姓名、邮箱本地部分
	redactInitial = map[string]bool{
		"firstname": true, "lastname": true, "beneficiaryname": true, "politicallyexposednames": true,
		"emailaddress": true, "email": true, "signedby": true,
		// 沙盒实测：DW User 对象中的姓名派生字段与签名人
		"displayname": true, "acksignedby": true, "employercompany": true,
		// 沙盒实测（2026-11-20）：GET /funding/deposits/{id} 的 details.accountHolderName 为开户姓名
		"accountholdername": true,
		// 审计 SEC-P1-3：dwmapper / 资金请求中实际出现的雇主、职位、董事、券商关联与自定义名称
		"company": true, "position": true, "directorof": true, "broker": true,
		"bankaccountnickname": true, "beneficiarybankname": true, "nickname": true,
	}

	// 自由文本字段：DW 的错误说明、状态备注等，可能回显用户输入（审计 SEC-P1-4）
	freeText = map[string]bool{
		"message": true, "errormessage": true, "error": true, "comment": true, "note": true,
		"othernotes": true, "otherdetails": true, "description": true, "reason": true, "statusmessage": true,
	}

	// DW 账户号码（4 位字母 + 6 位数字，如 FEYQ000001）：出现在 accountNo，也作为入金 / 出金 id 的前缀与 URL 路径
	accountNoRE = regexp.MustCompile(`\b[A-Z]{4}\d{6}\b`)
	emailRE     = regexp.MustCompile(`[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}`)
	ssnRE       = regexp.MustCompile(`\b\d{3}-\d{2}-\d{4}\b`)
	longDigitRE = regexp.MustCompile(`\d{7,}`)
)

const maxLoggedBody = 4096

// RedactJSON 返回脱敏后的 JSON 字符串，用于日志。非 JSON 内容只记录长度。
func RedactJSON(b []byte) string {
	if len(b) == 0 {
		return ""
	}
	var v any
	if err := json.Unmarshal(b, &v); err != nil {
		return fmt.Sprintf("[non-json body, %d bytes]", len(b))
	}
	out, err := json.Marshal(redactValue("", v))
	if err != nil {
		return "[unloggable body]"
	}
	if len(out) > maxLoggedBody {
		return string(out[:maxLoggedBody]) + "…[truncated]"
	}
	return string(out)
}

// RedactAccountNos 把字符串中的 DW 账户号码打码为只留尾 4 位（用于路径与任意字符串值）。
func RedactAccountNos(s string) string {
	return accountNoRE.ReplaceAllStringFunc(s, maskLast4)
}

// SanitizeText 清洗自由文本：账户号码、邮箱、SSN 格式与 7 位以上连续数字（证件号、电话、账号）打码。
func SanitizeText(s string) string {
	s = RedactAccountNos(s)
	s = emailRE.ReplaceAllStringFunc(s, maskInitial)
	s = ssnRE.ReplaceAllStringFunc(s, maskLast4)
	return longDigitRE.ReplaceAllStringFunc(s, maskLast4)
}

func redactValue(key string, v any) any {
	k := strings.ToLower(key)
	switch t := v.(type) {
	case map[string]any:
		m := make(map[string]any, len(t))
		for kk, vv := range t {
			m[kk] = redactValue(kk, vv)
		}
		return m
	case []any:
		s := make([]any, len(t))
		for i, vv := range t {
			s[i] = redactValue(key, vv)
		}
		return s
	case nil, bool:
		return t
	}
	s := fmt.Sprint(v)
	switch {
	case redactFull[k]:
		return "[REDACTED]"
	case redactLast4[k]:
		return maskLast4(s)
	case redactInitial[k]:
		return maskInitial(s)
	case freeText[k]:
		return SanitizeText(s)
	}
	if str, ok := v.(string); ok {
		return RedactAccountNos(str)
	}
	return v
}

func maskLast4(s string) string {
	r := []rune(s)
	if len(r) <= 4 {
		return strings.Repeat("*", len(r))
	}
	return strings.Repeat("*", len(r)-4) + string(r[len(r)-4:])
}

func maskInitial(s string) string {
	if s == "" {
		return s
	}
	if at := strings.IndexByte(s, '@'); at > 0 {
		return string([]rune(s)[:1]) + "***" + s[at:]
	}
	return string([]rune(s)[:1]) + "***"
}
