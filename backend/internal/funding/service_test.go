package funding

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"sort"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/account"
	"github.com/imamura-akira/New_FinX/backend/internal/config"
	"github.com/imamura-akira/New_FinX/backend/internal/crypto"
	"github.com/imamura-akira/New_FinX/backend/internal/dwclient"
	"github.com/imamura-akira/New_FinX/backend/internal/httpx"
)

// ---------- 内存仓储 ----------

type memRepo struct {
	mu        sync.Mutex
	banks     []Bank
	deleted   map[string]bool
	transfers []Transfer
	seq       int
}

func newMem() *memRepo { return &memRepo{deleted: map[string]bool{}} }

func (m *memRepo) id(p string) string { m.seq++; return fmt.Sprintf("%s-%d", p, m.seq) }

func (m *memRepo) ListBanks(_ context.Context, acc string) ([]Bank, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := []Bank{}
	for _, b := range m.banks {
		if b.AccountID == acc && !m.deleted[b.ID] {
			out = append(out, b)
		}
	}
	return out, nil
}

func (m *memRepo) GetBank(ctx context.Context, acc, id string) (*Bank, error) {
	list, _ := m.ListBanks(ctx, acc)
	for _, b := range list {
		if b.ID == id {
			return &b, nil
		}
	}
	return nil, ErrNotFound
}

func (m *memRepo) InsertBank(_ context.Context, b Bank) (string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	b.ID, b.CreatedAt = m.id("bank"), time.Now()
	m.banks = append(m.banks, b)
	return b.ID, nil
}

func (m *memRepo) DeleteBank(_ context.Context, id string, _ time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.deleted[id] = true
	return nil
}

func (m *memRepo) HasInFlight(_ context.Context, bankID string) (bool, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, t := range m.transfers {
		if t.BankAccountID != nil && *t.BankAccountID == bankID && t.Status != "SUCCESSFUL" && !Terminal(t.Status) {
			return true, nil
		}
	}
	return false, nil
}

func (m *memRepo) InsertTransfer(_ context.Context, t Transfer) (string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	t.ID, t.SubmittedAt = m.id("tr"), time.Now().Add(time.Duration(m.seq)*time.Millisecond)
	t.AmountJSON = json.Number(t.Amount)
	if t.BankAccountID != nil {
		for _, b := range m.banks {
			if b.ID == *t.BankAccountID {
				t.DWBankID = b.DWBankID
			}
		}
	}
	m.transfers = append(m.transfers, t)
	return t.ID, nil
}

func (m *memRepo) find(id string) *Transfer {
	for i := range m.transfers {
		if m.transfers[i].ID == id {
			return &m.transfers[i]
		}
	}
	return nil
}

func (m *memRepo) SetSubmitted(_ context.Context, id, ref, st string, _ time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	t := m.find(id)
	t.DWRef, t.Status = ref, st
	return nil
}

func (m *memRepo) DeleteTransfer(_ context.Context, id string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	for i, t := range m.transfers {
		if t.ID == id {
			m.transfers = append(m.transfers[:i], m.transfers[i+1:]...)
			break
		}
	}
	return nil
}

func (m *memRepo) RecentDuplicate(_ context.Context, acc, typ, amount string, bankID *string, since time.Time) (bool, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, t := range m.transfers {
		sameBank := (t.BankAccountID == nil && bankID == nil) || (t.BankAccountID != nil && bankID != nil && *t.BankAccountID == *bankID)
		if t.AccountID == acc && t.Type == typ && t.Amount == amount && sameBank && !t.SubmittedAt.Before(since) && !Terminal(t.Status) {
			return true, nil
		}
	}
	return false, nil
}

func (m *memRepo) SumDeposits(_ context.Context, acc string, since time.Time) (string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var c int64
	for _, t := range m.transfers {
		if t.AccountID == acc && t.Type == "DEPOSIT" && !t.SubmittedAt.Before(since) && !Terminal(t.Status) {
			c += parseCents(t.Amount)
		}
	}
	return Cents(c), nil
}

func (m *memRepo) ListTransfers(_ context.Context, acc, typ string, before *time.Time, limit int) ([]Transfer, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := []Transfer{}
	for _, t := range m.transfers {
		if t.AccountID == acc && (typ == "" || t.Type == typ) && (before == nil || t.SubmittedAt.Before(*before)) {
			out = append(out, t)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].SubmittedAt.After(out[j].SubmittedAt) })
	if len(out) > limit {
		out = out[:limit]
	}
	return out, nil
}

func (m *memRepo) DueTransfers(context.Context, time.Time, time.Time, int) ([]Transfer, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var out []Transfer
	for _, t := range m.transfers {
		if !Terminal(t.Status) {
			t.DWAccountNo = "TEST000001"
			out = append(out, t)
		}
	}
	return out, nil
}

func (m *memRepo) UpdateTransfer(_ context.Context, id, st string, reason *string, done *time.Time, _ time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	t := m.find(id)
	t.Status, t.FailureReason = st, reason
	if done != nil {
		t.DoneAt = done
	}
	return nil
}

func (m *memRepo) TouchTransfer(context.Context, string, time.Time) error { return nil }

func (m *memRepo) SetAvailability(_ context.Context, id string, bp, wd *time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	t := m.find(id)
	t.BuyingPowerAt, t.WithdrawableAt = bp, wd
	return nil
}
func (m *memRepo) Audit(context.Context, string, string, string, map[string]any) error {
	return nil
}

// ---------- 假 DW ----------

type dwCall struct {
	method, path, idem string
	body               map[string]any
}

type fakeDW struct {
	mu    sync.Mutex
	calls []dwCall
	fail  map[string][]error // "METHOD /path-prefix"
	resp  map[string]string  // "METHOD /path-prefix" → JSON
}

func (f *fakeDW) Do(ctx context.Context, method, path string, body, out any) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	var m map[string]any
	raw, _ := json.Marshal(body)
	_ = json.Unmarshal(raw, &m)
	f.calls = append(f.calls, dwCall{method, path, dwclient.IdempotencyKey(ctx), m})
	key := method + " " + path
	for k, errs := range f.fail {
		if strings.HasPrefix(key, k) && len(errs) > 0 {
			f.fail[k] = errs[1:]
			if errs[0] != nil {
				return errs[0]
			}
		}
	}
	for k, js := range f.resp {
		if strings.HasPrefix(key, k) && out != nil {
			return json.Unmarshal([]byte(js), out)
		}
	}
	return nil
}

func (f *fakeDW) last(prefix string) *dwCall {
	f.mu.Lock()
	defer f.mu.Unlock()
	for i := len(f.calls) - 1; i >= 0; i-- {
		if strings.HasPrefix(f.calls[i].method+" "+f.calls[i].path, prefix) {
			return &f.calls[i]
		}
	}
	return nil
}

func (f *fakeDW) count(prefix string) int {
	f.mu.Lock()
	defer f.mu.Unlock()
	n := 0
	for _, c := range f.calls {
		if strings.HasPrefix(c.method+" "+c.path, prefix) {
			n++
		}
	}
	return n
}

// ---------- 夹具 ----------

type fx struct {
	svc  *Service
	repo *memRepo
	dw   *fakeDW
	mux  *http.ServeMux
	acct *account.Account
}

const moneyJSON = `{"accountNo":"TEST000001","updated":"2026-11-19T13:00:00Z","cash":{"cashAvailableForTrade":1000.5,"cashAvailableForWithdrawal":250.25,"cashBalance":1300.5,"cashPendingSettlement":300},"payments":{"buyingPower":{"pendingDepositsAmountNotAvailable":300},"redemptions":{"amountWithheldFromRedemptions":50}}}`

func newFx(t *testing.T) *fx {
	t.Helper()
	c, _ := crypto.New(bytes.Repeat([]byte{3}, 32))
	f := &fx{repo: newMem(), dw: &fakeDW{fail: map[string][]error{}, resp: map[string]string{
		"POST /bank-accounts":       `{"id":"bank_test1","status":"ACTIVE","bankAccountDetails":{"bankAccountNumber":"****6789","bankName":"Test Bank"}}`,
		"POST /funding/deposits":    `{"id":"DEP-1","status":{"id":1,"message":"PENDING"}}`,
		"POST /funding/redemptions": `{"id":"RED-1","status":{"name":"PENDING"}}`,
		"GET /accounts/":            moneyJSON,
	}}}
	f.acct = &account.Account{ID: "acc-1", DWAccountID: "dwacc-1", DWUserID: "dwuser-1", AccountNo: "TEST000001", Status: "OPEN"}
	f.svc = New(Deps{
		Repo: f.repo, DW: f.dw, Cipher: c,
		Account:   func(context.Context, string) (*account.Account, error) { return f.acct, nil },
		LegalName: func(context.Context, string) (string, error) { return "Demo Tester", nil },
		Limits:    config.Limits{MinDeposit: 10, MaxDeposit: 50000, DailyDeposit: 60000, MinWithdrawal: 1, MaxWithdrawal: 50000, MinWire: 100, MaxBanks: 2},
		BankLink:  config.BankLinkDirect,
		Logger:    slog.New(slog.NewTextHandler(io.Discard, nil)),
	})
	f.mux = http.NewServeMux()
	f.svc.Routes(f.mux, "/api/v1", func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			next.ServeHTTP(w, r.WithContext(httpx.WithUser(r.Context(), "u1")))
		})
	})
	return f
}

type res struct {
	HTTP   int
	Header http.Header
	Code   int             `json:"code"`
	Msg    string          `json:"message"`
	Data   json.RawMessage `json:"data"`
}

func (f *fx) call(method, path, body string) res {
	var rd io.Reader
	if body != "" {
		rd = strings.NewReader(body)
	}
	req := httptest.NewRequest(method, path, rd)
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	f.mux.ServeHTTP(rec, req)
	var r res
	_ = json.Unmarshal(rec.Body.Bytes(), &r)
	r.HTTP, r.Header = rec.Code, rec.Header()
	return r
}

func (r res) fields() string {
	var d struct{ Fields []httpx.FieldError }
	_ = json.Unmarshal(r.Data, &d)
	var out []string
	for _, f := range d.Fields {
		out = append(out, f.Field)
	}
	return strings.Join(out, ",")
}

func (f *fx) link(t *testing.T) string {
	t.Helper()
	r := f.call("POST", "/api/v1/funding/bank-accounts", `{"accountNumber":"000123456789","routingNumber":"021000021","type":"CHECKING","nickname":"Main"}`)
	if r.Code != 0 {
		t.Fatalf("link: %+v", r)
	}
	var d struct{ ID string }
	_ = json.Unmarshal(r.Data, &d)
	return d.ID
}

// ---------- 测试 ----------

func TestParseAmount(t *testing.T) {
	cases := []struct {
		in    string
		cents int64
		ok    bool
	}{
		{"10", 1000, true}, {"0.01", 1, true}, {"100.5", 10050, true}, {"49999.99", 4999999, true},
		{"10.005", 0, false}, {"0", 0, false}, {"-5", 0, false}, {"1e3", 0, false}, {"abc", 0, false}, {"", 0, false},
	}
	for _, tc := range cases {
		c, err := ParseAmount(json.Number(tc.in))
		if (err == nil) != tc.ok || c != tc.cents {
			t.Errorf("ParseAmount(%q) = %d, %v", tc.in, c, err)
		}
	}
}

func TestValidABA(t *testing.T) {
	for in, want := range map[string]bool{"021000021": true, "011000015": true, "123456789": false, "02100002": false, "02100002a": false} {
		if ValidABA(in) != want {
			t.Errorf("ValidABA(%s) != %v", in, want)
		}
	}
}

func TestStatusOf(t *testing.T) {
	cases := []struct {
		in   any
		want string
	}{
		{map[string]any{"id": 1.0, "message": "PENDING"}, "PENDING"},
		{map[string]any{"id": 2.0}, "SUCCESSFUL"},
		{map[string]any{"name": "On_Hold"}, "ON_HOLD"},
		{map[string]any{"id": 17.0, "message": "Processing", "updated": "2026-11-19T13:18:00Z"}, "PROCESSING"},
		{map[string]any{"id": 17.0}, "PROCESSING"},
		{"approved", "APPROVED"},
		{nil, ""},
	}
	for _, tc := range cases {
		if got := statusOf(tc.in); got != tc.want {
			t.Errorf("statusOf(%v) = %q，期望 %q", tc.in, got, tc.want)
		}
	}
}

func TestLinkBank(t *testing.T) {
	cases := []struct {
		name      string
		body      string
		setup     func(f *fx)
		wantCode  int
		wantField string
	}{
		{"成功", `{"accountNumber":"0001-2345-6789","routingNumber":"021000021","type":"CHECKING","nickname":"Main"}`, nil, 0, ""},
		{"路由号校验和错误", `{"accountNumber":"000123456789","routingNumber":"123456789","type":"CHECKING"}`, nil, 42200, "routingNumber"},
		{"账号过短", `{"accountNumber":"12","routingNumber":"021000021","type":"SAVINGS"}`, nil, 42200, "accountNumber"},
		{"类型非法", `{"accountNumber":"000123456789","routingNumber":"021000021","type":"BROKERAGE"}`, nil, 42200, "type"},
		{"备注名等于账号", `{"accountNumber":"000123456789","routingNumber":"021000021","type":"CHECKING","nickname":"000123456789"}`, nil, 42200, "nickname"},
		{"客户端不得指定户名", `{"accountNumber":"000123456789","routingNumber":"021000021","type":"CHECKING","ownerName":"Someone Else"}`, nil, 42200, ""},
		{"Plaid 未开通", `{"plaidProcessorToken":"x"}`, func(f *fx) { f.svc.BankLink = config.BankLinkPlaid }, 50003, ""},
		{"账户冻结", `{"accountNumber":"000123456789","routingNumber":"021000021","type":"CHECKING"}`, func(f *fx) { f.acct.Status = "FROZEN" }, 40301, ""},
		{"尚未开户", `{"accountNumber":"000123456789","routingNumber":"021000021","type":"CHECKING"}`, func(f *fx) { f.acct = nil }, 40901, ""},
		{"DW 拒绝", `{"accountNumber":"000123456789","routingNumber":"021000021","type":"CHECKING"}`, func(f *fx) {
			f.dw.fail["POST /bank-accounts"] = []error{&dwclient.APIError{Status: 400, DWCode: "E032"}}
		}, 42200, ""},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			f := newFx(t)
			if tc.setup != nil {
				tc.setup(f)
			}
			r := f.call("POST", "/api/v1/funding/bank-accounts", tc.body)
			if r.Code != tc.wantCode || (tc.wantField != "" && r.fields() != tc.wantField) {
				t.Fatalf("code=%d fields=%s msg=%s，期望 %d %s", r.Code, r.fields(), r.Msg, tc.wantCode, tc.wantField)
			}
			if tc.wantCode != 0 {
				if len(f.repo.banks) != 0 {
					t.Fatal("失败时不应落库")
				}
				return
			}
			c := f.dw.last("POST /bank-accounts")
			if c.body["bankAccountNumber"] != "000123456789" || c.body["userID"] != "dwuser-1" ||
				c.body["beneficiaryDetails"].(map[string]any)["accountHolderName"] != "Demo Tester" {
				t.Fatalf("DW 请求体不正确（户名须为开户姓名）: %v", c.body["beneficiaryDetails"])
			}
			b := f.repo.banks[0]
			if b.Mask != "6789" || b.OwnerName != "Demo Tester" || b.DWBankID != "bank_test1" || b.BankName != "Test Bank" {
				t.Fatalf("落库不正确: %+v", b)
			}
			list := f.call("GET", "/api/v1/funding/bank-accounts", "")
			if strings.Contains(string(list.Data), "000123456789") || strings.Contains(string(list.Data), "bank_test1") {
				t.Fatal("列表不应返回完整账号或 DW 内部 id")
			}
		})
	}
}

func TestLinkBankMaxBanks(t *testing.T) {
	f := newFx(t)
	f.link(t)
	f.link(t)
	if r := f.call("POST", "/api/v1/funding/bank-accounts", `{"accountNumber":"000123456789","routingNumber":"021000021","type":"CHECKING"}`); r.Code != 40901 {
		t.Fatalf("超过绑卡上限应 40901: %+v", r)
	}
}

func TestDeposit(t *testing.T) {
	cases := []struct {
		name     string
		amount   string
		setup    func(f *fx)
		wantCode int
	}{
		{"成功", `100.25`, nil, 0},
		{"低于最低", `9.99`, nil, 42201},
		{"高于单笔上限", `50000.01`, nil, 42201},
		{"超过两位小数", `10.005`, nil, 42200},
		{"金额为字符串", `"100"`, nil, 42200},
		{"超过每日限额", `40000`, func(f *fx) {
			bank := f.repo.banks[0].ID
			f.repo.transfers = append(f.repo.transfers, Transfer{ID: "old", AccountID: "acc-1", BankAccountID: &bank, Type: "DEPOSIT", Amount: "30000.00", Status: "PENDING", SubmittedAt: time.Now()})
		}, 42201},
		{"已失败的入金不占每日额度", `40000`, func(f *fx) {
			f.repo.transfers = append(f.repo.transfers, Transfer{ID: "old", AccountID: "acc-1", Type: "DEPOSIT", Amount: "30000.00", Status: "FAILED", SubmittedAt: time.Now()})
		}, 0},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			f := newFx(t)
			bank := f.link(t)
			if tc.setup != nil {
				tc.setup(f)
			}
			r := f.call("POST", "/api/v1/funding/deposits", `{"bankAccountId":"`+bank+`","amount":`+tc.amount+`}`)
			if r.Code != tc.wantCode {
				t.Fatalf("code=%d msg=%s，期望 %d", r.Code, r.Msg, tc.wantCode)
			}
			if tc.wantCode != 0 {
				if f.dw.count("POST /funding/deposits") != 0 {
					t.Fatal("校验失败时不应调用 DW")
				}
				return
			}
			c := f.dw.last("POST /funding/deposits")
			if c.idem == "" || c.body["type"] != "ACH" || c.body["currency"] != "USD" || c.body["accountNo"] != "TEST000001" || c.body["bankAccountID"] != "bank_test1" {
				t.Fatalf("DW 请求不正确: idem=%q %v", c.idem, c.body)
			}
			var d struct{ TransferID, Status string }
			_ = json.Unmarshal(r.Data, &d)
			if d.Status != "PENDING" {
				t.Fatalf("状态 %s", d.Status)
			}
		})
	}
}

func TestDepositOtherUsersBankAndDuplicate(t *testing.T) {
	f := newFx(t)
	bank := f.link(t)
	f.repo.banks = append(f.repo.banks, Bank{ID: "bank-other", AccountID: "acc-OTHER", DWBankID: "bank_x"})
	if r := f.call("POST", "/api/v1/funding/deposits", `{"bankAccountId":"bank-other","amount":100}`); r.Code != 42200 || r.fields() != "bankAccountId" {
		t.Fatalf("他人银行账户应拒绝: %+v", r)
	}
	if r := f.call("POST", "/api/v1/funding/deposits", `{"bankAccountId":"`+bank+`","amount":100}`); r.Code != 0 {
		t.Fatal(r)
	}
	if r := f.call("POST", "/api/v1/funding/deposits", `{"bankAccountId":"`+bank+`","amount":100}`); r.Code != 40901 {
		t.Fatalf("60 秒内重复提交应 40901: %+v", r)
	}
	if f.dw.count("POST /funding/deposits") != 1 {
		t.Fatal("重复提交不应再次调用 DW")
	}
}

func TestDepositDWFailures(t *testing.T) {
	// DW 明确拒绝：撤销本地记录
	f := newFx(t)
	bank := f.link(t)
	f.dw.fail["POST /funding/deposits"] = []error{&dwclient.APIError{Status: 400, DWCode: "E1"}}
	if r := f.call("POST", "/api/v1/funding/deposits", `{"bankAccountId":"`+bank+`","amount":100}`); r.Code != 42200 || len(f.repo.transfers) != 0 {
		t.Fatalf("DW 4xx 应 42200 且不留记录: %+v %d", r, len(f.repo.transfers))
	}

	// 结果不明：保留 SUBMITTING，对账时用同一幂等键重放
	f = newFx(t)
	bank = f.link(t)
	f.dw.fail["POST /funding/deposits"] = []error{fmt.Errorf("timeout")}
	r := f.call("POST", "/api/v1/funding/deposits", `{"bankAccountId":"`+bank+`","amount":100}`)
	if r.Code != 50001 || len(f.repo.transfers) != 1 || f.repo.transfers[0].Status != StatusSubmitting {
		t.Fatalf("结果不明应 50001 并保留记录: %+v", r)
	}
	firstKey := f.dw.last("POST /funding/deposits").idem
	f.svc.Sync(context.Background(), time.Minute)
	if f.dw.count("POST /funding/deposits") != 2 || f.dw.last("POST /funding/deposits").idem != firstKey {
		t.Fatal("对账重放必须使用同一个 Idempotency-Key")
	}
	if tr := f.repo.transfers[0]; tr.Status != "PENDING" || tr.DWRef != "DEP-1" {
		t.Fatalf("重放后应记录 DW 编号与状态: %+v", tr)
	}
}

func TestWithdrawal(t *testing.T) {
	cases := []struct {
		name     string
		body     func(bank string) string
		setup    func(f *fx)
		wantCode int
		check    func(t *testing.T, f *fx)
	}{
		{"ACH 成功", func(b string) string { return `{"method":"ACH","amount":100,"bankAccountId":"` + b + `"}` }, nil, 0, func(t *testing.T, f *fx) {
			c := f.dw.last("POST /funding/redemptions")
			if c.body["type"] != "ACH" || c.body["bankAccountID"] != "bank_test1" || c.idem != "" {
				t.Fatalf("ACH 出金请求不正确（出金不附带幂等键）: %v idem=%q", c.body, c.idem)
			}
		}},
		{"超过可提现金额（DW 返回 250.25）", func(b string) string { return `{"method":"ACH","amount":250.26,"bankAccountId":"` + b + `"}` }, nil, 42201, func(t *testing.T, f *fx) {
			if f.dw.count("POST /funding/redemptions") != 0 {
				t.Fatal("超额不应提交")
			}
		}},
		{"恰好等于可提现金额", func(b string) string { return `{"method":"ACH","amount":250.25,"bankAccountId":"` + b + `"}` }, nil, 0, nil},
		{"WIRE 收款人强制为开户姓名", func(string) string {
			return `{"method":"WIRE","amount":150,"wire":{"bankName":"Example Bank","accountNumber":"GB00TEST0000000001","swiftOrAba":"EXAMGB2L","country":"GBR"}}`
		}, nil, 0, func(t *testing.T, f *fx) {
			d := f.dw.last("POST /funding/redemptions").body["details"].(map[string]any)
			if d["beneficiaryName"] != "Demo Tester" || d["beneficiarySwiftABA"] != "EXAMGB2L" {
				t.Fatalf("WIRE 收款信息不正确: %v", d)
			}
			if bytes.Contains(f.repo.transfers[0].WireEnc, []byte("GB00TEST")) {
				t.Fatal("收款账号应加密保存")
			}
		}},
		{"客户端试图指定 WIRE 收款人", func(string) string {
			return `{"method":"WIRE","amount":150,"wire":{"beneficiaryName":"Someone Else","bankName":"B","accountNumber":"123456","swiftOrAba":"021000021","country":"USA"}}`
		}, nil, 42200, nil},
		{"WIRE 低于电汇最低额", func(string) string {
			return `{"method":"WIRE","amount":50,"wire":{"bankName":"B","accountNumber":"123456","swiftOrAba":"021000021","country":"USA"}}`
		}, nil, 42201, nil},
		{"WIRE 缺 SWIFT", func(string) string {
			return `{"method":"WIRE","amount":150,"wire":{"bankName":"B","accountNumber":"123456","swiftOrAba":"x","country":"USA"}}`
		}, nil, 42200, nil},
		{"方式非法", func(string) string { return `{"method":"PAYPAL","amount":10}` }, nil, 42200, nil},
		{"ACH 缺银行账户", func(string) string { return `{"method":"ACH","amount":10}` }, nil, 42200, nil},
		{"仅可卖出的账户仍可出金", func(b string) string { return `{"method":"ACH","amount":10,"bankAccountId":"` + b + `"}` }, func(f *fx) { f.acct.Status = "OPEN_NO_NEW_TRADES" }, 0, nil},
		{"关闭的账户不可出金", func(b string) string { return `{"method":"ACH","amount":10,"bankAccountId":"` + b + `"}` }, func(f *fx) { f.acct.Status = "CLOSED" }, 40301, nil},
		{"DW 资金汇总失败", func(b string) string { return `{"method":"ACH","amount":10,"bankAccountId":"` + b + `"}` }, func(f *fx) {
			f.dw.fail["GET /accounts/"] = []error{fmt.Errorf("timeout")}
		}, 50001, nil},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			f := newFx(t)
			bank := f.link(t)
			if tc.setup != nil {
				tc.setup(f)
			}
			r := f.call("POST", "/api/v1/funding/withdrawals", tc.body(bank))
			if r.Code != tc.wantCode {
				t.Fatalf("code=%d fields=%s msg=%s，期望 %d", r.Code, r.fields(), r.Msg, tc.wantCode)
			}
			if tc.check != nil {
				tc.check(t, f)
			}
		})
	}
}

func TestDeleteBank(t *testing.T) {
	f := newFx(t)
	bank := f.link(t)
	f.call("POST", "/api/v1/funding/deposits", `{"bankAccountId":"`+bank+`","amount":100}`)
	if r := f.call("DELETE", "/api/v1/funding/bank-accounts/"+bank, ""); r.Code != 40901 {
		t.Fatalf("有在途入金时应 40901: %+v", r)
	}
	f.repo.transfers[0].Status = "SUCCESSFUL"
	if r := f.call("DELETE", "/api/v1/funding/bank-accounts/"+bank, ""); r.Code != 0 {
		t.Fatalf("解绑: %+v", r)
	}
	if c := f.dw.last("DELETE /bank-accounts/"); c == nil || c.path != "/bank-accounts/bank_test1" {
		t.Fatal("应调用 DW 解绑")
	}
	if r := f.call("DELETE", "/api/v1/funding/bank-accounts/"+bank, ""); r.Code != 40901 {
		t.Fatal("重复解绑应 40901")
	}
}

func TestTransfersAndMoney(t *testing.T) {
	f := newFx(t)
	bank := f.link(t)
	f.call("POST", "/api/v1/funding/deposits", `{"bankAccountId":"`+bank+`","amount":100}`)
	f.call("POST", "/api/v1/funding/withdrawals", `{"method":"ACH","amount":20,"bankAccountId":"`+bank+`"}`)
	r := f.call("GET", "/api/v1/funding/transfers", "")
	var list []Transfer
	_ = json.Unmarshal(r.Data, &list)
	if len(list) != 2 || list[0].Type != "WITHDRAWAL" || list[1].AmountJSON != "100.00" {
		t.Fatalf("资金记录不正确（应按时间倒序）: %+v", list)
	}
	r = f.call("GET", "/api/v1/funding/transfers?type=DEPOSIT", "")
	_ = json.Unmarshal(r.Data, &list)
	if len(list) != 1 || list[0].Type != "DEPOSIT" {
		t.Fatalf("类型过滤: %+v", list)
	}
	if r := f.call("GET", "/api/v1/funding/transfers?type=X", ""); r.Code != 42200 {
		t.Fatal("非法类型应 42200")
	}

	if !strings.Contains(string(r.Data), `"amount":100.00`) && !strings.Contains(string(f.call("GET", "/api/v1/funding/transfers?type=DEPOSIT", "").Data), `"amount":100.00`) {
		t.Fatal("金额应输出为 JSON number")
	}
	r = f.call("GET", "/api/v1/account/money", "")
	if strings.Contains(string(r.Data), `"cash":"`) {
		t.Fatalf("资金汇总金额应为 JSON number: %s", r.Data)
	}
	var m Money
	_ = json.Unmarshal(r.Data, &m)
	if m.Cash != "1300.50" || m.SettledCash != "1000.50" || m.BuyingPower != "1000.50" || m.CashAvailableForWithdrawal != "250.25" ||
		m.Unsettled != "300.00" || m.PendingDeposits != "300.00" || m.WithheldForSeasoning != "50.00" || m.UpdatedAt == nil {
		t.Fatalf("资金汇总映射不正确: %+v", m)
	}
}

func TestSyncUpdatesStatus(t *testing.T) {
	f := newFx(t)
	bank := f.link(t)
	f.call("POST", "/api/v1/funding/deposits", `{"bankAccountId":"`+bank+`","amount":100}`)
	// 沙盒实测结构：status 带 comment，seasoningDetails 给出购买力与可提现日期
	f.dw.resp["GET /funding/deposits/"] = `{"id":"DEP-1","status":{"comment":"MMW Open. Moving to Successful","id":2,"message":"Successful"},` +
		`"seasoningDetails":{"depositBuyingPowerHoldExpires":"2026-11-23T00:00:00Z","seasoningPeriodExpires":"2026-11-23T00:00:00Z","status":6,"statusMessage":"AWAITING_BUYING_POWER"}}`
	f.svc.Sync(context.Background(), time.Minute)
	tr := f.repo.transfers[0]
	if tr.Status != "SUCCESSFUL" || tr.DoneAt == nil || tr.FailureReason != nil {
		t.Fatalf("应更新为 SUCCESSFUL: %+v", tr)
	}
	if tr.WithdrawableAt == nil || tr.WithdrawableAt.Format("2006-01-02") != "2026-11-23" || tr.BuyingPowerAt == nil {
		t.Fatalf("应记录 DW 返回的可用日期: %+v", tr)
	}
	f.dw.resp["GET /funding/deposits/"] = `{"id":"DEP-1","status":{"id":5,"message":"RETURNED"}}`
	f.svc.Sync(context.Background(), time.Minute)
	if tr := f.repo.transfers[0]; tr.Status != "RETURNED" || tr.FailureReason == nil || !strings.Contains(*tr.FailureReason, "退回") {
		t.Fatalf("成功后被退回应更新并给出中文原因: %+v", tr)
	}
}
