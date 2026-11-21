-- F22-e / F22-f 最小 XP 体系（演示）：XP 账本 + 每日签到。XP 为站内成长值，与券商资金、模拟盘、预测积分完全隔离，不可兑换现金。
-- 余额 = 账本合计（初始 0）。来源：CHECKIN（每日签到，ref = 美东日期，同日只记一次）/ DEMO_GRANT（cmd/demoreset grant-xp，ref 固定，重复执行覆盖为新值）。
CREATE TABLE xp_ledger (
    id          bigserial   PRIMARY KEY,
    user_id     uuid        NOT NULL REFERENCES users_app (id),
    delta       integer     NOT NULL CHECK (delta > 0),
    reason      text        NOT NULL CHECK (reason IN ('CHECKIN', 'DEMO_GRANT')),
    ref         text        NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, reason, ref)
);

-- 每日签到：每个用户 × 美东日期一条（主键防重复）。
CREATE TABLE xp_checkins (
    user_id     uuid        NOT NULL REFERENCES users_app (id),
    day         date        NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, day)
);
