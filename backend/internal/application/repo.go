package application

import (
	"context"
	"database/sql"
	"errors"
	"time"
)

// App：applications 行（data_enc 为加密后的 stored JSON）。
type App struct {
	ID             string
	UserID         string
	Status         string // NONE/DRAFT/SUBMITTED/APPROVED/DENIED
	Step           string
	DataEnc        []byte
	Ref            string
	SubmittedAt    *time.Time
	OrchState      string // ""/CREATED/PATCHED/DOCS_DONE
	SubmitAttempts int
	SubmitBlocked  bool
}

// DocMeta：已暂存证件（不含影像）。
type DocMeta struct {
	ID         string    `json:"documentId"`
	DocType    string    `json:"docType"`
	Side       string    `json:"side"`
	UploadedAt time.Time `json:"uploadedAt"`
}

// KYCInfo：dw_users 影子中与展示相关的部分。
type KYCInfo struct {
	DWUserID  string
	Status    string
	UpdatedAt *time.Time
}

var (
	// ErrNotDraft：申请已提交，不能再修改草稿。
	ErrNotDraft = errors.New("application: 不是草稿状态")
)

// Repo：草稿相关持久化（提交编排的方法见 orchestrator 所在文件）。
type Repo interface {
	GetByUser(ctx context.Context, userID string) (*App, error) // 没有时返回 nil, nil
	EnsureDraft(ctx context.Context, userID string) (*App, error)
	SaveDraft(ctx context.Context, appID, step string, dataEnc []byte, now time.Time) error // 非草稿返回 ErrNotDraft
	PutDocument(ctx context.Context, appID, docType, side, contentType string, imageEnc []byte) (string, error)
	ListDocuments(ctx context.Context, appID string) ([]DocMeta, error)
	KYC(ctx context.Context, appID string) (*KYCInfo, error) // 尚未创建 DW User 时返回 nil, nil
}

// PGRepo：Postgres 实现。
type PGRepo struct{ DB *sql.DB }

const appCols = `id, user_id, status, coalesce(step, ''), data_enc, coalesce(application_ref, ''), submitted_at,
	coalesce(orchestration_state, ''), submit_attempts, submit_blocked`

func scanApp(row interface{ Scan(...any) error }) (*App, error) {
	var a App
	err := row.Scan(&a.ID, &a.UserID, &a.Status, &a.Step, &a.DataEnc, &a.Ref, &a.SubmittedAt, &a.OrchState, &a.SubmitAttempts, &a.SubmitBlocked)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &a, nil
}

func (p PGRepo) GetByUser(ctx context.Context, userID string) (*App, error) {
	return scanApp(p.DB.QueryRowContext(ctx, `SELECT `+appCols+` FROM applications WHERE user_id = $1 AND deleted_at IS NULL`, userID))
}

func (p PGRepo) EnsureDraft(ctx context.Context, userID string) (*App, error) {
	if _, err := p.DB.ExecContext(ctx, `INSERT INTO applications (user_id, status) VALUES ($1, 'DRAFT') ON CONFLICT (user_id) DO NOTHING`, userID); err != nil {
		return nil, err
	}
	return p.GetByUser(ctx, userID)
}

func (p PGRepo) SaveDraft(ctx context.Context, appID, step string, dataEnc []byte, now time.Time) error {
	res, err := p.DB.ExecContext(ctx,
		`UPDATE applications SET step = $2, data_enc = $3, updated_at = $4 WHERE id = $1 AND status = 'DRAFT'`, appID, step, dataEnc, now)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return ErrNotDraft
	}
	return nil
}

func (p PGRepo) PutDocument(ctx context.Context, appID, docType, side, contentType string, imageEnc []byte) (string, error) {
	tx, err := p.DB.BeginTx(ctx, nil)
	if err != nil {
		return "", err
	}
	defer tx.Rollback() //nolint:errcheck
	if _, err := tx.ExecContext(ctx,
		`UPDATE application_documents SET deleted_at = now() WHERE application_id = $1 AND side = $2 AND deleted_at IS NULL`, appID, side); err != nil {
		return "", err
	}
	var id string
	if err := tx.QueryRowContext(ctx,
		`INSERT INTO application_documents (application_id, doc_type, side, content_type, image_enc) VALUES ($1, $2, $3, $4, $5) RETURNING id`,
		appID, docType, side, contentType, imageEnc).Scan(&id); err != nil {
		return "", err
	}
	return id, tx.Commit()
}

func (p PGRepo) ListDocuments(ctx context.Context, appID string) ([]DocMeta, error) {
	rows, err := p.DB.QueryContext(ctx,
		`SELECT id, doc_type, side, created_at FROM application_documents WHERE application_id = $1 AND deleted_at IS NULL ORDER BY side`, appID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []DocMeta{}
	for rows.Next() {
		var d DocMeta
		if err := rows.Scan(&d.ID, &d.DocType, &d.Side, &d.UploadedAt); err != nil {
			return nil, err
		}
		out = append(out, d)
	}
	return out, rows.Err()
}

func (p PGRepo) KYC(ctx context.Context, appID string) (*KYCInfo, error) {
	var k KYCInfo
	var dwID sql.NullString
	err := p.DB.QueryRowContext(ctx,
		`SELECT dw_user_id, kyc_status, kyc_updated_at FROM dw_users WHERE application_id = $1 AND deleted_at IS NULL`, appID).
		Scan(&dwID, &k.Status, &k.UpdatedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	k.DWUserID = dwID.String
	return &k, nil
}
