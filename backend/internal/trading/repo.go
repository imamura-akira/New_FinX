package trading

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"strings"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/store"
)

// Order：orders 行与 API 视图（api-spec.md 5.6）。数字以数据库 numeric 文本输出为 JSON number。
type Order struct {
	ID           string       `json:"orderId"`
	OrderNo      *string      `json:"orderNo"`
	Symbol       string       `json:"symbol"`
	Side         string       `json:"side"`
	OrderType    string       `json:"orderType"`
	Quantity     *json.Number `json:"quantity"`
	Amount       *json.Number `json:"amount"`
	Status       string       `json:"status"`
	FilledQty    *json.Number `json:"filledQty"`
	AvgPrice     *json.Number `json:"avgPrice"`
	TotalAmount  *json.Number `json:"totalAmount"`
	Fees         *json.Number `json:"fees"`
	LimitPrice   *json.Number `json:"limitPrice"`  // 限价单（F14 扩展）
	TimeInForce  *string      `json:"timeInForce"` // 限价单：DAY
	RejectReason *string      `json:"rejectReason"`
	SubmittedAt  time.Time    `json:"submittedAt"`
	UpdatedAt    time.Time    `json:"updatedAt"`
	DoneAt       *time.Time   `json:"doneAt"`

	AccountID      string  `json:"-"`
	DWOrderID      string  `json:"-"`
	DWAccountNo    string  `json:"-"`
	IdempotencyKey string  `json:"-"`
	CreatedBy      string  `json:"-"`
	DWReason       *string `json:"-"` // DW 原始原因，只入库与日志
}

// Fill：从 DW 刷新的字段。
type Fill struct {
	Status       string
	OrderNo      string
	FilledQty    *string
	AvgPrice     *string
	TotalAmount  *string
	Fees         *string
	RejectReason *string
	DWReason     *string
	DoneAt       *time.Time
}

// ErrNotFound：订单不存在或不属于当前用户。
var ErrNotFound = errors.New("trading: not found")

// Repo：持久化。
type Repo interface {
	InsertOrder(ctx context.Context, o Order) (string, error)
	// OrderByIdemKey：本账户下使用该幂等键的订单（App 重试去重）；没有时返回 ErrNotFound。
	OrderByIdemKey(ctx context.Context, accountID, key string) (*Order, error)
	SetSubmitted(ctx context.Context, id, dwOrderID, dwOrderNo string, now time.Time) error
	DeleteOrder(ctx context.Context, id string) error // DW 明确拒绝创建时撤销本地记录
	RecentDuplicate(ctx context.Context, o Order, since time.Time) (bool, error)
	ListOrders(ctx context.Context, accountID, filter string, before *time.Time, limit int) ([]Order, error) // filter: "" / OPEN / CLOSED
	GetOrder(ctx context.Context, accountID, id string) (*Order, error)
	UpdateOrder(ctx context.Context, id string, f Fill, now time.Time) error
	DueOrders(ctx context.Context, checkedBefore time.Time, limit int) ([]Order, error)
	TouchOrder(ctx context.Context, id string, now time.Time) error
	Audit(ctx context.Context, actor, action, target string, detail map[string]any) error
}

// openStatuses：未完结（需刷新）的状态。
var openStatuses = []string{StatusSubmitting, StatusNew, StatusPartialFill, StatusPendingCancel}

// IsOpen 是否未完结。
func IsOpen(s string) bool {
	for _, o := range openStatuses {
		if s == o {
			return true
		}
	}
	return false
}

// openSQL：openStatuses 的 SQL 字面量（常量，非用户输入）。
const openSQL = `('SUBMITTING', 'NEW', 'PARTIAL_FILL', 'PENDING_CANCEL')`

// PGRepo：Postgres 实现。
type PGRepo struct{ DB *sql.DB }

const orderCols = `o.id, o.dw_order_no, o.symbol, o.side, o.order_type, o.quantity::text, o.notional::text, o.status,
	o.filled_qty::text, o.avg_price::text, o.total_amount::text, o.fees::text, o.reject_reason, o.submitted_at, o.updated_at, o.done_at,
	o.account_id, coalesce(o.dw_order_id, ''), coalesce(a.account_no, ''), o.idempotency_key::text, coalesce(o.created_by::text, ''), o.dw_reason,
	o.limit_price::text, o.time_in_force`

const orderFrom = ` FROM orders o JOIN accounts a ON a.id = o.account_id`

// trimNum 去掉 numeric 文本多余的小数零（"1.50000000" → "1.5"）。
func trimNum(s sql.NullString) *json.Number {
	if !s.Valid {
		return nil
	}
	v := s.String
	if strings.Contains(v, ".") {
		v = strings.TrimRight(strings.TrimRight(v, "0"), ".")
	}
	n := json.Number(v)
	return &n
}

func scanOrder(row interface{ Scan(...any) error }) (Order, error) {
	var o Order
	var no, reason, dwReason sql.NullString
	var qty, notional, filled, avg, total, fees, limit, tif sql.NullString
	err := row.Scan(&o.ID, &no, &o.Symbol, &o.Side, &o.OrderType, &qty, &notional, &o.Status,
		&filled, &avg, &total, &fees, &reason, &o.SubmittedAt, &o.UpdatedAt, &o.DoneAt,
		&o.AccountID, &o.DWOrderID, &o.DWAccountNo, &o.IdempotencyKey, &o.CreatedBy, &dwReason, &limit, &tif)
	if err != nil {
		return o, err
	}
	if no.Valid {
		o.OrderNo = &no.String
	}
	if reason.Valid {
		o.RejectReason = &reason.String
	}
	if dwReason.Valid {
		o.DWReason = &dwReason.String
	}
	o.LimitPrice = trimNum(limit)
	if tif.Valid {
		o.TimeInForce = &tif.String
	}
	o.Quantity, o.Amount, o.FilledQty, o.AvgPrice, o.TotalAmount, o.Fees = trimNum(qty), trimNum(notional), trimNum(filled), trimNum(avg), trimNum(total), trimNum(fees)
	o.SubmittedAt, o.UpdatedAt = o.SubmittedAt.UTC(), o.UpdatedAt.UTC()
	if o.DoneAt != nil {
		t := o.DoneAt.UTC()
		o.DoneAt = &t
	}
	return o, nil
}

func numArg(n *json.Number) any {
	if n == nil {
		return nil
	}
	return n.String()
}

func strArg(s *string) any {
	if s == nil {
		return nil
	}
	return *s
}

func (p PGRepo) InsertOrder(ctx context.Context, o Order) (string, error) {
	var id string
	var createdBy any
	if o.CreatedBy != "" {
		createdBy = o.CreatedBy
	}
	err := p.DB.QueryRowContext(ctx, `INSERT INTO orders (account_id, symbol, side, order_type, quantity, notional, status, idempotency_key, created_by,
		limit_price, time_in_force)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11) RETURNING id`,
		o.AccountID, o.Symbol, o.Side, o.OrderType, numArg(o.Quantity), numArg(o.Amount), o.Status, o.IdempotencyKey, createdBy,
		numArg(o.LimitPrice), strArg(o.TimeInForce)).Scan(&id)
	return id, err
}

func (p PGRepo) SetSubmitted(ctx context.Context, id, dwOrderID, dwOrderNo string, now time.Time) error {
	_, err := p.DB.ExecContext(ctx, `UPDATE orders SET dw_order_id = $2, dw_order_no = nullif($3, ''), status = $4, updated_at = $5, checked_at = $5
		WHERE id = $1`, id, dwOrderID, dwOrderNo, StatusNew, now)
	return err
}

func (p PGRepo) DeleteOrder(ctx context.Context, id string) error {
	_, err := p.DB.ExecContext(ctx, `DELETE FROM orders WHERE id = $1 AND dw_order_id IS NULL`, id)
	return err
}

func (p PGRepo) RecentDuplicate(ctx context.Context, o Order, since time.Time) (bool, error) {
	var n int
	err := p.DB.QueryRowContext(ctx, `SELECT count(*) FROM orders WHERE account_id = $1 AND symbol = $2 AND side = $3
		AND quantity IS NOT DISTINCT FROM $4::numeric AND notional IS NOT DISTINCT FROM $5::numeric AND submitted_at >= $6
		AND order_type = $7 AND limit_price IS NOT DISTINCT FROM $8::numeric`,
		o.AccountID, o.Symbol, o.Side, numArg(o.Quantity), numArg(o.Amount), since, o.OrderType, numArg(o.LimitPrice)).Scan(&n)
	return n > 0, err
}

func (p PGRepo) ListOrders(ctx context.Context, accountID, filter string, before *time.Time, limit int) ([]Order, error) {
	rows, err := p.DB.QueryContext(ctx, `SELECT `+orderCols+orderFrom+`
		WHERE o.account_id = $1
		  AND ($2 = '' OR ($2 = 'OPEN') = (o.status IN `+openSQL+`))
		  AND ($3::timestamptz IS NULL OR o.submitted_at < $3)
		ORDER BY o.submitted_at DESC LIMIT $4`, accountID, filter, before, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Order{}
	for rows.Next() {
		o, err := scanOrder(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, o)
	}
	return out, rows.Err()
}

func (p PGRepo) OrderByIdemKey(ctx context.Context, accountID, key string) (*Order, error) {
	o, err := scanOrder(p.DB.QueryRowContext(ctx, `SELECT `+orderCols+orderFrom+` WHERE o.account_id = $1 AND o.idempotency_key = $2::uuid`, accountID, key))
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &o, nil
}

func (p PGRepo) GetOrder(ctx context.Context, accountID, id string) (*Order, error) {
	o, err := scanOrder(p.DB.QueryRowContext(ctx, `SELECT `+orderCols+orderFrom+` WHERE o.id::text = $1 AND o.account_id = $2`, id, accountID))
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &o, nil
}

func (p PGRepo) UpdateOrder(ctx context.Context, id string, f Fill, now time.Time) error {
	_, err := p.DB.ExecContext(ctx, `UPDATE orders SET status = $2, dw_order_no = coalesce(nullif($3, ''), dw_order_no),
		filled_qty = $4, avg_price = $5, total_amount = $6, fees = $7, reject_reason = $8, dw_reason = $9,
		done_at = coalesce(done_at, $10), updated_at = $11, checked_at = $11 WHERE id = $1`,
		id, f.Status, f.OrderNo, strArg(f.FilledQty), strArg(f.AvgPrice), strArg(f.TotalAmount), strArg(f.Fees),
		strArg(f.RejectReason), strArg(f.DWReason), f.DoneAt, now)
	return err
}

func (p PGRepo) DueOrders(ctx context.Context, checkedBefore time.Time, limit int) ([]Order, error) {
	rows, err := p.DB.QueryContext(ctx, `SELECT `+orderCols+orderFrom+`
		WHERE o.status IN `+openSQL+` AND (o.checked_at IS NULL OR o.checked_at < $1)
		ORDER BY o.checked_at NULLS FIRST LIMIT $2`, checkedBefore, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Order
	for rows.Next() {
		o, err := scanOrder(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, o)
	}
	return out, rows.Err()
}

func (p PGRepo) TouchOrder(ctx context.Context, id string, now time.Time) error {
	_, err := p.DB.ExecContext(ctx, `UPDATE orders SET checked_at = $2 WHERE id = $1`, id, now)
	return err
}

func (p PGRepo) Audit(ctx context.Context, actor, action, target string, detail map[string]any) error {
	return store.Audit(ctx, p.DB, actor, action, target, detail)
}
