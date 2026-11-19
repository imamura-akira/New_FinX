package main

import (
	"encoding/json"
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
