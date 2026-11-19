package funding

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// DW 资金接口适配（依据 DW 文档 depositing-1、withdrawing-1 与参考页，2026-11-19 查阅；字段以沙盒实测为准）。
// 路径相对 DW_BASE_URL（已含 /back-office）。

const (
	pathBanks       = "/bank-accounts"
	pathDeposits    = "/funding/deposits"
	pathRedemptions = "/funding/redemptions"
)

func pathMoney(dwAccountID string) string { return "/accounts/" + dwAccountID + "/summary/money" }

func pathInstructions(dwAccountID string) string {
	return "/accounts/" + dwAccountID + "/funding/deposit-instructions"
}

// ---------- 金额（分为单位的整数，避免浮点误差） ----------

var amountRE = regexp.MustCompile(`^\d{1,12}(\.\d{1,2})?$`)

// ParseAmount 只接受最多两位小数的正数（numeric(18,2) 会静默四舍五入，必须在接口层拒绝）。
func ParseAmount(n json.Number) (int64, error) {
	s := strings.TrimSpace(n.String())
	if !amountRE.MatchString(s) {
		return 0, errors.New("金额格式不正确（最多两位小数）")
	}
	r, ok := new(big.Rat).SetString(s)
	if !ok {
		return 0, errors.New("金额格式不正确")
	}
	cents := new(big.Rat).Mul(r, big.NewRat(100, 1))
	if !cents.IsInt() || cents.Sign() <= 0 {
		return 0, errors.New("金额须大于 0")
	}
	return cents.Num().Int64(), nil
}

// AmountFromJSON：契约中金额为 JSON number（openapi Money），字符串、null 一律拒绝。
func AmountFromJSON(raw json.RawMessage) (int64, error) {
	t := bytes.TrimSpace(raw)
	if len(t) == 0 || t[0] == '"' || bytes.Equal(t, []byte("null")) {
		return 0, errors.New("请输入金额")
	}
	return ParseAmount(json.Number(t))
}

// Cents 格式化为 "123.45"。
func Cents(c int64) string { return fmt.Sprintf("%d.%02d", c/100, c%100) }

// CentsOf 把配置中的美元金额（float64）转为分。
func CentsOf(usd float64) int64 { return int64(usd*100 + 0.5) }

// parseCents 解析数据库 numeric 文本。
func parseCents(s string) int64 {
	n, _ := ParseAmount(json.Number(strings.TrimSpace(s)))
	return n
}

// ---------- 绑卡 ----------

func linkBankBody(dwUserID, accountNumber, routingNumber, typ, nickname, ownerName string) map[string]any {
	return map[string]any{
		"userID":              dwUserID,
		"bankAccountNumber":   accountNumber,
		"bankRoutingNumber":   routingNumber,
		"bankAccountType":     typ,
		"bankAccountNickname": nickname,
		// 户名：后端强制为开户法定姓名（不信任客户端）；DW 对该字段的校验方式待确认
		"beneficiaryDetails": map[string]any{"accountHolderName": ownerName},
	}
}

type dwBankRes struct {
	ID          string `json:"id"`
	Status      any    `json:"status"`
	BankDetails struct {
		BankName string `json:"bankName"`
	} `json:"bankAccountDetails"`
}

// ---------- 入金 / 出金 ----------

func depositBody(accountNo string, cents int64, dwBankID string) map[string]any {
	return map[string]any{
		"accountNo":     accountNo,
		"amount":        json.Number(Cents(cents)),
		"currency":      "USD",
		"type":          "ACH",
		"bankAccountID": dwBankID,
	}
}

// Wire：WIRE 出金收款信息（收款人姓名由后端强制为开户法定姓名，客户端不传）。
type Wire struct {
	BankName          string `json:"bankName"`
	AccountNumber     string `json:"accountNumber"`
	SwiftOrAba        string `json:"swiftOrAba"`
	Country           string `json:"country"`
	IntermediarySwift string `json:"intermediarySwift,omitempty"`
}

var abaRE = regexp.MustCompile(`^\d{9}$`)

func redemptionBody(accountNo string, cents int64, method, dwBankID, beneficiary string, w *Wire) map[string]any {
	b := map[string]any{"accountNo": accountNo, "amount": json.Number(Cents(cents)), "currency": "USD", "type": method}
	if method == "ACH" {
		b["bankAccountID"] = dwBankID
		return b
	}
	details := map[string]any{
		"beneficiaryName":          beneficiary,
		"beneficiaryAccountNumber": w.AccountNumber,
		"beneficiaryBankName":      w.BankName,
		"beneficiaryBankCountry":   w.Country,
	}
	if abaRE.MatchString(w.SwiftOrAba) {
		details["beneficiaryRoutingNumber"] = w.SwiftOrAba
	} else {
		details["beneficiarySwiftABA"] = w.SwiftOrAba // 境外 SWIFT 的字段名待沙盒验证
	}
	if w.IntermediarySwift != "" {
		details["intermediaryBankSwift"] = w.IntermediarySwift // 字段名待沙盒验证
	}
	b["details"] = details
	return b
}

type dwTransferRes struct {
	ID     string `json:"id"`
	Status any    `json:"status"`
}

// statusOf：DW 状态可能是 {id, message, updated}（入金文档）、{name}、或字符串；
// 出金枚举 On_Hold 拼写与入金不同，统一为 ON_HOLD。
func statusOf(v any) string {
	var s string
	switch x := v.(type) {
	case string:
		s = x
	case map[string]any:
		for _, k := range []string{"message", "name"} {
			if m, ok := x[k].(string); ok && m != "" {
				s = m
				break
			}
		}
		if s == "" {
			if id, ok := x["id"].(float64); ok {
				s = statusByNumber[int(id)]
			}
		}
	}
	s = strings.ToUpper(strings.TrimSpace(s))
	return s
}

// statusByNumber：DW Deposit / Redemption Status 编号（deposit-status.md、redemption-status.md）。
var statusByNumber = map[int]string{0: "STARTED", 1: "PENDING", 2: "SUCCESSFUL", 3: "FAILED", 4: "OTHER", 5: "RETURNED",
	11: "RIA_PENDING", 12: "RIA_APPROVED", 13: "RIA_REJECTED", 14: "APPROVED", 15: "REJECTED", 16: "ON_HOLD"}

// failureText：给用户看的失败原因（不透出 DW 原文）。
func failureText(status string) *string {
	m := map[string]string{
		"FAILED":       "处理失败，请稍后重试或联系客服",
		"REJECTED":     "未通过券商审核，请联系客服",
		"RETURNED":     "银行已退回该笔资金，请核对银行账户信息",
		"RIA_REJECTED": "未通过审核，请联系客服",
	}[status]
	if m == "" {
		return nil
	}
	return &m
}

// ---------- 资金汇总（GET /accounts/{id}/summary/money） ----------

type dwMoney struct {
	Updated string `json:"updated"`
	Cash    struct {
		CashAvailableForTrade      json.Number `json:"cashAvailableForTrade"`
		CashAvailableForWithdrawal json.Number `json:"cashAvailableForWithdrawal"`
		CashBalance                json.Number `json:"cashBalance"`
		CashPendingSettlement      json.Number `json:"cashPendingSettlement"`
	} `json:"cash"`
	Payments struct {
		BuyingPower struct {
			PendingAvailable    json.Number `json:"pendingDepositsAmountAvailable"`
			PendingNotAvailable json.Number `json:"pendingDepositsAmountNotAvailable"`
		} `json:"buyingPower"`
		Redemptions struct {
			Withheld json.Number `json:"amountWithheldFromRedemptions"`
		} `json:"redemptions"`
	} `json:"payments"`
}

// Money：GET /account/money 的数据（api-spec.md 第 3 节；可提现一律用 DW 返回值）。金额为 JSON number（契约 Money）。
type Money struct {
	Cash                       json.Number `json:"cash"`
	SettledCash                json.Number `json:"settledCash"`
	BuyingPower                json.Number `json:"buyingPower"`
	CashAvailableForWithdrawal json.Number `json:"cashAvailableForWithdrawal"`
	Unsettled                  json.Number `json:"unsettled"`
	PendingDeposits            json.Number `json:"pendingDeposits"`      // 新增：尚未计入购买力的在途入金
	WithheldForSeasoning       json.Number `json:"withheldForSeasoning"` // 新增：因观察期未计入可提现的金额
	UpdatedAt                  *time.Time  `json:"updatedAt"`
}

func num(n json.Number) float64 {
	f, _ := strconv.ParseFloat(n.String(), 64)
	return f
}

func usd(f float64) json.Number { return json.Number(strconv.FormatFloat(f, 'f', 2, 64)) }

func (m dwMoney) view() Money {
	bal, pend := num(m.Cash.CashBalance), num(m.Cash.CashPendingSettlement)
	v := Money{
		Cash:                       usd(bal),
		SettledCash:                usd(bal - pend),
		BuyingPower:                usd(num(m.Cash.CashAvailableForTrade)),
		CashAvailableForWithdrawal: usd(num(m.Cash.CashAvailableForWithdrawal)),
		Unsettled:                  usd(pend),
		PendingDeposits:            usd(num(m.Payments.BuyingPower.PendingNotAvailable)),
		WithheldForSeasoning:       usd(num(m.Payments.Redemptions.Withheld)),
	}
	if t, err := time.Parse(time.RFC3339, m.Updated); err == nil {
		v.UpdatedAt = &t
	}
	return v
}

func (m dwMoney) withdrawableCents() int64 {
	return int64(num(m.Cash.CashAvailableForWithdrawal)*100 + 1e-6)
}

// ---------- 电汇入金指引 ----------

type dwInstructions struct {
	WireDetails struct {
		BankAccountNumber string         `json:"bankAccountNumber"`
		BankName          string         `json:"bankName"`
		BankSwiftCode     string         `json:"bankSwiftCode"`
		RawAddress        map[string]any `json:"bankAddress"`
		BeneficiaryName   string         `json:"beneficiaryName"`
	} `json:"wireDetails"`
	ACHDetails struct {
		BankRoutingNumber string `json:"bankRoutingNumber"`
	} `json:"achDetails"`
	WireDomestic struct {
		BankRoutingNumber string `json:"bankRoutingNumber"`
	} `json:"wireDomesticDetails"`
}
