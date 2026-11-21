// Package trading：交易模块（F14，api-spec.md 5.6）——市价单下单、订单查询与撤单、持仓。
//
// 后端强制校验（不信任客户端，App 只做前置提示）：
//   - 买入：预估金额 ≥ 单笔最低（config.Limits.MinOrder，示例值），且 ≤ DW 实时购买力（summary/money 的 cashAvailableForTrade）；
//   - 卖出：股数 ≤ DW 可卖数量（summary/positions 的 availableForTradingQty）；按金额卖出 ≤ 可卖数量 × DW 市价；
//   - 账户 OPEN_NO_NEW_TRADES 仅可卖出，FROZEN / CLOSED 不可交易。
//
// 订单先落库（SUBMITTING + Idempotency-Key）再调 DW；结果不明时保留记录，由 Sync 用原键重放（DW 保存 4 天）。
package trading

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"math"
	"math/big"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/account"
	"github.com/imamura-akira/New_FinX/backend/internal/dwclient"
	"github.com/imamura-akira/New_FinX/backend/internal/funding"
	"github.com/imamura-akira/New_FinX/backend/internal/httpx"
	"github.com/imamura-akira/New_FinX/backend/internal/orderrules"
)

// DW：所需的 DW 能力（*dwclient.Client 满足）。
type DW interface {
	Do(ctx context.Context, method, path string, reqBody, out any) error
}

// Deps：外部依赖。
type Deps struct {
	Repo    Repo
	DW      DW
	Account func(ctx context.Context, userID string) (*account.Account, error)
	// Price 返回演示行情的参考价（卖一价，无则最新价），用于按股数买入时估算金额；ok=false 表示无报价。
	Price          func(symbol string) (price float64, ok bool)
	MinOrder       float64 // 单笔最低下单金额（USD，示例值）
	PreventQueuing bool    // DW preventQueuing（sandbox-log T-3）
	Logger         *slog.Logger
}

// Service：交易模块。
type Service struct {
	Deps
	now func() time.Time
}

// New 创建模块。
func New(d Deps) *Service {
	if d.Logger == nil {
		d.Logger = slog.Default()
	}
	if d.MinOrder <= 0 {
		d.MinOrder = 1
	}
	return &Service{Deps: d, now: time.Now}
}

// Routes 注册接口。
func (s *Service) Routes(mux *http.ServeMux, prefix string, auth func(http.Handler) http.Handler) {
	h := func(f http.HandlerFunc) http.Handler { return auth(f) }
	mux.Handle("POST "+prefix+"/orders", h(s.handleCreate))
	mux.Handle("GET "+prefix+"/orders", h(s.handleList))
	mux.Handle("GET "+prefix+"/orders/{id}", h(s.handleGet))
	mux.Handle("POST "+prefix+"/orders/{id}/cancel", h(s.handleCancel))
	mux.Handle("GET "+prefix+"/positions", h(s.handlePositions))
}

// ---------- 公共 ----------

func (s *Service) openedAccount(ctx context.Context) (*account.Account, error) {
	a, err := s.Account(ctx, httpx.UserID(ctx))
	if err != nil {
		return nil, err
	}
	if a == nil || a.DWAccountID == "" {
		return nil, httpx.Conflict("交易账户尚未开立")
	}
	return a, nil
}

// tradable：可下单的账户。OPEN_NO_NEW_TRADES 仅可卖出。
func (s *Service) tradable(ctx context.Context, side string) (*account.Account, error) {
	a, err := s.openedAccount(ctx)
	if err != nil {
		return nil, err
	}
	switch a.Status {
	case "OPEN":
		return a, nil
	case "OPEN_NO_NEW_TRADES":
		if side == "SELL" {
			return a, nil
		}
		return nil, &httpx.Error{HTTP: http.StatusForbidden, Code: httpx.CodeRestricted, Message: "账户当前仅可卖出，暂不能买入",
			Data: map[string]string{"restriction": a.Status}}
	case "FROZEN", "CLOSED":
		return nil, httpx.Restricted(a.Status)
	default:
		return nil, httpx.Conflict("交易账户尚未开通")
	}
}

func (s *Service) dwFail(ctx context.Context, op string, err error) error {
	var ae *dwclient.APIError
	if errors.As(err, &ae) {
		s.Logger.WarnContext(ctx, "dw trading call failed", slog.String("op", op), slog.Int("status", ae.Status), slog.String("dw_code", ae.DWCode))
	} else {
		s.Logger.WarnContext(ctx, "dw trading call failed", slog.String("op", op), slog.String("error", err.Error()))
	}
	return httpx.DWFailed()
}

func limitErr(msg string, limits map[string]string) error {
	return &httpx.Error{HTTP: http.StatusUnprocessableEntity, Code: httpx.CodeLimit, Message: msg, Data: map[string]any{"limits": limits}}
}

// orderFingerprint：同一幂等键的重试必须是同一笔订单。
type orderFingerprint struct {
	symbol, side, orderType string
	byAmount                bool
	amountCents             int64
	qty, limitPrice         float64
}

func numOf(n *json.Number) float64 {
	if n == nil {
		return 0
	}
	f, _ := n.Float64()
	return f
}

// replayed：本账户已有使用该幂等键的订单时，按原订单作答并返回 true（审计 FUND-P0-1）。
//   - 内容不同：422，不覆盖原订单；
//   - 原订单尚无 DW 编号（提交中 / 结果不明）：502 50001 + orderId；
//   - 否则：200 + 原订单的 orderId 与状态。
func (s *Service) replayed(w http.ResponseWriter, r *http.Request, accountID, key string, want orderFingerprint) bool {
	o, err := s.Repo.OrderByIdemKey(r.Context(), accountID, key)
	if errors.Is(err, ErrNotFound) {
		return false
	}
	if err != nil {
		httpx.Fail(w, r, err)
		return true
	}
	same := o.Symbol == want.symbol && o.Side == want.side && o.OrderType == want.orderType && (o.Amount != nil) == want.byAmount &&
		math.Abs(numOf(o.LimitPrice)-want.limitPrice) < 1e-9
	if want.byAmount {
		same = same && cents(numOf(o.Amount)) == want.amountCents
	} else {
		same = same && math.Abs(numOf(o.Quantity)-want.qty) < 1e-9
	}
	if !same {
		httpx.Fail(w, r, httpx.Validation("该笔订单的请求编号已被另一笔订单使用，请返回后重新下单"))
		return true
	}
	if o.DWOrderID == "" {
		httpx.Fail(w, r, &httpx.Error{HTTP: http.StatusBadGateway, Code: httpx.CodeDWFailed, Message: "订单提交结果暂未确认，请稍后在订单列表中查看，请勿重复提交",
			Data: map[string]string{"orderId": o.ID}})
		return true
	}
	httpx.OK(w, map[string]string{"orderId": o.ID, "status": o.Status})
	return true
}

func newUUID() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:])
}

var (
	symbolRE = regexp.MustCompile(`^[A-Z][A-Z0-9.]{0,9}$`)
	qtyRE    = regexp.MustCompile(`^\d{1,9}(\.\d{1,6})?$`) // 最多 6 位小数（sandbox-log T-4）
)

// parseQty：股数为 JSON number，> 0，最多 6 位小数。
func parseQty(raw json.RawMessage) (string, float64, error) {
	t := strings.TrimSpace(string(raw))
	if t == "" || t == "null" || strings.HasPrefix(t, `"`) {
		return "", 0, errors.New("请输入股数")
	}
	if !qtyRE.MatchString(t) {
		return "", 0, errors.New("股数格式不正确（最多 6 位小数）")
	}
	r, ok := new(big.Rat).SetString(t)
	if !ok || r.Sign() <= 0 {
		return "", 0, errors.New("股数须大于 0")
	}
	f, _ := r.Float64()
	return t, f, nil
}

func present(raw json.RawMessage) bool {
	t := strings.TrimSpace(string(raw))
	return t != "" && t != "null"
}

func cents(f float64) int64 { return int64(math.Floor(f*100 + 1e-6)) }

// fmtQty：股数展示（去掉多余的零）。
func fmtQty(f float64) string { return strconv.FormatFloat(math.Floor(f*1e6+1e-6)/1e6, 'f', -1, 64) }

// ---------- 下单 ----------

func (s *Service) handleCreate(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	var in struct {
		Symbol      string          `json:"symbol"`
		Side        string          `json:"side"`
		OrderType   string          `json:"orderType"`
		Amount      json.RawMessage `json:"amount"`
		Quantity    json.RawMessage `json:"quantity"`
		LimitPrice  json.RawMessage `json:"limitPrice"`
		TimeInForce string          `json:"timeInForce"`
	}
	if err := httpx.Decode(w, r, 0, &in); err != nil {
		httpx.Fail(w, r, err)
		return
	}
	sym := strings.ToUpper(strings.TrimSpace(in.Symbol))
	var fe []httpx.FieldError
	if !symbolRE.MatchString(sym) {
		fe = append(fe, httpx.FieldError{Field: "symbol", Reason: "请选择要交易的股票"})
	}
	if in.Side != "BUY" && in.Side != "SELL" {
		fe = append(fe, httpx.FieldError{Field: "side", Reason: "请选择买入或卖出"})
	}
	limitOrder := in.OrderType == "LIMIT"
	if in.OrderType != "MARKET" && !limitOrder {
		fe = append(fe, httpx.FieldError{Field: "orderType", Reason: "请选择市价单或限价单"})
	}
	if in.TimeInForce != "" && in.TimeInForce != "DAY" {
		fe = append(fe, httpx.FieldError{Field: "timeInForce", Reason: "有效期目前只支持当日有效（DAY）"})
	}
	var (
		amountCents int64
		qtyStr      string
		qty         float64
		limitPrice  float64
		byAmount    = present(in.Amount)
	)
	if limitOrder {
		lp, err := orderrules.ParseLimitPrice(in.LimitPrice)
		if err != nil {
			fe = append(fe, httpx.FieldError{Field: "limitPrice", Reason: err.Error()})
		}
		limitPrice = lp
	}
	switch {
	case limitOrder && byAmount:
		fe = append(fe, httpx.FieldError{Field: "amount", Reason: "限价单请按股数下单"})
	case byAmount && present(in.Quantity):
		fe = append(fe, httpx.FieldError{Field: "amount", Reason: "金额与股数只能填写一项"})
	case byAmount:
		c, err := funding.AmountFromJSON(in.Amount)
		if err != nil {
			fe = append(fe, httpx.FieldError{Field: "amount", Reason: err.Error()})
		}
		amountCents = c
	default:
		q, f, err := parseQty(in.Quantity)
		if err != nil {
			fe = append(fe, httpx.FieldError{Field: "quantity", Reason: err.Error()})
		}
		qtyStr, qty = q, f
	}
	if len(fe) > 0 {
		httpx.Fail(w, r, httpx.Validation("", fe...))
		return
	}

	minC := funding.CentsOf(s.MinOrder)
	limits := map[string]string{"min": funding.Cents(minC)}
	minMsg := fmt.Sprintf("单笔最低 $%s（示例值，以券商为准）", funding.Cents(minC))
	if byAmount && amountCents < minC {
		httpx.Fail(w, r, limitErr(minMsg, limits))
		return
	}
	a, err := s.tradable(ctx, in.Side)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	// App 重试同一笔订单（同一 Idempotency-Key）：返回原订单，不再向 DW 提交（审计 FUND-P0-1）
	idem, err := httpx.ClientIdempotencyKey(r)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	want := orderFingerprint{sym, in.Side, in.OrderType, byAmount, amountCents, qty, limitPrice}
	if idem != "" && s.replayed(w, r, a.ID, idem, want) {
		return
	}

	if in.Side == "BUY" {
		est := amountCents
		if limitOrder { // 限价买单：冻结金额按限价计算
			est = int64(math.Ceil(qty*limitPrice*100 - 1e-6))
			limits["estimated"] = funding.Cents(est)
			if est < minC {
				httpx.Fail(w, r, limitErr(minMsg, limits))
				return
			}
		} else if !byAmount {
			price, ok := 0.0, false
			if s.Price != nil {
				price, ok = s.Price(sym)
			}
			if !ok || price <= 0 {
				httpx.Fail(w, r, httpx.Validation("", httpx.FieldError{Field: "quantity", Reason: "暂无该股票报价，请按金额买入"}))
				return
			}
			est = int64(math.Ceil(qty*price*100 - 1e-6))
			limits["estimated"] = funding.Cents(est)
			if est < minC {
				httpx.Fail(w, r, limitErr(minMsg, limits))
				return
			}
		}
		var m dwMoney
		if err := s.DW.Do(ctx, http.MethodGet, pathMoney(a.DWAccountID), nil, &m); err != nil {
			httpx.Fail(w, r, s.dwFail(ctx, "money", err))
			return
		}
		if bp := m.buyingPowerCents(); est > bp {
			limits["buyingPower"] = funding.Cents(bp)
			httpx.Fail(w, r, limitErr(fmt.Sprintf("超过可用购买力 $%s", funding.Cents(bp)), limits))
			return
		}
	} else {
		var p dwPositions
		if err := s.DW.Do(ctx, http.MethodGet, pathPositions(a.DWAccountID), nil, &p); err != nil {
			httpx.Fail(w, r, s.dwFail(ctx, "positions", err))
			return
		}
		sellable, mkt := 0.0, 0.0
		for _, e := range p.EquityPositions {
			if strings.EqualFold(e.Symbol, sym) {
				sellable, mkt = e.AvailableForTradingQty, e.MktPrice
			}
		}
		limits["sellableQty"] = fmtQty(sellable)
		switch {
		case sellable <= 0:
			httpx.Fail(w, r, limitErr(fmt.Sprintf("没有可卖出的 %s 持仓", sym), limits))
			return
		case !byAmount && qty > sellable+1e-9:
			httpx.Fail(w, r, limitErr(fmt.Sprintf("超过可卖数量 %s 股", fmtQty(sellable)), limits))
			return
		case byAmount && amountCents > cents(sellable*mkt):
			limits["sellableValue"] = funding.Cents(cents(sellable * mkt))
			httpx.Fail(w, r, limitErr(fmt.Sprintf("超过可卖市值 $%s", funding.Cents(cents(sellable*mkt))), limits))
			return
		}
	}

	o := Order{AccountID: a.ID, Symbol: sym, Side: in.Side, OrderType: in.OrderType, Status: StatusSubmitting,
		IdempotencyKey: newUUID(), CreatedBy: httpx.UserID(ctx), DWAccountNo: a.AccountNo}
	if idem != "" {
		o.IdempotencyKey = idem
	}
	if limitOrder {
		lp, tif := json.Number(orderrules.FormatPrice(limitPrice)), "DAY"
		o.LimitPrice, o.TimeInForce = &lp, &tif
	}
	if byAmount {
		n := json.Number(funding.Cents(amountCents))
		o.Amount = &n
	} else {
		n := json.Number(qtyStr)
		o.Quantity = &n
	}
	if dup, err := s.Repo.RecentDuplicate(ctx, o, s.now().Add(-10*time.Second)); err != nil {
		httpx.Fail(w, r, err)
		return
	} else if dup {
		httpx.Fail(w, r, httpx.Conflict("刚刚已提交过相同的订单，请勿重复提交"))
		return
	}
	if o.ID, err = s.Repo.InsertOrder(ctx, o); err != nil {
		if idem != "" && s.replayed(w, r, a.ID, idem, want) { // 同键并发请求：另一请求已落库
			return
		}
		httpx.Fail(w, r, err)
		return
	}
	status, err := s.submit(ctx, o)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	_ = s.Repo.Audit(ctx, "user:"+httpx.UserID(ctx), "order.submitted", "order:"+o.ID, map[string]any{
		"symbol": sym, "side": in.Side, "type": o.OrderType, "quantity": numArg(o.Quantity), "amount": numArg(o.Amount),
		"limitPrice": numArg(o.LimitPrice), "status": status})
	httpx.OK(w, map[string]string{"orderId": o.ID, "status": status})
}

// submit 用固定的 Idempotency-Key 调 DW（首次提交与结果不明后的重放共用），成功后立即查询一次状态。
func (s *Service) submit(ctx context.Context, o Order) (string, error) {
	var res dwCreateRes
	var qty, notional *string
	if o.Quantity != nil {
		q := o.Quantity.String()
		qty = &q
	}
	if o.Amount != nil {
		n := o.Amount.String()
		notional = &n
	}
	dctx := dwclient.WithIdempotencyKey(ctx, o.IdempotencyKey)
	var price *string
	if o.LimitPrice != nil {
		p := o.LimitPrice.String()
		price = &p
	}
	err := s.DW.Do(dctx, http.MethodPost, pathOrders, orderBody(o.DWAccountNo, o.Symbol, o.Side, o.OrderType, qty, notional, price, o.TimeInForce, s.PreventQueuing), &res)
	if err != nil {
		var ae *dwclient.APIError
		// 幂等键类错误（IK 开头）只说明缓存响应暂不可取，DW 可能已受理（2026-11-21 沙盒实测），按结果不明处理
		if errors.As(err, &ae) && ae.Status >= 400 && ae.Status < 500 && ae.Status != http.StatusTooManyRequests && !strings.HasPrefix(ae.DWCode, "IK") {
			_ = s.Repo.DeleteOrder(ctx, o.ID)
			s.Logger.WarnContext(ctx, "dw order rejected", slog.String("order_id", o.ID), slog.Int("status", ae.Status), slog.String("dw_code", ae.DWCode))
			msg := "券商未受理该笔订单，请核对后重试"
			if ae.DWCode == "O098" {
				msg = "交易账户当前不可下单，请联系客服"
			}
			return "", httpx.Validation(msg)
		}
		s.Logger.ErrorContext(ctx, "dw order outcome unknown", slog.String("order_id", o.ID), slog.String("error", err.Error()))
		return "", &httpx.Error{HTTP: http.StatusBadGateway, Code: httpx.CodeDWFailed, Message: "订单提交结果暂未确认，请稍后在订单列表中查看，请勿重复提交",
			Data: map[string]string{"orderId": o.ID}}
	}
	if res.id() == "" {
		s.Logger.ErrorContext(ctx, "dw order response unrecognized", slog.String("order_id", o.ID))
		return "", &httpx.Error{HTTP: http.StatusBadGateway, Code: httpx.CodeDWBadData, Message: "券商返回数据异常，已记录，请稍后在订单列表中查看",
			Data: map[string]string{"orderId": o.ID}}
	}
	now := s.now().UTC()
	if err := s.Repo.SetSubmitted(ctx, o.ID, res.id(), res.OrderNo, now); err != nil {
		return "", err
	}
	o.DWOrderID, o.Status = res.id(), StatusNew
	return s.refresh(ctx, o, now), nil
}

// ---------- 刷新（查询、撤单与对账共用） ----------

// refresh 向 DW 查询订单最新状态并落库，返回最新状态（失败时返回原状态）。
func (s *Service) refresh(ctx context.Context, o Order, now time.Time) string {
	if o.DWOrderID == "" {
		return o.Status
	}
	var d dwOrder
	if err := s.DW.Do(ctx, http.MethodGet, pathOrder(o.DWOrderID), nil, &d); err != nil {
		s.Logger.WarnContext(ctx, "refresh order failed", slog.String("order_id", o.ID), slog.String("error", err.Error()))
		_ = s.Repo.TouchOrder(ctx, o.ID, now)
		return o.Status
	}
	st := statusOf(d.Status)
	if st == "" {
		s.Logger.WarnContext(ctx, "dw order status unrecognized", slog.String("order_id", o.ID))
		_ = s.Repo.TouchOrder(ctx, o.ID, now)
		return o.Status
	}
	// 我方已请求撤单而 DW 仍为 NEW：保持"撤单中"，等待 DW 推进
	if o.Status == StatusPendingCancel && st == StatusNew {
		st = StatusPendingCancel
	}
	f := Fill{Status: st, OrderNo: d.OrderNo, FilledQty: optF(d.CumulativeQuantity), AvgPrice: optF(d.AveragePrice),
		TotalAmount: optF(d.TotalOrderAmount), Fees: optF(d.Fees)}
	if reason := d.reason(); reason != "" {
		f.DWReason = &reason
	}
	f.RejectReason = rejectText(st, d.reason())
	if Terminal(st) {
		f.DoneAt = &now
	}
	if err := s.Repo.UpdateOrder(ctx, o.ID, f, now); err != nil {
		s.Logger.ErrorContext(ctx, "update order failed", slog.String("order_id", o.ID), slog.String("error", err.Error()))
		return o.Status
	}
	if st != o.Status {
		_ = s.Repo.Audit(ctx, "system", "order.status", "order:"+o.ID, map[string]any{"from": o.Status, "to": st})
		s.Logger.InfoContext(ctx, "order status changed", slog.String("order_id", o.ID), slog.String("from", o.Status), slog.String("to", st))
	}
	return st
}

// optF：DW 数值（0 视为未成交 / 无数据时仍原样保留，nil 为未返回）。
func optF(f *float64) *string {
	if f == nil {
		return nil
	}
	v := string(fnum(*f))
	return &v
}

// ---------- 查询 ----------

func (s *Service) handleList(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	filter := r.URL.Query().Get("status")
	if filter != "" && filter != "OPEN" && filter != "CLOSED" {
		httpx.Fail(w, r, httpx.Validation("", httpx.FieldError{Field: "status", Reason: "状态只能是 OPEN 或 CLOSED"}))
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
	a, err := s.Account(ctx, httpx.UserID(ctx))
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	if a == nil {
		httpx.OK(w, []Order{})
		return
	}
	const page = 50
	list, err := s.Repo.ListOrders(ctx, a.ID, filter, before, page)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	// 列表只同步刷新少量未完结订单（每次 DW 查询约 0.7 秒），其余由对账任务推进
	refreshed := 0
	now := s.now().UTC()
	for i := range list {
		if refreshed >= 3 || !IsOpen(list[i].Status) || list[i].DWOrderID == "" {
			continue
		}
		refreshed++
		if st := s.refresh(ctx, list[i], now); st != list[i].Status {
			if o, err := s.Repo.GetOrder(ctx, a.ID, list[i].ID); err == nil {
				list[i] = *o
			}
		}
	}
	if len(list) == page {
		w.Header().Set("X-Next-Cursor", base64.RawURLEncoding.EncodeToString([]byte(list[len(list)-1].SubmittedAt.Format(time.RFC3339Nano))))
	}
	httpx.OK(w, list)
}

func (s *Service) loadOrder(ctx context.Context, id string) (*account.Account, *Order, error) {
	a, err := s.openedAccount(ctx)
	if err != nil {
		return nil, nil, err
	}
	o, err := s.Repo.GetOrder(ctx, a.ID, id)
	if errors.Is(err, ErrNotFound) {
		return nil, nil, httpx.Conflict("订单不存在")
	}
	return a, o, err
}

func (s *Service) handleGet(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	a, o, err := s.loadOrder(ctx, r.PathValue("id"))
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	if IsOpen(o.Status) && o.DWOrderID != "" {
		if st := s.refresh(ctx, *o, s.now().UTC()); st != o.Status {
			if n, err := s.Repo.GetOrder(ctx, a.ID, o.ID); err == nil {
				o = n
			}
		}
	}
	httpx.OK(w, o)
}

// ---------- 撤单 ----------

func (s *Service) handleCancel(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	a, o, err := s.loadOrder(ctx, r.PathValue("id"))
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	if a.Status == "CLOSED" {
		httpx.Fail(w, r, httpx.Restricted(a.Status))
		return
	}
	if !Cancellable(o.Status) || o.DWOrderID == "" {
		httpx.Fail(w, r, httpx.Conflict("该订单当前状态不可撤单"))
		return
	}
	now := s.now().UTC()
	if err := s.DW.Do(ctx, http.MethodPatch, pathOrder(o.DWOrderID), map[string]any{"method": "CANCEL"}, nil); err != nil {
		var ae *dwclient.APIError
		if errors.As(err, &ae) && ae.Status >= 400 && ae.Status < 500 && ae.Status != http.StatusTooManyRequests {
			s.Logger.WarnContext(ctx, "dw cancel rejected", slog.String("order_id", o.ID), slog.Int("status", ae.Status), slog.String("dw_code", ae.DWCode))
			s.refresh(ctx, *o, now)
			httpx.Fail(w, r, httpx.Conflict("撤单未被券商受理，订单可能已成交，请刷新查看"))
			return
		}
		httpx.Fail(w, r, s.dwFail(ctx, "cancel_order", err))
		return
	}
	_ = s.Repo.Audit(ctx, "user:"+httpx.UserID(ctx), "order.cancel_requested", "order:"+o.ID, nil)
	o.Status = StatusPendingCancel
	st := s.refresh(ctx, *o, now)
	if st == StatusPendingCancel { // 刷新失败或 DW 仍为 NEW：记为撤单中
		_ = s.Repo.UpdateOrder(ctx, o.ID, fillOf(*o, StatusPendingCancel), now)
	}
	httpx.OK(w, map[string]string{"orderId": o.ID, "status": st})
}

// fillOf：保留现有成交数据，只改状态。
func fillOf(o Order, status string) Fill {
	str := func(n *json.Number) *string {
		if n == nil {
			return nil
		}
		v := n.String()
		return &v
	}
	no := ""
	if o.OrderNo != nil {
		no = *o.OrderNo
	}
	return Fill{Status: status, OrderNo: no, FilledQty: str(o.FilledQty), AvgPrice: str(o.AvgPrice), TotalAmount: str(o.TotalAmount),
		Fees: str(o.Fees), RejectReason: o.RejectReason, DWReason: o.DWReason}
}

// ---------- 持仓 ----------

func (s *Service) handlePositions(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	a, err := s.openedAccount(ctx)
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	var p dwPositions
	if err := s.DW.Do(ctx, http.MethodGet, pathPositions(a.DWAccountID), nil, &p); err != nil {
		httpx.Fail(w, r, s.dwFail(ctx, "positions", err))
		return
	}
	httpx.OK(w, p.view())
}
