// Package account：交易账户开立（KYC_APPROVED 后 POST /accounts）与 GET /account（api-spec.md 第 3 节，F6）。
package account

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/dwclient"
	"github.com/imamura-akira/New_FinX/backend/internal/httpx"
	"github.com/imamura-akira/New_FinX/backend/internal/store"
)

// 首期账户参数（已核实 opening-accounts；SELF 不发送任何 RIA 字段，Q-DW-7）。
const (
	AccountType    = "LIVE"
	TradingType    = "CASH"
	ManagementType = "SELF"

	maxCreateAttempts = 5
)

// 账户状态（api-spec.md 第 3 节）。
var validStatus = map[string]bool{"PENDING": true, "OPEN": true, "OPEN_NO_NEW_TRADES": true, "FROZEN": true, "CLOSED": true}

// Account：accounts 行。
type Account struct {
	ID          string     `json:"accountId"`
	AccountNo   string     `json:"accountNo"`
	Status      string     `json:"status"`
	AccountType string     `json:"accountType"`
	TradingType string     `json:"tradingType"`
	Management  string     `json:"managementType"`
	OpenedAt    *time.Time `json:"openedAt"`
	DWAccountID string     `json:"-"`
	DWUserID    string     `json:"-"`
}

// Pending：KYC 已通过但尚未开户的申请。
type Pending struct {
	AppID, DWUserID string
}

// Repo：持久化。
type Repo interface {
	NeedAccount(ctx context.Context, limit int) ([]Pending, error)
	SaveAccount(ctx context.Context, a Account, now time.Time) error
	RecordAttempt(ctx context.Context, appID, errMsg string) error
	NotOpen(ctx context.Context, limit int) ([]Account, error)
	UpdateStatus(ctx context.Context, dwAccountID, status string, openedAt *time.Time, now time.Time) error
	ForUser(ctx context.Context, userID string) (*Account, error)
	Audit(ctx context.Context, actor, action, target string, detail map[string]any) error
}

// DW：账户相关的 DW 能力。
type DW interface {
	Do(ctx context.Context, method, path string, reqBody, out any) error
}

// Service：开户与账户查询。
type Service struct {
	repo   Repo
	dw     DW
	logger *slog.Logger
	now    func() time.Time
}

// New 创建模块；dw 为 nil 时只提供查询。
func New(repo Repo, dw DW, logger *slog.Logger) *Service {
	if logger == nil {
		logger = slog.Default()
	}
	return &Service{repo: repo, dw: dw, logger: logger, now: time.Now}
}

// Routes 注册 GET /account。
func (s *Service) Routes(mux *http.ServeMux, prefix string, auth func(http.Handler) http.Handler) {
	mux.Handle("GET "+prefix+"/account", auth(http.HandlerFunc(s.handleGet)))
}

func (s *Service) handleGet(w http.ResponseWriter, r *http.Request) {
	a, err := s.repo.ForUser(r.Context(), httpx.UserID(r.Context()))
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	if a == nil {
		httpx.Fail(w, r, httpx.Conflict("交易账户尚未开立"))
		return
	}
	httpx.OK(w, a)
}

// ---------- 开户 ----------

// dwAccount：POST /accounts 与 GET /accounts/{id} 的响应（字段名待沙盒验证，宽松解析）。
type dwAccount struct {
	ID          string `json:"id"`
	AccountNo   string `json:"accountNo"`
	AccountType any    `json:"accountType"`
	Status      any    `json:"status"` // "OPEN" 或 {"name":"OPEN"}
	Opened      string `json:"openedWhen"`
}

func (d dwAccount) status() string { return nameOf(d.Status) }

func (d dwAccount) isLive() bool {
	t := nameOf(d.AccountType)
	return t == "" || t == AccountType
}

func nameOf(v any) string {
	switch x := v.(type) {
	case string:
		return strings.ToUpper(x)
	case map[string]any:
		if n, ok := x["name"].(string); ok {
			return strings.ToUpper(n)
		}
	}
	return ""
}

// EnsureAccounts 为 KYC 已通过、资料已全部提交给 DW（编排 DOCS_DONE）、尚无账户的用户开户。每个用户最多尝试 maxCreateAttempts 次。
//
// 幂等：开户前先查 GET /users/{userID}/accounts，已有 LIVE 账户则直接采用，避免超时重试导致重复开户。
func (s *Service) EnsureAccounts(ctx context.Context) {
	if s.dw == nil {
		return
	}
	list, err := s.repo.NeedAccount(ctx, 20)
	if err != nil {
		s.logger.ErrorContext(ctx, "list pending accounts failed", slog.String("error", err.Error()))
		return
	}
	for _, p := range list {
		if err := s.open(ctx, p); err != nil {
			msg := safeErr(err)
			s.logger.WarnContext(ctx, "open account failed", slog.String("application_id", p.AppID), slog.String("error", msg))
			_ = s.repo.RecordAttempt(ctx, p.AppID, msg)
		}
	}
}

func (s *Service) open(ctx context.Context, p Pending) error {
	var existing []dwAccount
	if err := s.dw.Do(ctx, http.MethodGet, "/users/"+p.DWUserID+"/accounts", nil, &existing); err != nil {
		return err
	}
	var acc *dwAccount
	for i := range existing {
		if existing[i].isLive() && existing[i].ID != "" {
			acc = &existing[i]
			break
		}
	}
	if acc == nil {
		body := map[string]any{
			"userID":                p.DWUserID,
			"accountType":           AccountType,
			"accountManagementType": ManagementType,
			"tradingType":           TradingType,
		}
		var created dwAccount
		if err := s.dw.Do(ctx, http.MethodPost, "/accounts", body, &created); err != nil {
			return err
		}
		if created.ID == "" {
			return errors.New("DW 开户响应中没有账户 id（字段名待沙盒验证）")
		}
		acc = &created
	}
	status := acc.status()
	if !validStatus[status] {
		status = "PENDING"
	}
	now := s.now().UTC()
	a := Account{DWAccountID: acc.ID, DWUserID: p.DWUserID, AccountNo: acc.AccountNo, Status: status}
	if status == "OPEN" {
		a.OpenedAt = &now
	}
	if err := s.repo.SaveAccount(ctx, a, now); err != nil {
		return err
	}
	_ = s.repo.Audit(ctx, "system", "dw.account.created", "application:"+p.AppID, map[string]any{"status": status})
	s.logger.InfoContext(ctx, "account opened", slog.String("application_id", p.AppID), slog.String("status", status))
	return nil
}

// RefreshStatuses 对未 OPEN 的账户查询 DW 最新状态（PENDING → OPEN 等）。
func (s *Service) RefreshStatuses(ctx context.Context) {
	if s.dw == nil {
		return
	}
	list, err := s.repo.NotOpen(ctx, 20)
	if err != nil {
		s.logger.ErrorContext(ctx, "list accounts failed", slog.String("error", err.Error()))
		return
	}
	for _, a := range list {
		var d dwAccount
		if err := s.dw.Do(ctx, http.MethodGet, "/accounts/"+a.DWAccountID, nil, &d); err != nil {
			s.logger.WarnContext(ctx, "refresh account failed", slog.String("account_id", a.ID), slog.String("error", safeErr(err)))
			continue
		}
		st := d.status()
		if !validStatus[st] || st == a.Status {
			continue
		}
		now := s.now().UTC()
		var opened *time.Time
		if st == "OPEN" && a.OpenedAt == nil {
			opened = &now
		}
		if err := s.repo.UpdateStatus(ctx, a.DWAccountID, st, opened, now); err != nil {
			s.logger.ErrorContext(ctx, "update account status failed", slog.String("error", err.Error()))
			continue
		}
		_ = s.repo.Audit(ctx, "system", "dw.account.status", "account:"+a.ID, map[string]any{"from": a.Status, "to": st})
	}
}

func safeErr(err error) string {
	var ae *dwclient.APIError
	if errors.As(err, &ae) {
		s := fmt.Sprintf("DW HTTP %d", ae.Status)
		if ae.DWCode != "" {
			s += " code=" + ae.DWCode
		}
		return s
	}
	return err.Error()
}

// ---------- Postgres ----------

// PGRepo：Postgres 实现。
type PGRepo struct{ DB *sql.DB }

func (p PGRepo) NeedAccount(ctx context.Context, limit int) ([]Pending, error) {
	rows, err := p.DB.QueryContext(ctx,
		`SELECT d.application_id, d.dw_user_id FROM dw_users d
		   JOIN applications ap ON ap.id = d.application_id
		  WHERE d.kyc_status = 'KYC_APPROVED' AND d.dw_user_id IS NOT NULL AND d.deleted_at IS NULL
		    -- 沙盒实测：POST /users 后即自动 APPROVED，此时披露等资料尚未 PATCH。
		    -- 必须等编排全部完成（DISCLOSURES 已提交）才开户。
		    AND ap.orchestration_state = 'DOCS_DONE' AND ap.submit_blocked = false
		    AND d.account_attempts < $2
		    AND NOT EXISTS (SELECT 1 FROM accounts a WHERE a.dw_user_id = d.dw_user_id)
		  ORDER BY d.kyc_updated_at LIMIT $1`, limit, maxCreateAttempts)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Pending
	for rows.Next() {
		var x Pending
		if err := rows.Scan(&x.AppID, &x.DWUserID); err != nil {
			return nil, err
		}
		out = append(out, x)
	}
	return out, rows.Err()
}

func (p PGRepo) SaveAccount(ctx context.Context, a Account, now time.Time) error {
	_, err := p.DB.ExecContext(ctx,
		`INSERT INTO accounts (dw_user_id, dw_account_id, account_no, status, opened_at, created_at, updated_at)
		 VALUES ($1, $2, nullif($3, ''), $4, $5, $6, $6)
		 ON CONFLICT (dw_account_id) DO NOTHING`, a.DWUserID, a.DWAccountID, a.AccountNo, a.Status, a.OpenedAt, now)
	return err
}

func (p PGRepo) RecordAttempt(ctx context.Context, appID, errMsg string) error {
	_, err := p.DB.ExecContext(ctx,
		`UPDATE dw_users SET account_attempts = account_attempts + 1, account_error = $2 WHERE application_id = $1`, appID, errMsg)
	return err
}

const accCols = `id, coalesce(account_no, ''), status, account_type, trading_type, management_type, opened_at, dw_account_id, dw_user_id`

func scanAccount(row interface{ Scan(...any) error }) (*Account, error) {
	var a Account
	var dwAcc sql.NullString
	err := row.Scan(&a.ID, &a.AccountNo, &a.Status, &a.AccountType, &a.TradingType, &a.Management, &a.OpenedAt, &dwAcc, &a.DWUserID)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	a.DWAccountID = dwAcc.String
	return &a, err
}

func (p PGRepo) NotOpen(ctx context.Context, limit int) ([]Account, error) {
	rows, err := p.DB.QueryContext(ctx,
		`SELECT `+accCols+` FROM accounts WHERE status IN ('PENDING') AND dw_account_id IS NOT NULL ORDER BY updated_at LIMIT $1`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Account
	for rows.Next() {
		a, err := scanAccount(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *a)
	}
	return out, rows.Err()
}

func (p PGRepo) UpdateStatus(ctx context.Context, dwAccountID, status string, openedAt *time.Time, now time.Time) error {
	_, err := p.DB.ExecContext(ctx,
		`UPDATE accounts SET status = $2, opened_at = coalesce(opened_at, $3), updated_at = $4 WHERE dw_account_id = $1`,
		dwAccountID, status, openedAt, now)
	return err
}

func (p PGRepo) ForUser(ctx context.Context, userID string) (*Account, error) {
	return scanAccount(p.DB.QueryRowContext(ctx,
		`SELECT a.id, coalesce(a.account_no, ''), a.status, a.account_type, a.trading_type, a.management_type, a.opened_at, a.dw_account_id, a.dw_user_id
		   FROM accounts a
		   JOIN dw_users d ON d.dw_user_id = a.dw_user_id
		   JOIN applications ap ON ap.id = d.application_id
		  WHERE ap.user_id = $1 AND ap.deleted_at IS NULL
		  ORDER BY a.created_at LIMIT 1`, userID))
}

func (p PGRepo) Audit(ctx context.Context, actor, action, target string, detail map[string]any) error {
	return store.Audit(ctx, p.DB, actor, action, target, detail)
}
