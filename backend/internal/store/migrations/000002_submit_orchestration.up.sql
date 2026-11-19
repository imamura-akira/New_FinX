-- 开户提交编排与 KYC 对账（backend-design.md 第 4、5 节；design/progress.md 第 3 节）

-- 1. 先落库后端生成的 DW username/password，再调 POST /users，成功后回填 dw_user_id。
--    这样请求结果不明（超时）时不会用新用户名重复创建 DW User。
ALTER TABLE dw_users ALTER COLUMN dw_user_id DROP NOT NULL;
ALTER TABLE dw_users
    ADD COLUMN kyc_checked_at         timestamptz,           -- 最近一次对账（GET kyc-status）时间
    ADD COLUMN account_attempts       integer NOT NULL DEFAULT 0, -- KYC_APPROVED 后 POST /accounts 尝试次数
    ADD COLUMN account_error          text;                  -- 最近一次开户失败原因（不含 PII）

-- 2. 提交编排断点重试
ALTER TABLE applications
    ADD COLUMN submit_attempts integer     NOT NULL DEFAULT 0,
    ADD COLUMN submit_error    text,                         -- 最近一次失败原因（不含 PII）
    ADD COLUMN submit_blocked  boolean     NOT NULL DEFAULT false, -- DW 4xx 等不可自动重试的错误，转人工
    ADD COLUMN last_attempt_at timestamptz;
CREATE INDEX applications_pending_submit_idx ON applications (last_attempt_at)
    WHERE status = 'SUBMITTED' AND submit_blocked = false AND (orchestration_state IS NULL OR orchestration_state <> 'DOCS_DONE');

-- 3. 提交前暂存的证件影像（加密），提交编排时转 DW POST /documents
CREATE TABLE application_documents (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id    uuid        NOT NULL REFERENCES applications (id),
    doc_type          text        NOT NULL,
    side              text        NOT NULL CHECK (side IN ('FRONT', 'BACK')),
    content_type      text        NOT NULL,
    image_enc         bytea       NOT NULL,
    dw_document_id    text,
    uploaded_to_dw_at timestamptz,
    created_at        timestamptz NOT NULL DEFAULT now(),
    deleted_at        timestamptz
);
-- 同一面重复上传时旧记录软删，每面只保留一份有效记录
CREATE UNIQUE INDEX application_documents_side_uq ON application_documents (application_id, side) WHERE deleted_at IS NULL;
