package papertrade

import (
	"context"
	"database/sql"
	"errors"
	"strconv"
	"time"
)

// ErrNotFound：订单不存在或不属于当前用户。
var ErrNotFound = errors.New("papertrade: not found")

// Repo：持久化。WithBook 在同一用户的锁内加载账户（不存在则以 initial 创建），执行 fn 后保存变化。
type Repo interface {
	WithBook(ctx context.Context, userID string, initial int64, fn func(*Book) error) error
	ListOrders(ctx context.Context, userID, filter string, before *time.Time, limit int) ([]Order, error) // filter: "" / OPEN / CLOSED
	GetOrder(ctx context.Context, userID, id string) (*Order, error)
	UsersWithOpenOrders(ctx context.Context) ([]string, error)
}

// PGRepo：Postgres 实现。
type PGRepo struct{ DB *sql.DB }

func (p PGRepo) WithBook(ctx context.Context, userID string, initial int64, fn func(*Book) error) error {
	tx, err := p.DB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()

	res, err := tx.ExecContext(ctx, `INSERT INTO paper_accounts (user_id, initial_cash, cash) VALUES ($1, $2::numeric / 100, $2::numeric / 100)
		ON CONFLICT (user_id) DO NOTHING`, userID, initial)
	if err != nil {
		return err
	}
	created, _ := res.RowsAffected()
	b := &Book{UserID: userID, Pos: map[string]*Position{}, Touched: map[string]*Order{}, IsNew: created > 0}
	var initialS, cashS string
	if err := tx.QueryRowContext(ctx, `SELECT initial_cash::text, cash::text, reset_at FROM paper_accounts WHERE user_id = $1 FOR UPDATE`, userID).
		Scan(&initialS, &cashS, &b.ResetAt); err != nil {
		return err
	}
	b.Initial, b.Cash = parseCents(initialS), parseCents(cashS)

	rows, err := tx.QueryContext(ctx, `SELECT symbol, quantity::text, cost_basis::text FROM paper_positions WHERE user_id = $1`, userID)
	if err != nil {
		return err
	}
	for rows.Next() {
		var sym, q, c string
		if err := rows.Scan(&sym, &q, &c); err != nil {
			rows.Close()
			return err
		}
		b.Pos[sym] = &Position{Symbol: sym, Qty: parseF(q), Cost: parseCents(c)}
	}
	rows.Close()

	open, err := queryOrders(ctx, tx, `WHERE o.user_id = $1 AND o.status = 'NEW' ORDER BY o.submitted_at`, userID)
	if err != nil {
		return err
	}
	for i := range open {
		b.Open = append(b.Open, &open[i])
	}

	if err := fn(b); err != nil {
		return err
	}

	if b.WasReset {
		if _, err := tx.ExecContext(ctx, `DELETE FROM paper_orders WHERE user_id = $1`, userID); err != nil {
			return err
		}
	}
	if _, err := tx.ExecContext(ctx, `UPDATE paper_accounts SET cash = $2::numeric / 100, reset_at = $3, updated_at = now() WHERE user_id = $1`,
		userID, b.Cash, b.ResetAt); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, `DELETE FROM paper_positions WHERE user_id = $1`, userID); err != nil {
		return err
	}
	for _, ps := range b.Pos {
		if _, err := tx.ExecContext(ctx, `INSERT INTO paper_positions (user_id, symbol, quantity, cost_basis) VALUES ($1, $2, $3, $4::numeric / 100)`,
			userID, ps.Symbol, ps.Qty, ps.Cost); err != nil {
			return err
		}
	}
	added := map[string]bool{}
	for _, o := range b.Added {
		added[o.ID] = true
		if _, err := tx.ExecContext(ctx, `INSERT INTO paper_orders (id, user_id, symbol, side, order_type, quantity, notional, limit_price, time_in_force,
			status, reserved_cash, filled_qty, avg_price, total_amount, reject_reason, submitted_at, done_at, updated_at)
			VALUES ($1, $2, $3, $4, $5, $6, $7::numeric / 100, $8, $9, $10, $11::numeric / 100, $12, $13, $14::numeric / 100, $15, $16, $17, $18)`,
			o.ID, userID, o.Symbol, o.Side, o.Type, o.Qty, o.Notional, o.Limit, o.TIF,
			o.Status, o.Reserved, o.FilledQty, o.AvgPrice, o.Total, o.Reason, o.SubmittedAt, o.DoneAt, o.UpdatedAt); err != nil {
			return err
		}
	}
	for id, o := range b.Touched {
		if added[id] {
			continue
		}
		if _, err := tx.ExecContext(ctx, `UPDATE paper_orders SET status = $3, reserved_cash = $4::numeric / 100, filled_qty = $5, avg_price = $6,
			total_amount = $7::numeric / 100, reject_reason = $8, done_at = $9, updated_at = $10 WHERE id = $1 AND user_id = $2`,
			id, userID, o.Status, o.Reserved, o.FilledQty, o.AvgPrice, o.Total, o.Reason, o.DoneAt, o.UpdatedAt); err != nil {
			return err
		}
	}
	return tx.Commit()
}

type querier interface {
	QueryContext(ctx context.Context, q string, args ...any) (*sql.Rows, error)
}

const orderCols = `SELECT o.id::text, o.user_id::text, o.symbol, o.side, o.order_type, o.quantity::text, o.notional::text, o.limit_price::text,
	o.time_in_force, o.status, o.reserved_cash::text, o.filled_qty::text, o.avg_price::text, o.total_amount::text, o.reject_reason,
	o.submitted_at, o.done_at, o.updated_at FROM paper_orders o `

func queryOrders(ctx context.Context, q querier, where string, args ...any) ([]Order, error) {
	rows, err := q.QueryContext(ctx, orderCols+where, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Order{}
	for rows.Next() {
		var o Order
		var qty, notional, limit, filled, avg, total sql.NullString
		var reserved string
		if err := rows.Scan(&o.ID, &o.UserID, &o.Symbol, &o.Side, &o.Type, &qty, &notional, &limit, &o.TIF, &o.Status, &reserved,
			&filled, &avg, &total, &o.Reason, &o.SubmittedAt, &o.DoneAt, &o.UpdatedAt); err != nil {
			return nil, err
		}
		o.Qty, o.Limit, o.FilledQty, o.AvgPrice = nf(qty), nf(limit), nf(filled), nf(avg)
		o.Notional, o.Total = nc(notional), nc(total)
		o.Reserved = parseCents(reserved)
		o.SubmittedAt, o.UpdatedAt = o.SubmittedAt.UTC(), o.UpdatedAt.UTC()
		if o.DoneAt != nil {
			t := o.DoneAt.UTC()
			o.DoneAt = &t
		}
		out = append(out, o)
	}
	return out, rows.Err()
}

func (p PGRepo) ListOrders(ctx context.Context, userID, filter string, before *time.Time, limit int) ([]Order, error) {
	return queryOrders(ctx, p.DB, `WHERE o.user_id = $1 AND ($2 = '' OR ($2 = 'OPEN') = (o.status = 'NEW'))
		AND ($3::timestamptz IS NULL OR o.submitted_at < $3) ORDER BY o.submitted_at DESC LIMIT $4`, userID, filter, before, limit)
}

func (p PGRepo) GetOrder(ctx context.Context, userID, id string) (*Order, error) {
	list, err := queryOrders(ctx, p.DB, `WHERE o.id::text = $1 AND o.user_id = $2`, id, userID)
	if err != nil {
		return nil, err
	}
	if len(list) == 0 {
		return nil, ErrNotFound
	}
	return &list[0], nil
}

func (p PGRepo) UsersWithOpenOrders(ctx context.Context) ([]string, error) {
	rows, err := p.DB.QueryContext(ctx, `SELECT DISTINCT user_id::text FROM paper_orders WHERE status = 'NEW'`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var s string
		if err := rows.Scan(&s); err != nil {
			return nil, err
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// ---------- 数值解析 ----------

func parseF(s string) float64 {
	f, _ := strconv.ParseFloat(s, 64)
	return f
}

func parseCents(s string) int64 { return roundCents(parseF(s)) }

func nf(s sql.NullString) *float64 {
	if !s.Valid {
		return nil
	}
	f := parseF(s.String)
	return &f
}

func nc(s sql.NullString) *int64 {
	if !s.Valid {
		return nil
	}
	c := parseCents(s.String)
	return &c
}
