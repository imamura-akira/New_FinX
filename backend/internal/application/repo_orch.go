package application

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"time"
)

// ---------- OrchRepo 的 Postgres 实现 ----------

func (p PGRepo) MarkSubmitted(ctx context.Context, appID, ref string, dataEnc, usernameEnc, passwordEnc []byte, now time.Time) error {
	tx, err := p.DB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback() //nolint:errcheck
	res, err := tx.ExecContext(ctx,
		`UPDATE applications SET status = 'SUBMITTED', step = 'p30', data_enc = $2, application_ref = $3,
		        submitted_at = $4, updated_at = $4, orchestration_state = NULL, submit_attempts = 0,
		        submit_error = NULL, submit_blocked = false, last_attempt_at = NULL
		  WHERE id = $1 AND status = 'DRAFT'`, appID, dataEnc, ref, now)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return ErrNotDraft
	}
	if _, err := tx.ExecContext(ctx,
		`INSERT INTO dw_users (application_id, dw_username_enc, dw_password_enc, kyc_status) VALUES ($1, $2, $3, 'KYC_NOT_READY')`,
		appID, usernameEnc, passwordEnc); err != nil {
		return err
	}
	return tx.Commit()
}

func (p PGRepo) LoadOrch(ctx context.Context, appID string) (*OrchApp, error) {
	var o OrchApp
	var dwID sql.NullString
	err := p.DB.QueryRowContext(ctx,
		`SELECT a.id, a.user_id, a.status, coalesce(a.step, ''), a.data_enc, coalesce(a.application_ref, ''), a.submitted_at,
		        coalesce(a.orchestration_state, ''), a.submit_attempts, a.submit_blocked,
		        u.email, d.dw_user_id, d.dw_username_enc, d.dw_password_enc
		   FROM applications a
		   JOIN users_app u ON u.id = a.user_id
		   JOIN dw_users d ON d.application_id = a.id AND d.deleted_at IS NULL
		  WHERE a.id = $1`, appID).
		Scan(&o.ID, &o.UserID, &o.Status, &o.Step, &o.DataEnc, &o.Ref, &o.SubmittedAt, &o.OrchState, &o.SubmitAttempts, &o.SubmitBlocked,
			&o.LoginEmail, &dwID, &o.UsernameEnc, &o.PasswordEnc)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	o.DWUserID = dwID.String
	return &o, nil
}

func (p PGRepo) SetDWUser(ctx context.Context, appID, dwUserID, state string, now time.Time) error {
	tx, err := p.DB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback() //nolint:errcheck
	if _, err := tx.ExecContext(ctx,
		`UPDATE dw_users SET dw_user_id = $2, updated_at = $3 WHERE application_id = $1`, appID, dwUserID, now); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx,
		`UPDATE applications SET orchestration_state = $2, updated_at = $3 WHERE id = $1`, appID, state, now); err != nil {
		return err
	}
	return tx.Commit()
}

func (p PGRepo) SetOrchState(ctx context.Context, appID, state string) error {
	_, err := p.DB.ExecContext(ctx, `UPDATE applications SET orchestration_state = $2, updated_at = now() WHERE id = $1`, appID, state)
	return err
}

func (p PGRepo) RecordAttempt(ctx context.Context, appID, errMsg string, blocked bool, now time.Time) error {
	_, err := p.DB.ExecContext(ctx,
		`UPDATE applications SET submit_attempts = submit_attempts + 1, submit_error = nullif($2, ''),
		        submit_blocked = submit_blocked OR $3, last_attempt_at = $4
		  WHERE id = $1`, appID, errMsg, blocked, now)
	return err
}

func (p PGRepo) PendingSubmissions(ctx context.Context, retryBefore time.Time, limit int) ([]string, error) {
	rows, err := p.DB.QueryContext(ctx,
		`SELECT id FROM applications
		  WHERE status = 'SUBMITTED' AND submit_blocked = false
		    AND (orchestration_state IS NULL OR orchestration_state <> 'DOCS_DONE')
		    AND submit_attempts < $3
		    AND (last_attempt_at IS NULL OR last_attempt_at < $1)
		  ORDER BY last_attempt_at NULLS FIRST LIMIT $2`, retryBefore, limit, maxSubmitAttempts)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

func (p PGRepo) StagedDocuments(ctx context.Context, appID string) ([]StagedDoc, error) {
	rows, err := p.DB.QueryContext(ctx,
		`SELECT id, doc_type, side, content_type, image_enc FROM application_documents
		  WHERE application_id = $1 AND deleted_at IS NULL AND uploaded_to_dw_at IS NULL ORDER BY side DESC`, appID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []StagedDoc
	for rows.Next() {
		var d StagedDoc
		if err := rows.Scan(&d.ID, &d.DocType, &d.Side, &d.ContentType, &d.ImageEnc); err != nil {
			return nil, err
		}
		out = append(out, d)
	}
	return out, rows.Err()
}

func (p PGRepo) MarkDocumentUploaded(ctx context.Context, docID, dwDocumentID string, now time.Time) error {
	_, err := p.DB.ExecContext(ctx,
		`UPDATE application_documents SET dw_document_id = nullif($2, ''), uploaded_to_dw_at = $3 WHERE id = $1`, docID, dwDocumentID, now)
	return err
}

func (p PGRepo) Audit(ctx context.Context, actor, action, target string, detail map[string]any) error {
	var raw []byte
	if detail != nil {
		raw, _ = json.Marshal(detail)
	}
	_, err := p.DB.ExecContext(ctx, `INSERT INTO audit_log (actor, action, target, detail) VALUES ($1, $2, $3, $4)`, actor, action, target, raw)
	return err
}
