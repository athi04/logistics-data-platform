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

-- ---------------------------------------------------------
-- category_performance
-- Grain: one row per product category.
-- Question: which categories bring in the most money, and how?
--
-- Category name: English when translated, the Portuguese name
-- when the translation file is missing it, 'unknown' when the
-- product has no category at all.
--
-- order_count counts DISTINCT orders per category. An order with
-- items in two categories counts once in each, so the column sums
-- to more than the number of orders. Item and money columns do
-- add up to the overall totals, because each item has exactly
-- one category.
-- ---------------------------------------------------------

CREATE TABLE IF NOT EXISTS marts.category_performance (
    category                     VARCHAR(100)   PRIMARY KEY,
    category_translation_status  VARCHAR(20)    NOT NULL,
    order_count                  INTEGER        NOT NULL,
    item_count                   INTEGER        NOT NULL,
    product_value                NUMERIC(14,2)  NOT NULL,
    freight_value                NUMERIC(14,2)  NOT NULL,
    total_value                  NUMERIC(14,2)  NOT NULL,
    avg_item_price               NUMERIC(10,2)  NOT NULL,
    freight_share                NUMERIC(5,4)   NOT NULL
);

BEGIN;

TRUNCATE marts.category_performance;

INSERT INTO marts.category_performance (
    category, category_translation_status, order_count, item_count,
    product_value, freight_value, total_value, avg_item_price,
    freight_share
)
SELECT
    COALESCE(p.product_category_name_english,
             p.product_category_name,
             'unknown')                          AS category,
    p.category_translation_status,
    COUNT(DISTINCT f.order_id),
    COUNT(*),
    SUM(f.price),
    SUM(f.freight_value),
    SUM(f.item_total_value),
    ROUND(AVG(f.price), 2),
    ROUND(SUM(f.freight_value) / SUM(f.item_total_value), 4)
FROM analytics.fact_order_items f
JOIN analytics.dim_product p ON p.product_id = f.product_id
GROUP BY 1, 2;

COMMIT;

-- ---------------------------------------------------------
-- customer_performance
-- Grain: one row per real person (customer_unique_id).
-- Question: who are the customers, how much do they spend,
-- and do they come back?
--
-- Olist issues a new customer_id for every order, so grouping
-- by customer_id would make every customer look like a one off
-- buyer. customer_unique_id identifies the person.
--
-- Each source is aggregated to one row per person in its own
-- CTE before joining, to avoid fan out between orders and
-- reviews (547 orders have more than one review).
-- ---------------------------------------------------------

CREATE TABLE IF NOT EXISTS marts.customer_performance (
    customer_unique_id   VARCHAR(50)    PRIMARY KEY,
    customer_state       CHAR(2)        NOT NULL,
    first_purchase_date  DATE           NOT NULL,
    last_purchase_date   DATE           NOT NULL,
    order_count          INTEGER        NOT NULL,
    item_count           INTEGER        NOT NULL,
    total_spent          NUMERIC(14,2)  NOT NULL,
    avg_order_value      NUMERIC(12,2),
    delivered_orders     INTEGER        NOT NULL,
    late_deliveries      INTEGER        NOT NULL,
    avg_review_score     NUMERIC(3,2),
    is_repeat_customer   BOOLEAN        NOT NULL
);

BEGIN;

TRUNCATE marts.customer_performance;

WITH customer_orders AS (
    -- One row per order, labelled with the person who placed it
    SELECT
        c.customer_unique_id,
        c.customer_state,
        s.order_id,
        d.full_date AS purchase_date,
        s.item_count,
        s.item_total_value,
        s.delivered_late
    FROM analytics.order_summary s
    JOIN analytics.dim_customer c ON c.customer_id = s.customer_id
    JOIN analytics.dim_date     d ON d.date_key    = s.purchase_date_key
),
order_totals AS (
    -- One row per person: orders, money and delivery
    SELECT
        customer_unique_id,
        MIN(purchase_date)                          AS first_purchase_date,
        MAX(purchase_date)                          AS last_purchase_date,
        COUNT(*)                                    AS order_count,
        COUNT(*) FILTER (WHERE item_count > 0)      AS orders_with_items,
        SUM(item_count)                             AS item_count,
        SUM(item_total_value)                       AS total_spent,
        COUNT(delivered_late)                       AS delivered_orders,
        COUNT(*) FILTER (WHERE delivered_late)      AS late_deliveries
    FROM customer_orders
    GROUP BY customer_unique_id
),
latest_state AS (
    -- One row per person: the state of their most recent order
    SELECT DISTINCT ON (customer_unique_id)
        customer_unique_id,
        customer_state
    FROM customer_orders
    ORDER BY customer_unique_id, purchase_date DESC, order_id DESC
),
review_totals AS (
    -- One row per person: average of all their review scores
    SELECT
        c.customer_unique_id,
        AVG(r.review_score) AS avg_review_score
    FROM analytics.fact_reviews r
    JOIN analytics.fact_orders  o ON o.order_id    = r.order_id
    JOIN analytics.dim_customer c ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)
INSERT INTO marts.customer_performance (
    customer_unique_id, customer_state, first_purchase_date,
    last_purchase_date, order_count, item_count, total_spent,
    avg_order_value, delivered_orders, late_deliveries,
    avg_review_score, is_repeat_customer
)
SELECT
    t.customer_unique_id,
    l.customer_state,
    t.first_purchase_date,
    t.last_purchase_date,
    t.order_count,
    t.item_count,
    t.total_spent,
    ROUND(t.total_spent / NULLIF(t.orders_with_items, 0), 2),
    t.delivered_orders,
    t.late_deliveries,
    ROUND(r.avg_review_score, 2),
    t.order_count > 1
FROM order_totals t
JOIN      latest_state  l ON l.customer_unique_id = t.customer_unique_id
LEFT JOIN review_totals r ON r.customer_unique_id = t.customer_unique_id;

COMMIT;
