-- F14 交易：市价单（api-spec.md 5.6）。委托与成交数字以 DW 返回为准；DW 原始拒单原因只存 dw_reason，不对外返回。
CREATE TABLE orders (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id       uuid          NOT NULL REFERENCES accounts (id),
    symbol           text          NOT NULL,
    side             text          NOT NULL CHECK (side IN ('BUY', 'SELL')),
    order_type       text          NOT NULL DEFAULT 'MARKET' CHECK (order_type IN ('MARKET')),
    quantity         numeric(24, 8) CHECK (quantity > 0),
    notional         numeric(18, 2) CHECK (notional > 0),
    status           text          NOT NULL,
    dw_order_id      text UNIQUE,
    dw_order_no      text,
    filled_qty       numeric(24, 8),
    avg_price        numeric(18, 6),
    total_amount     numeric(18, 2),
    fees             numeric(18, 2),
    reject_reason    text,
    dw_reason        text,
    idempotency_key  uuid          NOT NULL UNIQUE,
    created_by       uuid REFERENCES users_app (id),
    submitted_at     timestamptz   NOT NULL DEFAULT now(),
    done_at          timestamptz,
    checked_at       timestamptz,
    created_at       timestamptz   NOT NULL DEFAULT now(),
    updated_at       timestamptz   NOT NULL DEFAULT now(),
    CHECK ((quantity IS NULL) <> (notional IS NULL))
);
CREATE INDEX orders_account_idx ON orders (account_id, submitted_at DESC);
CREATE INDEX orders_open_idx ON orders (checked_at NULLS FIRST)
    WHERE status IN ('SUBMITTING', 'NEW', 'PARTIAL_FILL', 'PENDING_CANCEL');
