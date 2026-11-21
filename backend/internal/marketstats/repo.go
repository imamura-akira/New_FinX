package marketstats

import (
	"context"
	"database/sql"
	"strconv"
	"time"
)

// PGRepo：Postgres 实现（表 instrument_daily_close，迁移 000011）。
type PGRepo struct{ DB *sql.DB }

func (p PGRepo) SaveCloses(ctx context.Context, cs []Close) error {
	tx, err := p.DB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()
	for _, c := range cs {
		if _, err := tx.ExecContext(ctx, `INSERT INTO instrument_daily_close (symbol, day, close, chg_pct, captured_at)
		    VALUES ($1, $2, $3, $4, now())
		    ON CONFLICT (symbol, day) DO UPDATE SET close = EXCLUDED.close, chg_pct = EXCLUDED.chg_pct, captured_at = EXCLUDED.captured_at`,
			c.Symbol, c.Day.Format("2006-01-02"), strconv.FormatFloat(c.Close, 'f', 4, 64), strconv.FormatFloat(c.ChgPct, 'f', 4, 64)); err != nil {
			return err
		}
	}
	return tx.Commit()
}

func (p PGRepo) BaseCloses(ctx context.Context, onOrBefore time.Time) (map[string]float64, error) {
	rows, err := p.DB.QueryContext(ctx, `SELECT DISTINCT ON (symbol) symbol, close::float8
	    FROM instrument_daily_close WHERE day <= $1 ORDER BY symbol, day DESC`, onOrBefore.Format("2006-01-02"))
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := map[string]float64{}
	for rows.Next() {
		var s string
		var c float64
		if err := rows.Scan(&s, &c); err != nil {
			return nil, err
		}
		out[s] = c
	}
	return out, rows.Err()
}

func (p PGRepo) FirstDay(ctx context.Context) (time.Time, bool, error) {
	var d sql.NullTime
	if err := p.DB.QueryRowContext(ctx, `SELECT min(day) FROM instrument_daily_close`).Scan(&d); err != nil {
		return time.Time{}, false, err
	}
	if !d.Valid {
		return time.Time{}, false, nil
	}
	t := d.Time
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC), true, nil
}
