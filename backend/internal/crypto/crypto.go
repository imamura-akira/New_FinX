// Package crypto 提供 PII 字段级加解密（AES-256-GCM），密钥来自环境变量 PII_ENCRYPTION_KEY。
//
// 密文格式：version(1 字节, 当前 0x01) | nonce(12 字节) | ciphertext+tag。
// 建议每个字段使用 AAD 绑定上下文（如 "applications.data_enc:<id>"），防止密文被挪到别的行/列解密。
// 适用字段见 backend-design.md 第 6 节 PII 规则：SSN/税号、证件影像对象键、地址、出生日期、DW 用户名/密码等。
package crypto

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
)

const (
	version1  byte = 0x01
	keySize        = 32
	nonceSize      = 12
)

var (
	// ErrKeySize：密钥不是 32 字节。
	ErrKeySize = errors.New("crypto: 密钥必须是 32 字节（AES-256）")
	// ErrCiphertext：密文过短、版本不支持、被篡改或 AAD/密钥不匹配。错误信息不包含任何明文或密钥。
	ErrCiphertext = errors.New("crypto: 密文无效或校验失败")
)

// Cipher 是并发安全的 AES-256-GCM 加解密器。
type Cipher struct {
	aead cipher.AEAD
	rand io.Reader
}

// New 用 32 字节密钥创建 Cipher。
func New(key []byte) (*Cipher, error) {
	if len(key) != keySize {
		return nil, ErrKeySize
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, fmt.Errorf("crypto: %w", err)
	}
	aead, err := cipher.NewGCM(block)
	if err != nil {
		return nil, fmt.Errorf("crypto: %w", err)
	}
	return &Cipher{aead: aead, rand: rand.Reader}, nil
}

// NewFromBase64 用 base64 编码的密钥创建 Cipher（PII_ENCRYPTION_KEY 的格式）。
func NewFromBase64(b64 string) (*Cipher, error) {
	key, err := base64.StdEncoding.DecodeString(b64)
	if err != nil {
		return nil, ErrKeySize
	}
	return New(key)
}

// Encrypt 加密 plaintext。每次调用生成随机 nonce，相同明文两次加密结果不同。
func (c *Cipher) Encrypt(plaintext, aad []byte) ([]byte, error) {
	out := make([]byte, 1+nonceSize, 1+nonceSize+len(plaintext)+c.aead.Overhead())
	out[0] = version1
	if _, err := io.ReadFull(c.rand, out[1:1+nonceSize]); err != nil {
		return nil, fmt.Errorf("crypto: 生成 nonce 失败: %w", err)
	}
	return c.aead.Seal(out, out[1:1+nonceSize], plaintext, aad), nil
}

// Decrypt 解密并校验完整性。
func (c *Cipher) Decrypt(ciphertext, aad []byte) ([]byte, error) {
	if len(ciphertext) < 1+nonceSize+c.aead.Overhead() || ciphertext[0] != version1 {
		return nil, ErrCiphertext
	}
	pt, err := c.aead.Open(nil, ciphertext[1:1+nonceSize], ciphertext[1+nonceSize:], aad)
	if err != nil {
		return nil, ErrCiphertext
	}
	return pt, nil
}

// EncryptString / DecryptString：字符串字段便捷方法。空字符串加密为 nil（数据库存 NULL）。
func (c *Cipher) EncryptString(s string, aad []byte) ([]byte, error) {
	if s == "" {
		return nil, nil
	}
	return c.Encrypt([]byte(s), aad)
}

func (c *Cipher) DecryptString(b, aad []byte) (string, error) {
	if len(b) == 0 {
		return "", nil
	}
	pt, err := c.Decrypt(b, aad)
	if err != nil {
		return "", err
	}
	return string(pt), nil
}

// AAD 生成"表.列:行 id"形式的附加认证数据。
func AAD(table, column, rowID string) []byte {
	return []byte(table + "." + column + ":" + rowID)
}
