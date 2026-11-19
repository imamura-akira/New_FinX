package application

import (
	"encoding/json"
	"testing"
	"time"
)

func sp(s string) *string { return &s }

func TestBuildStatus(t *testing.T) {
	now := time.Date(2026, 11, 19, 10, 0, 0, 0, time.UTC)
	cases := []struct {
		name      string
		p         *Progress
		wantKYC   string
		wantState string
		wantAcct  string
	}{
		{"无申请", nil, "KYC_NOT_READY", SubmitNotSubmitted, ""},
		{"草稿", &Progress{AppStatus: "DRAFT"}, "KYC_NOT_READY", SubmitNotSubmitted, ""},
		{"已提交、DW User 未创建", &Progress{AppStatus: "SUBMITTED", Ref: "FX1", SubmittedAt: &now, KYCStatus: "KYC_NOT_READY"}, "KYC_NOT_READY", SubmitSubmitting, ""},
		{"已创建、PATCH 未完成", &Progress{AppStatus: "SUBMITTED", HasDWUser: true, OrchState: StateCreated, KYCStatus: "KYC_PROCESSING"}, "KYC_PROCESSING", SubmitSubmitting, ""},
		{"DW 拒绝请求", &Progress{AppStatus: "SUBMITTED", Blocked: true}, "KYC_NOT_READY", SubmitNeedsAttention, ""},
		{"KYC 通过、账户开立中", &Progress{AppStatus: "APPROVED", HasDWUser: true, OrchState: StateDocsDone, KYCStatus: "KYC_APPROVED", AccountStatus: sp("PENDING")}, "KYC_APPROVED", SubmitDone, "PENDING"},
		{"账户已开通", &Progress{AppStatus: "APPROVED", HasDWUser: true, OrchState: StateDocsDone, KYCStatus: "KYC_APPROVED", AccountStatus: sp("OPEN"), AccountNo: sp("TEST0000")}, "KYC_APPROVED", SubmitDone, "OPEN"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			v := buildStatus(tc.p)
			if v.KYCStatus != tc.wantKYC || v.SubmitState != tc.wantState {
				t.Fatalf("kyc=%s state=%s，期望 %s %s", v.KYCStatus, v.SubmitState, tc.wantKYC, tc.wantState)
			}
			got := ""
			if v.AccountStatus != nil {
				got = *v.AccountStatus
			}
			if got != tc.wantAcct || v.Issues == nil || v.RequiredDocs == nil {
				t.Fatalf("account=%q issues=%v", got, v.Issues)
			}
		})
	}
}

func TestStatusEndpoint(t *testing.T) {
	f := newFixture(t)
	f.repo.prog["u1"] = &Progress{AppStatus: "SUBMITTED", Ref: "FX261119-ABCDEFGH", HasDWUser: true, OrchState: StateDocsDone, KYCStatus: "KYC_INFO_REQUIRED",
		Issues: []Issue{{Code: "ADDRESS_MISMATCH", Field: sp("residentialAddress.line1"), UserMessage: "请核对此项信息"}}}
	r := f.call("u1", "GET", "/api/v1/application/status", nil)
	if r.Code != 0 {
		t.Fatal(r)
	}
	var v statusView
	_ = json.Unmarshal(r.Data, &v)
	if v.KYCStatus != "KYC_INFO_REQUIRED" || len(v.Issues) != 1 || *v.ApplicationRef != "FX261119-ABCDEFGH" || v.SubmitState != SubmitDone {
		t.Fatalf("响应不正确: %+v", v)
	}
	if r := f.call("u2", "GET", "/api/v1/application/status", nil); r.Code != 0 {
		t.Fatal(r)
	}
	if r := f.call("", "GET", "/api/v1/application/status", nil); r.HTTP != 401 {
		t.Fatal("未登录应 401")
	}
}
