CREATE TABLE IF NOT EXISTS staging.orders (
    order_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL,
    order_status VARCHAR(30) NOT NULL,

    order_purchase_timestamp TIMESTAMP NOT NULL,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP NOT NULL,

    approval_delay_hours NUMERIC(10,2),
    carrier_delay_hours NUMERIC(10,2),
    delivery_time_hours NUMERIC(10,2),
    delivery_vs_estimated_hours NUMERIC(10,2)
);