DROP TABLE IF EXISTS application_documents;
DROP INDEX IF EXISTS applications_pending_submit_idx;
ALTER TABLE applications
    DROP COLUMN IF EXISTS last_attempt_at,
    DROP COLUMN IF EXISTS submit_blocked,
    DROP COLUMN IF EXISTS submit_error,
    DROP COLUMN IF EXISTS submit_attempts;
ALTER TABLE dw_users
    DROP COLUMN IF EXISTS account_error,
    DROP COLUMN IF EXISTS account_attempts,
    DROP COLUMN IF EXISTS kyc_checked_at;
-- 回滚前须确保没有 dw_user_id 为空的行
ALTER TABLE dw_users ALTER COLUMN dw_user_id SET NOT NULL;
