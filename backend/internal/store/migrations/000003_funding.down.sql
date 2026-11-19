DROP INDEX IF EXISTS transfers_inflight_idx;
ALTER TABLE transfers
    DROP COLUMN IF EXISTS created_by,
    DROP COLUMN IF EXISTS wire_enc,
    DROP COLUMN IF EXISTS checked_at,
    DROP COLUMN IF EXISTS idempotency_key;
ALTER TABLE bank_accounts DROP COLUMN IF EXISTS nickname;
