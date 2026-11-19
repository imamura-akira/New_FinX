package application

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/config"
	"github.com/imamura-akira/New_FinX/backend/internal/dwclient"
	"github.com/imamura-akira/New_FinX/backend/internal/dwmapper"
)

// ---------- 内存 OrchRepo ----------

type memDW struct {
	dwUserID     string
	username     []byte
	password     []byte
	attempts     int
	lastErr      string
	blocked      bool
	lastAttempt  time.Time
	uploadedDocs map[string]string
}

type memOrch struct {
	*memRepo
	mu    sync.Mutex
	dw    map[string]*memDW // by app
	audit []string
	email string
}

func newMemOrch(base *memRepo) *memOrch {
	return &memOrch{memRepo: base, dw: map[string]*memDW{}, email: "login@example.com"}
}

func (m *memOrch) MarkSubmitted(_ context.Context, appID, ref string, dataEnc, u, p []byte, now time.Time) error {
	m.memRepo.mu.Lock()
	defer m.memRepo.mu.Unlock()
	a := m.byID(appID)
	if a == nil || a.Status != "DRAFT" {
		return ErrNotDraft
	}
	a.Status, a.Ref, a.DataEnc, a.SubmittedAt, a.OrchState = "SUBMITTED", ref, dataEnc, &now, ""
	m.mu.Lock()
	m.dw[appID] = &memDW{username: u, password: p, uploadedDocs: map[string]string{}}
	m.mu.Unlock()
	return nil
}

func (m *memOrch) LoadOrch(_ context.Context, appID string) (*OrchApp, error) {
	m.memRepo.mu.Lock()
	a := m.byID(appID)
	m.memRepo.mu.Unlock()
	m.mu.Lock()
	defer m.mu.Unlock()
	d := m.dw[appID]
	if a == nil || d == nil {
		return nil, nil
	}
	o := &OrchApp{App: *a, LoginEmail: m.email, DWUserID: d.dwUserID, UsernameEnc: d.username, PasswordEnc: d.password}
	o.SubmitAttempts, o.SubmitBlocked = d.attempts, d.blocked
	return o, nil
}

func (m *memOrch) SetDWUser(_ context.Context, appID, id, state string, _ time.Time) error {
	m.mu.Lock()
	m.dw[appID].dwUserID = id
	m.mu.Unlock()
	return m.SetOrchState(context.Background(), appID, state)
}

func (m *memOrch) SetOrchState(_ context.Context, appID, state string) error {
	m.memRepo.mu.Lock()
	defer m.memRepo.mu.Unlock()
	m.byID(appID).OrchState = state
	return nil
}

func (m *memOrch) RecordAttempt(_ context.Context, appID, msg string, blocked bool, now time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	d := m.dw[appID]
	d.attempts++
	d.lastErr, d.blocked, d.lastAttempt = msg, d.blocked || blocked, now
	return nil
}

func (m *memOrch) PendingSubmissions(context.Context, time.Time, int) ([]string, error) {
	return nil, nil
}

func (m *memOrch) StagedDocuments(_ context.Context, appID string) ([]StagedDoc, error) {
	m.memRepo.mu.Lock()
	defer m.memRepo.mu.Unlock()
	var out []StagedDoc
	for _, d := range m.docs {
		if d.appID == appID && !d.deleted {
			if _, done := m.dw[appID].uploadedDocs[d.ID]; !done {
				out = append(out, StagedDoc{ID: d.ID, DocType: d.DocType, Side: d.Side, ContentType: d.ctype, ImageEnc: d.enc})
			}
		}
	}
	return out, nil
}

func (m *memOrch) MarkDocumentUploaded(_ context.Context, docID, dwDocID string, _ time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, d := range m.dw {
		d.uploadedDocs[docID] = dwDocID
	}
	return nil
}

func (m *memOrch) Audit(_ context.Context, actor, action, target string, _ map[string]any) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.audit = append(m.audit, action)
	return nil
}

// ---------- 假 DW ----------

type dwCall struct {
	Method, Path string
	Body         map[string]any
}

type fakeDW struct {
	mu    sync.Mutex
	calls []dwCall
	fail  map[string][]error // "METHOD /path" → 依次返回的错误
}

func (f *fakeDW) Do(_ context.Context, method, path string, body, out any) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	var m map[string]any
	raw, _ := json.Marshal(body)
	_ = json.Unmarshal(raw, &m)
	key := method + " " + path
	if strings.HasPrefix(path, "/users/") && method == http.MethodPatch {
		key = "PATCH /users/{id}"
	}
	f.calls = append(f.calls, dwCall{method, path, m})
	if errs := f.fail[key]; len(errs) > 0 {
		f.fail[key] = errs[1:]
		if errs[0] != nil {
			return errs[0]
		}
	}
	if out != nil {
		resp := map[string]any{}
		switch key {
		case "POST /users":
			resp["id"] = "dw-user-0001"
		case "POST /documents":
			resp["id"] = "dw-doc-" + m["side"].(string)
		}
		raw, _ := json.Marshal(resp)
		_ = json.Unmarshal(raw, out)
	}
	return nil
}

func (f *fakeDW) count(key string) int {
	f.mu.Lock()
	defer f.mu.Unlock()
	n := 0
	for _, c := range f.calls {
		k := c.Method + " " + c.Path
		if c.Method == http.MethodPatch && strings.HasPrefix(c.Path, "/users/") {
			k = "PATCH /users/{id}"
		}
		if k == key {
			n++
		}
	}
	return n
}

// ---------- 夹具 ----------

type submitFixture struct {
	*fixture
	orepo *memOrch
	dw    *fakeDW
	orch  *Orchestrator
	logs  *bytes.Buffer
}

func newSubmitFixture(t *testing.T, mode config.UserSubmitMode) *submitFixture {
	t.Helper()
	f := newFixture(t)
	sf := &submitFixture{fixture: f, orepo: newMemOrch(f.repo), dw: &fakeDW{fail: map[string][]error{}}, logs: &bytes.Buffer{}}
	logger := slog.New(slog.NewJSONHandler(sf.logs, nil))
	sf.orch = NewOrchestrator(sf.orepo, sf.dw, f.svc.cipher, mode, logger)
	f.svc.logger = logger
	f.svc.WithOrchestrator(sf.orch, sf.orepo, config.KYCModeDoKYC)
	f.mux = http.NewServeMux()
	f.svc.Routes(f.mux, "/api/v1", fakeAuth)
	return sf
}

// waitOrch 等待提交后的异步编排结束。
func (sf *submitFixture) waitOrch(t *testing.T, appID string) {
	t.Helper()
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		sf.orepo.mu.Lock()
		d := sf.orepo.dw[appID]
		done := d != nil && d.attempts > 0
		sf.orepo.mu.Unlock()
		if _, running := sf.orch.running.Load(appID); done && !running {
			return
		}
		time.Sleep(5 * time.Millisecond)
	}
	t.Fatal("编排未在 3 秒内结束")
}

func validUSDraft() map[string]any {
	return map[string]any{
		"firstName": "Alex", "lastName": "Chen", "dateOfBirth": "1990-03-07",
		"citizenship": "US", "taxResidency": "US", "phone": "+1 415 555 0142", "contactEmail": "alex@example.com", "language": "zh_CN",
		"usTaxPayer": "YES", "tinType": "SSN", "tin": "234-56-7890", "irsBackup": "NO", "tinConfirm": true,
		"residentialAddress": map[string]any{"line1": "200 Market Street", "city": "San Francisco", "state": "CA", "postalCode": "94105", "country": "US"},
		"employmentStatus":   "EMPLOYED", "employerName": "Example Corp", "industry": "PROFESSIONAL", "position": "ENGINEER",
		"annualIncomeRange": "100k-200k", "netWorthRange": "200k-500k", "netWorthLiquidRange": "50k-200k",
		"investmentExperience": "3-5", "investmentObjective": "GROWTH", "riskTolerance": "MED",
		"fundingSources": []string{"EMPLOYMENT"},
		"isAffiliatedBD": false, "isPEP": false, "isControlPerson": false,
	}
}

func allDisclosures() []map[string]any {
	var out []map[string]any
	for _, id := range append(append([]string{}, dwmapper.DWRequiredDisclosures...), PartnerDisclosures...) {
		out = append(out, map[string]any{"id": id, "accepted": true})
	}
	return append(out, map[string]any{"id": "rule14b", "accepted": false})
}

func submitBody() map[string]any {
	return map[string]any{"signatureName": "alex  chen", "disclosures": allDisclosures()}
}

func (sf *submitFixture) prepare(t *testing.T, user string, draft map[string]any) string {
	t.Helper()
	if r := sf.call(user, "PUT", "/api/v1/application/draft", map[string]any{"step": "p30", "data": draft}); r.Code != 0 {
		t.Fatalf("draft: %+v", r)
	}
	return sf.repo.apps[user].ID
}

// ---------- 测试 ----------

func TestSubmitHappyPathPostThenPatch(t *testing.T) {
	sf := newSubmitFixture(t, config.SubmitPostPatch)
	appID := sf.prepare(t, "u1", validUSDraft())
	r := sf.call("u1", "POST", "/api/v1/application/submit", submitBody())
	if r.Code != 0 {
		t.Fatalf("submit: %+v fields=%v", r, r.fields())
	}
	var out struct {
		ApplicationRef string    `json:"applicationRef"`
		SubmittedAt    time.Time `json:"submittedAt"`
	}
	_ = json.Unmarshal(r.Data, &out)
	if !strings.HasPrefix(out.ApplicationRef, "FX") || out.SubmittedAt.IsZero() {
		t.Fatalf("响应不正确: %+v", out)
	}
	sf.waitOrch(t, appID)

	if sf.dw.count("POST /users") != 1 || sf.dw.count("PATCH /users/{id}") != 1 || sf.dw.count("POST /documents") != 0 {
		t.Fatalf("DW 调用不正确: %+v", sf.dw.calls)
	}
	post := sf.dw.calls[0].Body
	if len(post["documents"].([]any)) != 4 || post["userType"] != dwmapper.UserType {
		t.Fatalf("POST /users 应含四类核心 documents: %v", post["documents"])
	}
	if u := post["username"].(string); !strings.HasPrefix(u, "fx") || len(u) != 18 {
		t.Fatalf("username 格式: %q", u)
	}
	if pw := post["password"].(string); len(pw) != 24 {
		t.Fatalf("password 长度: %d", len(pw))
	}
	if sf.dw.calls[1].Path != "/users/dw-user-0001" || len(sf.dw.calls[1].Body["documents"].([]any)) != 5 {
		t.Fatalf("PATCH 不正确: %+v", sf.dw.calls[1])
	}
	if got := sf.repo.apps["u1"]; got.Status != "SUBMITTED" || got.OrchState != StateDocsDone {
		t.Fatalf("状态不正确: %+v", got)
	}
	// 披露与签名随 DISCLOSURES 发送
	disc := docOf(sf.dw.calls[1].Body, dwmapper.DocDisclosures)
	if disc["signedBy"] != "alex chen" || disc["rule14b"] != false || disc["termsOfUse"] != true {
		t.Fatalf("DISCLOSURES 不正确: %v", disc)
	}
	// 生成的 DW 密码不得出现在日志中
	if strings.Contains(sf.logs.String(), post["password"].(string)) || strings.Contains(sf.logs.String(), "234-56-7890") {
		t.Fatal("日志泄露 DW 密码或税号")
	}
	// 重复提交
	if r := sf.call("u1", "POST", "/api/v1/application/submit", submitBody()); r.HTTP != 409 || r.Code != 40901 {
		t.Fatalf("重复提交应 40901: %+v", r)
	}
	// 提交后草稿不可修改
	if r := sf.call("u1", "PUT", "/api/v1/application/draft", map[string]any{"step": "b", "data": map[string]any{"firstName": "Bob"}}); r.Code != 40901 {
		t.Fatalf("提交后改草稿应 40901: %+v", r)
	}
}

func docOf(body map[string]any, typ string) map[string]any {
	for _, d := range body["documents"].([]any) {
		m := d.(map[string]any)
		if m["type"] == typ {
			return m["data"].(map[string]any)
		}
	}
	return nil
}

func TestSubmitSinglePostMode(t *testing.T) {
	sf := newSubmitFixture(t, config.SubmitSinglePost)
	appID := sf.prepare(t, "u1", validUSDraft())
	if r := sf.call("u1", "POST", "/api/v1/application/submit", submitBody()); r.Code != 0 {
		t.Fatal(r)
	}
	sf.waitOrch(t, appID)
	if sf.dw.count("POST /users") != 1 || sf.dw.count("PATCH /users/{id}") != 0 {
		t.Fatalf("SINGLE_POST 应只调用一次 POST: %+v", sf.dw.calls)
	}
	if n := len(sf.dw.calls[0].Body["documents"].([]any)); n != 9 {
		t.Fatalf("SINGLE_POST 应包含全部 9 类 documents，实际 %d", n)
	}
	if sf.repo.apps["u1"].OrchState != StateDocsDone {
		t.Fatal("应完成编排")
	}
}

func TestSubmitNonUSUploadsDocuments(t *testing.T) {
	sf := newSubmitFixture(t, config.SubmitPostPatch)
	d := validUSDraft()
	d["citizenship"], d["taxResidency"], d["usTaxPayer"], d["tinType"], d["tin"], d["taxTreaty"] = "SG", "SG", "NO", "FOREIGN_TIN", "S1234567D", "YES"
	d["residentialAddress"] = map[string]any{"line1": "1 Example Road", "city": "Singapore", "postalCode": "000001", "country": "SG"}
	appID := sf.prepare(t, "u1", d)

	// 未上传证件 → 校验失败
	r := sf.call("u1", "POST", "/api/v1/application/submit", submitBody())
	if r.Code != 42200 || !contains(r.fields(), "documents") {
		t.Fatalf("缺证件应 42200 documents: %+v %v", r, r.fields())
	}
	sf.call("u1", "POST", "/api/v1/application/documents", map[string]string{"docType": "NATIONAL_ID_CARD", "side": "FRONT", "image": b64(jpeg)})
	if r := sf.call("u1", "POST", "/api/v1/application/submit", submitBody()); r.Code != 42200 {
		t.Fatalf("身份证缺背面应 42200: %+v", r)
	}
	sf.call("u1", "POST", "/api/v1/application/documents", map[string]string{"docType": "NATIONAL_ID_CARD", "side": "BACK", "image": b64(png)})
	if r := sf.call("u1", "POST", "/api/v1/application/submit", submitBody()); r.Code != 0 {
		t.Fatalf("submit: %+v %v", r, r.fields())
	}
	sf.waitOrch(t, appID)
	if sf.dw.count("POST /documents") != 2 || sf.repo.apps["u1"].OrchState != StateDocsDone {
		t.Fatalf("应上传两面证件: %+v", sf.dw.calls)
	}
	for _, c := range sf.dw.calls {
		if c.Path == "/documents" && (c.Body["userID"] != "dw-user-0001" || c.Body["document"] == "") {
			t.Fatalf("证件请求体不正确: %v", c.Body["userID"])
		}
	}
}

func TestSubmitFailureClassification(t *testing.T) {
	cases := []struct {
		name        string
		failKey     string
		err         error
		wantBlocked bool
		wantState   string
	}{
		{"DW 400 → 转人工", "POST /users", &dwclient.APIError{Status: 400, DWCode: "E_INVALID", Message: "ssn 123-45-6789 invalid"}, true, ""},
		{"DW 503 → 可重试", "POST /users", &dwclient.APIError{Status: 503}, false, ""},
		{"429 → 可重试", "POST /users", &dwclient.APIError{Status: 429}, false, ""},
		{"网络错误 → 可重试", "POST /users", errors.New("connection reset"), false, ""},
		{"PATCH 失败停在 CREATED", "PATCH /users/{id}", &dwclient.APIError{Status: 502}, false, StateCreated},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			sf := newSubmitFixture(t, config.SubmitPostPatch)
			sf.dw.fail[tc.failKey] = []error{tc.err}
			appID := sf.prepare(t, "u1", validUSDraft())
			if r := sf.call("u1", "POST", "/api/v1/application/submit", submitBody()); r.Code != 0 {
				t.Fatal(r)
			}
			sf.waitOrch(t, appID)
			d := sf.orepo.dw[appID]
			if d.blocked != tc.wantBlocked || sf.repo.apps["u1"].OrchState != tc.wantState {
				t.Fatalf("blocked=%v state=%q，期望 %v %q", d.blocked, sf.repo.apps["u1"].OrchState, tc.wantBlocked, tc.wantState)
			}
			if d.lastErr == "" || strings.Contains(d.lastErr, "123-45-6789") {
				t.Fatalf("错误记录应存在且不含 DW 原文: %q", d.lastErr)
			}
			if tc.wantBlocked {
				return
			}
			// 续传：不重复创建 DW User（POST 只在尚未拿到 id 时调用），最终完成
			sf.orch.Run(context.Background(), appID)
			wantPosts := 1
			if tc.failKey == "POST /users" {
				wantPosts = 2 // 第一次失败、第二次成功
			}
			if sf.dw.count("POST /users") != wantPosts || sf.repo.apps["u1"].OrchState != StateDocsDone {
				t.Fatalf("续传后应完成: posts=%d state=%s", sf.dw.count("POST /users"), sf.repo.apps["u1"].OrchState)
			}
			// 两次 POST 使用同一 username（防止超时后重复创建）
			if wantPosts == 2 && sf.dw.calls[0].Body["username"] != sf.dw.calls[1].Body["username"] {
				t.Fatal("重试必须使用同一 username")
			}
		})
	}
}

func TestSubmitValidationErrors(t *testing.T) {
	cases := []struct {
		name   string
		mutate func(d map[string]any, b map[string]any)
		want   string
	}{
		{"签名不一致", func(_, b map[string]any) { b["signatureName"] = "Someone Else" }, "signatureName"},
		{"缺少 DW 披露", func(_, b map[string]any) { b["disclosures"] = allDisclosures()[1:] }, "disclosures.termsOfUse"},
		{"未回答 rule14b", func(_, b map[string]any) { ds := allDisclosures(); b["disclosures"] = ds[:len(ds)-1] }, "disclosures.rule14b"},
		{"未同意 E-Sign", func(_, b map[string]any) {
			ds := allDisclosures()
			for _, x := range ds {
				if x["id"] == "esign" {
					x["accepted"] = false
				}
			}
			b["disclosures"] = ds
		}, "disclosures.esign"},
		{"未成年", func(d, _ map[string]any) { d["dateOfBirth"] = time.Now().AddDate(-17, 0, 0).Format("2006-01-02") }, "dateOfBirth"},
		{"非 ASCII 姓名", func(d, _ map[string]any) { d["firstName"] = "Zoë" }, "firstName"},
		{"P.O. Box", func(d, _ map[string]any) {
			d["residentialAddress"].(map[string]any)["line1"] = "PO Box 123"
		}, "residentialAddress.line1"},
		{"美国地址缺州", func(d, _ map[string]any) { delete(d["residentialAddress"].(map[string]any), "state") }, "residentialAddress.state"},
		{"SSN 格式", func(d, _ map[string]any) { d["tin"] = "12-345" }, "tin"},
		{"SSN 为示例号码", func(d, _ map[string]any) { d["tin"] = "123-45-6789" }, "tin"},
		{"SSN 区号 9xx", func(d, _ map[string]any) { d["tin"] = "912-34-5678" }, "tin"},
		{"SSN 组号 00", func(d, _ map[string]any) { d["tin"] = "234-00-5678" }, "tin"},
		{"美国纳税人选外国税号", func(d, _ map[string]any) { d["tinType"] = "FOREIGN_TIN" }, "tinType"},
		{"未确认税号", func(d, _ map[string]any) { d["tinConfirm"] = false }, "tinConfirm"},
		{"在职缺雇主", func(d, _ map[string]any) { delete(d, "employerName") }, "employerName"},
		{"在职缺行业", func(d, _ map[string]any) { delete(d, "industry") }, "industry"},
		{"职位不在列表", func(d, _ map[string]any) { d["position"] = "ASTRONAUT" }, "position"},
		{"PEP 缺姓名", func(d, _ map[string]any) { d["isPEP"] = true }, "pepName"},
		{"券商关联缺确认", func(d, _ map[string]any) { d["isAffiliatedBD"], d["affiliatedFirmName"] = true, "X Securities" }, "affiliatedAck"},
		{"未回答控制人", func(d, _ map[string]any) { delete(d, "isControlPerson") }, "isControlPerson"},
		{"资金来源为空", func(d, _ map[string]any) { d["fundingSources"] = []string{} }, "fundingSources"},
		{"选项不在列表", func(d, _ map[string]any) { d["riskTolerance"] = "YOLO" }, "riskTolerance"},
		{"手机号格式", func(d, _ map[string]any) { d["phone"] = "abc" }, "phone"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			sf := newSubmitFixture(t, config.SubmitPostPatch)
			d, b := validUSDraft(), submitBody()
			tc.mutate(d, b)
			sf.prepare(t, "u1", d)
			r := sf.call("u1", "POST", "/api/v1/application/submit", b)
			if r.Code != 42200 || !contains(r.fields(), tc.want) {
				t.Fatalf("应 42200 含 %s，实际 %d %v", tc.want, r.Code, r.fields())
			}
			if len(sf.dw.calls) != 0 || sf.repo.apps["u1"].Status != "DRAFT" {
				t.Fatal("校验失败时不应调用 DW 或改变状态")
			}
		})
	}
}

func TestSubmitNoApplicationAndPartnerKYC(t *testing.T) {
	sf := newSubmitFixture(t, config.SubmitPostPatch)
	if r := sf.call("u1", "POST", "/api/v1/application/submit", submitBody()); r.Code != 40901 {
		t.Fatalf("无草稿应 40901: %+v", r)
	}
	sf.svc.kycMode = config.KYCModePartnerKYC
	if r := sf.call("u1", "POST", "/api/v1/application/submit", submitBody()); r.Code != 50003 {
		t.Fatalf("PARTNER_KYC 应 50003: %+v", r)
	}
}

func TestSubmitNotRegisteredWithoutOrchestrator(t *testing.T) {
	f := newFixture(t)
	if r := f.call("u1", "POST", "/api/v1/application/submit", submitBody()); r.HTTP != 404 && r.HTTP != 405 {
		t.Fatalf("未配置编排时不应注册 submit（由服务器统一 50003）: %+v", r)
	}
}

func TestDWCredentials(t *testing.T) {
	seen := map[string]bool{}
	for i := 0; i < 50; i++ {
		u, p, err := newDWCredentials()
		if err != nil {
			t.Fatal(err)
		}
		if seen[u] {
			t.Fatal("用户名重复")
		}
		seen[u] = true
		classes := []string{"abcdefghijklmnopqrstuvwxyz", "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "0123456789", "!@#$%^*-_"}
		for _, c := range classes {
			if !strings.ContainsAny(p, c) {
				t.Fatalf("密码缺少字符类 %q", c)
			}
		}
	}
	ref, _ := newApplicationRef(time.Date(2026, 11, 19, 0, 0, 0, 0, time.UTC))
	if !strings.HasPrefix(ref, "FX261119-") || len(ref) != 17 {
		t.Fatalf("参考号格式: %s", ref)
	}
}

func contains(list []string, s string) bool {
	for _, x := range list {
		if x == s {
			return true
		}
	}
	return false
}
