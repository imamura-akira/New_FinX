package rewards

import (
	"context"
	"database/sql"
	"time"
)

// PGRepo：Postgres 实现（表 xp_ledger / xp_checkins，迁移 000012）。
type PGRepo struct{ DB *sql.DB }

func (p PGRepo) Balance(ctx context.Context, userID string) (int, error) {
	var b int
	err := p.DB.QueryRowContext(ctx, `SELECT COALESCE(SUM(delta), 0) FROM xp_ledger WHERE user_id = $1`, userID).Scan(&b)
	return b, err
}

// CheckIn：签到与入账在同一事务；签到主键冲突（当日已签）时不入账。
func (p PGRepo) CheckIn(ctx context.Context, userID string, day time.Time, xp int) (bool, error) {
	tx, err := p.DB.BeginTx(ctx, nil)
	if err != nil {
		return false, err
	}
	defer func() { _ = tx.Rollback() }()
	d := day.Format("2006-01-02")
	res, err := tx.ExecContext(ctx, `INSERT INTO xp_checkins (user_id, day) VALUES ($1, $2) ON CONFLICT DO NOTHING`, userID, d)
	if err != nil {
		return false, err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return false, nil
	}
	if _, err := tx.ExecContext(ctx, `INSERT INTO xp_ledger (user_id, delta, reason, ref) VALUES ($1, $2, 'CHECKIN', $3)`, userID, xp, d); err != nil {
		return false, err
	}
	return true, tx.Commit()
}

func (p PGRepo) CheckinDays(ctx context.Context, userID string, since time.Time) ([]time.Time, error) {
	rows, err := p.DB.QueryContext(ctx, `SELECT day FROM xp_checkins WHERE user_id = $1 AND day >= $2 ORDER BY day DESC`, userID, since.Format("2006-01-02"))
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []time.Time
	for rows.Next() {
		var d time.Time
		if err := rows.Scan(&d); err != nil {
			return nil, err
		}
		out = append(out, time.Date(d.Year(), d.Month(), d.Day(), 0, 0, 0, 0, time.UTC))
	}
	return out, rows.Err()
}

// GrantDemo：演示发放（cmd/demoreset grant-xp）。固定 ref，重复执行把该笔改为新值（幂等，不叠加）。
func GrantDemo(ctx context.Context, db *sql.DB, userID string, xp int) error {
	_, err := db.ExecContext(ctx, `INSERT INTO xp_ledger (user_id, delta, reason, ref) VALUES ($1, $2, 'DEMO_GRANT', 'demo')
	    ON CONFLICT (user_id, reason, ref) DO UPDATE SET delta = EXCLUDED.delta, created_at = now()`, userID, xp)
	return err
}
