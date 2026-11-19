package crypto

import (
	"bytes"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"strings"
	"testing"
)

func newTestCipher(t *testing.T) *Cipher {
	t.Helper()
	key := make([]byte, 32)
	if _, err := rand.Read(key); err != nil {
		t.Fatal(err)
	}
	c, err := New(key)
	if err != nil {
		t.Fatal(err)
	}
	return c
}

func TestRoundTrip(t *testing.T) {
	c := newTestCipher(t)
	aad := AAD("applications", "data_enc", "row-1")
	for _, pt := range []string{"123-45-6789", "200 Market Street, Apt 5B", "测试中文", strings.Repeat("x", 10000)} {
		ct, err := c.EncryptString(pt, aad)
		if err != nil {
			t.Fatal(err)
		}
		if bytes.Contains(ct, []byte(pt)) {
			t.Fatal("密文中不应出现明文")
		}
		got, err := c.DecryptString(ct, aad)
		if err != nil || got != pt {
			t.Fatalf("往返失败: %q %v", got, err)
		}
	}
}

func TestNonceUnique(t *testing.T) {
	c := newTestCipher(t)
	a, _ := c.Encrypt([]byte("same"), nil)
	b, _ := c.Encrypt([]byte("same"), nil)
	if bytes.Equal(a, b) {
		t.Fatal("相同明文两次加密不应相同")
	}
}

func TestTamperAndMismatch(t *testing.T) {
	c := newTestCipher(t)
	aad := AAD("dw_users", "dw_password_enc", "u1")
	ct, _ := c.Encrypt([]byte("secret"), aad)

	cases := map[string]func() ([]byte, error){
		"篡改密文": func() ([]byte, error) {
			bad := append([]byte(nil), ct...)
			bad[len(bad)-1] ^= 0x01
			return c.Decrypt(bad, aad)
		},
		"AAD 不匹配": func() ([]byte, error) { return c.Decrypt(ct, AAD("dw_users", "dw_password_enc", "u2")) },
		"密钥不同":    func() ([]byte, error) { return newTestCipher(t).Decrypt(ct, aad) },
		"密文过短":    func() ([]byte, error) { return c.Decrypt(ct[:5], aad) },
		"版本不支持": func() ([]byte, error) {
			bad := append([]byte(nil), ct...)
			bad[0] = 0x02
			return c.Decrypt(bad, aad)
		},
	}
	for name, fn := range cases {
		t.Run(name, func(t *testing.T) {
			if _, err := fn(); !errors.Is(err, ErrCiphertext) {
				t.Fatalf("应返回 ErrCiphertext，实际 %v", err)
			}
		})
	}
}

func TestKeyValidation(t *testing.T) {
	if _, err := New(make([]byte, 16)); !errors.Is(err, ErrKeySize) {
		t.Fatal("16 字节密钥应被拒绝")
	}
	if _, err := NewFromBase64("not-base64!!"); !errors.Is(err, ErrKeySize) {
		t.Fatal("非 base64 密钥应被拒绝")
	}
	if _, err := NewFromBase64(base64.StdEncoding.EncodeToString(make([]byte, 32))); err != nil {
		t.Fatal(err)
	}
}

func TestEmptyString(t *testing.T) {
	c := newTestCipher(t)
	ct, err := c.EncryptString("", nil)
	if err != nil || ct != nil {
		t.Fatal("空字符串应加密为 nil")
	}
	s, err := c.DecryptString(nil, nil)
	if err != nil || s != "" {
		t.Fatal("nil 应解密为空字符串")
	}
}
