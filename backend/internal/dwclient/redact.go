package dwclient

import (
	"encoding/json"
	"fmt"
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
		// 沙盒实测：DW User 对象的地址行、头像（邮箱哈希）字段名
		"addressline1": true, "addressline2": true, "avatarurl": true,
	}
	// 保留尾 4 位：税号、证件号、银行与账户号码、电话
	redactLast4 = map[string]bool{
		"value": true, "ssn": true, "tin": true, "taxid": true, "idnumber": true,
		"bankaccountnumber": true, "bankroutingnumber": true,
		"accountnumber": true, "routingnumber": true, "accountno": true,
		"beneficiaryaccountnumber": true, "beneficiaryroutingnumber": true, "beneficiaryswiftaba": true,
		"phone": true, "phonenumber": true,
		"idno": true, // 沙盒实测：DW User 对象中的证件号字段
	}
	// 保留首字符：姓名、邮箱本地部分
	redactInitial = map[string]bool{
		"firstname": true, "lastname": true, "beneficiaryname": true, "politicallyexposednames": true,
		"emailaddress": true, "email": true, "signedby": true,
		// 沙盒实测：DW User 对象中的姓名派生字段与签名人
		"displayname": true, "acksignedby": true, "employercompany": true,
	}
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
