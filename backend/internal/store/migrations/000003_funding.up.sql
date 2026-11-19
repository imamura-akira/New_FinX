-- 出入金（Demo-1 #6；api-spec.md 第 4、5 节）

-- 银行账户：昵称（DW 必填）；账号全文仍不落库，只存 DW id 与尾号
ALTER TABLE bank_accounts ADD COLUMN nickname text;

-- 出入金：
--   idempotency_key：我方生成并发送给 DW（Create Deposit 支持 Idempotency-Key），先落库再调 DW，结果不明时用同一键重放
--   checked_at：最近一次向 DW 查询状态的时间（对账轮询）
--   wire_enc：WIRE 出金的收款银行信息（含账号，加密）
--   created_by：发起用户（审计）
ALTER TABLE transfers
    ADD COLUMN idempotency_key uuid UNIQUE,
    ADD COLUMN checked_at      timestamptz,
    ADD COLUMN wire_enc        bytea,
    ADD COLUMN created_by      uuid REFERENCES users_app (id);
CREATE INDEX transfers_inflight_idx ON transfers (checked_at NULLS FIRST)
    WHERE status NOT IN ('FAILED', 'REJECTED', 'RETURNED', 'CANCELLED');
