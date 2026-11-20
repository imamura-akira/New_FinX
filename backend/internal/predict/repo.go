package predict

import (
	"context"
	"database/sql"
	"errors"
	"sort"
	"sync"
	"time"
)

// Repo：持久化（PG 实现带行锁；Mem 实现供单测）。
type Repo interface {
	EnsureAccount(ctx context.Context, userID string) (int64, error)
	ListOpenMarkets(ctx context.Context, now time.Time) ([]Market, error)
	GetMarket(ctx context.Context, id string) (*Market, error)
	EnsureUpDown(ctx context.Context, symbol string, start time.Time, target float64) error
	PlaceBet(ctx context.Context, userID, marketID, outcome string, stake int64, now time.Time) (Bet, int64, Market, error)
	DueUpDown(ctx context.Context, now time.Time) ([]Market, error)
	Settle(ctx context.Context, marketID, result string, settlePrice *float64, now time.Time) (int, error)
	ListBets(ctx context.Context, userID string) ([]Bet, error)
	Claim(ctx context.Context, userID string, now time.Time) (int64, int64, error)
}

// applyBet：校验并生成下注（纯函数，两种实现共用）。
func applyBet(points int64, m Market, userID, outcome string, stake int64, now time.Time) (Bet, error) {
	if outcome != Yes && outcome != No {
		return Bet{}, ErrBadOutcome
	}
	if stake < MinStake || stake > MaxStake {
		return Bet{}, ErrStake
	}
	if !m.Open(now) {
		return Bet{}, ErrMarketClosed
	}
	if stake > points {
		return Bet{}, ErrInsufficient
	}
	p := m.Prob(outcome)
	return Bet{UserID: userID, MarketID: m.ID, Outcome: outcome, Stake: stake, Probability: roundProb(p),
		PotentialPayout: Payout(stake, p), Status: BetOpen, CreatedAt: now}, nil
}

func roundProb(p float64) float64 { return float64(int64(p*10000+0.5)) / 10000 }

// ---------------------------------------------------------------------------
// Postgres

// PGRepo：Postgres 实现（迁移 000009）。
type PGRepo struct{ DB *sql.DB }

const marketCols = `id, kind, category, symbol, title_zh, title_en, subtitle_zh, subtitle_en, yes_zh, yes_en, no_zh, no_en,
	seed_yes, seed_no, pool_yes, pool_no, opens_at, closes_at, target_price::float8, settle_price::float8, result, settled_at, sort_order`

func scanMarket(row interface{ Scan(...any) error }) (Market, error) {
	var m Market
	err := row.Scan(&m.ID, &m.Kind, &m.Category, &m.Symbol, &m.TitleZh, &m.TitleEn, &m.SubtitleZh, &m.SubtitleEn,
		&m.YesZh, &m.YesEn, &m.NoZh, &m.NoEn, &m.SeedYes, &m.SeedNo, &m.PoolYes, &m.PoolNo, &m.OpensAt, &m.ClosesAt,
		&m.TargetPrice, &m.SettlePrice, &m.Result, &m.SettledAt, &m.SortOrder)
	return m, err
}

func (p PGRepo) EnsureAccount(ctx context.Context, userID string) (int64, error) {
	if _, err := p.DB.ExecContext(ctx, `INSERT INTO predict_accounts (user_id, points) VALUES ($1, $2) ON CONFLICT DO NOTHING`, userID, InitialPoints); err != nil {
		return 0, err
	}
	var pts int64
	err := p.DB.QueryRowContext(ctx, `SELECT points FROM predict_accounts WHERE user_id = $1`, userID).Scan(&pts)
	return pts, err
}

func (p PGRepo) markets(ctx context.Context, q string, args ...any) ([]Market, error) {
	rows, err := p.DB.QueryContext(ctx, `SELECT `+marketCols+` FROM predict_markets `+q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Market
	for rows.Next() {
		m, err := scanMarket(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

func (p PGRepo) ListOpenMarkets(ctx context.Context, now time.Time) ([]Market, error) {
	return p.markets(ctx, `WHERE result IS NULL AND closes_at > $1 AND opens_at <= $1 ORDER BY kind DESC, sort_order, closes_at`, now)
}

func (p PGRepo) GetMarket(ctx context.Context, id string) (*Market, error) {
	m, err := scanMarket(p.DB.QueryRowContext(ctx, `SELECT `+marketCols+` FROM predict_markets WHERE id = $1`, id))
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	return &m, err
}

func (p PGRepo) EnsureUpDown(ctx context.Context, symbol string, start time.Time, target float64) error {
	_, err := p.DB.ExecContext(ctx, `INSERT INTO predict_markets (id, kind, category, symbol, title_zh, title_en, subtitle_zh, subtitle_en,
		yes_zh, yes_en, no_zh, no_en, seed_yes, seed_no, pool_yes, pool_no, opens_at, closes_at, target_price)
		VALUES ($1, 'UPDOWN', 'CRYPTO', $2, $3, $4, '加密 · 15 分钟', 'Crypto · 15m', '上涨', 'Up', '下跌', 'Down', $5, $5, $5, $5, $6, $7, $8)
		ON CONFLICT DO NOTHING`,
		UpDownID(symbol, start), symbol, symbol+" 15 分钟涨跌", symbol+" Up or Down · 15m", UpDownSeed, start, start.Add(Window), target)
	return err
}

func (p PGRepo) PlaceBet(ctx context.Context, userID, marketID, outcome string, stake int64, now time.Time) (Bet, int64, Market, error) {
	tx, err := p.DB.BeginTx(ctx, nil)
	if err != nil {
		return Bet{}, 0, Market{}, err
	}
	defer func() { _ = tx.Rollback() }()
	if _, err := tx.ExecContext(ctx, `INSERT INTO predict_accounts (user_id, points) VALUES ($1, $2) ON CONFLICT DO NOTHING`, userID, InitialPoints); err != nil {
		return Bet{}, 0, Market{}, err
	}
	var pts int64
	if err := tx.QueryRowContext(ctx, `SELECT points FROM predict_accounts WHERE user_id = $1 FOR UPDATE`, userID).Scan(&pts); err != nil {
		return Bet{}, 0, Market{}, err
	}
	m, err := scanMarket(tx.QueryRowContext(ctx, `SELECT `+marketCols+` FROM predict_markets WHERE id = $1 FOR UPDATE`, marketID))
	if errors.Is(err, sql.ErrNoRows) {
		return Bet{}, 0, Market{}, ErrNotFound
	} else if err != nil {
		return Bet{}, 0, Market{}, err
	}
	b, err := applyBet(pts, m, userID, outcome, stake, now)
	if err != nil {
		return Bet{}, 0, Market{}, err
	}
	if err := tx.QueryRowContext(ctx, `INSERT INTO predict_bets (user_id, market_id, outcome, stake, probability, potential_payout, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id`, userID, marketID, outcome, stake, b.Probability, b.PotentialPayout, now).Scan(&b.ID); err != nil {
		return Bet{}, 0, Market{}, err
	}
	col := "pool_yes"
	if outcome == No {
		col = "pool_no"
	}
	if _, err := tx.ExecContext(ctx, `UPDATE predict_markets SET `+col+` = `+col+` + $2 WHERE id = $1`, marketID, stake); err != nil {
		return Bet{}, 0, Market{}, err
	}
	if _, err := tx.ExecContext(ctx, `UPDATE predict_accounts SET points = points - $2, updated_at = $3 WHERE user_id = $1`, userID, stake, now); err != nil {
		return Bet{}, 0, Market{}, err
	}
	if outcome == Yes {
		m.PoolYes += stake
	} else {
		m.PoolNo += stake
	}
	return b, pts - stake, m, tx.Commit()
}

func (p PGRepo) DueUpDown(ctx context.Context, now time.Time) ([]Market, error) {
	return p.markets(ctx, `WHERE kind = 'UPDOWN' AND result IS NULL AND closes_at <= $1 ORDER BY closes_at`, now)
}

func (p PGRepo) Settle(ctx context.Context, marketID, result string, settlePrice *float64, now time.Time) (int, error) {
	tx, err := p.DB.BeginTx(ctx, nil)
	if err != nil {
		return 0, err
	}
	defer func() { _ = tx.Rollback() }()
	m, err := scanMarket(tx.QueryRowContext(ctx, `SELECT `+marketCols+` FROM predict_markets WHERE id = $1 FOR UPDATE`, marketID))
	if errors.Is(err, sql.ErrNoRows) {
		return 0, ErrNotFound
	} else if err != nil {
		return 0, err
	}
	if m.Result != nil {
		return 0, ErrSettled
	}
	if _, err := tx.ExecContext(ctx, `UPDATE predict_markets SET result = $2, settle_price = $3, settled_at = $4 WHERE id = $1`, marketID, result, settlePrice, now); err != nil {
		return 0, err
	}
	// 命中：派 potential_payout；作废：退本金；未命中：0
	res, err := tx.ExecContext(ctx, `UPDATE predict_bets SET
		status = CASE WHEN $2 = 'VOID' THEN 'VOID' WHEN outcome = $2 THEN 'WON' ELSE 'LOST' END,
		payout = CASE WHEN $2 = 'VOID' THEN stake WHEN outcome = $2 THEN potential_payout ELSE 0 END,
		settled_at = $3
		WHERE market_id = $1 AND status = 'OPEN'`, marketID, result, now)
	if err != nil {
		return 0, err
	}
	n, _ := res.RowsAffected()
	return int(n), tx.Commit()
}

func (p PGRepo) ListBets(ctx context.Context, userID string) ([]Bet, error) {
	rows, err := p.DB.QueryContext(ctx, `SELECT id, user_id, market_id, outcome, stake, probability::float8, potential_payout, status, payout,
		claimed_at, created_at, settled_at FROM predict_bets WHERE user_id = $1 ORDER BY created_at DESC LIMIT 200`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Bet
	for rows.Next() {
		var b Bet
		if err := rows.Scan(&b.ID, &b.UserID, &b.MarketID, &b.Outcome, &b.Stake, &b.Probability, &b.PotentialPayout, &b.Status, &b.Payout,
			&b.ClaimedAt, &b.CreatedAt, &b.SettledAt); err != nil {
			return nil, err
		}
		out = append(out, b)
	}
	return out, rows.Err()
}

func (p PGRepo) Claim(ctx context.Context, userID string, now time.Time) (int64, int64, error) {
	tx, err := p.DB.BeginTx(ctx, nil)
	if err != nil {
		return 0, 0, err
	}
	defer func() { _ = tx.Rollback() }()
	if _, err := tx.ExecContext(ctx, `INSERT INTO predict_accounts (user_id, points) VALUES ($1, $2) ON CONFLICT DO NOTHING`, userID, InitialPoints); err != nil {
		return 0, 0, err
	}
	var pts int64
	if err := tx.QueryRowContext(ctx, `SELECT points FROM predict_accounts WHERE user_id = $1 FOR UPDATE`, userID).Scan(&pts); err != nil {
		return 0, 0, err
	}
	var amt int64
	if err := tx.QueryRowContext(ctx, `WITH c AS (UPDATE predict_bets SET claimed_at = $2
		WHERE user_id = $1 AND status <> 'OPEN' AND payout > 0 AND claimed_at IS NULL RETURNING payout)
		SELECT coalesce(sum(payout), 0) FROM c`, userID, now).Scan(&amt); err != nil {
		return 0, 0, err
	}
	if amt > 0 {
		if _, err := tx.ExecContext(ctx, `UPDATE predict_accounts SET points = points + $2, updated_at = $3 WHERE user_id = $1`, userID, amt, now); err != nil {
			return 0, 0, err
		}
	}
	return amt, pts + amt, tx.Commit()
}

// ---------------------------------------------------------------------------
// 内存实现（单测用）

// Mem：并发安全的内存仓库。
type Mem struct {
	mu       sync.Mutex
	accounts map[string]int64
	markets  map[string]*Market
	bets     []*Bet
	seq      int
}

// NewMem 创建内存仓库并放入市场。
func NewMem(ms ...Market) *Mem {
	r := &Mem{accounts: map[string]int64{}, markets: map[string]*Market{}}
	for i := range ms {
		m := ms[i]
		r.markets[m.ID] = &m
	}
	return r
}

func (r *Mem) EnsureAccount(_ context.Context, uid string) (int64, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, ok := r.accounts[uid]; !ok {
		r.accounts[uid] = InitialPoints
	}
	return r.accounts[uid], nil
}

func (r *Mem) ListOpenMarkets(_ context.Context, now time.Time) ([]Market, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	var out []Market
	for _, m := range r.markets {
		if m.Open(now) {
			out = append(out, *m)
		}
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].Kind != out[j].Kind {
			return out[i].Kind > out[j].Kind
		}
		if out[i].SortOrder != out[j].SortOrder {
			return out[i].SortOrder < out[j].SortOrder
		}
		return out[i].ID < out[j].ID
	})
	return out, nil
}

func (r *Mem) GetMarket(_ context.Context, id string) (*Market, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if m, ok := r.markets[id]; ok {
		c := *m
		return &c, nil
	}
	return nil, nil
}

func (r *Mem) EnsureUpDown(_ context.Context, symbol string, start time.Time, target float64) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	id := UpDownID(symbol, start)
	if _, ok := r.markets[id]; ok {
		return nil
	}
	s, tp := symbol, target
	r.markets[id] = &Market{ID: id, Kind: KindUpDown, Category: "CRYPTO", Symbol: &s, TitleZh: symbol + " 15 分钟涨跌", TitleEn: symbol + " Up or Down · 15m",
		YesZh: "上涨", YesEn: "Up", NoZh: "下跌", NoEn: "Down", SeedYes: UpDownSeed, SeedNo: UpDownSeed, PoolYes: UpDownSeed, PoolNo: UpDownSeed,
		OpensAt: start, ClosesAt: start.Add(Window), TargetPrice: &tp}
	return nil
}

func (r *Mem) PlaceBet(_ context.Context, uid, marketID, outcome string, stake int64, now time.Time) (Bet, int64, Market, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, ok := r.accounts[uid]; !ok {
		r.accounts[uid] = InitialPoints
	}
	m, ok := r.markets[marketID]
	if !ok {
		return Bet{}, 0, Market{}, ErrNotFound
	}
	b, err := applyBet(r.accounts[uid], *m, uid, outcome, stake, now)
	if err != nil {
		return Bet{}, 0, Market{}, err
	}
	r.seq++
	b.ID = time.Unix(int64(r.seq), 0).UTC().Format("bet-150405")
	if outcome == Yes {
		m.PoolYes += stake
	} else {
		m.PoolNo += stake
	}
	r.accounts[uid] -= stake
	bb := b
	r.bets = append(r.bets, &bb)
	return b, r.accounts[uid], *m, nil
}

func (r *Mem) DueUpDown(_ context.Context, now time.Time) ([]Market, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	var out []Market
	for _, m := range r.markets {
		if m.Kind == KindUpDown && m.Result == nil && !now.Before(m.ClosesAt) {
			out = append(out, *m)
		}
	}
	return out, nil
}

func (r *Mem) Settle(_ context.Context, marketID, result string, settlePrice *float64, now time.Time) (int, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	m, ok := r.markets[marketID]
	if !ok {
		return 0, ErrNotFound
	}
	if m.Result != nil {
		return 0, ErrSettled
	}
	res := result
	m.Result, m.SettlePrice, m.SettledAt = &res, settlePrice, &now
	n := 0
	for _, b := range r.bets {
		if b.MarketID == marketID && b.Status == BetOpen {
			b.Status, b.Payout = SettleBet(*b, result)
			t := now
			b.SettledAt = &t
			n++
		}
	}
	return n, nil
}

func (r *Mem) ListBets(_ context.Context, uid string) ([]Bet, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	var out []Bet
	for i := len(r.bets) - 1; i >= 0; i-- {
		if r.bets[i].UserID == uid {
			out = append(out, *r.bets[i])
		}
	}
	return out, nil
}

func (r *Mem) Claim(_ context.Context, uid string, now time.Time) (int64, int64, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, ok := r.accounts[uid]; !ok {
		r.accounts[uid] = InitialPoints
	}
	var amt int64
	for _, b := range r.bets {
		if b.UserID == uid && b.Status != BetOpen && b.Payout > 0 && b.ClaimedAt == nil {
			t := now
			b.ClaimedAt = &t
			amt += b.Payout
		}
	}
	r.accounts[uid] += amt
	return amt, r.accounts[uid], nil
}
