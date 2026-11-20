-- F14 扩展：实盘限价单（LIMIT，当日有效 DAY）。DW 请求字段 price / timeInForce（DW Create Order 文档）。
ALTER TABLE orders DROP CONSTRAINT orders_order_type_check;
ALTER TABLE orders
    ADD CONSTRAINT orders_order_type_check CHECK (order_type IN ('MARKET', 'LIMIT')),
    ADD COLUMN limit_price numeric(18, 4) CHECK (limit_price > 0),
    ADD COLUMN time_in_force text CHECK (time_in_force IN ('DAY')),
    ADD CONSTRAINT orders_limit_fields_check CHECK (order_type = 'MARKET' OR (limit_price IS NOT NULL AND quantity IS NOT NULL));
