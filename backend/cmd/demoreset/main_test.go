package main

import (
	"bytes"
	"context"
	"encoding/json"
	"strings"
	"testing"
)

func TestDWUserName(t *testing.T) {
	cases := []struct {
		name, body, first, last string
	}{
		{"顶层姓名", `{"firstName":"Ann","lastName":"Lee"}`, "Ann", "Lee"},
		{"userDetails", `{"userDetails":{"firstName":"Bo","lastName":"Wu"}}`, "Bo", "Wu"},
		{"BASIC_INFO 文档", `{"documents":[{"type":"BASIC_INFO","data":{"firstName":"Cy","lastName":"Ng"}}]}`, "Cy", "Ng"},
		{"无姓名", `{"documents":[{"type":"ADDRESS_INFO","data":{}}]}`, "", ""},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			var u dwUser
			if err := json.Unmarshal([]byte(c.body), &u); err != nil {
				t.Fatal(err)
			}
			if f, l := u.name(); f != c.first || l != c.last {
				t.Fatalf("got %q %q", f, l)
			}
		})
	}
}

func TestNameOfAndTail(t *testing.T) {
	for _, c := range []struct {
		in   any
		want string
	}{
		{"OPEN", "OPEN"},
		{map[string]any{"name": "FROZEN"}, "FROZEN"},
		{nil, ""},
	} {
		if got := nameOf(c.in); got != c.want {
			t.Errorf("nameOf(%v) = %q", c.in, got)
		}
	}
	if tail4("ABCD123456") != "…3456" || tail4("12") != "12" {
		t.Error("tail4")
	}
}

func TestResetStepsOrder(t *testing.T) {
	// 外键依赖：子表必须先于父表删除
	idx := map[string]int{}
	for i, s := range resetSteps {
		idx[s.table] = i
	}
	for _, pair := range [][2]string{
		{"transfers", "bank_accounts"}, {"bank_accounts", "accounts"}, {"accounts", "dw_users"},
		{"kyc_issues", "dw_users"}, {"dw_users", "applications"}, {"applications", "users_app"}, {"sessions", "users_app"},
	} {
		if idx[pair[0]] >= idx[pair[1]] {
			t.Errorf("%s 应在 %s 之前删除", pair[0], pair[1])
		}
	}
}

// fakeDW：按路径返回预设 JSON。
type fakeDW map[string]string

func (f fakeDW) Do(_ context.Context, _, path string, _, out any) error {
	return json.Unmarshal([]byte(f[path]), out)
}

func TestPrintVerify(t *testing.T) {
	dw := fakeDW{
		"/users/u-1":                    `{"id":"u-1","status":{"name":"APPROVED"},"firstName":"Should","lastName":"NotPrint"}`,
		"/users/u-1/kyc-status":         `{"status":{"name":"KYC_APPROVED"}}`,
		"/users/u-1/accounts":           `[{"id":"acc-1","accountNo":"TEST000001","status":{"name":"OPEN"},"accountType":{"name":"LIVE"},"openedWhen":"2026-11-19T15:00:00Z"}]`,
		"/accounts/acc-1/summary/money": `{"updated":"2026-11-20T01:00:00Z","cash":{"cashBalance":1000,"cashAvailableForTrade":0,"cashAvailableForWithdrawal":0}}`,
	}
	var buf bytes.Buffer
	if err := printVerify(context.Background(), dw, "u-1", &buf); err != nil {
		t.Fatal(err)
	}
	out := buf.String()
	for _, want := range []string{"userID        u-1", "user.status   APPROVED", "kyc.status    KYC_APPROVED", "accountID     acc-1", "accountNo     TEST000001", "LIVE · OPEN", "cash 1000 · buyingPower 0 · withdrawable 0"} {
		if !strings.Contains(out, want) {
			t.Errorf("缺少 %q：\n%s", want, out)
		}
	}
	if strings.Contains(out, "Should") || strings.Contains(out, "NotPrint") {
		t.Error("不应打印姓名")
	}
}
