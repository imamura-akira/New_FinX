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

// memRepo：内存仓储，语义与 PGRepo 保持一致（审计 TEST-P1-2：删除保护、对账节流 / 退回窗口 / 条数上限、终态口径）。
type memRepo struct {
	mu        sync.Mutex
	banks     []Bank
	deleted   map[string]bool
	transfers []Transfer
	checked   map[string]time.Time // 对应 PG 的 checked_at
	seq       int
}

func newMem() *memRepo { return &memRepo{deleted: map[string]bool{}, checked: map[string]time.Time{}} }

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
	for _, x := range m.transfers {
		if x.IdempotencyKey == t.IdempotencyKey {
			return "", fmt.Errorf("duplicate key value violates unique constraint \"transfers_idempotency_key_key\"")
		}
	}
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

func (m *memRepo) SetSubmitted(_ context.Context, id, ref, st string, now time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	t := m.find(id)
	t.DWRef, t.Status = ref, st
	m.checked[id] = now
	return nil
}

func (m *memRepo) DeleteTransfer(_ context.Context, id string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	for i, t := range m.transfers {
		if t.ID == id && t.DWRef == "" { // 同 PG：WHERE dw_ref IS NULL
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

func (m *memRepo) DueTransfers(_ context.Context, checkedBefore, successSince time.Time, limit int) ([]Transfer, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var out []Transfer
	for _, t := range m.transfers {
		done := t.SubmittedAt
		if t.DoneAt != nil {
			done = *t.DoneAt
		}
		c, seen := m.checked[t.ID]
		if !Terminal(t.Status) && !(t.Status == "SUCCESSFUL" && done.Before(successSince)) && (!seen || c.Before(checkedBefore)) && len(out) < limit {
			t.DWAccountNo, t.DWAccountID = "TEST000001", "dwacc-1"
			out = append(out, t)
		}
	}
	return out, nil
}

func (m *memRepo) UpdateTransfer(_ context.Context, id, st string, reason *string, done *time.Time, now time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	t := m.find(id)
	t.Status, t.FailureReason = st, reason
	m.checked[id] = now
	if done != nil {
		t.DoneAt = done
	}
	return nil
}

func (m *memRepo) TouchTransfer(_ context.Context, id string, now time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.checked[id] = now
	return nil
}

func (m *memRepo) TransferByIdemKey(_ context.Context, acc, key string) (*Transfer, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, t := range m.transfers {
		if t.AccountID == acc && t.IdempotencyKey == key {
			c := t
			return &c, nil
		}
	}
	return nil, ErrNotFound
}

func (m *memRepo) DWRefUsed(_ context.Context, ref string) (bool, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, t := range m.transfers {
		if t.DWRef == ref {
			return true, nil
		}
	}
	return false, nil
}

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
	canceled           bool // 调用时 context 是否已取消（审计 FUND-P1-3）
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
	f.calls = append(f.calls, dwCall{method, path, dwclient.IdempotencyKey(ctx), m, ctx.Err() != nil})
	key := method + " " + path
	for k, errs := range f.fail {
		if strings.HasPrefix(key, k) && len(errs) > 0 {
			f.fail[k] = errs[1:]
			if errs[0] != nil {
				return errs[0]
			}
		}
	}
	best := "" // 最长前缀优先（如 GET /accounts/x/funding/deposits 优先于 GET /accounts/）
	for k := range f.resp {
		if strings.HasPrefix(key, k) && len(k) > len(best) {
			best = k
		}
	}
	if best != "" && out != nil {
		return json.Unmarshal([]byte(f.resp[best]), out)
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

func (f *fx) call(method, path, body string) res { return f.callKey(method, path, body, "") }

// callKey：带 App 幂等键（Idempotency-Key 头）调用。
func (f *fx) callKey(method, path, body, key string) res {
	var rd io.Reader
	if body != "" {
		rd = strings.NewReader(body)
	}
	req := httptest.NewRequest(method, path, rd)
	req.Header.Set("Content-Type", "application/json")
	if key != "" {
		req.Header.Set("Idempotency-Key", key)
	}
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
	if f.dw.count("POST /funding/deposits") != 1 {
		t.Fatal("提交后 1 分钟内不应重放（首次提交可能仍在进行中）")
	}
	f.svc.now = func() time.Time { return time.Now().Add(2 * time.Minute) }
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
			if c.body["type"] != "ACH" || c.body["bankAccountID"] != "bank_test1" || c.idem == "" || c.idem != f.repo.transfers[0].IdempotencyKey {
				t.Fatalf("ACH 出金请求不正确（须附带已落库的幂等键，审计 FUND-P1-2）: %v idem=%q", c.body, c.idem)
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
	f.svc.now = func() time.Time { return time.Now().Add(time.Minute) } // 同 PG：刚提交的记录 30 秒内不重复对账
	f.svc.Sync(context.Background(), time.Minute)
	tr := f.repo.transfers[0]
	if tr.Status != "SUCCESSFUL" || tr.DoneAt == nil || tr.FailureReason != nil {
		t.Fatalf("应更新为 SUCCESSFUL: %+v", tr)
	}
	if tr.WithdrawableAt == nil || tr.WithdrawableAt.Format("2006-01-02") != "2026-11-23" || tr.BuyingPowerAt == nil {
		t.Fatalf("应记录 DW 返回的可用日期: %+v", tr)
	}
	f.dw.resp["GET /funding/deposits/"] = `{"id":"DEP-1","status":{"id":5,"message":"RETURNED"}}`
	f.svc.now = func() time.Time { return time.Now().Add(2 * time.Minute) }
	f.svc.Sync(context.Background(), time.Minute)
	if tr := f.repo.transfers[0]; tr.Status != "RETURNED" || tr.FailureReason == nil || !strings.Contains(*tr.FailureReason, "退回") {
		t.Fatalf("成功后被退回应更新并给出中文原因: %+v", tr)
	}
}

// 2026-11-21 沙盒实测缺陷回归：首次提交超时期间对账并发重放得到 IK075，后端误判为拒绝并删除本地记录，
// 而 DW 实际已创建入金。
func TestDepositIdempotencyErrorIsUnknown(t *testing.T) {
	ik := &dwclient.APIError{Status: 404, DWCode: "IK075", Message: "Could not retrieve cached response for this idempotency key."}
	cases := []struct {
		name     string
		err      error
		wantCode int
		keep     bool
	}{
		{"IK075 结果不明：保留记录", ik, 50001, true},
		{"其他幂等错误同样不明", &dwclient.APIError{Status: 409, DWCode: "IK070"}, 50001, true},
		{"普通 4xx 仍为明确拒绝", &dwclient.APIError{Status: 400, DWCode: "E032"}, 42200, false},
		{"429 限流不明", &dwclient.APIError{Status: 429}, 50001, true},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			f := newFx(t)
			bank := f.link(t)
			f.dw.fail["POST /funding/deposits"] = []error{tc.err}
			r := f.call("POST", "/api/v1/funding/deposits", `{"bankAccountId":"`+bank+`","amount":10}`)
			if r.Code != tc.wantCode {
				t.Fatalf("code = %d，期望 %d", r.Code, tc.wantCode)
			}
			if got := len(f.repo.transfers) == 1 && f.repo.transfers[0].Status == StatusSubmitting; got != tc.keep {
				t.Fatalf("保留 SUBMITTING 记录 = %v，期望 %v", got, tc.keep)
			}
		})
	}
}

func TestSyncSubmittingDeposit(t *testing.T) {
	const listJSON = `[` +
		`{"id":"DEP-OLD","type":"ACH","amount":10,"timestamp":"2026-11-20T05:50:19.662Z","status":{"id":2,"message":"Successful"}},` +
		`{"id":"DEP-NEW","type":"ACH","amount":10,"timestamp":"%s","status":{"id":14,"message":"Approved"}},` +
		`{"id":"DEP-BIG","type":"ACH","amount":1000,"timestamp":"%s","status":{"id":14,"message":"Approved"}}]`
	cases := []struct {
		name      string
		age       time.Duration
		replayErr []error
		list      func(submitted time.Time) string
		wantPosts int
		wantRef   string
		wantState string
	}{
		{name: "1 分钟内不重放", age: 20 * time.Second, wantPosts: 1, wantState: StatusSubmitting},
		{name: "满 1 分钟用原幂等键重放成功", age: 2 * time.Minute, wantPosts: 2, wantRef: "DEP-1", wantState: "PENDING"},
		{name: "重放 IK075 未满 10 分钟：保留待下次", age: 5 * time.Minute, replayErr: []error{&dwclient.APIError{Status: 404, DWCode: "IK075"}},
			wantPosts: 2, wantState: StatusSubmitting},
		{name: "重放 IK075 满 10 分钟：按账户反查唯一匹配并关联", age: 11 * time.Minute, replayErr: []error{&dwclient.APIError{Status: 404, DWCode: "IK075"}},
			list: func(at time.Time) string {
				return fmt.Sprintf(listJSON, at.Add(13*time.Second).UTC().Format(time.RFC3339Nano), at.UTC().Format(time.RFC3339Nano))
			},
			wantPosts: 2, wantRef: "DEP-NEW", wantState: "APPROVED"},
		{name: "反查多笔同额同时段：不关联，转人工", age: 11 * time.Minute, replayErr: []error{fmt.Errorf("timeout")},
			list: func(at time.Time) string {
				ts := at.Add(5 * time.Second).UTC().Format(time.RFC3339Nano)
				return `[{"id":"A","amount":10,"timestamp":"` + ts + `"},{"id":"B","amount":10,"timestamp":"` + ts + `"}]`
			},
			wantPosts: 2, wantState: StatusSubmitting},
		{name: "反查无匹配（时间不符）：保留", age: 11 * time.Minute, replayErr: []error{fmt.Errorf("timeout")},
			list: func(at time.Time) string {
				return `[{"id":"X","amount":10,"timestamp":"` + at.Add(-2*time.Hour).UTC().Format(time.RFC3339Nano) + `"}]`
			},
			wantPosts: 2, wantState: StatusSubmitting},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			f := newFx(t)
			bank := f.link(t)
			f.dw.fail["POST /funding/deposits"] = []error{fmt.Errorf("timeout")} // 首次提交结果不明
			f.call("POST", "/api/v1/funding/deposits", `{"bankAccountId":"`+bank+`","amount":10}`)
			submitted := f.repo.transfers[0].SubmittedAt
			f.svc.now = func() time.Time { return submitted.Add(tc.age) }
			f.dw.fail["POST /funding/deposits"] = tc.replayErr
			if tc.list != nil {
				f.dw.resp["GET /accounts/dwacc-1/funding/deposits"] = tc.list(submitted)
			}
			f.svc.Sync(context.Background(), time.Minute)
			if n := f.dw.count("POST /funding/deposits"); n != tc.wantPosts {
				t.Fatalf("POST 次数 = %d，期望 %d", n, tc.wantPosts)
			}
			if p := f.dw.last("POST /funding/deposits"); tc.wantPosts > 1 && p.idem != f.dw.calls[0+countBefore(f, "POST /funding/deposits")].idem {
				t.Fatal("重放必须使用原幂等键")
			}
			tr := f.repo.transfers[0]
			if tr.DWRef != tc.wantRef || tr.Status != tc.wantState {
				t.Fatalf("关联结果 ref=%q status=%q，期望 ref=%q status=%q", tr.DWRef, tr.Status, tc.wantRef, tc.wantState)
			}
		})
	}
}

// countBefore 返回第一次匹配调用的下标（用于取首次提交的幂等键）。
func countBefore(f *fx, prefix string) int {
	for i, c := range f.dw.calls {
		if strings.HasPrefix(c.method+" "+c.path, prefix) {
			return i
		}
	}
	return 0
}

// 审计 FUND-P0-1：App 超时后重试同一笔申请（同一 Idempotency-Key）不得重复提交给 DW。
func TestClientIdempotencyKey(t *testing.T) {
	const key = "6f1c2a7e-3b4d-4e5f-8a9b-0c1d2e3f4a5b"
	body := func(amount int) string { return fmt.Sprintf(`{"bankAccountId":"%%s","amount":%d}`, amount) }
	cases := []struct {
		name      string
		firstErr  error
		retryBody int
		retryKey  string
		wantCode  int
		wantPosts int
		wantRows  int
	}{
		{name: "首次成功，重试返回原记录", retryBody: 100, retryKey: key, wantCode: 0, wantPosts: 1, wantRows: 1},
		{name: "首次结果不明，重试仍为不明且不再提交", firstErr: fmt.Errorf("timeout"), retryBody: 100, retryKey: key, wantCode: 50001, wantPosts: 1, wantRows: 1},
		{name: "同键不同金额：拒绝，不覆盖", retryBody: 200, retryKey: key, wantCode: 42200, wantPosts: 1, wantRows: 1},
		{name: "不带键：沿用后端生成（60 秒内同额被防重复拦截）", retryBody: 100, retryKey: "", wantCode: 40901, wantPosts: 1, wantRows: 1},
		{name: "键格式错误", retryBody: 100, retryKey: "not-a-uuid", wantCode: 42200, wantPosts: 1, wantRows: 1},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			f := newFx(t)
			bank := f.link(t)
			if tc.firstErr != nil {
				f.dw.fail["POST /funding/deposits"] = []error{tc.firstErr}
			}
			first := f.callKey("POST", "/api/v1/funding/deposits", fmt.Sprintf(body(100), bank), key)
			r := f.callKey("POST", "/api/v1/funding/deposits", fmt.Sprintf(body(tc.retryBody), bank), tc.retryKey)
			if r.Code != tc.wantCode {
				t.Fatalf("重试 code = %d，期望 %d（%+v）", r.Code, tc.wantCode, r)
			}
			if n := f.dw.count("POST /funding/deposits"); n != tc.wantPosts {
				t.Fatalf("DW 入金 POST 次数 = %d，期望 %d", n, tc.wantPosts)
			}
			if n := len(f.repo.transfers); n != tc.wantRows {
				t.Fatalf("本地记录数 = %d，期望 %d", n, tc.wantRows)
			}
			if tc.wantCode == 0 || tc.wantCode == 50001 {
				var a, b struct{ TransferID string }
				_ = json.Unmarshal(first.Data, &a)
				_ = json.Unmarshal(r.Data, &b)
				if a.TransferID == "" || a.TransferID != b.TransferID {
					t.Fatalf("重试应返回原 transferId：%q vs %q", a.TransferID, b.TransferID)
				}
			}
			if tc.retryKey == key && f.repo.transfers[0].IdempotencyKey != key {
				t.Fatal("记录应使用 App 提供的幂等键（对账重放与 DW 去重用同一个键）")
			}
		})
	}
}

func TestWithdrawalClientIdempotencyKey(t *testing.T) {
	const key = "0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d"
	f := newFx(t)
	bank := f.link(t)
	b := `{"method":"ACH","bankAccountId":"` + bank + `","amount":50}`
	r1 := f.callKey("POST", "/api/v1/funding/withdrawals", b, key)
	r2 := f.callKey("POST", "/api/v1/funding/withdrawals", b, key)
	if r1.Code != 0 || r2.Code != 0 {
		t.Fatalf("%+v / %+v", r1, r2)
	}
	if n := f.dw.count("POST /funding/redemptions"); n != 1 {
		t.Fatalf("同键重试不得重复出金：DW 出金 POST %d 次", n)
	}
}

// 审计 FUND-P0-2：DW 幂等键 4 天后失效，超过 95 小时不得再重放（否则新建一笔入金、重复扣款），只反查或转人工。
func TestSyncStopsReplayPastIdempotencyWindow(t *testing.T) {
	for _, tc := range []struct {
		name      string
		age       time.Duration
		wantPosts int
		wantList  int
		wantState string
	}{
		{"94 小时：仍重放", 94 * time.Hour, 2, 1, StatusSubmitting},
		{"95 小时：停止重放，只反查，查不到标为未确认", 95 * time.Hour, 1, 1, StatusUnconfirmed},
		{"10 天：停止重放，只反查，查不到标为未确认", 240 * time.Hour, 1, 1, StatusUnconfirmed},
	} {
		t.Run(tc.name, func(t *testing.T) {
			f := newFx(t)
			bank := f.link(t)
			f.dw.fail["POST /funding/deposits"] = []error{fmt.Errorf("timeout")}
			f.call("POST", "/api/v1/funding/deposits", `{"bankAccountId":"`+bank+`","amount":10}`)
			submitted := f.repo.transfers[0].SubmittedAt
			f.svc.now = func() time.Time { return submitted.Add(tc.age) }
			f.dw.fail["POST /funding/deposits"] = []error{fmt.Errorf("timeout")}
			f.dw.resp["GET /accounts/dwacc-1/funding/deposits"] = `[]`
			f.svc.Sync(context.Background(), time.Minute)
			if n := f.dw.count("POST /funding/deposits"); n != tc.wantPosts {
				t.Fatalf("POST 次数 = %d，期望 %d", n, tc.wantPosts)
			}
			if n := f.dw.count("GET /accounts/dwacc-1/funding/deposits"); n != tc.wantList {
				t.Fatalf("反查次数 = %d，期望 %d", n, tc.wantList)
			}
			if st := f.repo.transfers[0].Status; st != tc.wantState {
				t.Fatalf("状态 = %s，期望 %s", st, tc.wantState)
			}
		})
	}
}

// 审计 FUND-P1-4：首次提交的 4xx 只有"首次尝试即收到、且非幂等 / 冲突类"才算明确拒绝；对账重放被拒一律不删除。
func TestRejectionIsOnlyDefinitiveOnFirstAttempt(t *testing.T) {
	cases := []struct {
		name     string
		err      error
		wantCode int
		keep     bool
	}{
		{"首次尝试 400：明确拒绝，撤销记录", &dwclient.APIError{Status: 400, DWCode: "E032"}, 42200, false},
		{"重试后才收到 400：结果不明，保留", &dwclient.APIError{Status: 400, DWCode: "E032", Retried: true}, 50001, true},
		{"409 冲突：结果不明，保留", &dwclient.APIError{Status: 409}, 50001, true},
		{"408 超时：结果不明，保留", &dwclient.APIError{Status: 408}, 50001, true},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			f := newFx(t)
			bank := f.link(t)
			f.dw.fail["POST /funding/deposits"] = []error{tc.err}
			r := f.call("POST", "/api/v1/funding/deposits", `{"bankAccountId":"`+bank+`","amount":10}`)
			if r.Code != tc.wantCode {
				t.Fatalf("code = %d，期望 %d", r.Code, tc.wantCode)
			}
			if got := len(f.repo.transfers) == 1; got != tc.keep {
				t.Fatalf("保留记录 = %v，期望 %v", got, tc.keep)
			}
		})
	}
}

func TestReplayRejectionMarksUnconfirmed(t *testing.T) {
	for _, typ := range []string{"DEPOSIT", "WITHDRAWAL"} {
		t.Run(typ, func(t *testing.T) {
			f := newFx(t)
			bank := f.link(t)
			post, path, body := "POST /funding/deposits", "/api/v1/funding/deposits", `{"bankAccountId":"`+bank+`","amount":10}`
			if typ == "WITHDRAWAL" {
				post, path, body = "POST /funding/redemptions", "/api/v1/funding/withdrawals", `{"method":"ACH","bankAccountId":"`+bank+`","amount":10}`
			}
			f.dw.fail[post] = []error{fmt.Errorf("timeout")}
			f.call("POST", path, body)
			first := f.dw.last(post).idem
			f.svc.now = func() time.Time { return time.Now().Add(2 * time.Minute) }
			f.dw.fail[post] = []error{&dwclient.APIError{Status: 400, DWCode: "E031"}}
			f.svc.Sync(context.Background(), time.Minute)
			if n := f.dw.count(post); n != 2 || f.dw.last(post).idem != first {
				t.Fatalf("应用原幂等键重放一次：%d 次", n)
			}
			if len(f.repo.transfers) != 1 || f.repo.transfers[0].Status != StatusUnconfirmed {
				t.Fatalf("重放被拒不得删除，应标为 UNCONFIRMED：%+v", f.repo.transfers)
			}
			// 之后只反查、不再重放
			f.dw.resp["GET /accounts/dwacc-1/funding/"] = `[]`
			f.svc.Sync(context.Background(), time.Minute)
			if n := f.dw.count(post); n != 2 {
				t.Fatalf("UNCONFIRMED 不得再重放：%d 次", n)
			}
		})
	}
}

// 审计 FUND-P1-2：出金结果不明后，按账户列出出金反查（列表金额为负、无银行字段）并关联。
func TestWithdrawalLookupByRedemptions(t *testing.T) {
	f := newFx(t)
	bank := f.link(t)
	f.dw.fail["POST /funding/redemptions"] = []error{fmt.Errorf("timeout")}
	f.call("POST", "/api/v1/funding/withdrawals", `{"method":"ACH","bankAccountId":"`+bank+`","amount":50}`)
	submitted := f.repo.transfers[0].SubmittedAt
	f.svc.now = func() time.Time { return submitted.Add(11 * time.Minute) }
	f.dw.fail["POST /funding/redemptions"] = []error{fmt.Errorf("timeout")}
	f.dw.resp["GET /accounts/dwacc-1/funding/redemptions"] = `[{"id":"RED-9","amount":-50,"timestamp":"` +
		submitted.Add(3*time.Second).UTC().Format(time.RFC3339Nano) + `","status":{"id":14,"message":"Approved"}}]`
	f.svc.Sync(context.Background(), time.Minute)
	if tr := f.repo.transfers[0]; tr.DWRef != "RED-9" || tr.Status != "APPROVED" {
		t.Fatalf("应反查关联 RED-9：%+v", tr)
	}
}

// 审计 FUND-P1-3：App 断开（请求 context 取消）不得中途放弃提交券商与落库。
func TestSubmitSurvivesClientDisconnect(t *testing.T) {
	f := newFx(t)
	bank := f.link(t)
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	req := httptest.NewRequest("POST", "/api/v1/funding/deposits", strings.NewReader(`{"bankAccountId":"`+bank+`","amount":10}`)).WithContext(ctx)
	req.Header.Set("Content-Type", "application/json")
	f.mux.ServeHTTP(httptest.NewRecorder(), req)
	c := f.dw.last("POST /funding/deposits")
	if c == nil || c.canceled {
		t.Fatalf("提交券商时 context 不应已取消：%+v", c)
	}
	if tr := f.repo.transfers[0]; tr.DWRef != "DEP-1" {
		t.Fatalf("应完成落库：%+v", tr)
	}
}

// 审计 TEST-P1-2：SQL 中的终态列表必须与 Terminal() 一致（此前 SQL 漏了 RIA_REJECTED，导致被拒入金仍占每日额度）。
func TestTerminalSQLMatches(t *testing.T) {
	var inSQL []string
	for _, p := range strings.Split(strings.Trim(terminalSQL, "()"), ",") {
		inSQL = append(inSQL, strings.Trim(strings.TrimSpace(p), "'"))
	}
	for _, st := range inSQL {
		if !Terminal(st) {
			t.Errorf("terminalSQL 含 %s，但 Terminal() 不认为它是终态", st)
		}
	}
	for _, st := range []string{"FAILED", "REJECTED", "RETURNED", "RIA_REJECTED", "SUCCESSFUL", "PENDING", "APPROVED", StatusSubmitting, StatusUnconfirmed} {
		found := false
		for _, x := range inSQL {
			found = found || x == st
		}
		if Terminal(st) != found {
			t.Errorf("%s：Terminal()=%v，terminalSQL 包含=%v", st, Terminal(st), found)
		}
	}
}

// 审计 TEST-P1-2：内存仓储与 PG 同语义——对账节流（checked_at）、条数上限、有 DW 编号不可删。
func TestMemRepoMirrorsPG(t *testing.T) {
	m := newMem()
	ctx := context.Background()
	now := time.Now()
	for i := 0; i < 3; i++ {
		if _, err := m.InsertTransfer(ctx, Transfer{AccountID: "a", Type: "DEPOSIT", Method: "ACH", Amount: "10.00", Status: "PENDING", IdempotencyKey: fmt.Sprint(i)}); err != nil {
			t.Fatal(err)
		}
	}
	if got, _ := m.DueTransfers(ctx, now, now.Add(-time.Hour), 2); len(got) != 2 {
		t.Fatalf("limit 应生效：%d", len(got))
	}
	_ = m.TouchTransfer(ctx, m.transfers[0].ID, now)
	if got, _ := m.DueTransfers(ctx, now.Add(-time.Second), now.Add(-time.Hour), 10); len(got) != 2 {
		t.Fatalf("刚检查过的记录不应到期：%d", len(got))
	}
	_ = m.SetSubmitted(ctx, m.transfers[1].ID, "DEP-X", "PENDING", now.Add(-time.Hour))
	_ = m.DeleteTransfer(ctx, m.transfers[1].ID)
	if len(m.transfers) != 3 {
		t.Fatal("有 DW 编号的记录不可删除（同 PG：dw_ref IS NULL）")
	}
}

// 审计 3.3 覆盖空白（出金安全，CLAUDE.md 规则 5）：出金失败路径。
func TestWithdrawalFailurePaths(t *testing.T) {
	body := func(bank string, amount string) string {
		return `{"method":"ACH","bankAccountId":"` + bank + `","amount":` + amount + `}`
	}
	cases := []struct {
		name     string
		amount   string
		setup    func(f *fx)
		wantCode int
		keepRows int
	}{
		{"券商首次明确拒绝 → 42200，撤销记录", "100", func(f *fx) {
			f.dw.fail["POST /funding/redemptions"] = []error{&dwclient.APIError{Status: 400, DWCode: "Y075"}}
		}, 42200, 0},
		{"超时 → 50001，保留记录待对账", "100", func(f *fx) {
			f.dw.fail["POST /funding/redemptions"] = []error{fmt.Errorf("timeout")}
		}, 50001, 1},
		{"未找到开户姓名 → 40901，不提交券商", "100", func(f *fx) {
			f.svc.LegalName = func(context.Context, string) (string, error) { return "", nil }
		}, 40901, 0},
		{"超过单笔上限 → 42201", "50001", nil, 42201, 0},
		{"低于单笔下限 → 42201", "0.5", nil, 42201, 0},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			f := newFx(t)
			bank := f.link(t)
			f.dw.resp["GET /accounts/"] = strings.Replace(moneyJSON, "250.25", "100000", -1)
			if tc.setup != nil {
				tc.setup(f)
			}
			r := f.call("POST", "/api/v1/funding/withdrawals", body(bank, tc.amount))
			if r.Code != tc.wantCode {
				t.Fatalf("code = %d，期望 %d（%+v）", r.Code, tc.wantCode, r)
			}
			if len(f.repo.transfers) != tc.keepRows {
				t.Fatalf("本地记录 %d 条，期望 %d", len(f.repo.transfers), tc.keepRows)
			}
			if tc.wantCode == 40901 || tc.wantCode == 42201 {
				if n := f.dw.count("POST /funding/redemptions"); n != 0 {
					t.Fatalf("校验失败不得提交券商：%d", n)
				}
			}
		})
	}
	t.Run("60 秒内同额重复 → 40901", func(t *testing.T) {
		f := newFx(t)
		bank := f.link(t)
		if r := f.call("POST", "/api/v1/funding/withdrawals", body(bank, "50")); r.Code != 0 {
			t.Fatal(r)
		}
		if r := f.call("POST", "/api/v1/funding/withdrawals", body(bank, "50")); r.Code != 40901 {
			t.Fatalf("应拦截重复出金：%+v", r)
		}
		if n := f.dw.count("POST /funding/redemptions"); n != 1 {
			t.Fatalf("只应提交一次：%d", n)
		}
	})
}

// 审计 3.3：反查只关联"同额、同银行（列表带字段时）、时间吻合、未被关联"的唯一一笔。
func TestLookupExcludesLinkedAndOtherBank(t *testing.T) {
	f := newFx(t)
	bank := f.link(t)
	f.dw.fail["POST /funding/deposits"] = []error{fmt.Errorf("timeout")}
	f.call("POST", "/api/v1/funding/deposits", `{"bankAccountId":"`+bank+`","amount":10}`)
	// 另一条已关联 DEP-LINKED 的本地记录
	f.repo.transfers = append(f.repo.transfers, Transfer{ID: "tr-x", AccountID: "acc-1", Type: "DEPOSIT", Amount: "10.00", Status: "PENDING", DWRef: "DEP-LINKED", IdempotencyKey: "x"})
	submitted := f.repo.transfers[0].SubmittedAt
	ts := submitted.Add(2 * time.Second).UTC().Format(time.RFC3339Nano)
	f.dw.resp["GET /accounts/dwacc-1/funding/deposits"] = `[` +
		`{"id":"DEP-LINKED","amount":10,"timestamp":"` + ts + `","status":{"message":"Approved"}},` +
		`{"id":"DEP-OTHERBANK","amount":10,"bankAccountID":"bank_other","timestamp":"` + ts + `","status":{"message":"Approved"}},` +
		`{"id":"DEP-MINE","amount":10,"bankAccountID":"bank_test1","timestamp":"` + ts + `","status":{"message":"Approved"}}]`
	f.svc.now = func() time.Time { return submitted.Add(11 * time.Minute) }
	f.dw.fail["POST /funding/deposits"] = []error{fmt.Errorf("timeout")}
	f.svc.Sync(context.Background(), time.Minute)
	if tr := f.repo.transfers[0]; tr.DWRef != "DEP-MINE" {
		t.Fatalf("应只关联 DEP-MINE（排除已关联与他行）：%q", tr.DWRef)
	}
}

// 审计 DOC-P1-4/P1-5：GET /funding/limits 下发后端配置的限额与观察期，App 不再写死。
func TestFundingLimitsEndpoint(t *testing.T) {
	f := newFx(t)
	f.svc.SeasoningDays, f.svc.SeasoningStart = 5, "CLEARED"
	r := f.call("GET", "/api/v1/funding/limits", "")
	if r.Code != 0 {
		t.Fatal(r)
	}
	var d map[string]any
	_ = json.Unmarshal(r.Data, &d)
	for k, want := range map[string]any{"minDeposit": 10.0, "maxDeposit": 50000.0, "dailyDeposit": 60000.0, "minWithdrawal": 1.0,
		"maxWithdrawal": 50000.0, "minWire": 100.0, "maxBanks": 2.0, "seasoningDays": 5.0, "seasoningStart": "CLEARED"} {
		if d[k] != want {
			t.Errorf("%s = %#v，期望 %#v", k, d[k], want)
		}
	}
}
