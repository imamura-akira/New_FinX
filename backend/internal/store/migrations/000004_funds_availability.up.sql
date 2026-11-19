-- 入金资金可用日期（沙盒实测 2026-11-19：GET /funding/deposits/{id} 返回 seasoningDetails，
-- depositBuyingPowerHoldExpires = 购买力可用日，seasoningPeriodExpires = 可提现日）
ALTER TABLE transfers
    ADD COLUMN buying_power_at timestamptz,
    ADD COLUMN withdrawable_at timestamptz;
