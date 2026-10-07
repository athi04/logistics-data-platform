-- =========================================================
-- 04  Analytics dimensions
-- =========================================================

-- ---------------------------------------------------------
-- dim_date
-- Generated, not loaded. Range covers every date column in
-- staging so any date can be joined. Rerun safe: upsert, not
-- truncate, because fact tables reference this table.
-- ---------------------------------------------------------

CREATE TABLE IF NOT EXISTS analytics.dim_date (
    date_key    INTEGER      PRIMARY KEY,
    full_date   DATE         NOT NULL UNIQUE,
    year        INTEGER      NOT NULL,
    quarter     INTEGER      NOT NULL,
    month       INTEGER      NOT NULL,
    month_name  VARCHAR(20)  NOT NULL,
    week        INTEGER      NOT NULL,
    day         INTEGER      NOT NULL,
    day_name    VARCHAR(20)  NOT NULL,
    is_weekend  BOOLEAN      NOT NULL
);

WITH all_dates AS (
    SELECT order_purchase_timestamp::DATE      AS d FROM staging.orders
    UNION ALL
    SELECT order_approved_at::DATE                  FROM staging.orders
    UNION ALL
    SELECT order_delivered_carrier_date::DATE       FROM staging.orders
    UNION ALL
    SELECT order_delivered_customer_date::DATE      FROM staging.orders
    UNION ALL
    SELECT order_estimated_delivery_date::DATE      FROM staging.orders
    UNION ALL
    SELECT review_creation_date::DATE               FROM staging.order_reviews
    UNION ALL
    SELECT review_answer_timestamp::DATE            FROM staging.order_reviews
),
bounds AS (
    SELECT MIN(d) AS first_day, MAX(d) AS last_day
    FROM all_dates
),
days AS (
    SELECT gs::DATE AS d
    FROM bounds,
         generate_series(first_day, last_day, INTERVAL '1 day') AS gs
)
INSERT INTO analytics.dim_date (
    date_key, full_date, year, quarter, month, month_name,
    week, day, day_name, is_weekend
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT,
    d,
    EXTRACT(YEAR    FROM d)::INT,
    EXTRACT(QUARTER FROM d)::INT,
    EXTRACT(MONTH   FROM d)::INT,
    TO_CHAR(d, 'FMMonth'),
    EXTRACT(WEEK    FROM d)::INT,
    EXTRACT(DAY     FROM d)::INT,
    TO_CHAR(d, 'FMDay'),
    EXTRACT(ISODOW  FROM d) IN (6, 7)
FROM days
ON CONFLICT (date_key) DO UPDATE SET
    full_date  = EXCLUDED.full_date,
    year       = EXCLUDED.year,
    quarter    = EXCLUDED.quarter,
    month      = EXCLUDED.month,
    month_name = EXCLUDED.month_name,
    week       = EXCLUDED.week,
    day        = EXCLUDED.day,
    day_name   = EXCLUDED.day_name,
    is_weekend = EXCLUDED.is_weekend;

-- ---------------------------------------------------------
-- dim_geography
-- One row per ZIP prefix. Averaging the million raw
-- coordinates down to one point per prefix happens in staging.
-- ---------------------------------------------------------

CREATE TABLE IF NOT EXISTS analytics.dim_geography (
    geolocation_zip_code_prefix INTEGER        PRIMARY KEY,
    latitude                    NUMERIC(10,7)  NOT NULL,
    longitude                   NUMERIC(10,7)  NOT NULL,
    city                        VARCHAR(100),
    state                       CHAR(2)
);

INSERT INTO analytics.dim_geography (
    geolocation_zip_code_prefix, latitude, longitude, city, state
)
SELECT
    geolocation_zip_code_prefix,
    avg_latitude,
    avg_longitude,
    representative_city,
    representative_state
FROM staging.geolocation
ON CONFLICT (geolocation_zip_code_prefix) DO UPDATE SET
    latitude  = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    city      = EXCLUDED.city,
    state     = EXCLUDED.state;

-- ---------------------------------------------------------
-- dim_customer
-- LEFT JOIN, not INNER: 278 customers have a ZIP prefix with
-- no coordinates. An inner join would drop them, and their
-- orders would then break the foreign key from fact_orders.
-- ---------------------------------------------------------

CREATE TABLE IF NOT EXISTS analytics.dim_customer (
    customer_id               VARCHAR(50)    PRIMARY KEY,
    customer_unique_id        VARCHAR(50)    NOT NULL,
    customer_zip_code_prefix  INTEGER        NOT NULL,
    customer_city             VARCHAR(100)   NOT NULL,
    customer_state            CHAR(2)        NOT NULL,
    latitude                  NUMERIC(10,7),
    longitude                 NUMERIC(10,7)
);

INSERT INTO analytics.dim_customer (
    customer_id, customer_unique_id, customer_zip_code_prefix,
    customer_city, customer_state, latitude, longitude
)
SELECT
    c.customer_id,
    c.customer_unique_id,
    c.customer_zip_code_prefix,
    c.customer_city,
    c.customer_state,
    g.avg_latitude,
    g.avg_longitude
FROM staging.customers c
LEFT JOIN staging.geolocation g
       ON g.geolocation_zip_code_prefix = c.customer_zip_code_prefix
ON CONFLICT (customer_id) DO UPDATE SET
    customer_unique_id       = EXCLUDED.customer_unique_id,
    customer_zip_code_prefix = EXCLUDED.customer_zip_code_prefix,
    customer_city            = EXCLUDED.customer_city,
    customer_state           = EXCLUDED.customer_state,
    latitude                 = EXCLUDED.latitude,
    longitude                = EXCLUDED.longitude;

-- ---------------------------------------------------------
-- dim_seller
-- Same pattern as dim_customer. 7 sellers have no coordinates.
-- ---------------------------------------------------------

CREATE TABLE IF NOT EXISTS analytics.dim_seller (
    seller_id               VARCHAR(50)    PRIMARY KEY,
    seller_zip_code_prefix  INTEGER        NOT NULL,
    seller_city             VARCHAR(100)   NOT NULL,
    seller_state            CHAR(2)        NOT NULL,
    latitude                NUMERIC(10,7),
    longitude               NUMERIC(10,7)
);

INSERT INTO analytics.dim_seller (
    seller_id, seller_zip_code_prefix, seller_city, seller_state,
    latitude, longitude
)
SELECT
    s.seller_id,
    s.seller_zip_code_prefix,
    s.seller_city,
    s.seller_state,
    g.avg_latitude,
    g.avg_longitude
FROM staging.sellers s
LEFT JOIN staging.geolocation g
       ON g.geolocation_zip_code_prefix = s.seller_zip_code_prefix
ON CONFLICT (seller_id) DO UPDATE SET
    seller_zip_code_prefix = EXCLUDED.seller_zip_code_prefix,
    seller_city            = EXCLUDED.seller_city,
    seller_state           = EXCLUDED.seller_state,
    latitude               = EXCLUDED.latitude,
    longitude              = EXCLUDED.longitude;

-- ---------------------------------------------------------
-- dim_product
-- Straight copy of staging.products, which already joined in
-- the English category names and set the translation status.
-- ---------------------------------------------------------

CREATE TABLE IF NOT EXISTS analytics.dim_product (
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

INSERT INTO analytics.dim_product (
    product_id, product_category_name, product_category_name_english,
    product_name_length, product_description_length, product_photos_qty,
    product_weight_g, product_length_cm, product_height_cm, product_width_cm,
    category_translation_status
)
SELECT
    product_id, product_category_name, product_category_name_english,
    product_name_length, product_description_length, product_photos_qty,
    product_weight_g, product_length_cm, product_height_cm, product_width_cm,
    category_translation_status
FROM staging.products
ON CONFLICT (product_id) DO UPDATE SET
    product_category_name         = EXCLUDED.product_category_name,
    product_category_name_english = EXCLUDED.product_category_name_english,
    product_name_length           = EXCLUDED.product_name_length,
    product_description_length    = EXCLUDED.product_description_length,
    product_photos_qty            = EXCLUDED.product_photos_qty,
    product_weight_g              = EXCLUDED.product_weight_g,
    product_length_cm             = EXCLUDED.product_length_cm,
    product_height_cm             = EXCLUDED.product_height_cm,
    product_width_cm              = EXCLUDED.product_width_cm,
    category_translation_status   = EXCLUDED.category_translation_status;
