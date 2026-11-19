package auth

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"strings"
	"time"
)

// 会话 token 为 HS256 JWT；数据库只存其 SHA-256（sessions.token_hash），注销即作废。

var (
	errTokenInvalid = errors.New("auth: token 无效")
	errTokenExpired = errors.New("auth: token 已过期")
)

type claims struct {
	Sub string `json:"sub"` // users_app.id
	Sid string `json:"sid"` // 随机会话 id，保证每次登录 token 不同
	Iat int64  `json:"iat"`
	Exp int64  `json:"exp"`
}

var jwtHeader = base64.RawURLEncoding.EncodeToString([]byte(`{"alg":"HS256","typ":"JWT"}`))

func signJWT(secret []byte, c claims) (string, error) {
	payload, err := json.Marshal(c)
	if err != nil {
		return "", err
	}
	unsigned := jwtHeader + "." + base64.RawURLEncoding.EncodeToString(payload)
	return unsigned + "." + base64.RawURLEncoding.EncodeToString(mac(secret, unsigned)), nil
}

func verifyJWT(secret []byte, token string, now time.Time) (claims, error) {
	var c claims
	parts := strings.Split(token, ".")
	if len(parts) != 3 || parts[0] != jwtHeader {
		return c, errTokenInvalid
	}
	sig, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil || !hmac.Equal(sig, mac(secret, parts[0]+"."+parts[1])) {
		return c, errTokenInvalid
	}
	payload, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil || json.Unmarshal(payload, &c) != nil || c.Sub == "" {
		return c, errTokenInvalid
	}
	if now.Unix() >= c.Exp {
		return c, errTokenExpired
	}
	return c, nil
}

func mac(secret []byte, s string) []byte {
	h := hmac.New(sha256.New, secret)
	h.Write([]byte(s))
	return h.Sum(nil)
}

// tokenHash：sessions 表主键。
func tokenHash(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}
