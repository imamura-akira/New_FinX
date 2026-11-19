ALTER TABLE transfers
    DROP COLUMN IF EXISTS withdrawable_at,
    DROP COLUMN IF EXISTS buying_power_at;
