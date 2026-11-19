// Package events：DW 状态同步。第一阶段不接 SQS，以轮询对账为准（backend-design.md 第 5 节）。
//
// 每个周期：非终态 KYC → GET /users/{id}/kyc-status；KYC_APPROVED 且无账户 → 开户；未 OPEN 账户 → 刷新状态。
package events

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/dwclient"
	"github.com/imamura-akira/New_FinX/backend/internal/store"
)

// KYC 状态（DW 8 状态，已核实）。
var kycStatuses = map[string]bool{
	"KYC_NOT_READY": true, "KYC_READY": true, "KYC_PROCESSING": true, "KYC_INFO_REQUIRED": true,
	"KYC_DOC_REQUIRED": true, "KYC_MANUAL_REVIEW": true, "KYC_APPROVED": true, "KYC_DENIED": true,
}

// Terminal：终态不再轮询。
func Terminal(status string) bool { return status == "KYC_APPROVED" || status == "KYC_DENIED" }

// KYCTarget：需要对账的 DW User。
type KYCTarget struct {
	AppID, DWUserID, Status string
}

// Issue：KYC 问题项（P-34 数据源）。Raw 为 DW 原始条目，可能含 PII，只入库不写日志。
type Issue struct {
	Code, Field, UserMessage string
	Raw                      json.RawMessage
}

// KYCRepo：持久化。
type KYCRepo interface {
	DueKYC(ctx context.Context, checkedBefore time.Time, limit int) ([]KYCTarget, error)
	KYCTargetFor(ctx context.Context, appID string) (*KYCTarget, error)
	SaveKYC(ctx context.Context, t KYCTarget, status string, issues []Issue, now time.Time) error
	TouchKYC(ctx context.Context, appID string, now time.Time) error
}

// DW：所需的 DW 能力。
type DW interface {
	Do(ctx context.Context, method, path string, reqBody, out any) error
}

// Accounts：开户与账户状态刷新（account.Service 满足）。
type Accounts interface {
	EnsureAccounts(ctx context.Context)
	RefreshStatuses(ctx context.Context)
}

// Reconciler：轮询对账器。
type Reconciler struct {
	repo     KYCRepo
	dw       DW
	accounts Accounts
	interval time.Duration
	logger   *slog.Logger
	now      func() time.Time
}

// NewReconciler 创建对账器；interval 为轮询周期（KYC_POLL_INTERVAL）。
func NewReconciler(repo KYCRepo, dw DW, accounts Accounts, interval time.Duration, logger *slog.Logger) *Reconciler {
	if logger == nil {
		logger = slog.Default()
	}
	return &Reconciler{repo: repo, dw: dw, accounts: accounts, interval: interval, logger: logger, now: time.Now}
}

// Start 周期运行，直到 ctx 结束。
func (r *Reconciler) Start(ctx context.Context) {
	t := time.NewTicker(r.interval)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			r.Tick(ctx)
		}
	}
}

// Tick 执行一轮对账。
func (r *Reconciler) Tick(ctx context.Context) {
	due, err := r.repo.DueKYC(ctx, r.now().Add(-r.interval/2), 50)
	if err != nil {
		r.logger.ErrorContext(ctx, "list due kyc failed", slog.String("error", err.Error()))
	}
	for _, t := range due {
		r.refresh(ctx, t)
	}
	if r.accounts != nil {
		r.accounts.EnsureAccounts(ctx)
		r.accounts.RefreshStatuses(ctx)
	}
}

// RefreshApp 立即刷新一个申请的 KYC 状态（DW User 创建后调用），并在通过时尝试开户。
func (r *Reconciler) RefreshApp(ctx context.Context, appID string) {
	t, err := r.repo.KYCTargetFor(ctx, appID)
	if err != nil || t == nil {
		return
	}
	r.refresh(ctx, *t)
	if r.accounts != nil {
		r.accounts.EnsureAccounts(ctx)
	}
}

func (r *Reconciler) refresh(ctx context.Context, t KYCTarget) {
	var resp map[string]any
	if err := r.dw.Do(ctx, http.MethodGet, "/users/"+t.DWUserID+"/kyc-status", nil, &resp); err != nil {
		r.logger.WarnContext(ctx, "kyc-status failed", slog.String("application_id", t.AppID), slog.String("error", safeErr(err)))
		_ = r.repo.TouchKYC(ctx, t.AppID, r.now().UTC())
		return
	}
	status, issues := ParseKYC(resp)
	if !kycStatuses[status] {
		r.logger.ErrorContext(ctx, "kyc-status unrecognized (待沙盒验证)", slog.String("application_id", t.AppID), slog.String("status", status))
		_ = r.repo.TouchKYC(ctx, t.AppID, r.now().UTC())
		return
	}
	if err := r.repo.SaveKYC(ctx, t, status, issues, r.now().UTC()); err != nil {
		r.logger.ErrorContext(ctx, "save kyc failed", slog.String("application_id", t.AppID), slog.String("error", err.Error()))
		return
	}
	if status != t.Status {
		r.logger.InfoContext(ctx, "kyc status changed", slog.String("application_id", t.AppID), slog.String("from", t.Status), slog.String("to", status), slog.Int("issues", len(issues)))
	}
}

// ParseKYC 宽松解析 GET /users/{id}/kyc-status 的响应：
// 优先取 kyc.status.name（pages.md 3.1.2 文档描述）；沙盒实际无此字段时，顶层 status.name=APPROVED 视为 KYC_APPROVED；
// 问题项取 kyc.errors / kyc.details / kyc.reasons 数组中的对象。
func ParseKYC(resp map[string]any) (string, []Issue) {
	k, _ := resp["kyc"].(map[string]any)
	status := statusName(k["status"])
	if status == "" && k != nil {
		// 沙盒实测（2026-11-19）：kyc 对象只有 accepted / approved，无 kyc.status；
		// 粗粒度状态在顶层 status.name（User 对象：PENDING / APPROVED）。
		// 只把 APPROVED 映射为 KYC_APPROVED；PENDING 不映射（无法确定是哪个细分状态），保持原状态并记录。
		if top := statusName(resp["status"]); top == "APPROVED" {
			status = "KYC_APPROVED"
		} else if top != "" {
			status = "USER_" + top
		}
	}
	if status != "" && !strings.HasPrefix(status, "KYC_") && !strings.HasPrefix(status, "USER_") {
		status = "KYC_" + status
	}
	var issues []Issue
	for _, key := range []string{"errors", "details", "reasons"} {
		arr, _ := k[key].([]any)
		for _, item := range arr {
			m, ok := item.(map[string]any)
			if !ok {
				continue
			}
			code := firstString(m, "code", "name", "type")
			if code == "" {
				continue
			}
			raw, _ := json.Marshal(m)
			issues = append(issues, Issue{Code: code, Field: firstString(m, "field"), UserMessage: "请核对此项信息", Raw: raw})
		}
	}
	return status, issues
}

func statusName(v any) string {
	switch x := v.(type) {
	case string:
		return strings.ToUpper(strings.TrimSpace(x))
	case map[string]any:
		n, _ := x["name"].(string)
		return strings.ToUpper(strings.TrimSpace(n))
	}
	return ""
}

func firstString(m map[string]any, keys ...string) string {
	for _, k := range keys {
		if v, ok := m[k].(string); ok && v != "" {
			return v
		}
	}
	return ""
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

func (p PGRepo) DueKYC(ctx context.Context, checkedBefore time.Time, limit int) ([]KYCTarget, error) {
	rows, err := p.DB.QueryContext(ctx,
		`SELECT d.application_id, d.dw_user_id, d.kyc_status FROM dw_users d
		  WHERE d.dw_user_id IS NOT NULL AND d.deleted_at IS NULL
		    AND d.kyc_status NOT IN ('KYC_APPROVED', 'KYC_DENIED')
		    AND (d.kyc_checked_at IS NULL OR d.kyc_checked_at < $1)
		  ORDER BY d.kyc_checked_at NULLS FIRST LIMIT $2`, checkedBefore, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []KYCTarget
	for rows.Next() {
		var t KYCTarget
		if err := rows.Scan(&t.AppID, &t.DWUserID, &t.Status); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

func (p PGRepo) KYCTargetFor(ctx context.Context, appID string) (*KYCTarget, error) {
	var t KYCTarget
	var dwID sql.NullString
	err := p.DB.QueryRowContext(ctx,
		`SELECT application_id, dw_user_id, kyc_status FROM dw_users WHERE application_id = $1 AND deleted_at IS NULL`, appID).
		Scan(&t.AppID, &dwID, &t.Status)
	if errors.Is(err, sql.ErrNoRows) || (err == nil && !dwID.Valid) {
		return nil, nil
	}
	t.DWUserID = dwID.String
	return &t, err
}

func (p PGRepo) SaveKYC(ctx context.Context, t KYCTarget, status string, issues []Issue, now time.Time) error {
	tx, err := p.DB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback() //nolint:errcheck
	changed := status != t.Status
	if _, err := tx.ExecContext(ctx,
		`UPDATE dw_users SET kyc_status = $2, kyc_checked_at = $3, updated_at = $3,
		        kyc_updated_at = CASE WHEN $4 OR kyc_updated_at IS NULL THEN $3 ELSE kyc_updated_at END
		  WHERE application_id = $1`, t.AppID, status, now, changed); err != nil {
		return err
	}
	// 问题项：以本次 DW 返回为准（旧的标记已解决）
	if _, err := tx.ExecContext(ctx, `UPDATE kyc_issues SET resolved_at = $2 WHERE dw_user_id = $1 AND resolved_at IS NULL`, t.DWUserID, now); err != nil {
		return err
	}
	for _, is := range issues {
		if _, err := tx.ExecContext(ctx,
			`INSERT INTO kyc_issues (dw_user_id, code, field, raw, user_message) VALUES ($1, $2, nullif($3, ''), $4, $5)`,
			t.DWUserID, is.Code, is.Field, []byte(is.Raw), is.UserMessage); err != nil {
			return err
		}
	}
	appStatus := map[string]string{"KYC_APPROVED": "APPROVED", "KYC_DENIED": "DENIED"}[status]
	if appStatus != "" {
		if _, err := tx.ExecContext(ctx, `UPDATE applications SET status = $2, updated_at = $3 WHERE id = $1 AND status = 'SUBMITTED'`, t.AppID, appStatus, now); err != nil {
			return err
		}
	}
	if err := tx.Commit(); err != nil {
		return err
	}
	if changed {
		_ = store.Audit(ctx, p.DB, "system", "dw.kyc.status", "application:"+t.AppID, map[string]any{"from": t.Status, "to": status, "issues": len(issues)})
	}
	return nil
}

func (p PGRepo) TouchKYC(ctx context.Context, appID string, now time.Time) error {
	_, err := p.DB.ExecContext(ctx, `UPDATE dw_users SET kyc_checked_at = $2 WHERE application_id = $1`, appID, now)
	return err
}
