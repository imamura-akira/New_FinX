-- 首版数据模型（backend-design.md 第 6 节，11 张表）
-- PII 规则：SSN/税号、证件影像、地址、出生日期等 → 应用层 AES-256-GCM 字段级加密（*_enc 列，bytea）。
-- 保存期限与删除流程待法务（PRD 问题 15）：主要表预留 deleted_at 软删。
-- 需要 PostgreSQL 13+（gen_random_uuid 为内置函数）。

-- 1. App 登录账户（与 DW User 分开，通过 applications 关联）
CREATE TABLE users_app (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email             text        NOT NULL,
    login_provider    text        NOT NULL DEFAULT 'EMAIL' CHECK (login_provider IN ('EMAIL', 'GOOGLE', 'APPLE')),
    provider_user_id  text,
    email_is_relay    boolean     NOT NULL DEFAULT false,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),
    deleted_at        timestamptz
);
CREATE UNIQUE INDEX users_app_email_uq ON users_app (lower(email)) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX users_app_provider_uq ON users_app (login_provider, provider_user_id) WHERE provider_user_id IS NOT NULL;

-- 2. 会话（只存 token 哈希）
CREATE TABLE sessions (
    token_hash  text PRIMARY KEY,
    user_id     uuid        NOT NULL REFERENCES users_app (id),
    expires_at  timestamptz NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),
    revoked_at  timestamptz
);
CREATE INDEX sessions_user_idx ON sessions (user_id);

-- 3. 开户申请（草稿与提交）。data_enc 为加密后的 JSON（加密后无法用 jsonb，存 bytea）
CREATE TABLE applications (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             uuid        NOT NULL UNIQUE REFERENCES users_app (id),
    status              text        NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('NONE', 'DRAFT', 'SUBMITTED', 'APPROVED', 'DENIED')),
    step                text,
    data_enc            bytea,
    application_ref     text UNIQUE,
    orchestration_state text CHECK (orchestration_state IN ('CREATED', 'PATCHED', 'DOCS_DONE')), -- 提交编排断点（第 4 节）
    submitted_at        timestamptz,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    deleted_at          timestamptz
);

-- 4. DW User 影子（username/password 由后端生成并加密保存【Q-DW-4】）
CREATE TABLE dw_users (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id   uuid        NOT NULL UNIQUE REFERENCES applications (id),
    dw_user_id       text        NOT NULL UNIQUE,
    dw_username_enc  bytea,
    dw_password_enc  bytea,
    kyc_status       text        NOT NULL DEFAULT 'KYC_NOT_READY' CHECK (kyc_status IN (
                         'KYC_NOT_READY', 'KYC_READY', 'KYC_PROCESSING', 'KYC_INFO_REQUIRED',
                         'KYC_DOC_REQUIRED', 'KYC_MANUAL_REVIEW', 'KYC_APPROVED', 'KYC_DENIED')),
    kyc_updated_at   timestamptz,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),
    deleted_at       timestamptz
);

-- 5. KYC 问题项（P-34 数据源）。raw 为 DW 原始返回，可能含 PII，只供后台排查
CREATE TABLE kyc_issues (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    dw_user_id    text        NOT NULL REFERENCES dw_users (dw_user_id),
    code          text        NOT NULL,
    field         text,
    raw           jsonb,
    user_message  text,
    resolved_at   timestamptz,
    created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX kyc_issues_user_idx ON kyc_issues (dw_user_id) WHERE resolved_at IS NULL;

-- 6. 交易账户（首期固定 LIVE / CASH / SELF）
CREATE TABLE accounts (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    dw_user_id       text        NOT NULL REFERENCES dw_users (dw_user_id),
    dw_account_id    text UNIQUE,
    account_no       text UNIQUE,
    status           text        NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'OPEN', 'OPEN_NO_NEW_TRADES', 'FROZEN', 'CLOSED')),
    account_type     text        NOT NULL DEFAULT 'LIVE' CHECK (account_type = 'LIVE'),
    trading_type     text        NOT NULL DEFAULT 'CASH' CHECK (trading_type = 'CASH'),
    management_type  text        NOT NULL DEFAULT 'SELF' CHECK (management_type = 'SELF'),
    opened_at        timestamptz,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now()
);

-- 7. 银行账户（账号全文不落库：只存 DW id + 尾号）
CREATE TABLE bank_accounts (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id          uuid        NOT NULL REFERENCES accounts (id),
    dw_bank_account_id  text UNIQUE,
    bank_name           text,
    mask                text CHECK (mask ~ '^[0-9]{4}$'),
    type                text CHECK (type IN ('CHECKING', 'SAVINGS')),
    owner_name          text,
    status              text        NOT NULL DEFAULT 'PENDING',
    created_at          timestamptz NOT NULL DEFAULT now(),
    deleted_at          timestamptz
);
CREATE INDEX bank_accounts_account_idx ON bank_accounts (account_id) WHERE deleted_at IS NULL;

-- 8. 出入金（状态枚举：入金按 DW Deposit Status；出金待 Q-DW-8d，故不加 CHECK）
CREATE TABLE transfers (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id       uuid          NOT NULL REFERENCES accounts (id),
    bank_account_id  uuid REFERENCES bank_accounts (id),
    type             text          NOT NULL CHECK (type IN ('DEPOSIT', 'WITHDRAWAL')),
    method           text          NOT NULL CHECK (method IN ('ACH', 'WIRE')),
    amount           numeric(18,2) NOT NULL CHECK (amount > 0),
    currency         text          NOT NULL DEFAULT 'USD' CHECK (currency = 'USD'),
    status           text          NOT NULL,
    failure_reason   text,
    dw_ref           text UNIQUE,
    submitted_at     timestamptz   NOT NULL DEFAULT now(),
    done_at          timestamptz,
    created_at       timestamptz   NOT NULL DEFAULT now(),
    updated_at       timestamptz   NOT NULL DEFAULT now()
);
CREATE INDEX transfers_account_idx ON transfers (account_id, submitted_at DESC);

-- 9. 证件元数据（影像存对象存储，对象键加密）
CREATE TABLE documents_meta (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    dw_user_id       text        NOT NULL REFERENCES dw_users (dw_user_id),
    doc_type         text        NOT NULL,
    side             text        NOT NULL CHECK (side IN ('FRONT', 'BACK')),
    object_key_enc   bytea,
    dw_document_id   text,
    uploaded_at      timestamptz NOT NULL DEFAULT now(),
    deleted_at       timestamptz
);

-- 10. DW 事件幂等去重
CREATE TABLE dw_events (
    event_id      text PRIMARY KEY,
    type          text        NOT NULL,
    payload       jsonb,
    received_at   timestamptz NOT NULL DEFAULT now(),
    processed_at  timestamptz
);
CREATE INDEX dw_events_unprocessed_idx ON dw_events (received_at) WHERE processed_at IS NULL;

-- 11. 审计日志（状态变更）
CREATE TABLE audit_log (
    id      bigserial PRIMARY KEY,
    actor   text        NOT NULL,
    action  text        NOT NULL,
    target  text,
    at      timestamptz NOT NULL DEFAULT now(),
    detail  jsonb
);
CREATE INDEX audit_log_target_idx ON audit_log (target, at DESC);
