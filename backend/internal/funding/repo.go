package funding

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/store"
)

// Bank：bank_accounts 行（账号全文不落库）。
type Bank struct {
	ID          string    `json:"id"`
	BankName    string    `json:"bankName"`
	Mask        string    `json:"mask"`
	Type        string    `json:"type"`
	OwnerName   string    `json:"ownerName"`
	Status      string    `json:"status"`
	CreatedAt   time.Time `json:"createdAt"`
	Nickname    string    `json:"nickname"` // 新增字段：DW 不返回银行名称时用于显示（沙盒实测）
	DWBankID    string    `json:"-"`
	AccountID   string    `json:"-"`
	DWAccountNo string    `json:"-"`
}

// Transfer：transfers 行。
type Transfer struct {
	ID            string      `json:"transferId"`
	Type          string      `json:"type"`   // DEPOSIT / WITHDRAWAL
	Method        string      `json:"method"` // ACH / WIRE
	Amount        string      `json:"-"`      // 两位小数字符串（数据库 numeric 文本），避免浮点误差
	AmountJSON    json.Number `json:"amount"` // 契约 Money 为 JSON number；输出时由 Amount 生成
	Status        string      `json:"status"`
	FailureReason *string     `json:"failureReason"`
	SubmittedAt   time.Time   `json:"submittedAt"`
	DoneAt        *time.Time  `json:"doneAt"`
	BankAccountID *string     `json:"bankAccountId"` // 新增字段：关联的银行账户（P-18 显示）
	// 新增字段（入金）：DW 返回的购买力可用日与可提现日（seasoningDetails），P-13 / P-14 / P-18 显示
	BuyingPowerAt  *time.Time `json:"buyingPowerAvailableAt"`
	WithdrawableAt *time.Time `json:"withdrawableAt"`
	AccountID      string     `json:"-"`
	DWRef          string     `json:"-"`
	IdempotencyKey string     `json:"-"`
	CreatedBy      string     `json:"-"`
	WireEnc        []byte     `json:"-"`
	DWAccountNo    string     `json:"-"`
	DWBankID       string     `json:"-"`
	DWAccountID    string     `json:"-"` // DW accountID（按账户列出入金反查用）
}

// 我方状态（DW 返回前）。DW 状态见 api-spec.md 第 5 节。
const (
	StatusSubmitting = "SUBMITTING" // 已落库、正在提交给 DW（或结果不明待重放）
	// StatusUnconfirmed：券商结果待人工核对（对账重放被拒、超过幂等有效期仍查不到）。不是终态：继续按账户反查，
	// 仍视为在途（不能解绑该银行卡）；App 显示"未确认"（审计 FUND-P1-4 / P1-2）。
	StatusUnconfirmed = "UNCONFIRMED"
)

// terminalSQL：与 Terminal() 一致的 SQL 字面量（常量，非用户输入；TestTerminalSQLMatches 保证一致）。
// 已失败 / 被拒 / 退回的出入金不计入防重复与每日入金限额（审计 TEST-P1-2：此前 SQL 漏了 RIA_REJECTED）。
const terminalSQL = `('FAILED', 'REJECTED', 'RETURNED', 'RIA_REJECTED')`

// Terminal：不再轮询的状态。SUCCESSFUL 的 ACH 入金仍可能被退回（RETURNED），因此在 returnWindow 内继续对账。
func Terminal(status string) bool {
	switch status {
	case "FAILED", "REJECTED", "RETURNED", "RIA_REJECTED":
		return true
	}
	return false
}

// ErrNotFound：资源不存在或不属于当前用户。
var ErrNotFound = errors.New("funding: not found")

// Repo：持久化。
type Repo interface {
	ListBanks(ctx context.Context, accountID string) ([]Bank, error)
	GetBank(ctx context.Context, accountID, bankID string) (*Bank, error) // 不存在返回 ErrNotFound
	InsertBank(ctx context.Context, b Bank) (string, error)
	DeleteBank(ctx context.Context, bankID string, now time.Time) error
	HasInFlight(ctx context.Context, bankID string) (bool, error)

	InsertTransfer(ctx context.Context, t Transfer) (string, error)
	// TransferByIdemKey：本账户下使用该幂等键的记录（App 重试去重）；没有时返回 ErrNotFound。
	TransferByIdemKey(ctx context.Context, accountID, key string) (*Transfer, error)
	SetSubmitted(ctx context.Context, id, dwRef, status string, now time.Time) error
	DeleteTransfer(ctx context.Context, id string) error // DW 明确拒绝时撤销本地记录
	RecentDuplicate(ctx context.Context, accountID, typ, amount string, bankID *string, since time.Time) (bool, error)
	SumDeposits(ctx context.Context, accountID string, since time.Time) (string, error)
	ListTransfers(ctx context.Context, accountID, typ string, before *time.Time, limit int) ([]Transfer, error)

	// 对账
	DueTransfers(ctx context.Context, checkedBefore, successSince time.Time, limit int) ([]Transfer, error)
	UpdateTransfer(ctx context.Context, id, status string, reason *string, done *time.Time, now time.Time) error
	SetAvailability(ctx context.Context, id string, buyingPowerAt, withdrawableAt *time.Time) error
	TouchTransfer(ctx context.Context, id string, now time.Time) error
	// DWRefUsed：该 DW 编号是否已关联到某条本地记录（反查匹配时排除）。
	DWRefUsed(ctx context.Context, dwRef string) (bool, error)
	Audit(ctx context.Context, actor, action, target string, detail map[string]any) error
}

// PGRepo：Postgres 实现。
type PGRepo struct{ DB *sql.DB }

const bankCols = `b.id, coalesce(b.bank_name, ''), coalesce(b.mask, ''), coalesce(b.type, ''), coalesce(b.owner_name, ''), b.status, b.created_at,
	coalesce(b.nickname, ''), coalesce(b.dw_bank_account_id, ''), b.account_id`

func scanBank(row interface{ Scan(...any) error }) (Bank, error) {
	var b Bank
	err := row.Scan(&b.ID, &b.BankName, &b.Mask, &b.Type, &b.OwnerName, &b.Status, &b.CreatedAt, &b.Nickname, &b.DWBankID, &b.AccountID)
	return b, err
}

func (p PGRepo) ListBanks(ctx context.Context, accountID string) ([]Bank, error) {
	rows, err := p.DB.QueryContext(ctx, `SELECT `+bankCols+` FROM bank_accounts b WHERE b.account_id = $1 AND b.deleted_at IS NULL ORDER BY b.created_at`, accountID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Bank{}
	for rows.Next() {
		b, err := scanBank(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, b)
	}
	return out, rows.Err()
}

func (p PGRepo) GetBank(ctx context.Context, accountID, bankID string) (*Bank, error) {
	b, err := scanBank(p.DB.QueryRowContext(ctx,
		`SELECT `+bankCols+` FROM bank_accounts b WHERE b.id::text = $2 AND b.account_id = $1 AND b.deleted_at IS NULL`, accountID, bankID))
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &b, nil
}

func (p PGRepo) InsertBank(ctx context.Context, b Bank) (string, error) {
	var id string
	err := p.DB.QueryRowContext(ctx,
		`INSERT INTO bank_accounts (account_id, dw_bank_account_id, bank_name, mask, type, owner_name, status, nickname)
		 VALUES ($1, $2, nullif($3, ''), $4, $5, $6, $7, $8) RETURNING id`,
		b.AccountID, b.DWBankID, b.BankName, b.Mask, b.Type, b.OwnerName, b.Status, b.Nickname).Scan(&id)
	return id, err
}

func (p PGRepo) DeleteBank(ctx context.Context, bankID string, now time.Time) error {
	_, err := p.DB.ExecContext(ctx, `UPDATE bank_accounts SET deleted_at = $2, status = 'DELETED' WHERE id = $1`, bankID, now)
	return err
}

func (p PGRepo) HasInFlight(ctx context.Context, bankID string) (bool, error) {
	var n int
	err := p.DB.QueryRowContext(ctx,
		`SELECT count(*) FROM transfers WHERE bank_account_id = $1 AND status <> 'SUCCESSFUL' AND status NOT IN `+terminalSQL+``, bankID).Scan(&n)
	return n > 0, err
}

func (p PGRepo) InsertTransfer(ctx context.Context, t Transfer) (string, error) {
	var id string
	err := p.DB.QueryRowContext(ctx,
		`INSERT INTO transfers (account_id, bank_account_id, type, method, amount, status, idempotency_key, wire_enc, created_by)
		 VALUES ($1, $2, $3, $4, $5::numeric, $6, $7, $8, $9) RETURNING id`,
		t.AccountID, t.BankAccountID, t.Type, t.Method, t.Amount, t.Status, t.IdempotencyKey, t.WireEnc, t.CreatedBy).Scan(&id)
	return id, err
}

func (p PGRepo) SetSubmitted(ctx context.Context, id, dwRef, status string, now time.Time) error {
	_, err := p.DB.ExecContext(ctx,
		`UPDATE transfers SET dw_ref = $2, status = $3, checked_at = $4, updated_at = $4 WHERE id = $1`, id, dwRef, status, now)
	return err
}

func (p PGRepo) DeleteTransfer(ctx context.Context, id string) error {
	_, err := p.DB.ExecContext(ctx, `DELETE FROM transfers WHERE id = $1 AND dw_ref IS NULL`, id)
	return err
}

func (p PGRepo) RecentDuplicate(ctx context.Context, accountID, typ, amount string, bankID *string, since time.Time) (bool, error) {
	var n int
	err := p.DB.QueryRowContext(ctx,
		`SELECT count(*) FROM transfers
		  WHERE account_id = $1 AND type = $2 AND amount = $3::numeric
		    AND bank_account_id IS NOT DISTINCT FROM $4::uuid AND submitted_at >= $5
		    AND status NOT IN `+terminalSQL+``, accountID, typ, amount, bankID, since).Scan(&n)
	return n > 0, err
}

func (p PGRepo) SumDeposits(ctx context.Context, accountID string, since time.Time) (string, error) {
	var s string
	err := p.DB.QueryRowContext(ctx,
		`SELECT coalesce(sum(amount), 0)::text FROM transfers
		  WHERE account_id = $1 AND type = 'DEPOSIT' AND submitted_at >= $2 AND status NOT IN `+terminalSQL+``,
		accountID, since).Scan(&s)
	return s, err
}

const transferCols = `t.id, t.type, t.method, t.amount::text, t.status, t.failure_reason, t.submitted_at, t.done_at, t.bank_account_id::text,
	t.buying_power_at, t.withdrawable_at,
	t.account_id, coalesce(t.dw_ref, ''), coalesce(t.idempotency_key::text, ''), coalesce(t.created_by::text, ''), t.wire_enc,
	coalesce(a.account_no, ''), coalesce(b.dw_bank_account_id, ''), coalesce(a.dw_account_id, '')`

const transferFrom = ` FROM transfers t JOIN accounts a ON a.id = t.account_id LEFT JOIN bank_accounts b ON b.id = t.bank_account_id`

func scanTransfer(row interface{ Scan(...any) error }) (Transfer, error) {
	var t Transfer
	err := row.Scan(&t.ID, &t.Type, &t.Method, &t.Amount, &t.Status, &t.FailureReason, &t.SubmittedAt, &t.DoneAt, &t.BankAccountID,
		&t.BuyingPowerAt, &t.WithdrawableAt, &t.AccountID, &t.DWRef, &t.IdempotencyKey, &t.CreatedBy, &t.WireEnc, &t.DWAccountNo, &t.DWBankID, &t.DWAccountID)
	t.AmountJSON = json.Number(t.Amount)
	return t, err
}

func (p PGRepo) ListTransfers(ctx context.Context, accountID, typ string, before *time.Time, limit int) ([]Transfer, error) {
	rows, err := p.DB.QueryContext(ctx, `SELECT `+transferCols+transferFrom+`
		  WHERE t.account_id = $1 AND ($2 = '' OR t.type = $2) AND ($3::timestamptz IS NULL OR t.submitted_at < $3)
		  ORDER BY t.submitted_at DESC LIMIT $4`, accountID, typ, before, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Transfer{}
	for rows.Next() {
		t, err := scanTransfer(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

func (p PGRepo) DueTransfers(ctx context.Context, checkedBefore, successSince time.Time, limit int) ([]Transfer, error) {
	rows, err := p.DB.QueryContext(ctx, `SELECT `+transferCols+transferFrom+`
		  WHERE t.status NOT IN `+terminalSQL+`
		    AND NOT (t.status = 'SUCCESSFUL' AND coalesce(t.done_at, t.submitted_at) < $2)
		    AND (t.checked_at IS NULL OR t.checked_at < $1)
		  ORDER BY t.checked_at NULLS FIRST LIMIT $3`, checkedBefore, successSince, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Transfer
	for rows.Next() {
		t, err := scanTransfer(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

func (p PGRepo) UpdateTransfer(ctx context.Context, id, status string, reason *string, done *time.Time, now time.Time) error {
	_, err := p.DB.ExecContext(ctx,
		`UPDATE transfers SET status = $2, failure_reason = $3, done_at = coalesce($4, done_at), checked_at = $5, updated_at = $5 WHERE id = $1`,
		id, status, reason, done, now)
	return err
}

func (p PGRepo) SetAvailability(ctx context.Context, id string, bp, wd *time.Time) error {
	_, err := p.DB.ExecContext(ctx, `UPDATE transfers SET buying_power_at = $2, withdrawable_at = $3 WHERE id = $1`, id, bp, wd)
	return err
}

func (p PGRepo) TransferByIdemKey(ctx context.Context, accountID, key string) (*Transfer, error) {
	t, err := scanTransfer(p.DB.QueryRowContext(ctx, `SELECT `+transferCols+transferFrom+` WHERE t.account_id = $1 AND t.idempotency_key = $2::uuid`, accountID, key))
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &t, nil
}

func (p PGRepo) DWRefUsed(ctx context.Context, dwRef string) (bool, error) {
	var used bool
	err := p.DB.QueryRowContext(ctx, `SELECT EXISTS (SELECT 1 FROM transfers WHERE dw_ref = $1)`, dwRef).Scan(&used)
	return used, err
}

func (p PGRepo) TouchTransfer(ctx context.Context, id string, now time.Time) error {
	_, err := p.DB.ExecContext(ctx, `UPDATE transfers SET checked_at = $2 WHERE id = $1`, id, now)
	return err
}

func (p PGRepo) Audit(ctx context.Context, actor, action, target string, detail map[string]any) error {
	return store.Audit(ctx, p.DB, actor, action, target, detail)
}
