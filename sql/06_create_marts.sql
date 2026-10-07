-- =========================================================
-- 06  Marts
-- One table per business question, read by Power BI.
-- Built only from analytics. Nothing references a mart, so
-- each one is fully rebuilt (TRUNCATE then INSERT) inside a
-- transaction.
-- =========================================================

-- ---------------------------------------------------------
-- delivery_performance
-- Grain: one row per order.
-- Question: was each order delivered on time, and if there is
-- no delivery result, why not?
--
-- Rule: delivery data wins over order status. If an order has
-- a delivery date it is judged on it, whatever its status says.
-- This keeps 6 orders that were delivered and then canceled in
-- the on time and late figures, because the delivery did happen.
-- ---------------------------------------------------------

CREATE TABLE IF NOT EXISTS marts.delivery_performance (
    order_id                     VARCHAR(50)    PRIMARY KEY,
    customer_id                  VARCHAR(50)    NOT NULL,
    customer_state               CHAR(2)        NOT NULL,
    purchase_date_key            INTEGER        NOT NULL,
    order_status                 VARCHAR(30)    NOT NULL,
    delivered_late               BOOLEAN,
    delivery_time_hours          NUMERIC(10,2),
    delivery_vs_estimated_hours  NUMERIC(10,2),
    delivery_category            VARCHAR(30)    NOT NULL
);

BEGIN;

TRUNCATE marts.delivery_performance;

INSERT INTO marts.delivery_performance (
    order_id, customer_id, customer_state, purchase_date_key,
    order_status, delivered_late, delivery_time_hours,
    delivery_vs_estimated_hours, delivery_category
)
SELECT
    o.order_id,
    o.customer_id,
    c.customer_state,
    o.purchase_date_key,
    o.order_status,
    o.delivered_late,
    o.delivery_time_hours,
    o.delivery_vs_estimated_hours,
    CASE
        -- 1. A delivery result exists: judge it
        WHEN o.delivered_late IS FALSE THEN 'on_time_or_early'
        WHEN o.delivered_late IS TRUE  THEN 'late'
        -- 2. No result, and the order will never be delivered
        WHEN o.order_status IN ('canceled', 'unavailable')
                                       THEN 'not_completed'
        -- 3. No result, but the status says delivered: a data gap
        WHEN o.order_status = 'delivered'
                                       THEN 'missing_delivery_date'
        -- 4. No result yet: still moving through the process
        ELSE                                'in_progress'
    END
FROM analytics.fact_orders o
JOIN analytics.dim_customer c ON c.customer_id = o.customer_id;

COMMIT;
