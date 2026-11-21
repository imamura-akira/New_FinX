package portfolio

import (
	"context"
	"database/sql"
	"strconv"
	"time"
)

// PGRepo：Postgres 实现（表 asset_snapshots，迁移 000008）。
type PGRepo struct{ DB *sql.DB }

func dec(c int64) string { return string(Cents(c)) }

func (p PGRepo) Save(ctx context.Context, s Snapshot, overwrite bool) (bool, error) {
	q := `INSERT INTO asset_snapshots (user_id, mode, day, total, cash, stock_value, etf_value, source, captured_at)
	      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	      ON CONFLICT (user_id, mode, day) DO NOTHING`
	if overwrite {
		q = `INSERT INTO asset_snapshots (user_id, mode, day, total, cash, stock_value, etf_value, source, captured_at)
		     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		     ON CONFLICT (user_id, mode, day) DO UPDATE SET total = EXCLUDED.total, cash = EXCLUDED.cash,
		       stock_value = EXCLUDED.stock_value, etf_value = EXCLUDED.etf_value, source = EXCLUDED.source, captured_at = EXCLUDED.captured_at`
	}
	b := s.Breakdown
	res, err := p.DB.ExecContext(ctx, q, s.UserID, string(s.Mode), s.Day.Format("2006-01-02"),
		dec(b.Total()), dec(b.Cash), dec(b.Stock), dec(b.ETF), s.Source, s.CapturedAt)
	if err != nil {
		return false, err
	}
	n, _ := res.RowsAffected()
	return n > 0, nil
}

func (p PGRepo) Has(ctx context.Context, userID string, mode Mode, day time.Time) (bool, error) {
	var ok bool
	err := p.DB.QueryRowContext(ctx, `SELECT EXISTS (SELECT 1 FROM asset_snapshots WHERE user_id = $1 AND mode = $2 AND day = $3)`,
		userID, string(mode), day.Format("2006-01-02")).Scan(&ok)
	return ok, err
}

func cents(s string) int64 {
	f, _ := strconv.ParseFloat(s, 64)
	if f < 0 {
		return -int64(-f*100 + 0.5)
	}
	return int64(f*100 + 0.5)
}

func (p PGRepo) List(ctx context.Context, userID string, mode Mode, from time.Time) ([]Snapshot, error) {
	fromDay := "0001-01-01"
	if !from.IsZero() {
		fromDay = from.Format("2006-01-02")
	}
	rows, err := p.DB.QueryContext(ctx, `SELECT day, cash::text, stock_value::text, etf_value::text, source, captured_at
	    FROM asset_snapshots WHERE user_id = $1 AND mode = $2 AND day >= $3 ORDER BY day`, userID, string(mode), fromDay)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Snapshot
	for rows.Next() {
		var day time.Time
		var cash, stock, etf string
		s := Snapshot{UserID: userID, Mode: mode}
		if err := rows.Scan(&day, &cash, &stock, &etf, &s.Source, &s.CapturedAt); err != nil {
			return nil, err
		}
		s.Day = time.Date(day.Year(), day.Month(), day.Day(), 0, 0, 0, 0, time.UTC)
		s.Breakdown = Breakdown{Cash: cents(cash), Stock: cents(stock), ETF: cents(etf)}
		out = append(out, s)
	}
	return out, rows.Err()
}

func (p PGRepo) users(ctx context.Context, q string) ([]string, error) {
	rows, err := p.DB.QueryContext(ctx, q)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out = append(out, id)
	}
	return out, rows.Err()
}

// RealUsers：已开立 DW 账户（未关闭）的用户。
func (p PGRepo) RealUsers(ctx context.Context) ([]string, error) {
	return p.users(ctx, `SELECT DISTINCT ap.user_id::text
	    FROM accounts a
	    JOIN dw_users d ON d.dw_user_id = a.dw_user_id
	    JOIN applications ap ON ap.id = d.application_id
	   WHERE ap.deleted_at IS NULL AND a.dw_account_id IS NOT NULL AND a.status IN ('OPEN', 'OPEN_NO_NEW_TRADES', 'FROZEN')`)
}

// PaperUsers：已有模拟账户的用户。
func (p PGRepo) PaperUsers(ctx context.Context) ([]string, error) {
	return p.users(ctx, `SELECT user_id::text FROM paper_accounts`)
}

// SaveIntraday 写入日内快照（同一档位重复写入时忽略）。
func (p PGRepo) SaveIntraday(ctx context.Context, s IntradaySnapshot) error {
	b := s.Breakdown
	_, err := p.DB.ExecContext(ctx, `INSERT INTO asset_intraday (user_id, mode, slot_at, total, cash, stock_value, etf_value, captured_at)
	    VALUES ($1, $2, $3, $4, $5, $6, $7, $8) ON CONFLICT (user_id, mode, slot_at) DO NOTHING`,
		s.UserID, string(s.Mode), s.At, dec(b.Total()), dec(b.Cash), dec(b.Stock), dec(b.ETF), s.CapturedAt)
	return err
}

// ListIntraday 返回 slot_at ≥ since 的日内快照，按时刻升序。
func (p PGRepo) ListIntraday(ctx context.Context, userID string, mode Mode, since time.Time) ([]IntradaySnapshot, error) {
	rows, err := p.DB.QueryContext(ctx, `SELECT slot_at, cash::text, stock_value::text, etf_value::text, captured_at
	    FROM asset_intraday WHERE user_id = $1 AND mode = $2 AND slot_at >= $3 ORDER BY slot_at`, userID, string(mode), since)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []IntradaySnapshot
	for rows.Next() {
		var cash, stock, etf string
		s := IntradaySnapshot{UserID: userID, Mode: mode}
		if err := rows.Scan(&s.At, &cash, &stock, &etf, &s.CapturedAt); err != nil {
			return nil, err
		}
		s.At = s.At.UTC()
		s.Breakdown = Breakdown{Cash: cents(cash), Stock: cents(stock), ETF: cents(etf)}
		out = append(out, s)
	}
	return out, rows.Err()
}
