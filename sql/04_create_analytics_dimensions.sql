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
