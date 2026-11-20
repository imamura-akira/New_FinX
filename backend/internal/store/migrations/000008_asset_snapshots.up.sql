-- F17 资产趋势：每日资产快照（实盘取 DW 返回的现金与持仓市值；模拟盘取模拟账户）。
-- 每个用户、每种账户、每个美东日期只保留一条（主键去重）：收盘后快照（CLOSE）覆盖当日兜底快照（FIRST_REQUEST），
-- 兜底快照只在当日尚无记录时写入。快照为内部记录，不参与任何资金计算。
CREATE TABLE asset_snapshots (
    user_id      uuid           NOT NULL REFERENCES users_app (id),
    mode         text           NOT NULL CHECK (mode IN ('REAL', 'PAPER')),
    day          date           NOT NULL,
    total        numeric(18, 2) NOT NULL,
    cash         numeric(18, 2) NOT NULL,
    stock_value  numeric(18, 2) NOT NULL,
    etf_value    numeric(18, 2) NOT NULL,
    source       text           NOT NULL CHECK (source IN ('CLOSE', 'FIRST_REQUEST')),
    captured_at  timestamptz    NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, mode, day)
);
