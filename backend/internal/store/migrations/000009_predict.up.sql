-- F19 预测板块（积分演示版）：预测积分账户、预测市场、下注。与券商资金、模拟盘完全隔离，不涉及真实资金。
CREATE TABLE predict_accounts (
    user_id     uuid        PRIMARY KEY REFERENCES users_app (id),
    points      bigint      NOT NULL CHECK (points >= 0),
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);

-- kind：UPDOWN（15 分钟涨跌，按虚拟行情自动结算）/ EVENT（事件，管理命令结算）。
-- 二元结果：YES / NO（UPDOWN 中 YES = 上涨，NO = 下跌）。pool_* 含种子流动性（seed_*），概率 = pool_yes / (pool_yes + pool_no)。
CREATE TABLE predict_markets (
    id               text           PRIMARY KEY,
    kind             text           NOT NULL CHECK (kind IN ('UPDOWN', 'EVENT')),
    category         text           NOT NULL CHECK (category IN ('CRYPTO', 'STOCKS', 'MACRO', 'SPORTS', 'TRENDING')),
    symbol           text,
    title_zh         text           NOT NULL,
    title_en         text           NOT NULL,
    subtitle_zh      text           NOT NULL DEFAULT '',
    subtitle_en      text           NOT NULL DEFAULT '',
    yes_zh           text           NOT NULL DEFAULT '会',
    yes_en           text           NOT NULL DEFAULT 'Yes',
    no_zh            text           NOT NULL DEFAULT '不会',
    no_en            text           NOT NULL DEFAULT 'No',
    seed_yes         bigint         NOT NULL CHECK (seed_yes > 0),
    seed_no          bigint         NOT NULL CHECK (seed_no > 0),
    pool_yes         bigint         NOT NULL,
    pool_no          bigint         NOT NULL,
    opens_at         timestamptz    NOT NULL,
    closes_at        timestamptz    NOT NULL,
    target_price     numeric(18, 2),
    settle_price     numeric(18, 2),
    result           text           CHECK (result IN ('YES', 'NO', 'VOID')),
    settled_at       timestamptz,
    sort_order       int            NOT NULL DEFAULT 0,
    created_at       timestamptz    NOT NULL DEFAULT now(),
    CHECK (kind <> 'UPDOWN' OR (symbol IS NOT NULL AND target_price IS NOT NULL))
);
CREATE INDEX predict_markets_open ON predict_markets (kind, closes_at) WHERE result IS NULL;
CREATE UNIQUE INDEX predict_markets_window ON predict_markets (symbol, opens_at) WHERE kind = 'UPDOWN';

CREATE TABLE predict_bets (
    id                uuid           PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           uuid           NOT NULL REFERENCES users_app (id),
    market_id         text           NOT NULL REFERENCES predict_markets (id),
    outcome           text           NOT NULL CHECK (outcome IN ('YES', 'NO')),
    stake             bigint         NOT NULL CHECK (stake > 0),
    probability       numeric(6, 4)  NOT NULL,
    potential_payout  bigint         NOT NULL,
    status            text           NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'WON', 'LOST', 'VOID')),
    payout            bigint         NOT NULL DEFAULT 0,
    claimed_at        timestamptz,
    created_at        timestamptz    NOT NULL DEFAULT now(),
    settled_at        timestamptz
);
CREATE INDEX predict_bets_user ON predict_bets (user_id, created_at DESC);
CREATE INDEX predict_bets_market ON predict_bets (market_id) WHERE status = 'OPEN';

-- 种子事件市场（演示示例；结算走管理命令 cmd/predictctl）。种子池决定初始概率。
INSERT INTO predict_markets (id, kind, category, title_zh, title_en, subtitle_zh, subtitle_en, yes_zh, yes_en, no_zh, no_en,
                             seed_yes, seed_no, pool_yes, pool_no, opens_at, closes_at, sort_order) VALUES
('fed-dec-cut', 'EVENT', 'MACRO', '美联储 12 月会议会降息 25 个基点吗？', 'Will the Fed cut rates by 25 bps at its December meeting?',
 '宏观 · 美联储', 'Macro · Fed', '会降息', 'Cut', '不会降息', 'No cut', 6800, 3200, 6800, 3200, '2026-11-20T00:00:00Z', '2026-12-18T00:00:00Z', 10),
('nvda-150-week', 'EVENT', 'STOCKS', 'NVDA 本周收盘价会站上 $150 吗？', 'Will NVDA close above $150 this week?',
 '美股 · 科技', 'US Stocks · Tech', '会', 'Yes', '不会', 'No', 5700, 4300, 5700, 4300, '2026-11-20T00:00:00Z', '2026-11-27T21:00:00Z', 20),
('btc-ath-2026', 'EVENT', 'CRYPTO', 'BTC 年底前会创历史新高吗？', 'Will BTC hit a new all-time high by year-end?',
 '加密', 'Crypto', '会', 'Yes', '不会', 'No', 2400, 7600, 2400, 7600, '2026-11-20T00:00:00Z', '2026-12-31T23:59:00Z', 30),
('cpi-dec-below', 'EVENT', 'MACRO', '12 月公布的美国 CPI 同比会低于 2.5% 吗？', 'Will the US CPI print released in December come in below 2.5% YoY?',
 '宏观 · 通胀', 'Macro · Inflation', '会', 'Yes', '不会', 'No', 4100, 5900, 4100, 5900, '2026-11-20T00:00:00Z', '2026-12-10T13:30:00Z', 40),
('spx-last-week', 'EVENT', 'STOCKS', 'S&P 500 在 2026 年最后一周会上涨吗？', 'Will the S&P 500 finish the last week of 2026 higher?',
 '美股 · 指数', 'US Stocks · Index', '会', 'Yes', '不会', 'No', 6200, 3800, 6200, 3800, '2026-11-20T00:00:00Z', '2026-12-31T21:00:00Z', 50),
('superbowl-afc', 'EVENT', 'SPORTS', '下一届超级碗冠军会来自 AFC 吗？', 'Will the next Super Bowl champion come from the AFC?',
 '体育 · 橄榄球', 'Sports · Football', '会', 'Yes', '不会', 'No', 5200, 4800, 5200, 4800, '2026-11-20T00:00:00Z', '2027-02-14T23:00:00Z', 60),
('ai-model-dec', 'EVENT', 'TRENDING', '12 月会有主流 AI 公司发布新一代旗舰模型吗？', 'Will a major AI lab release a new flagship model in December?',
 '热点 · 科技', 'Trending · Tech', '会', 'Yes', '不会', 'No', 7300, 2700, 7300, 2700, '2026-11-20T00:00:00Z', '2026-12-31T23:59:00Z', 70);
