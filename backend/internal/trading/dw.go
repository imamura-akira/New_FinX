package trading

import (
	"encoding/json"
	"math"
	"strconv"
	"strings"
	"time"
)

// DW 交易接口适配（DW 参考文档 Create Order / Retrieve Order / Update Order / List Account Positions，2026-11-20 查阅；
// 沙盒实测排在 2026-11-23，未实测项见 design/sandbox-log.md "F14 交易模块：未实测项与假设"）。
// 路径相对 DW_BASE_URL（已含 /back-office）。

const pathOrders = "/orders"

func pathOrder(dwOrderID string) string { return pathOrders + "/" + dwOrderID }

func pathPositions(dwAccountID string) string {
	return "/accounts/" + dwAccountID + "/summary/positions"
}

func pathMoney(dwAccountID string) string { return "/accounts/" + dwAccountID + "/summary/money" }

// orderBody：市价单。quantity 与 amountCash 二选一（DW 错误码 O015）。
func orderBody(accountNo, symbol, side string, qty, notional *string, preventQueuing bool) map[string]any {
	b := map[string]any{"accountNo": accountNo, "orderType": "MARKET", "symbol": symbol, "side": side}
	if qty != nil {
		b["quantity"] = json.Number(*qty)
	} else if notional != nil {
		b["amountCash"] = json.Number(*notional)
	}
	if preventQueuing {
		b["preventQueuing"] = true
	}
	return b
}

// dwCreateRes：文档为 {orderId, orderNo}；旧版 / 示例中也见 {id}，两者都读（sandbox-log T-1）。
type dwCreateRes struct {
	OrderID string `json:"orderId"`
	ID      string `json:"id"`
	OrderNo string `json:"orderNo"`
}

func (r dwCreateRes) id() string {
	if r.OrderID != "" {
		return r.OrderID
	}
	return r.ID
}

// dwOrder：GET /orders/{orderID}。
type dwOrder struct {
	ID                 string   `json:"id"`
	OrderNo            string   `json:"orderNo"`
	Status             any      `json:"status"`
	CumulativeQuantity *float64 `json:"cumulativeQuantity"`
	AveragePrice       *float64 `json:"averagePrice"`
	TotalOrderAmount   *float64 `json:"totalOrderAmount"`
	Fees               *float64 `json:"fees"`
	StatusMessage      *struct {
		Message string `json:"message"`
		Reason  string `json:"reason"`
	} `json:"statusMessage"`
}

// 订单状态（DW Order Status）+ 我方 SUBMITTING。
const (
	StatusSubmitting    = "SUBMITTING"
	StatusNew           = "NEW"
	StatusPartialFill   = "PARTIAL_FILL"
	StatusFilled        = "FILLED"
	StatusRejected      = "REJECTED"
	StatusCanceled      = "CANCELED"
	StatusPendingCancel = "PENDING_CANCEL"
)

var knownStatus = map[string]bool{StatusNew: true, StatusPartialFill: true, StatusFilled: true, StatusRejected: true, StatusCanceled: true, StatusPendingCancel: true}

// Terminal：不再刷新的状态。
func Terminal(s string) bool { return s == StatusFilled || s == StatusRejected || s == StatusCanceled }

// Cancellable：可撤单的状态。
func Cancellable(s string) bool { return s == StatusNew || s == StatusPartialFill }

// statusOf：文档为字符串枚举；兼容 {message}/{name} 对象与 CANCELLED 拼写。未知取值返回 ""。
func statusOf(v any) string {
	var s string
	switch x := v.(type) {
	case string:
		s = x
	case map[string]any:
		for _, k := range []string{"name", "message"} {
			if m, ok := x[k].(string); ok && m != "" {
				s = m
				break
			}
		}
	}
	s = strings.ToUpper(strings.ReplaceAll(strings.TrimSpace(s), " ", "_"))
	switch s {
	case "CANCELLED":
		s = StatusCanceled
	case "PARTIALLY_FILLED":
		s = StatusPartialFill
	}
	if !knownStatus[s] {
		return ""
	}
	return s
}

// rejectText：给用户看的拒单原因（不透出 DW 原文；常见原因细分，其余通用文案）。
func rejectText(status, dwReason string) *string {
	if status != StatusRejected {
		return nil
	}
	r := strings.ToLower(dwReason)
	msg := "券商已拒绝该订单，请稍后重试或联系客服"
	switch {
	case strings.Contains(r, "buying power") || strings.Contains(r, "insufficient"):
		msg = "购买力不足，券商已拒绝该订单"
	case strings.Contains(r, "market") && (strings.Contains(r, "closed") || strings.Contains(r, "hours")):
		msg = "当前不在交易时段，券商已拒绝该订单"
	case strings.Contains(r, "fraction") || strings.Contains(r, "order size") || strings.Contains(r, "minimum"):
		msg = "下单数量或金额不符合券商要求，券商已拒绝该订单"
	case strings.Contains(r, "position") || strings.Contains(r, "short"):
		msg = "可卖持仓不足，券商已拒绝该订单"
	}
	return &msg
}

func (d dwOrder) reason() string {
	if d.StatusMessage == nil {
		return ""
	}
	return strings.TrimSpace(strings.Trim(d.StatusMessage.Message+" "+d.StatusMessage.Reason, " "))
}

// dwPositions：GET /accounts/{accountID}/summary/positions。
type dwPositions struct {
	Updated         string  `json:"updated"`
	EquityValue     float64 `json:"equityValue"`
	EquityPositions []struct {
		Symbol                 string  `json:"symbol"`
		OpenQty                float64 `json:"openQty"`
		AvailableForTradingQty float64 `json:"availableForTradingQty"`
		AvgPrice               float64 `json:"avgPrice"`
		CostBasis              float64 `json:"costBasis"`
		MktPrice               float64 `json:"mktPrice"`
		MarketValue            float64 `json:"marketValue"`
		UnrealizedPL           float64 `json:"unrealizedPL"`
		UnrealizedDayPL        float64 `json:"unrealizedDayPL"`
	} `json:"equityPositions"`
}

// Position：GET /positions 条目（全部为 DW 返回值）。
type Position struct {
	Symbol          string      `json:"symbol"`
	Quantity        json.Number `json:"quantity"`
	SellableQty     json.Number `json:"sellableQty"`
	AvgPrice        json.Number `json:"avgPrice"`
	CostBasis       json.Number `json:"costBasis"`
	MarketPrice     json.Number `json:"marketPrice"`
	MarketValue     json.Number `json:"marketValue"`
	UnrealizedPL    json.Number `json:"unrealizedPL"`
	UnrealizedDayPL json.Number `json:"unrealizedDayPL"`
}

// Positions：GET /positions 的数据。
type Positions struct {
	UpdatedAt   *time.Time  `json:"updatedAt"`
	EquityValue json.Number `json:"equityValue"`
	Positions   []Position  `json:"positions"`
}

func (p dwPositions) view() Positions {
	v := Positions{EquityValue: fnum(p.EquityValue), Positions: []Position{}}
	if t, err := time.Parse(time.RFC3339, p.Updated); err == nil {
		v.UpdatedAt = &t
	}
	for _, e := range p.EquityPositions {
		if e.OpenQty == 0 {
			continue
		}
		v.Positions = append(v.Positions, Position{
			Symbol: e.Symbol, Quantity: fnum(e.OpenQty), SellableQty: fnum(e.AvailableForTradingQty),
			AvgPrice: fnum(e.AvgPrice), CostBasis: fnum(e.CostBasis), MarketPrice: fnum(e.MktPrice), MarketValue: fnum(e.MarketValue),
			UnrealizedPL: fnum(e.UnrealizedPL), UnrealizedDayPL: fnum(e.UnrealizedDayPL),
		})
	}
	return v
}

// dwMoney：只取购买力（cash.cashAvailableForTrade，与 GET /account/money 的 buyingPower 同源）。
type dwMoney struct {
	Cash struct {
		CashAvailableForTrade json.Number `json:"cashAvailableForTrade"`
	} `json:"cash"`
}

func (m dwMoney) buyingPowerCents() int64 {
	f, _ := strconv.ParseFloat(m.Cash.CashAvailableForTrade.String(), 64)
	return int64(math.Floor(f*100 + 1e-6))
}

// fnum：DW double → JSON number（不加多余精度）。
func fnum(f float64) json.Number { return json.Number(strconv.FormatFloat(f, 'f', -1, 64)) }
