// Package funding：银行账户、入金、出金、资金记录与资金汇总（api-spec.md 第 3–5 节，F7–F9）。
//
// 出金安全（CLAUDE.md 硬性规则 5）：金额、限额、收款人全部后端强制校验，不信任客户端：
//   - 金额最多两位小数；限额来自 config.Limits；
//   - 出金金额不得超过 DW 实时返回的 cashAvailableForWithdrawal；
//   - WIRE 收款人固定为开户法定姓名；绑卡户名同样由后端写入开户姓名。
package funding

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"regexp"
	"strings"
	"time"
	_ "time/tzdata" // 美东日界线（每日入金限额）

	"github.com/imamura-akira/New_FinX/backend/internal/account"
	"github.com/imamura-akira/New_FinX/backend/internal/config"
	"github.com/imamura-akira/New_FinX/backend/internal/crypto"
	"github.com/imamura-akira/New_FinX/backend/internal/dwclient"
	"github.com/imamura-akira/New_FinX/backend/internal/httpx"
)

// DW：所需的 DW 能力（*dwclient.Client 满足）。
type DW interface {
	Do(ctx context.Context, method, path string, reqBody, out any) error
}

// Deps：外部依赖。
type Deps struct {
	Repo      Repo
	DW        DW
	Cipher    *crypto.Cipher
	Account   func(ctx context.Context, userID string) (*account.Account, error)
	LegalName func(ctx context.Context, userID string) (string, error) // 开户法定姓名（来自开户资料）
	Limits    config.Limits
	BankLink  config.BankLinkMethod
	Logger    *slog.Logger
}

// Service：资金模块。
type Service struct {
	Deps
	now func() time.Time
	et  *time.Location
}

// New 创建模块。
func New(d Deps) *Service {
	if d.Logger == nil {
		d.Logger = slog.Default()
	}
	et, err := time.LoadLocation("America/New_York")
	if err != nil {
		et = time.UTC
	}
	return &Service{Deps: d, now: time.Now, et: et}
}

// Routes 注册接口。
func (s *Service) Routes(mux *http.ServeMux, prefix string, auth func(http.Handler) http.Handler) {
	h := func(f http.HandlerFunc) http.Handler { return auth(f) }
	mux.Handle("GET "+prefix+"/funding/bank-accounts", h(s.handleListBanks))
	mux.Handle("POST "+prefix+"/funding/bank-accounts", h(s.handleLinkBank))
	mux.Handle("DELETE "+prefix+"/funding/bank-accounts/{id}", h(s.handleDeleteBank))
	mux.Handle("GET "+prefix+"/funding/deposit-instructions", h(s.handleInstructions))
	mux.Handle("POST "+prefix+"/funding/deposits", h(s.handleDeposit))
	mux.Handle("POST "+prefix+"/funding/withdrawals", h(s.handleWithdrawal))
	mux.Handle("GET "+prefix+"/funding/transfers", h(s.handleTransfers))
	mux.Handle("GET "+prefix+"/account/money", h(s.handleMoney))
}

// ---------- 公共 ----------

// account 返回可做资金操作的账户；未开户 40901，冻结/关闭 40301。
func (s *Service) account(ctx context.Context) (*account.Account, error) {
	a, err := s.Account(ctx, httpx.UserID(ctx))
	if err != nil {
		return nil, err
	}
	if a == nil || a.DWAccountID == "" {
		return nil, httpx.Conflict("交易账户尚未开立")
	}
	switch a.Status {
	case "OPEN", "OPEN_NO_NEW_TRADES": // 仅可卖出的账户不影响出入金
		return a, nil
	case "FROZEN", "CLOSED":
		return nil, httpx.Restricted(a.Status)
	default:
		return nil, httpx.Conflict("交易账户尚未开通")
	}
}

func (s *Service) dwFail(ctx context.Context, op string, err error) error {
	var ae *dwclient.APIError
	if errors.As(err, &ae) {
		s.Logger.WarnContext(ctx, "dw funding call failed", slog.String("op", op), slog.Int("status", ae.Status), slog.String("dw_code", ae.DWCode))
	} else {
		s.Logger.WarnContext(ctx, "dw funding call failed", slog.String("op", op), slog.String("error", err.Error()))
	}
	return httpx.DWFailed()
}

func newUUID() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:])
}

// keyOr：App 提供了幂等键就用它，否则后端生成（兼容旧版 App）。
func keyOr(clientKey string) string {
	if clientKey != "" {
		return clientKey
	}
	return newUUID()
}

// replayed：本账户已有使用该幂等键的记录时，按原记录作答并返回 true（App 超时后重试同一笔申请，审计 FUND-P0-1）。
//   - 内容不同（金额、方式、银行账户）：422，提示刷新后重试，不覆盖原记录；
//   - 原记录尚无 DW 编号（提交中 / 结果不明）：502 50001 + transferId，与首次结果不明时一致；
//   - 否则：200 + 原记录的 transferId 与状态。
func (s *Service) replayed(w http.ResponseWriter, r *http.Request, accountID, key, typ, method, amount string, bankID *string) bool {
	t, err := s.Repo.TransferByIdemKey(r.Context(), accountID, key)
	if errors.Is(err, ErrNotFound) {
		return false
	}
	if err != nil {
		httpx.Fail(w, r, err)
		return true
	}
	sameBank := (t.BankAccountID == nil) == (bankID == nil) && (bankID == nil || *t.BankAccountID == *bankID)
	if t.Type != typ || t.Method != method || parseCents(t.Amount) != parseCents(amount) || !sameBank {
		httpx.Fail(w, r, httpx.Validation("该笔申请的请求编号已被另一笔申请使用，请返回后重新提交"))
		return true
	}
	if t.DWRef == "" {
		httpx.Fail(w, r, &httpx.Error{HTTP: http.StatusBadGateway, Code: httpx.CodeDWFailed, Message: "提交结果暂未确认，请稍后在资金记录中查看，请勿重复提交",
			Data: map[string]string{"transferId": t.ID}})
		return true
	}
	httpx.OK(w, map[string]string{"transferId": t.ID, "status": t.Status})
	return true
}

// ---------- 银行账户 ----------

func (s *Service) handleListBanks(w http.ResponseWriter, r *http.Request) {
	a, err := s.Account(r.Context(), httpx.UserID(r.Context()))
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	if a == nil {
		httpx.OK(w, []Bank{})
		return
	}
	list, err := s.Repo.ListBanks(r.Context(), a.ID)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	httpx.OK(w, list)
}

var (
	digitsRE   = regexp.MustCompile(`^\d+$`)
	nonDigitRE = regexp.MustCompile(`[\s-]`)
)

// ValidABA：9 位 ABA 路由号码校验和。
func ValidABA(s string) bool {
	if len(s) != 9 || !digitsRE.MatchString(s) {
		return false
	}
	w := []int{3, 7, 1, 3, 7, 1, 3, 7, 1}
	sum := 0
	for i, c := range s {
		sum += int(c-'0') * w[i]
	}
	return sum%10 == 0
}

func (s *Service) handleLinkBank(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if s.BankLink == config.BankLinkPlaid {
		httpx.Fail(w, r, httpx.NotEnabled("通过 Plaid 绑定银行账户暂未开通"))
		return
	}
	var in struct {
		AccountNumber       string `json:"accountNumber"`
		RoutingNumber       string `json:"routingNumber"`
		Type                string `json:"type"`
		Nickname            string `json:"nickname"`
		PlaidProcessorToken string `json:"plaidProcessorToken"` // 方案 B 字段，DIRECT 模式下忽略
	}
	if err := httpx.Decode(w, r, 0, &in); err != nil {
		httpx.Fail(w, r, err)
		return
	}
	acct := nonDigitRE.ReplaceAllString(in.AccountNumber, "")
	routing := nonDigitRE.ReplaceAllString(in.RoutingNumber, "")
	nick := strings.TrimSpace(in.Nickname)
	var fe []httpx.FieldError
	if !digitsRE.MatchString(acct) || len(acct) < 4 || len(acct) > 17 {
		fe = append(fe, httpx.FieldError{Field: "accountNumber", Reason: "请输入 4–17 位银行账号"})
	}
	if !ValidABA(routing) {
		fe = append(fe, httpx.FieldError{Field: "routingNumber", Reason: "请输入有效的 9 位 ABA 路由号码"})
	}
	if in.Type != "CHECKING" && in.Type != "SAVINGS" {
		fe = append(fe, httpx.FieldError{Field: "type", Reason: "请选择账户类型"})
	}
	if len([]rune(nick)) > 30 || (nick != "" && nonDigitRE.ReplaceAllString(nick, "") == acct) {
		fe = append(fe, httpx.FieldError{Field: "nickname", Reason: "备注名最多 30 个字，且不能与账号相同"})
	}
	if len(fe) > 0 {
		httpx.Fail(w, r, httpx.Validation("", fe...))
		return
	}
	a, err := s.account(ctx)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	banks, err := s.Repo.ListBanks(ctx, a.ID)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	if len(banks) >= s.Limits.MaxBanks {
		httpx.Fail(w, r, httpx.Conflict(fmt.Sprintf("最多绑定 %d 个银行账户，请先解绑一个", s.Limits.MaxBanks)))
		return
	}
	owner, err := s.LegalName(ctx, httpx.UserID(ctx))
	if err != nil || owner == "" {
		httpx.Fail(w, r, httpx.Conflict("未找到开户姓名，暂不能绑定银行账户"))
		return
	}
	mask := acct[len(acct)-4:]
	if nick == "" {
		nick = map[string]string{"CHECKING": "Checking", "SAVINGS": "Savings"}[in.Type] + " " + mask
	}
	var res dwBankRes
	if err := s.DW.Do(ctx, http.MethodPost, pathBanks, linkBankBody(a.DWUserID, acct, routing, in.Type, nick, owner), &res); err != nil {
		var ae *dwclient.APIError
		if errors.As(err, &ae) && ae.Status >= 400 && ae.Status < 500 {
			s.Logger.WarnContext(ctx, "dw link bank rejected", slog.Int("status", ae.Status), slog.String("dw_code", ae.DWCode))
			httpx.Fail(w, r, httpx.Validation("银行账户信息未通过券商校验，请核对账号与路由号码"))
			return
		}
		httpx.Fail(w, r, s.dwFail(ctx, "link_bank", err))
		return
	}
	if res.ID == "" {
		httpx.Fail(w, r, &httpx.Error{HTTP: http.StatusBadGateway, Code: httpx.CodeDWBadData, Message: "券商返回数据异常，已记录"})
		return
	}
	status := statusOf(res.Status)
	if status == "" {
		status = "ACTIVE"
	}
	id, err := s.Repo.InsertBank(ctx, Bank{AccountID: a.ID, DWBankID: res.ID, BankName: res.BankDetails.BankName, Mask: mask, Type: in.Type, OwnerName: owner, Status: status, Nickname: nick})
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	_ = s.Repo.Audit(ctx, "user:"+httpx.UserID(ctx), "bank.linked", "bank_account:"+id, map[string]any{"mask": mask, "type": in.Type})
	httpx.OK(w, map[string]string{"id": id, "status": status})
}

func (s *Service) handleDeleteBank(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	a, err := s.account(ctx)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	b, err := s.Repo.GetBank(ctx, a.ID, r.PathValue("id"))
	if errors.Is(err, ErrNotFound) {
		httpx.Fail(w, r, httpx.Conflict("银行账户不存在或已解绑"))
		return
	}
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	busy, err := s.Repo.HasInFlight(ctx, b.ID)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	if busy {
		httpx.Fail(w, r, httpx.Conflict("该银行账户有处理中的出入金，完成后才能解绑"))
		return
	}
	if err := s.DW.Do(ctx, http.MethodDelete, pathBanks+"/"+b.DWBankID, nil, nil); err != nil {
		httpx.Fail(w, r, s.dwFail(ctx, "delete_bank", err))
		return
	}
	if err := s.Repo.DeleteBank(ctx, b.ID, s.now().UTC()); err != nil {
		httpx.Fail(w, r, err)
		return
	}
	_ = s.Repo.Audit(ctx, "user:"+httpx.UserID(ctx), "bank.unlinked", "bank_account:"+b.ID, nil)
	httpx.OK(w, nil)
}

// ---------- 入金 ----------

func (s *Service) limitErr(msg string, limits map[string]string) error {
	return &httpx.Error{HTTP: http.StatusUnprocessableEntity, Code: httpx.CodeLimit, Message: msg, Data: map[string]any{"limits": limits}}
}

func (s *Service) handleDeposit(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	var in struct {
		BankAccountID string          `json:"bankAccountId"`
		Amount        json.RawMessage `json:"amount"`
	}
	if err := httpx.Decode(w, r, 0, &in); err != nil {
		httpx.Fail(w, r, err)
		return
	}
	cents, err := AmountFromJSON(in.Amount)
	if err != nil {
		httpx.Fail(w, r, httpx.Validation("", httpx.FieldError{Field: "amount", Reason: err.Error()}))
		return
	}
	minC, maxC, dayC := CentsOf(s.Limits.MinDeposit), CentsOf(s.Limits.MaxDeposit), CentsOf(s.Limits.DailyDeposit)
	limits := map[string]string{"min": Cents(minC), "max": Cents(maxC), "daily": Cents(dayC)}
	if cents < minC || cents > maxC {
		httpx.Fail(w, r, s.limitErr(fmt.Sprintf("单笔入金金额须在 $%s – $%s 之间", Cents(minC), Cents(maxC)), limits))
		return
	}
	a, err := s.account(ctx)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	bank, err := s.Repo.GetBank(ctx, a.ID, in.BankAccountID)
	if errors.Is(err, ErrNotFound) {
		httpx.Fail(w, r, httpx.Validation("", httpx.FieldError{Field: "bankAccountId", Reason: "请选择已绑定的银行账户"}))
		return
	}
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	// App 重试同一笔申请（同一 Idempotency-Key）：返回原记录，不再向 DW 提交（审计 FUND-P0-1）
	idem, err := httpx.ClientIdempotencyKey(r)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	if idem != "" && s.replayed(w, r, a.ID, idem, "DEPOSIT", "ACH", Cents(cents), &bank.ID) {
		return
	}
	now := s.now()
	y, m, d := now.In(s.et).Date()
	todayET := time.Date(y, m, d, 0, 0, 0, 0, s.et)
	sum, err := s.Repo.SumDeposits(ctx, a.ID, todayET)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	if used := parseCents(sum); used+cents > dayC {
		limits["remainingToday"] = Cents(max(0, dayC-used))
		httpx.Fail(w, r, s.limitErr(fmt.Sprintf("超过每日入金限额 $%s，今日还可入金 $%s", Cents(dayC), Cents(max(0, dayC-used))), limits))
		return
	}
	amount := Cents(cents)
	if dup, err := s.Repo.RecentDuplicate(ctx, a.ID, "DEPOSIT", amount, &bank.ID, now.Add(-60*time.Second)); err != nil {
		httpx.Fail(w, r, err)
		return
	} else if dup {
		httpx.Fail(w, r, httpx.Conflict("刚刚已提交过相同金额的入金，请勿重复提交"))
		return
	}

	ctx, cancel := detached(ctx) // 落库 + 提交券商不随请求取消（审计 FUND-P1-3）
	defer cancel()
	t := Transfer{AccountID: a.ID, BankAccountID: &bank.ID, Type: "DEPOSIT", Method: "ACH", Amount: amount, Status: StatusSubmitting,
		IdempotencyKey: keyOr(idem), CreatedBy: httpx.UserID(ctx), DWAccountNo: a.AccountNo, DWBankID: bank.DWBankID}
	if t.ID, err = s.Repo.InsertTransfer(ctx, t); err != nil {
		if idem != "" && s.replayed(w, r, a.ID, idem, "DEPOSIT", "ACH", amount, &bank.ID) { // 同键并发请求：另一请求已落库
			return
		}
		httpx.Fail(w, r, err)
		return
	}
	status, err := s.submitDeposit(ctx, t, false)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	_ = s.Repo.Audit(ctx, "user:"+httpx.UserID(ctx), "deposit.submitted", "transfer:"+t.ID, map[string]any{"amount": amount, "method": "ACH", "status": status})
	httpx.OK(w, map[string]string{"transferId": t.ID, "status": status})
}

// submitDeposit 用固定的 Idempotency-Key 调 DW（首次提交与结果不明后的重放共用；replay 标明是否为对账重放）。
func (s *Service) submitDeposit(ctx context.Context, t Transfer, replay bool) (string, error) {
	var res dwTransferRes
	dctx := dwclient.WithIdempotencyKey(ctx, t.IdempotencyKey)
	err := s.DW.Do(dctx, http.MethodPost, pathDeposits, depositBody(t.DWAccountNo, parseCents(t.Amount), t.DWBankID), &res)
	return s.afterSubmit(ctx, t, res, err, "deposit", replay)
}

// submitWithdrawal：出金同样带已落库的 Idempotency-Key（DW 文档：Create Withdrawal 支持，保存 4 天，重复键返回原响应），
// 首次提交与对账重放共用（审计 FUND-P1-2）。收款人一律为开户法定姓名，WIRE 信息从加密存储中解出。
func (s *Service) submitWithdrawal(ctx context.Context, t Transfer, owner string, wire *Wire, replay bool) (string, error) {
	var res dwTransferRes
	dctx := dwclient.WithIdempotencyKey(ctx, t.IdempotencyKey)
	err := s.DW.Do(dctx, http.MethodPost, pathRedemptions, redemptionBody(t.DWAccountNo, parseCents(t.Amount), t.Method, t.DWBankID, owner, wire), &res)
	return s.afterSubmit(ctx, t, res, err, "redemption", replay)
}

// idempotencyError：DW 幂等键类错误（错误码 IK 开头，DW Errors 文档 "Idempotency Errors"）。
// 它只说明缓存的响应暂不可取，不能说明请求未被处理——沙盒实测（2026-11-21）首次提交超时后得到 IK075，
// DW 实际已创建入金。因此按"结果不明"处理，不能当作拒绝删除本地记录。
func idempotencyError(ae *dwclient.APIError) bool { return strings.HasPrefix(ae.DWCode, "IK") }

// definitiveReject：只有首次尝试就收到的 4xx 才算券商明确拒绝。幂等键类错误（IK*）、408/409/425/429，
// 以及经过重试才收到的 4xx（前一次尝试可能已生效）一律按"结果不明"处理（审计 FUND-P1-4）。
func definitiveReject(err error) (*dwclient.APIError, bool) {
	var ae *dwclient.APIError
	if !errors.As(err, &ae) || ae.Status < 400 || ae.Status >= 500 || ae.Retried || idempotencyError(ae) {
		return ae, false
	}
	switch ae.Status {
	case http.StatusRequestTimeout, http.StatusConflict, http.StatusTooEarly, http.StatusTooManyRequests:
		return ae, false
	}
	return ae, true
}

// afterSubmit：处理提交 / 重放结果。
//   - 首次提交（replay=false）且券商明确拒绝：撤销本地记录，返回可展示的错误；
//   - 对账重放（replay=true）被拒：不删除记录（首次请求可能已生效），标为 UNCONFIRMED 转人工核对；
//   - 结果不明：保留记录，首次提交返回 502/50001，对账稍后重放。
func (s *Service) afterSubmit(ctx context.Context, t Transfer, res dwTransferRes, err error, op string, replay bool) (string, error) {
	if err != nil {
		if ae, ok := definitiveReject(err); ok {
			if replay {
				reason := fmt.Sprintf("对账重放被券商拒绝（%s），待人工核对", ae.DWCode)
				_ = s.Repo.UpdateTransfer(ctx, t.ID, StatusUnconfirmed, &reason, nil, s.now().UTC())
				s.Logger.ErrorContext(ctx, "dw "+op+" replay rejected, manual check required", slog.String("transfer_id", t.ID),
					slog.Int("status", ae.Status), slog.String("dw_code", ae.DWCode))
				return "", errReplayRejected
			}
			_ = s.Repo.DeleteTransfer(ctx, t.ID)
			s.Logger.WarnContext(ctx, "dw "+op+" rejected", slog.String("transfer_id", t.ID), slog.Int("status", ae.Status), slog.String("dw_code", ae.DWCode))
			return "", httpx.Validation("券商未受理该笔申请，请核对金额与账户后重试")
		}
		s.Logger.ErrorContext(ctx, "dw "+op+" outcome unknown", slog.String("transfer_id", t.ID), slog.String("error", err.Error()))
		return "", &httpx.Error{HTTP: http.StatusBadGateway, Code: httpx.CodeDWFailed, Message: "提交结果暂未确认，请稍后在资金记录中查看，请勿重复提交",
			Data: map[string]string{"transferId": t.ID}}
	}
	status := statusOf(res.Status)
	if res.ID == "" || status == "" {
		s.Logger.ErrorContext(ctx, "dw "+op+" response unrecognized", slog.String("transfer_id", t.ID))
		status = "PENDING"
	}
	if err := s.Repo.SetSubmitted(ctx, t.ID, res.ID, status, s.now().UTC()); err != nil {
		return "", err
	}
	return status, nil
}

// errReplayRejected：对账重放被券商拒绝，记录已标为 UNCONFIRMED。
var errReplayRejected = errors.New("funding: replay rejected, marked unconfirmed")

// detached：提交券商与落库这一段不随请求取消（App 超时断开时不中途放弃，审计 FUND-P1-3），另设独立超时。
func detached(ctx context.Context) (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.WithoutCancel(ctx), 2*time.Minute)
}

// ---------- 出金 ----------

func (s *Service) handleWithdrawal(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	var in struct {
		Method        string          `json:"method"`
		Amount        json.RawMessage `json:"amount"`
		BankAccountID string          `json:"bankAccountId"`
		Wire          *Wire           `json:"wire"`
	}
	if err := httpx.Decode(w, r, 0, &in); err != nil {
		httpx.Fail(w, r, err)
		return
	}
	cents, err := AmountFromJSON(in.Amount)
	if err != nil {
		httpx.Fail(w, r, httpx.Validation("", httpx.FieldError{Field: "amount", Reason: err.Error()}))
		return
	}
	var fe []httpx.FieldError
	switch in.Method {
	case "ACH":
		if in.BankAccountID == "" {
			fe = append(fe, httpx.FieldError{Field: "bankAccountId", Reason: "请选择收款银行账户"})
		}
	case "WIRE":
		if in.Wire == nil {
			in.Wire = &Wire{}
		}
		in.Wire.AccountNumber = strings.TrimSpace(in.Wire.AccountNumber)
		in.Wire.SwiftOrAba = strings.ToUpper(strings.TrimSpace(in.Wire.SwiftOrAba))
		if strings.TrimSpace(in.Wire.BankName) == "" {
			fe = append(fe, httpx.FieldError{Field: "wire.bankName", Reason: "请输入收款银行名称"})
		}
		if len(in.Wire.AccountNumber) < 4 {
			fe = append(fe, httpx.FieldError{Field: "wire.accountNumber", Reason: "请输入收款账号"})
		}
		if !ValidABA(in.Wire.SwiftOrAba) && !regexp.MustCompile(`^[A-Z]{6}[A-Z0-9]{2}([A-Z0-9]{3})?$`).MatchString(in.Wire.SwiftOrAba) {
			fe = append(fe, httpx.FieldError{Field: "wire.swiftOrAba", Reason: "请输入有效的 SWIFT 代码或 9 位 ABA 路由号码"})
		}
		if len(in.Wire.Country) != 3 {
			fe = append(fe, httpx.FieldError{Field: "wire.country", Reason: "请选择收款银行所在国家/地区"})
		}
	default:
		fe = append(fe, httpx.FieldError{Field: "method", Reason: "请选择出金方式"})
	}
	if len(fe) > 0 {
		httpx.Fail(w, r, httpx.Validation("", fe...))
		return
	}
	minC, maxC := CentsOf(s.Limits.MinWithdrawal), CentsOf(s.Limits.MaxWithdrawal)
	if in.Method == "WIRE" && CentsOf(s.Limits.MinWire) > minC {
		minC = CentsOf(s.Limits.MinWire)
	}
	limits := map[string]string{"min": Cents(minC), "max": Cents(maxC)}
	if cents < minC || cents > maxC {
		httpx.Fail(w, r, s.limitErr(fmt.Sprintf("单笔出金金额须在 $%s – $%s 之间", Cents(minC), Cents(maxC)), limits))
		return
	}
	a, err := s.account(ctx)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	var bank *Bank
	if in.Method == "ACH" {
		if bank, err = s.Repo.GetBank(ctx, a.ID, in.BankAccountID); errors.Is(err, ErrNotFound) {
			httpx.Fail(w, r, httpx.Validation("", httpx.FieldError{Field: "bankAccountId", Reason: "请选择已绑定的银行账户"}))
			return
		} else if err != nil {
			httpx.Fail(w, r, err)
			return
		}
	}
	// 可提现金额一律以 DW 实时返回为准
	var money dwMoney
	if err := s.DW.Do(ctx, http.MethodGet, pathMoney(a.DWAccountID), nil, &money); err != nil {
		httpx.Fail(w, r, s.dwFail(ctx, "money", err))
		return
	}
	if avail := money.withdrawableCents(); cents > avail {
		limits["available"] = Cents(avail)
		httpx.Fail(w, r, s.limitErr(fmt.Sprintf("超过可提现金额 $%s", Cents(avail)), limits))
		return
	}
	owner, err := s.LegalName(ctx, httpx.UserID(ctx))
	if err != nil || owner == "" {
		httpx.Fail(w, r, httpx.Conflict("未找到开户姓名，暂不能出金"))
		return
	}
	amount := Cents(cents)
	var bankID *string
	if bank != nil {
		bankID = &bank.ID
	}
	idem, err := httpx.ClientIdempotencyKey(r)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	if idem != "" && s.replayed(w, r, a.ID, idem, "WITHDRAWAL", in.Method, amount, bankID) {
		return
	}
	if dup, err := s.Repo.RecentDuplicate(ctx, a.ID, "WITHDRAWAL", amount, bankID, s.now().Add(-60*time.Second)); err != nil {
		httpx.Fail(w, r, err)
		return
	} else if dup {
		httpx.Fail(w, r, httpx.Conflict("刚刚已提交过相同金额的出金，请勿重复提交"))
		return
	}
	ctx, cancel := detached(ctx) // 落库 + 提交券商不随请求取消（审计 FUND-P1-3）
	defer cancel()
	t := Transfer{AccountID: a.ID, BankAccountID: bankID, Type: "WITHDRAWAL", Method: in.Method, Amount: amount, Status: StatusSubmitting,
		IdempotencyKey: keyOr(idem), CreatedBy: httpx.UserID(ctx), DWAccountNo: a.AccountNo}
	if in.Method == "WIRE" {
		raw, _ := json.Marshal(in.Wire)
		if t.WireEnc, err = s.Cipher.Encrypt(raw, crypto.AAD("transfers", "wire_enc", t.IdempotencyKey)); err != nil {
			httpx.Fail(w, r, err)
			return
		}
	}
	if t.ID, err = s.Repo.InsertTransfer(ctx, t); err != nil {
		if idem != "" && s.replayed(w, r, a.ID, idem, "WITHDRAWAL", in.Method, amount, bankID) {
			return
		}
		httpx.Fail(w, r, err)
		return
	}
	if bank != nil {
		t.DWBankID = bank.DWBankID
	}
	status, err := s.submitWithdrawal(ctx, t, owner, in.Wire, false)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	_ = s.Repo.Audit(ctx, "user:"+httpx.UserID(ctx), "withdrawal.submitted", "transfer:"+t.ID, map[string]any{"amount": amount, "method": in.Method, "status": status})
	httpx.OK(w, map[string]string{"transferId": t.ID, "status": status})
}

// ---------- 资金记录 ----------

func (s *Service) handleTransfers(w http.ResponseWriter, r *http.Request) {
	typ := r.URL.Query().Get("type")
	if typ != "" && typ != "DEPOSIT" && typ != "WITHDRAWAL" {
		httpx.Fail(w, r, httpx.Validation("", httpx.FieldError{Field: "type", Reason: "类型只能是 DEPOSIT 或 WITHDRAWAL"}))
		return
	}
	var before *time.Time
	if c := r.URL.Query().Get("cursor"); c != "" {
		raw, err := base64.RawURLEncoding.DecodeString(c)
		t, perr := time.Parse(time.RFC3339Nano, string(raw))
		if err != nil || perr != nil {
			httpx.Fail(w, r, httpx.Validation("", httpx.FieldError{Field: "cursor", Reason: "翻页参数无效"}))
			return
		}
		before = &t
	}
	a, err := s.Account(r.Context(), httpx.UserID(r.Context()))
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	if a == nil {
		httpx.OK(w, []Transfer{})
		return
	}
	const page = 50
	list, err := s.Repo.ListTransfers(r.Context(), a.ID, typ, before, page)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	if len(list) == page { // 下一页游标放在响应头，不改变契约中 data 为数组的结构
		w.Header().Set("X-Next-Cursor", base64.RawURLEncoding.EncodeToString([]byte(list[len(list)-1].SubmittedAt.Format(time.RFC3339Nano))))
	}
	httpx.OK(w, list)
}

// ---------- 资金汇总 / 电汇指引 ----------

func (s *Service) handleMoney(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	a, err := s.Account(ctx, httpx.UserID(ctx))
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	if a == nil || a.DWAccountID == "" {
		httpx.Fail(w, r, httpx.Conflict("交易账户尚未开立"))
		return
	}
	var m dwMoney
	if err := s.DW.Do(ctx, http.MethodGet, pathMoney(a.DWAccountID), nil, &m); err != nil {
		httpx.Fail(w, r, s.dwFail(ctx, "money", err))
		return
	}
	httpx.OK(w, m.view())
}

func (s *Service) handleInstructions(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	a, err := s.account(ctx)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	var d dwInstructions
	if err := s.DW.Do(ctx, http.MethodGet, pathInstructions(a.DWAccountID), nil, &d); err != nil {
		httpx.Fail(w, r, s.dwFail(ctx, "deposit_instructions", err))
		return
	}
	name, _ := s.LegalName(ctx, httpx.UserID(ctx))
	var addr []string
	for _, k := range []string{"addressLine1", "city", "stateProvince", "zipPostalCode", "country"} {
		if v, ok := d.WireDetails.RawAddress[k].(string); ok && v != "" {
			addr = append(addr, v)
		}
	}
	routing := d.WireDomestic.BankRoutingNumber
	if routing == "" {
		routing = d.ACHDetails.BankRoutingNumber
	}
	httpx.OK(w, map[string]string{
		"beneficiaryName": d.WireDetails.BeneficiaryName,
		"bankName":        d.WireDetails.BankName,
		"bankAddress":     strings.Join(addr, ", "),
		"accountNumber":   d.WireDetails.BankAccountNumber,
		"routingNumber":   routing,
		"swift":           d.WireDetails.BankSwiftCode,
		"reference":       strings.TrimSpace(a.AccountNo + " " + name), // api-spec：附言必含账户号 + 姓名
	})
}
