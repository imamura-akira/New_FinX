-- F15 模拟交易（模拟盘，演示与练习用途）：全部在我方后端，不调用 DW；与真实账户、DW 资金数字完全分开。
CREATE TABLE paper_accounts (
    user_id       uuid PRIMARY KEY REFERENCES users_app (id),
    initial_cash  numeric(18, 2) NOT NULL CHECK (initial_cash > 0),
    cash          numeric(18, 2) NOT NULL CHECK (cash >= 0),
    reset_at      timestamptz,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE paper_positions (
    user_id     uuid           NOT NULL REFERENCES paper_accounts (user_id) ON DELETE CASCADE,
    symbol      text           NOT NULL,
    quantity    numeric(24, 8) NOT NULL CHECK (quantity > 0),
    cost_basis  numeric(18, 2) NOT NULL CHECK (cost_basis >= 0),
    updated_at  timestamptz    NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, symbol)
);

CREATE TABLE paper_orders (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        uuid           NOT NULL REFERENCES paper_accounts (user_id) ON DELETE CASCADE,
    symbol         text           NOT NULL,
    side           text           NOT NULL CHECK (side IN ('BUY', 'SELL')),
    order_type     text           NOT NULL CHECK (order_type IN ('MARKET', 'LIMIT')),
    quantity       numeric(24, 8) CHECK (quantity > 0),
    notional       numeric(18, 2) CHECK (notional > 0),
    limit_price    numeric(18, 4) CHECK (limit_price > 0),
    time_in_force  text           NOT NULL DEFAULT 'DAY' CHECK (time_in_force IN ('DAY')),
    status         text           NOT NULL CHECK (status IN ('NEW', 'FILLED', 'CANCELED', 'REJECTED')),
    reserved_cash  numeric(18, 2) NOT NULL DEFAULT 0,
    filled_qty     numeric(24, 8),
    avg_price      numeric(18, 6),
    total_amount   numeric(18, 2),
    reject_reason  text,
    submitted_at   timestamptz    NOT NULL DEFAULT now(),
    done_at        timestamptz,
    updated_at     timestamptz    NOT NULL DEFAULT now(),
    CHECK ((quantity IS NULL) <> (notional IS NULL)),
    CHECK (order_type = 'MARKET' OR (limit_price IS NOT NULL AND quantity IS NOT NULL))
);
CREATE INDEX paper_orders_user_idx ON paper_orders (user_id, submitted_at DESC);
CREATE INDEX paper_orders_open_idx ON paper_orders (user_id) WHERE status = 'NEW';
