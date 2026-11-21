package httpx

import (
	"net/http/httptest"
	"net/netip"
	"testing"
)

// 审计 SEC-P1-1：限速按真实客户端 IP；只信任受信代理写入的 X-Forwarded-For 最右侧一项，防伪造。
func TestClientIP(t *testing.T) {
	SetTrustedProxies([]netip.Prefix{netip.MustParsePrefix("172.16.0.0/12")})
	t.Cleanup(func() { SetTrustedProxies(nil) })
	cases := []struct {
		name   string
		remote string
		xff    []string
		want   string
	}{
		{"受信代理 + 单值", "172.16.0.1:40000", []string{"203.0.113.7"}, "203.0.113.7"},
		{"受信代理 + 客户端伪造在左侧：取最右侧", "172.16.41.1:40000", []string{"1.1.1.1, 203.0.113.7"}, "203.0.113.7"},
		{"受信代理 + 多个头：取最后一个头的最右侧", "172.16.0.1:40000", []string{"9.9.9.9", "198.51.100.4"}, "198.51.100.4"},
		{"受信代理 + IPv6", "172.16.0.1:40000", []string{"2001:db8::1"}, "2001:db8::1"},
		{"受信代理 + 非法值：退回连接地址", "172.16.0.1:40000", []string{"not-an-ip"}, "172.16.0.1"},
		{"受信代理 + 无头：连接地址", "172.16.0.1:40000", nil, "172.16.0.1"},
		{"非受信来源带头：忽略（防伪造）", "203.0.113.9:5555", []string{"10.0.0.1"}, "203.0.113.9"},
		{"IPv6 连接地址", "[2001:db8::2]:443", nil, "2001:db8::2"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			r := httptest.NewRequest("GET", "/", nil)
			r.RemoteAddr = tc.remote
			for _, v := range tc.xff {
				r.Header.Add("X-Forwarded-For", v)
			}
			if got := ClientIP(r); got != tc.want {
				t.Fatalf("ClientIP = %q，期望 %q", got, tc.want)
			}
		})
	}
	SetTrustedProxies(nil)
	r := httptest.NewRequest("GET", "/", nil)
	r.RemoteAddr = "172.16.0.1:1"
	r.Header.Set("X-Forwarded-For", "203.0.113.7")
	if got := ClientIP(r); got != "172.16.0.1" {
		t.Fatalf("未配置受信代理时一律取连接地址：%q", got)
	}
}
