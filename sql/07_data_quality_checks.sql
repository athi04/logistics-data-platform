-- =========================================================
-- 07  Data quality checks
--
-- Each check is one SELECT that returns the number of FAILING
-- rows, so 0 always means "pass". The header above each query
-- is read by src/quality_checks.py:
--
--   @check  unique name
--   @stage  raw | staging | analytics | marts  (when it runs)
--   @level  critical: any failure stops the pipeline
--           warning:  a known issue in the source data; reported,
--                     but the run carries on
--   @about  what is being checked, in plain words
--
-- Every query also runs on its own in DBeaver.
-- =========================================================


-- ---------------------------------------------------------
-- raw
-- ---------------------------------------------------------

-- @check  raw_order_status_known
-- @stage  raw
-- @level  critical
-- @about  Every order status is one the delivery mart can categorise
SELECT COUNT(*) FROM raw.orders
WHERE order_status NOT IN ('delivered', 'shipped', 'canceled', 'unavailable',
                           'invoiced', 'processing', 'created', 'approved');

-- @check  raw_no_negative_money
-- @stage  raw
-- @level  critical
-- @about  No negative prices, freight or payments
SELECT (SELECT COUNT(*) FROM raw.order_items
        WHERE price < 0 OR freight_value < 0)
     + (SELECT COUNT(*) FROM raw.order_payments
        WHERE payment_value < 0);

-- @check  raw_delivered_before_purchase
-- @stage  raw
-- @level  critical
-- @about  No order is delivered before it was bought
SELECT COUNT(*) FROM raw.orders
WHERE order_delivered_customer_date < order_purchase_timestamp;

-- @check  raw_review_answered_before_created
-- @stage  raw
-- @level  critical
-- @about  No review is answered before it was written
SELECT COUNT(*) FROM raw.order_reviews
WHERE review_answer_timestamp < review_creation_date;

-- @check  raw_carrier_before_approval
-- @stage  raw
-- @level  warning
-- @about  Handed to carrier before payment approval (negative carrier delay)
SELECT COUNT(*) FROM raw.orders
WHERE order_delivered_carrier_date < order_approved_at;

-- @check  raw_delivered_before_carrier
-- @stage  raw
-- @level  warning
-- @about  Delivered to customer before the carrier received it
SELECT COUNT(*) FROM raw.orders
WHERE order_delivered_customer_date < order_delivered_carrier_date;

-- @check  raw_geolocation_outside_brazil
-- @stage  raw
-- @level  warning
-- @about  Coordinates outside Brazil's bounding box, included in averages
SELECT COUNT(*) FROM raw.geolocation
WHERE geolocation_lat NOT BETWEEN -34 AND 6
   OR geolocation_lng NOT BETWEEN -74 AND -34;

-- @check  raw_payment_type_not_defined
-- @stage  raw
-- @level  warning
-- @about  Payments with no payment method recorded
SELECT COUNT(*) FROM raw.order_payments
WHERE payment_type = 'not_defined';

-- @check  raw_installments_below_one
-- @stage  raw
-- @level  warning
-- @about  Payments with zero instalments, which is impossible
SELECT COUNT(*) FROM raw.order_payments
WHERE payment_installments < 1;

-- @check  raw_products_without_category
-- @stage  raw
-- @level  warning
-- @about  Products with no category
SELECT COUNT(*) FROM raw.products
WHERE product_category_name IS NULL;

-- @check  raw_products_without_dimensions
-- @stage  raw
-- @level  warning
-- @about  Products missing weight or size
SELECT COUNT(*) FROM raw.products
WHERE product_weight_g IS NULL OR product_length_cm IS NULL;


-- ---------------------------------------------------------
-- staging
-- ---------------------------------------------------------

-- @check  staging_no_rows_lost
-- @stage  staging
-- @level  critical
-- @about  Staging keeps every row from raw (geolocation excepted: it is aggregated)
SELECT ABS((SELECT COUNT(*) FROM raw.orders)         - (SELECT COUNT(*) FROM staging.orders))
     + ABS((SELECT COUNT(*) FROM raw.order_items)    - (SELECT COUNT(*) FROM staging.order_items))
     + ABS((SELECT COUNT(*) FROM raw.order_payments) - (SELECT COUNT(*) FROM staging.order_payments))
     + ABS((SELECT COUNT(*) FROM raw.order_reviews)  - (SELECT COUNT(*) FROM staging.order_reviews))
     + ABS((SELECT COUNT(*) FROM raw.customers)      - (SELECT COUNT(*) FROM staging.customers))
     + ABS((SELECT COUNT(*) FROM raw.sellers)        - (SELECT COUNT(*) FROM staging.sellers))
     + ABS((SELECT COUNT(*) FROM raw.products)       - (SELECT COUNT(*) FROM staging.products));

-- @check  staging_one_row_per_zip_prefix
-- @stage  staging
-- @level  critical
-- @about  Geolocation has exactly one row for every ZIP prefix in raw
SELECT ABS((SELECT COUNT(DISTINCT geolocation_zip_code_prefix) FROM raw.geolocation)
         - (SELECT COUNT(*) FROM staging.geolocation));

-- @check  staging_item_total_is_price_plus_freight
-- @stage  staging
-- @level  critical
-- @about  Every line total equals price plus freight
SELECT COUNT(*) FROM staging.order_items
WHERE item_total_value <> price + freight_value;

-- @check  staging_customers_without_coordinates
-- @stage  staging
-- @level  warning
-- @about  Customers whose ZIP prefix has no coordinates
SELECT COUNT(*) FROM staging.customers c
WHERE NOT EXISTS (SELECT 1 FROM staging.geolocation g
                  WHERE g.geolocation_zip_code_prefix = c.customer_zip_code_prefix);

-- @check  staging_sellers_without_coordinates
-- @stage  staging
-- @level  warning
-- @about  Sellers whose ZIP prefix has no coordinates
SELECT COUNT(*) FROM staging.sellers s
WHERE NOT EXISTS (SELECT 1 FROM staging.geolocation g
                  WHERE g.geolocation_zip_code_prefix = s.seller_zip_code_prefix);


-- ---------------------------------------------------------
-- analytics
-- ---------------------------------------------------------

-- @check  analytics_dim_date_has_no_gaps
-- @stage  analytics
-- @level  critical
-- @about  The date dimension has one row for every day in its range
SELECT (MAX(full_date) - MIN(full_date) + 1) - COUNT(*)
FROM analytics.dim_date;

-- @check  analytics_item_value_preserved
-- @stage  analytics
-- @level  critical
-- @about  Item value in the fact table and order summary equals staging
SELECT ((SELECT SUM(item_total_value) FROM staging.order_items)
        <> (SELECT SUM(item_total_value) FROM analytics.fact_order_items)
     OR (SELECT SUM(item_total_value) FROM staging.order_items)
        <> (SELECT SUM(item_total_value) FROM analytics.order_summary))::INT;

-- @check  analytics_payment_value_preserved
-- @stage  analytics
-- @level  critical
-- @about  Payment value in the fact table and order summary equals staging
SELECT ((SELECT SUM(payment_value) FROM staging.order_payments)
        <> (SELECT SUM(payment_value) FROM analytics.fact_payments)
     OR (SELECT SUM(payment_value) FROM staging.order_payments)
        <> (SELECT SUM(payment_total) FROM analytics.order_summary))::INT;

-- @check  analytics_every_order_reconciled
-- @stage  analytics
-- @level  critical
-- @about  Every order has a reconciliation status
SELECT COUNT(*) FROM analytics.order_summary
WHERE reconciliation_status IS NULL;

-- @check  analytics_delivered_without_date
-- @stage  analytics
-- @level  warning
-- @about  Status says delivered but there is no delivery date
SELECT COUNT(*) FROM analytics.fact_orders
WHERE order_status = 'delivered' AND delivered_late IS NULL;

-- @check  analytics_canceled_after_delivery
-- @stage  analytics
-- @level  warning
-- @about  Canceled or unavailable orders that have a delivery result
SELECT COUNT(*) FROM analytics.fact_orders
WHERE order_status IN ('canceled', 'unavailable') AND delivered_late IS NOT NULL;

-- @check  analytics_orders_without_items
-- @stage  analytics
-- @level  warning
-- @about  Orders with no items
SELECT COUNT(*) FROM analytics.order_summary
WHERE item_count = 0;


-- ---------------------------------------------------------
-- marts
-- ---------------------------------------------------------

-- @check  marts_delivery_covers_every_order
-- @stage  marts
-- @level  critical
-- @about  Every order appears in delivery_performance exactly once
SELECT ABS((SELECT COUNT(*) FROM analytics.fact_orders)
         - (SELECT COUNT(*) FROM marts.delivery_performance));

-- @check  marts_category_value_preserved
-- @stage  marts
-- @level  critical
-- @about  Category totals add up to the item total
SELECT ((SELECT SUM(total_value) FROM marts.category_performance)
        <> (SELECT SUM(item_total_value) FROM analytics.fact_order_items))::INT;

-- @check  marts_customers_cover_every_order
-- @stage  marts
-- @level  critical
-- @about  Customer order counts add up to the number of orders
SELECT ABS((SELECT SUM(order_count) FROM marts.customer_performance)
         - (SELECT COUNT(*) FROM analytics.fact_orders));

-- @check  marts_payment_value_preserved
-- @stage  marts
-- @level  critical
-- @about  Payment mart totals equal the payment fact table
SELECT ((SELECT SUM(payment_total) FROM marts.payment_analysis)
        <> (SELECT SUM(payment_value) FROM analytics.fact_payments))::INT;
