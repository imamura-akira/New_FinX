package application

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/crypto"
	"github.com/imamura-akira/New_FinX/backend/internal/httpx"
)

// ---------- 内存仓储（草稿部分） ----------

type memDoc struct {
	DocMeta
	appID, ctype string
	enc          []byte
	deleted      bool
}

type memRepo struct {
	mu   sync.Mutex
	apps map[string]*App // by user
	docs []*memDoc
	kyc  map[string]*KYCInfo // by app
	seq  int
}

func newMemRepo() *memRepo {
	return &memRepo{apps: map[string]*App{}, kyc: map[string]*KYCInfo{}}
}

func (m *memRepo) id(p string) string { m.seq++; return fmt.Sprintf("%s-%d", p, m.seq) }

func (m *memRepo) GetByUser(_ context.Context, uid string) (*App, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if a, ok := m.apps[uid]; ok {
		c := *a
		return &c, nil
	}
	return nil, nil
}

func (m *memRepo) EnsureDraft(ctx context.Context, uid string) (*App, error) {
	m.mu.Lock()
	if _, ok := m.apps[uid]; !ok {
		m.apps[uid] = &App{ID: m.id("app"), UserID: uid, Status: "DRAFT"}
	}
	m.mu.Unlock()
	return m.GetByUser(ctx, uid)
}

func (m *memRepo) byID(appID string) *App {
	for _, a := range m.apps {
		if a.ID == appID {
			return a
		}
	}
	return nil
}

func (m *memRepo) SaveDraft(_ context.Context, appID, step string, enc []byte, _ time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	a := m.byID(appID)
	if a == nil || a.Status != "DRAFT" {
		return ErrNotDraft
	}
	a.Step, a.DataEnc = step, enc
	return nil
}

func (m *memRepo) PutDocument(_ context.Context, appID, docType, side, ctype string, enc []byte) (string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, d := range m.docs {
		if d.appID == appID && d.Side == side {
			d.deleted = true
		}
	}
	d := &memDoc{DocMeta: DocMeta{ID: m.id("doc"), DocType: docType, Side: side, UploadedAt: time.Now()}, appID: appID, ctype: ctype, enc: enc}
	m.docs = append(m.docs, d)
	return d.ID, nil
}

func (m *memRepo) ListDocuments(_ context.Context, appID string) ([]DocMeta, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := []DocMeta{}
	for _, d := range m.docs {
		if d.appID == appID && !d.deleted {
			out = append(out, d.DocMeta)
		}
	}
	return out, nil
}

func (m *memRepo) KYC(_ context.Context, appID string) (*KYCInfo, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.kyc[appID], nil
}

// ---------- 测试夹具 ----------

var testKey = bytes.Repeat([]byte{7}, 32)

type fixture struct {
	repo *memRepo
	svc  *Service
	mux  *http.ServeMux
}

// fakeAuth：测试中用 X-Test-User 头模拟已登录用户。
func fakeAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		uid := r.Header.Get("X-Test-User")
		if uid == "" {
			httpx.Fail(w, r, httpx.Unauthorized())
			return
		}
		next.ServeHTTP(w, r.WithContext(httpx.WithUser(r.Context(), uid)))
	})
}

func newFixture(t *testing.T) *fixture {
	t.Helper()
	c, err := crypto.New(testKey)
	if err != nil {
		t.Fatal(err)
	}
	f := &fixture{repo: newMemRepo()}
	f.svc = New(f.repo, c, slog.New(slog.NewTextHandler(io.Discard, nil)))
	f.mux = http.NewServeMux()
	f.svc.Routes(f.mux, "/api/v1", fakeAuth)
	return f
}

type result struct {
	HTTP int
	Code int             `json:"code"`
	Msg  string          `json:"message"`
	Data json.RawMessage `json:"data"`
}

func (f *fixture) call(user, method, path string, body any) result {
	var rd io.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		rd = bytes.NewReader(b)
	}
	req := httptest.NewRequest(method, path, rd)
	req.Header.Set("Content-Type", "application/json")
	if user != "" {
		req.Header.Set("X-Test-User", user)
	}
	rec := httptest.NewRecorder()
	f.mux.ServeHTTP(rec, req)
	var r result
	_ = json.Unmarshal(rec.Body.Bytes(), &r)
	r.HTTP = rec.Code
	return r
}

func (r result) fields() []string {
	var d struct {
		Fields []httpx.FieldError `json:"fields"`
	}
	_ = json.Unmarshal(r.Data, &d)
	var out []string
	for _, f := range d.Fields {
		out = append(out, f.Field)
	}
	return out
}

func getApp(t *testing.T, f *fixture, user string) appView {
	t.Helper()
	r := f.call(user, "GET", "/api/v1/application", nil)
	if r.Code != 0 {
		t.Fatalf("GET /application: %+v", r)
	}
	var v appView
	if err := json.Unmarshal(r.Data, &v); err != nil {
		t.Fatal(err)
	}
	return v
}

func str(raw json.RawMessage) string {
	var s string
	_ = json.Unmarshal(raw, &s)
	return s
}

// ---------- 测试 ----------

func TestGetApplicationNone(t *testing.T) {
	f := newFixture(t)
	v := getApp(t, f, "u1")
	if v.Status != "NONE" || v.ApplicationID != nil || v.KYC != nil || len(v.Data) != 0 {
		t.Fatalf("无申请时应返回 NONE: %+v", v)
	}
	if r := f.call("", "GET", "/api/v1/application", nil); r.HTTP != 401 {
		t.Fatalf("未登录应 401: %+v", r)
	}
}

func TestSaveDraft(t *testing.T) {
	cases := []struct {
		name       string
		body       any
		wantCode   int
		wantFields []string
	}{
		{"合法草稿", map[string]any{"step": "b", "data": map[string]any{"firstName": "Alex", "dateOfBirth": "1990-03-07"}}, 0, nil},
		{"非法步骤", map[string]any{"step": "z", "data": map[string]any{}}, 42200, []string{"step"}},
		{"字段类型错误", map[string]any{"step": "f", "data": map[string]any{"isPEP": "YES"}}, 42200, []string{"isPEP"}},
		{"地址必须是对象", map[string]any{"step": "d", "data": map[string]any{"residentialAddress": "200 Market St"}}, 42200, []string{"residentialAddress"}},
		{"缺少 data 也接受（仅更新步骤）", map[string]any{"step": "c"}, 0, nil},
		{"顶层未知字段", map[string]any{"step": "b", "data": map[string]any{}, "extra": 1}, 42200, nil},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			f := newFixture(t)
			r := f.call("u1", "PUT", "/api/v1/application/draft", tc.body)
			if r.Code != tc.wantCode {
				t.Fatalf("code %d (%s)，期望 %d", r.Code, r.Msg, tc.wantCode)
			}
			if tc.wantFields != nil && strings.Join(r.fields(), ",") != strings.Join(tc.wantFields, ",") {
				t.Fatalf("fields %v，期望 %v", r.fields(), tc.wantFields)
			}
		})
	}
}

func TestDraftMergeMaskAndFixedFields(t *testing.T) {
	f := newFixture(t)
	put := func(step string, data map[string]any) {
		t.Helper()
		if r := f.call("u1", "PUT", "/api/v1/application/draft", map[string]any{"step": step, "data": data}); r.Code != 0 {
			t.Fatalf("PUT: %+v", r)
		}
	}
	put("b", map[string]any{"firstName": "Alex", "lastName": "Chen", "unknownField": "dropped"})
	put("c", map[string]any{"tinType": "SSN", "tin": "123-45-6789", "accountType": "MARGIN_HACK"})

	v := getApp(t, f, "u1")
	if v.Status != "DRAFT" || v.Step == nil || *v.Step != "c" || v.ApplicationID == nil {
		t.Fatalf("状态或步骤不正确: %+v", v)
	}
	if str(v.Data["firstName"]) != "Alex" || str(v.Data["tinType"]) != "SSN" {
		t.Fatalf("浅合并失败: %v", v.Data)
	}
	if _, ok := v.Data["unknownField"]; ok {
		t.Fatal("未知字段应丢弃")
	}
	if got := str(v.Data["tin"]); got != "•••-••-6789" {
		t.Fatalf("税号应打码，实际 %q", got)
	}
	if str(v.Data["accountType"]) != "LIVE" || str(v.Data["tradingType"]) != "CASH" || str(v.Data["accountManagementType"]) != "SELF" {
		t.Fatalf("账户类型应固定为 LIVE/CASH/SELF: %v", v.Data)
	}

	// 客户端回传打码值 → 视为未修改；null → 删除
	put("c", map[string]any{"tin": "•••-••-6789", "lastName": nil})
	st, _ := f.svc.load(f.repo.apps["u1"])
	if str(st.Data["tin"]) != "123-45-6789" {
		t.Fatalf("回传打码值不应覆盖原税号，实际 %q", str(st.Data["tin"]))
	}
	if _, ok := st.Data["lastName"]; ok {
		t.Fatal("null 应删除字段")
	}

	// 库中为密文，不含明文税号
	if bytes.Contains(f.repo.apps["u1"].DataEnc, []byte("6789")) {
		t.Fatal("data_enc 中出现明文")
	}
}

func TestDraftRejectedAfterSubmit(t *testing.T) {
	f := newFixture(t)
	f.call("u1", "PUT", "/api/v1/application/draft", map[string]any{"step": "b", "data": map[string]any{"firstName": "Alex"}})
	f.repo.apps["u1"].Status = "SUBMITTED"
	r := f.call("u1", "PUT", "/api/v1/application/draft", map[string]any{"step": "b", "data": map[string]any{"firstName": "Bob"}})
	if r.HTTP != 409 || r.Code != 40901 {
		t.Fatalf("提交后修改草稿应 40901: %+v", r)
	}
}

func TestUsersAreIsolated(t *testing.T) {
	f := newFixture(t)
	f.call("u1", "PUT", "/api/v1/application/draft", map[string]any{"step": "b", "data": map[string]any{"firstName": "Alex"}})
	if v := getApp(t, f, "u2"); v.Status != "NONE" || len(v.Data) != 0 {
		t.Fatalf("用户之间数据不应可见: %+v", v)
	}
}

var (
	jpeg = append([]byte{0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10, 'J', 'F', 'I', 'F', 0}, bytes.Repeat([]byte{1}, 64)...)
	png  = append([]byte("\x89PNG\r\n\x1a\n"), bytes.Repeat([]byte{1}, 64)...)
)

func b64(b []byte) string { return base64.StdEncoding.EncodeToString(b) }

func TestUploadDocument(t *testing.T) {
	cases := []struct {
		name       string
		body       map[string]string
		wantCode   int
		wantFields []string
	}{
		{"护照 JPG", map[string]string{"docType": "PASSPORT", "side": "FRONT", "image": b64(jpeg)}, 0, nil},
		{"身份证背面 PNG", map[string]string{"docType": "NATIONAL_ID_CARD", "side": "BACK", "image": b64(png)}, 0, nil},
		{"护照背面", map[string]string{"docType": "PASSPORT", "side": "BACK", "image": b64(jpeg)}, 42200, []string{"side"}},
		{"未知证件类型", map[string]string{"docType": "LIBRARY_CARD", "side": "FRONT", "image": b64(jpeg)}, 42200, []string{"docType"}},
		{"非图片", map[string]string{"docType": "PASSPORT", "side": "FRONT", "image": b64([]byte("hello world, not an image"))}, 42200, []string{"image"}},
		{"base64 损坏", map[string]string{"docType": "PASSPORT", "side": "FRONT", "image": "!!!"}, 42200, []string{"image"}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			f := newFixture(t)
			r := f.call("u1", "POST", "/api/v1/application/documents", tc.body)
			if r.Code != tc.wantCode {
				t.Fatalf("code %d (%s)，期望 %d", r.Code, r.Msg, tc.wantCode)
			}
			if tc.wantFields != nil && strings.Join(r.fields(), ",") != strings.Join(tc.wantFields, ",") {
				t.Fatalf("fields %v，期望 %v", r.fields(), tc.wantFields)
			}
		})
	}
}

func TestUploadReplacesSameSideAndEncrypts(t *testing.T) {
	f := newFixture(t)
	f.call("u1", "POST", "/api/v1/application/documents", map[string]string{"docType": "NATIONAL_ID_CARD", "side": "FRONT", "image": b64(jpeg)})
	f.call("u1", "POST", "/api/v1/application/documents", map[string]string{"docType": "NATIONAL_ID_CARD", "side": "FRONT", "image": b64(png)})
	f.call("u1", "POST", "/api/v1/application/documents", map[string]string{"docType": "NATIONAL_ID_CARD", "side": "BACK", "image": b64(jpeg)})
	v := getApp(t, f, "u1")
	if len(v.Documents) != 2 {
		t.Fatalf("每面只保留一份，实际 %d 份", len(v.Documents))
	}
	var active *memDoc
	for _, d := range f.repo.docs {
		if !d.deleted && d.Side == "FRONT" {
			active = d
		}
	}
	if active.ctype != "image/png" || bytes.Contains(active.enc, png[:8]) {
		t.Fatalf("应保存最新影像且加密: ctype=%s", active.ctype)
	}
	pt, err := f.svc.cipher.Decrypt(active.enc, docAAD(active.appID, "FRONT"))
	if err != nil || !bytes.Equal(pt, png) {
		t.Fatalf("解密失败或内容不一致: %v", err)
	}
}

func TestMaskTIN(t *testing.T) {
	cases := []struct{ in, want string }{
		{"123-45-6789", "•••-••-6789"},
		{"123456789", "•••••6789"},
		{"S1234567D", "•••••567D"},
		{"12", "12"},
		{"", ""},
	}
	for _, tc := range cases {
		if got := MaskTIN(tc.in); got != tc.want {
			t.Errorf("MaskTIN(%q) = %q，期望 %q", tc.in, got, tc.want)
		}
	}
}
