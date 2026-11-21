-- F22-b 市场统计"近 30 日"：标的每日收盘快照（虚拟行情）。美东交易日收盘后（16:05 起）为标的池全部股票与 ETF 各记一条，
-- 每个代码 × 美东日期一条（主键去重，重复执行覆盖为同日最新值）。只用于展示统计，不参与任何资金计算。
CREATE TABLE instrument_daily_close (
    symbol       text           NOT NULL,
    day          date           NOT NULL,
    close        numeric(18, 4) NOT NULL,
    chg_pct      numeric(9, 4)  NOT NULL,
    captured_at  timestamptz    NOT NULL DEFAULT now(),
    PRIMARY KEY (symbol, day)
);
