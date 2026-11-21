-- F22-a 资产页 1D 走势：日内资产快照。美东交易日盘中（09:30–16:00，周一至周五）每 30 分钟一档，
-- 实盘（DW 现金 + 持仓市值）与模拟盘（模拟账户）各记一条；每个用户 × 账户类型 × 档位时刻一条（主键去重）。
-- 与 asset_snapshots（每日收盘快照）互不影响；为内部记录，不参与任何资金计算。
CREATE TABLE asset_intraday (
    user_id      uuid           NOT NULL REFERENCES users_app (id),
    mode         text           NOT NULL CHECK (mode IN ('REAL', 'PAPER')),
    slot_at      timestamptz    NOT NULL,
    total        numeric(18, 2) NOT NULL,
    cash         numeric(18, 2) NOT NULL,
    stock_value  numeric(18, 2) NOT NULL,
    etf_value    numeric(18, 2) NOT NULL,
    captured_at  timestamptz    NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, mode, slot_at)
);
