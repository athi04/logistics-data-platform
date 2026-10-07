-- =========================================================
-- 03  Staging
-- Cleans and enriches raw into one row per real thing.
-- Grain is unchanged for every table except geolocation,
-- which collapses about a million points to one per ZIP prefix.
--
-- Rerun safe: all staging tables are truncated together and
-- reloaded in one transaction. Nothing outside staging holds a
-- foreign key to these tables, so a full rebuild is safe.
-- =========================================================

-- ---------------------------------------------------------
-- Tables
-- ---------------------------------------------------------

CREATE TABLE IF NOT EXISTS staging.customers (
    customer_id               VARCHAR(50)   PRIMARY KEY,
    customer_unique_id        VARCHAR(50)   NOT NULL,
    customer_zip_code_prefix  INTEGER       NOT NULL,
    customer_city             VARCHAR(100)  NOT NULL,
    customer_state            CHAR(2)       NOT NULL
);

CREATE TABLE IF NOT EXISTS staging.sellers (
    seller_id               VARCHAR(50)   PRIMARY KEY,
    seller_zip_code_prefix  INTEGER       NOT NULL,
    seller_city             VARCHAR(100)  NOT NULL,
    seller_state            CHAR(2)       NOT NULL
);

CREATE TABLE IF NOT EXISTS staging.geolocation (
    geolocation_zip_code_prefix  INTEGER        PRIMARY KEY,
    avg_latitude                 NUMERIC(10,7)  NOT NULL,
    avg_longitude                NUMERIC(10,7)  NOT NULL,
    representative_city          VARCHAR(100),
    representative_state         CHAR(2)
);

CREATE TABLE IF NOT EXISTS staging.products (
    product_id                     VARCHAR(50)   PRIMARY KEY,
    product_category_name          VARCHAR(100),
    product_category_name_english  VARCHAR(100),
    product_name_length            INTEGER,
    product_description_length     INTEGER,
    product_photos_qty             INTEGER,
    product_weight_g               NUMERIC,
    product_length_cm              NUMERIC,
    product_height_cm              NUMERIC,
    product_width_cm               NUMERIC,
    category_translation_status    VARCHAR(20)   NOT NULL
);

CREATE TABLE IF NOT EXISTS staging.orders (
    order_id                       VARCHAR(50)    PRIMARY KEY,
    customer_id                    VARCHAR(50)    NOT NULL,
    order_status                   VARCHAR(30)    NOT NULL,
    order_purchase_timestamp       TIMESTAMP      NOT NULL,
    order_approved_at              TIMESTAMP,
    order_delivered_carrier_date   TIMESTAMP,
    order_delivered_customer_date  TIMESTAMP,
    order_estimated_delivery_date  TIMESTAMP      NOT NULL,
    approval_delay_hours           NUMERIC(10,2),
    carrier_delay_hours            NUMERIC(10,2),
    delivery_time_hours            NUMERIC(10,2),
    delivery_vs_estimated_hours    NUMERIC(10,2)
);

CREATE TABLE IF NOT EXISTS staging.order_items (
    order_id                       VARCHAR(50)    NOT NULL
        REFERENCES staging.orders (order_id),
    order_item_id                  INTEGER        NOT NULL,
    product_id                     VARCHAR(50)    NOT NULL
        REFERENCES staging.products (product_id),
    seller_id                      VARCHAR(50)    NOT NULL
        REFERENCES staging.sellers (seller_id),
    shipping_limit_date            TIMESTAMP      NOT NULL,
    price                          NUMERIC(12,2)  NOT NULL,
    freight_value                  NUMERIC(12,2)  NOT NULL,
    product_category_name          VARCHAR(100),
    product_category_name_english  VARCHAR(100),
    seller_city                    VARCHAR(100),
    seller_state                   CHAR(2),
    item_total_value               NUMERIC(12,2)  NOT NULL,
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE IF NOT EXISTS staging.order_payments (
    order_id              VARCHAR(50)    NOT NULL
        REFERENCES staging.orders (order_id),
    payment_sequential    INTEGER        NOT NULL,
    payment_type          VARCHAR(30)    NOT NULL,
    payment_installments  INTEGER        NOT NULL,
    payment_value         NUMERIC(12,2)  NOT NULL,
    PRIMARY KEY (order_id, payment_sequential)
);

CREATE TABLE IF NOT EXISTS staging.order_reviews (
    review_id                    VARCHAR(50)    NOT NULL,
    order_id                     VARCHAR(50)    NOT NULL
        REFERENCES staging.orders (order_id),
    review_score                 INTEGER        NOT NULL
        CONSTRAINT chk_staging_review_score CHECK (review_score BETWEEN 1 AND 5),
    review_comment_title         VARCHAR(500),
    review_comment_message       TEXT,
    review_creation_date         TIMESTAMP,
    review_answer_timestamp      TIMESTAMP,
    has_comment                  BOOLEAN        NOT NULL,
    review_response_delay_hours  NUMERIC(10,2),
    review_score_category        VARCHAR(20)    NOT NULL,
    PRIMARY KEY (review_id, order_id)
);

-- ---------------------------------------------------------
-- Load
-- ---------------------------------------------------------

BEGIN;

TRUNCATE
    staging.order_reviews,
    staging.order_payments,
    staging.order_items,
    staging.orders,
    staging.products,
    staging.geolocation,
    staging.sellers,
    staging.customers;

-- customers, sellers: clean already, copied as is
INSERT INTO staging.customers
SELECT customer_id, customer_unique_id, customer_zip_code_prefix,
       customer_city, customer_state
FROM raw.customers;

INSERT INTO staging.sellers
SELECT seller_id, seller_zip_code_prefix, seller_city, seller_state
FROM raw.sellers;

-- geolocation: about 1,000,000 points become one row per prefix.
-- Coordinates are averaged; city and state take the most common
-- value (MODE), so a few misspelled rows cannot win.
-- COLLATE "C" makes ties break the same way on every machine:
-- without it the winner depends on the server's locale.
INSERT INTO staging.geolocation
SELECT
    geolocation_zip_code_prefix,
    ROUND(AVG(geolocation_lat), 7),
    ROUND(AVG(geolocation_lng), 7),
    MODE() WITHIN GROUP (ORDER BY geolocation_city  COLLATE "C"),
    MODE() WITHIN GROUP (ORDER BY geolocation_state COLLATE "C")
FROM raw.geolocation
GROUP BY geolocation_zip_code_prefix;

-- products: English category joined in here, so no staging
-- table is needed for the translation lookup itself.
INSERT INTO staging.products
SELECT
    p.product_id,
    p.product_category_name,
    t.product_category_name_english,
    p.product_name_length,
    p.product_description_length,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,
    CASE WHEN t.product_category_name IS NOT NULL
         THEN 'translated' ELSE 'untranslated' END
FROM raw.products p
LEFT JOIN raw.category_translation t
       ON t.product_category_name = p.product_category_name;

-- orders: durations between stages, in hours.
-- Any missing timestamp gives NULL, which means "not reached".
INSERT INTO staging.orders
SELECT
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    ROUND(EXTRACT(EPOCH FROM order_approved_at             - order_purchase_timestamp)      / 3600, 2),
    ROUND(EXTRACT(EPOCH FROM order_delivered_carrier_date  - order_approved_at)             / 3600, 2),
    ROUND(EXTRACT(EPOCH FROM order_delivered_customer_date - order_purchase_timestamp)      / 3600, 2),
    ROUND(EXTRACT(EPOCH FROM order_delivered_customer_date - order_estimated_delivery_date) / 3600, 2)
FROM raw.orders;

-- order_items: category and seller location attached, plus the
-- line total. Loaded after orders, products and sellers because
-- of its foreign keys.
INSERT INTO staging.order_items
SELECT
    i.order_id,
    i.order_item_id,
    i.product_id,
    i.seller_id,
    i.shipping_limit_date,
    i.price,
    i.freight_value,
    p.product_category_name,
    p.product_category_name_english,
    s.seller_city,
    s.seller_state,
    i.price + i.freight_value
FROM raw.order_items i
JOIN staging.products p ON p.product_id = i.product_id
JOIN staging.sellers  s ON s.seller_id  = i.seller_id;

INSERT INTO staging.order_payments
SELECT order_id, payment_sequential, payment_type,
       payment_installments, payment_value
FROM raw.order_payments;

-- order_reviews: key is (review_id, order_id) because one review
-- can cover several orders. A comment counts if either the title
-- or the message is present.
INSERT INTO staging.order_reviews
SELECT
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp,
    review_comment_title IS NOT NULL OR review_comment_message IS NOT NULL,
    ROUND(EXTRACT(EPOCH FROM review_answer_timestamp - review_creation_date) / 3600, 2),
    CASE
        WHEN review_score >= 4 THEN 'positive'
        WHEN review_score  = 3 THEN 'neutral'
        ELSE                        'negative'
    END
FROM raw.order_reviews;

COMMIT;
