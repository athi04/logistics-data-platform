-- =========================================================
-- 05  Analytics facts
-- Run after 04: every fact references dimensions.
-- Order inside this file matters too: fact_orders first,
-- because the other three facts reference it.
-- =========================================================

-- ---------------------------------------------------------
-- fact_orders
-- Grain: one row per order.
-- Date key is calculated, not looked up, so a date missing
-- from dim_date fails loudly on the foreign key.
-- delivered_late is NULL when the order was never delivered:
-- comparing NULL to a date gives NULL, not false.
-- ---------------------------------------------------------

CREATE TABLE IF NOT EXISTS analytics.fact_orders (
    order_id                     VARCHAR(50)    PRIMARY KEY,
    customer_id                  VARCHAR(50)    NOT NULL
        REFERENCES analytics.dim_customer (customer_id),
    purchase_date_key            INTEGER        NOT NULL
        REFERENCES analytics.dim_date (date_key),
    order_status                 VARCHAR(30)    NOT NULL,
    approval_delay_hours         NUMERIC(10,2),
    carrier_delay_hours          NUMERIC(10,2),
    delivery_time_hours          NUMERIC(10,2),
    delivery_vs_estimated_hours  NUMERIC(10,2),
    delivered_late               BOOLEAN
);

INSERT INTO analytics.fact_orders (
    order_id, customer_id, purchase_date_key, order_status,
    approval_delay_hours, carrier_delay_hours, delivery_time_hours,
    delivery_vs_estimated_hours, delivered_late
)
SELECT
    order_id,
    customer_id,
    TO_CHAR(order_purchase_timestamp, 'YYYYMMDD')::INT,
    order_status,
    approval_delay_hours,
    carrier_delay_hours,
    delivery_time_hours,
    delivery_vs_estimated_hours,
    order_delivered_customer_date > order_estimated_delivery_date
FROM staging.orders
ON CONFLICT (order_id) DO UPDATE SET
    customer_id                 = EXCLUDED.customer_id,
    purchase_date_key           = EXCLUDED.purchase_date_key,
    order_status                = EXCLUDED.order_status,
    approval_delay_hours        = EXCLUDED.approval_delay_hours,
    carrier_delay_hours         = EXCLUDED.carrier_delay_hours,
    delivery_time_hours         = EXCLUDED.delivery_time_hours,
    delivery_vs_estimated_hours = EXCLUDED.delivery_vs_estimated_hours,
    delivered_late              = EXCLUDED.delivered_late;

-- ---------------------------------------------------------
-- fact_order_items
-- Grain: one row per item in an order.
-- purchase_date_key is copied from the order so items can be
-- grouped by date without joining back to fact_orders.
-- ---------------------------------------------------------

CREATE TABLE IF NOT EXISTS analytics.fact_order_items (
    order_id           VARCHAR(50)    NOT NULL
        REFERENCES analytics.fact_orders (order_id),
    order_item_id      INTEGER        NOT NULL,
    product_id         VARCHAR(50)    NOT NULL
        REFERENCES analytics.dim_product (product_id),
    seller_id          VARCHAR(50)    NOT NULL
        REFERENCES analytics.dim_seller (seller_id),
    purchase_date_key  INTEGER        NOT NULL
        REFERENCES analytics.dim_date (date_key),
    price              NUMERIC(12,2)  NOT NULL,
    freight_value      NUMERIC(12,2)  NOT NULL,
    item_total_value   NUMERIC(12,2)  NOT NULL,
    PRIMARY KEY (order_id, order_item_id)
);

INSERT INTO analytics.fact_order_items (
    order_id, order_item_id, product_id, seller_id, purchase_date_key,
    price, freight_value, item_total_value
)
SELECT
    i.order_id,
    i.order_item_id,
    i.product_id,
    i.seller_id,
    TO_CHAR(o.order_purchase_timestamp, 'YYYYMMDD')::INT,
    i.price,
    i.freight_value,
    i.item_total_value
FROM staging.order_items i
JOIN staging.orders o ON o.order_id = i.order_id
ON CONFLICT (order_id, order_item_id) DO UPDATE SET
    product_id        = EXCLUDED.product_id,
    seller_id         = EXCLUDED.seller_id,
    purchase_date_key = EXCLUDED.purchase_date_key,
    price             = EXCLUDED.price,
    freight_value     = EXCLUDED.freight_value,
    item_total_value  = EXCLUDED.item_total_value;

-- ---------------------------------------------------------
-- fact_payments
-- Grain: one row per payment. An order can be paid in parts
-- (voucher plus card, say), numbered by payment_sequential.
-- ---------------------------------------------------------

CREATE TABLE IF NOT EXISTS analytics.fact_payments (
    order_id              VARCHAR(50)    NOT NULL
        REFERENCES analytics.fact_orders (order_id),
    payment_sequential    INTEGER        NOT NULL,
    payment_type          VARCHAR(30)    NOT NULL,
    payment_installments  INTEGER        NOT NULL,
    payment_value         NUMERIC(12,2)  NOT NULL,
    PRIMARY KEY (order_id, payment_sequential)
);

INSERT INTO analytics.fact_payments (
    order_id, payment_sequential, payment_type,
    payment_installments, payment_value
)
SELECT
    order_id, payment_sequential, payment_type,
    payment_installments, payment_value
FROM staging.order_payments
ON CONFLICT (order_id, payment_sequential) DO UPDATE SET
    payment_type         = EXCLUDED.payment_type,
    payment_installments = EXCLUDED.payment_installments,
    payment_value        = EXCLUDED.payment_value;

-- ---------------------------------------------------------
-- fact_reviews
-- Grain: one row per review per order. review_id alone is not
-- unique in Olist: the same review can cover several orders.
-- ---------------------------------------------------------

CREATE TABLE IF NOT EXISTS analytics.fact_reviews (
    review_id                    VARCHAR(50)    NOT NULL,
    order_id                     VARCHAR(50)    NOT NULL
        REFERENCES analytics.fact_orders (order_id),
    review_score                 INTEGER        NOT NULL,
    review_score_category        VARCHAR(20)    NOT NULL,
    has_comment                  BOOLEAN        NOT NULL,
    review_response_delay_hours  NUMERIC(10,2),
    review_creation_date_key     INTEGER
        REFERENCES analytics.dim_date (date_key),
    PRIMARY KEY (review_id, order_id)
);

INSERT INTO analytics.fact_reviews (
    review_id, order_id, review_score, review_score_category,
    has_comment, review_response_delay_hours, review_creation_date_key
)
SELECT
    review_id,
    order_id,
    review_score,
    review_score_category,
    has_comment,
    review_response_delay_hours,
    TO_CHAR(review_creation_date, 'YYYYMMDD')::INT
FROM staging.order_reviews
ON CONFLICT (review_id, order_id) DO UPDATE SET
    review_score                = EXCLUDED.review_score,
    review_score_category       = EXCLUDED.review_score_category,
    has_comment                 = EXCLUDED.has_comment,
    review_response_delay_hours = EXCLUDED.review_response_delay_hours,
    review_creation_date_key    = EXCLUDED.review_creation_date_key;
