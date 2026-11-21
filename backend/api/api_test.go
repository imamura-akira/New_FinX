package api

import (
	"strings"
	"testing"

	"gopkg.in/yaml.v3"
)

// api-spec.md v1 的全部接口（方法 路径）。改契约时两边同步。
var wantOps = []string{
	"post /auth/otp/request", "post /auth/otp/verify", "post /auth/oauth", "post /auth/logout", "get /me",
	"get /application", "put /application/draft", "post /application/documents", "post /application/submit",
	"get /application/status", "patch /application/remediate",
	"get /account", "get /account/money", "get /account/allocation", "get /account/history",
	"get /funding/bank-accounts", "post /funding/bank-accounts", "delete /funding/bank-accounts/{id}",
	"get /funding/deposit-instructions", "post /funding/deposits", "post /funding/withdrawals", "get /funding/transfers", "get /funding/limits",
	"get /documents", "get /notifications", "post /notifications/read",
	"get /market/quotes", "get /market/instruments/{symbol}", "get /market/sentiment", "get /market/stats",
	"post /orders", "get /orders", "get /orders/{id}", "post /orders/{id}/cancel", "get /positions",
	"get /paper/account", "post /paper/account/reset", "get /paper/account/allocation", "get /paper/account/history", "post /paper/orders", "get /paper/orders",
	"get /paper/orders/{id}", "post /paper/orders/{id}/cancel", "get /paper/positions",
	"get /predict/account", "get /predict/markets", "get /predict/markets/{id}", "post /predict/bets", "get /predict/bets", "post /predict/claim",
	"get /rewards/xp", "get /rewards/catalog", "get /rewards/checkin", "post /rewards/checkin",
}

// 无需登录的接口（api-spec.md：除 /auth/* 外均需 Bearer；logout 需要会话）。
var publicOps = map[string]bool{"post /auth/otp/request": true, "post /auth/otp/verify": true, "post /auth/oauth": true,
	"get /market/quotes": true, "get /market/instruments/{symbol}": true, "get /market/sentiment": true, "get /market/stats": true} // 虚拟行情公开（api-spec.md 第 10 节）

type doc struct {
	OpenAPI    string                            `yaml:"openapi"`
	Servers    []map[string]string               `yaml:"servers"`
	Paths      map[string]map[string]operation   `yaml:"paths"`
	Components map[string]map[string]interface{} `yaml:"components"`
}

type operation struct {
	OperationID string                 `yaml:"operationId"`
	Security    *[]map[string][]string `yaml:"security"`
	Responses   map[string]interface{} `yaml:"responses"`
}

func load(t *testing.T) doc {
	t.Helper()
	var d doc
	if err := yaml.Unmarshal(OpenAPI, &d); err != nil {
		t.Fatalf("openapi.yaml 不是合法 YAML: %v", err)
	}
	return d
}

func TestContractCoversAPISpec(t *testing.T) {
	d := load(t)
	if !strings.HasPrefix(d.OpenAPI, "3.") || len(d.Servers) == 0 || d.Servers[0]["url"] != "/api/v1" {
		t.Fatalf("版本或 base URL 不正确: %s %v", d.OpenAPI, d.Servers)
	}
	got := map[string]operation{}
	ids := map[string]bool{}
	for path, ops := range d.Paths {
		for m, op := range ops {
			key := m + " " + path
			got[key] = op
			if op.OperationID == "" || ids[op.OperationID] {
				t.Errorf("%s 缺少或重复 operationId", key)
			}
			ids[op.OperationID] = true
			if _, ok := op.Responses["200"]; !ok {
				t.Errorf("%s 缺少 200 响应", key)
			}
		}
	}
	for _, k := range wantOps {
		op, ok := got[k]
		if !ok {
			t.Errorf("缺少接口 %s", k)
			continue
		}
		isPublic := op.Security != nil && len(*op.Security) == 0
		if isPublic != publicOps[k] {
			t.Errorf("%s 鉴权设置不符（public=%v）", k, isPublic)
		}
	}
	if len(got) != len(wantOps) {
		t.Errorf("接口数 %d，期望 %d（新增接口须先改 api-spec.md）", len(got), len(wantOps))
	}
}

func TestRefsResolve(t *testing.T) {
	d := load(t)
	var walk func(v interface{})
	walk = func(v interface{}) {
		switch t2 := v.(type) {
		case map[string]interface{}:
			for k, vv := range t2 {
				if k == "$ref" {
					ref, _ := vv.(string)
					parts := strings.Split(strings.TrimPrefix(ref, "#/components/"), "/")
					if len(parts) != 2 || d.Components[parts[0]][parts[1]] == nil {
						t.Errorf("无法解析的 $ref: %s", ref)
					}
				}
				walk(vv)
			}
		case []interface{}:
			for _, vv := range t2 {
				walk(vv)
			}
		}
	}
	var raw map[string]interface{}
	if err := yaml.Unmarshal(OpenAPI, &raw); err != nil {
		t.Fatal(err)
	}
	walk(raw)
}

func TestEnumsMatchSpec(t *testing.T) {
	s := string(OpenAPI)
	for _, v := range []string{
		"KYC_NOT_READY, KYC_READY, KYC_PROCESSING, KYC_INFO_REQUIRED, KYC_DOC_REQUIRED, KYC_MANUAL_REVIEW, KYC_APPROVED, KYC_DENIED",
		"STARTED, PENDING, SUCCESSFUL, FAILED, RETURNED, APPROVED, REJECTED, ON_HOLD, PROCESSING",
		"PENDING, OPEN, OPEN_NO_NEW_TRADES, FROZEN, CLOSED",
		"NONE, DRAFT, SUBMITTED, APPROVED, DENIED",
		"0, 40101, 40102, 40301, 40901, 42200, 42201, 42901, 50000, 50001, 50002, 50003", // api-spec.md 第 8 节
	} {
		if !strings.Contains(s, v) {
			t.Errorf("枚举与 api-spec.md 不一致或缺失: %s", v)
		}
	}
}
