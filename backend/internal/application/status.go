package application

import (
	"context"
	"database/sql"
	"errors"
	"net/http"
	"time"

	"github.com/imamura-akira/New_FinX/backend/internal/httpx"
)

// 提交进度（GET /application/status 新增字段 submitState，api-spec.md 第 10 节登记）。
// KYC 状态一律是 DW 真实返回；DW User 创建前保持 KYC_NOT_READY，由 submitState 说明我方进度。
const (
	SubmitNotSubmitted   = "NOT_SUBMITTED"   // 草稿 / 无申请
	SubmitSubmitting     = "SUBMITTING"      // 已提交，正在提交给 DW（含续传中）
	SubmitDone           = "SUBMITTED"       // 已全部提交给 DW
	SubmitNeedsAttention = "NEEDS_ATTENTION" // DW 拒绝了请求，需人工处理
)

// Issue：P-34 问题项。
type Issue struct {
	Code        string  `json:"code"`
	Field       *string `json:"field"`
	UserMessage string  `json:"userMessage"`
}

// Progress：开户进度快照。
type Progress struct {
	AppStatus     string
	Ref           string
	SubmittedAt   *time.Time
	OrchState     string
	Blocked       bool
	HasDWUser     bool
	KYCStatus     string
	KYCUpdatedAt  *time.Time
	Issues        []Issue
	AccountStatus *string
	AccountNo     *string
}

type statusView struct {
	KYCStatus      string     `json:"kycStatus"`
	KYCUpdatedAt   *time.Time `json:"kycUpdatedAt"`
	Issues         []Issue    `json:"issues"`
	RequiredDocs   []any      `json:"requiredDocs"`
	AccountStatus  *string    `json:"accountStatus"`
	AccountNo      *string    `json:"accountNo"`
	ApplicationRef *string    `json:"applicationRef"`
	SubmittedAt    *time.Time `json:"submittedAt"`
	SubmitState    string     `json:"submitState"`
}

func (s *Service) handleStatus(w http.ResponseWriter, r *http.Request) {
	p, err := s.repo.Progress(r.Context(), httpx.UserID(r.Context()))
	if err != nil {
		httpx.Fail(w, r, err)
		return
	}
	httpx.OK(w, buildStatus(p))
}

func buildStatus(p *Progress) statusView {
	v := statusView{KYCStatus: "KYC_NOT_READY", Issues: []Issue{}, RequiredDocs: []any{}, SubmitState: SubmitNotSubmitted}
	if p == nil || p.AppStatus == "" || p.AppStatus == "DRAFT" {
		return v
	}
	if p.KYCStatus != "" {
		v.KYCStatus = p.KYCStatus
	}
	v.KYCUpdatedAt, v.AccountStatus, v.AccountNo, v.SubmittedAt = p.KYCUpdatedAt, p.AccountStatus, p.AccountNo, p.SubmittedAt
	if p.Ref != "" {
		v.ApplicationRef = &p.Ref
	}
	if p.Issues != nil {
		v.Issues = p.Issues
	}
	switch {
	case p.Blocked:
		v.SubmitState = SubmitNeedsAttention
	case !p.HasDWUser || p.OrchState != StateDocsDone:
		v.SubmitState = SubmitSubmitting
	default:
		v.SubmitState = SubmitDone
	}
	return v
}

// Progress：PGRepo 实现。
func (p PGRepo) Progress(ctx context.Context, userID string) (*Progress, error) {
	var pr Progress
	var appID string
	var dwID, kyc, accStatus, accNo sql.NullString
	err := p.DB.QueryRowContext(ctx,
		`SELECT a.id, a.status, coalesce(a.application_ref, ''), a.submitted_at, coalesce(a.orchestration_state, ''), a.submit_blocked,
		        d.dw_user_id, d.kyc_status, d.kyc_updated_at, ac.status, ac.account_no
		   FROM applications a
		   LEFT JOIN dw_users d ON d.application_id = a.id AND d.deleted_at IS NULL
		   LEFT JOIN accounts ac ON ac.dw_user_id = d.dw_user_id
		  WHERE a.user_id = $1 AND a.deleted_at IS NULL
		  ORDER BY ac.created_at NULLS LAST LIMIT 1`, userID).
		Scan(&appID, &pr.AppStatus, &pr.Ref, &pr.SubmittedAt, &pr.OrchState, &pr.Blocked, &dwID, &kyc, &pr.KYCUpdatedAt, &accStatus, &accNo)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	pr.HasDWUser, pr.KYCStatus = dwID.Valid, kyc.String
	if accStatus.Valid {
		pr.AccountStatus = &accStatus.String
	}
	if accNo.Valid {
		pr.AccountNo = &accNo.String
	}
	if dwID.Valid {
		rows, err := p.DB.QueryContext(ctx,
			`SELECT code, field, coalesce(user_message, '') FROM kyc_issues WHERE dw_user_id = $1 AND resolved_at IS NULL ORDER BY created_at`, dwID.String)
		if err != nil {
			return nil, err
		}
		defer rows.Close()
		for rows.Next() {
			var is Issue
			var field sql.NullString
			if err := rows.Scan(&is.Code, &field, &is.UserMessage); err != nil {
				return nil, err
			}
			if field.Valid {
				is.Field = &field.String
			}
			pr.Issues = append(pr.Issues, is)
		}
		if err := rows.Err(); err != nil {
			return nil, err
		}
	}
	return &pr, nil
}

// LegalName 返回开户资料中的法定姓名（"First Last"），供资金模块强制写入绑卡户名与 WIRE 收款人。
// 只允许已提交的申请（草稿中的姓名可能还会修改）。
func (s *Service) LegalName(ctx context.Context, userID string) (string, error) {
	a, err := s.repo.GetByUser(ctx, userID)
	if err != nil || a == nil || a.Status == "DRAFT" {
		return "", err
	}
	st, err := s.load(a)
	if err != nil {
		return "", err
	}
	d, err := decodeData(st.Data)
	if err != nil {
		return "", err
	}
	return FullName(d), nil
}
