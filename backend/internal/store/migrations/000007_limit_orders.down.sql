-- 回滚前须确认已无限价单（否则恢复只允许 MARKET 的约束会失败）。
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_limit_fields_check;
ALTER TABLE orders DROP COLUMN IF EXISTS time_in_force;
ALTER TABLE orders DROP COLUMN IF EXISTS limit_price;
ALTER TABLE orders DROP CONSTRAINT orders_order_type_check;
ALTER TABLE orders ADD CONSTRAINT orders_order_type_check CHECK (order_type IN ('MARKET'));
