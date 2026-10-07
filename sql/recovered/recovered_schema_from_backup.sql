-- Recovered from backup.dump (pg_dump 17.11, taken 4 Oct 2026)
-- Table definitions, keys and foreign keys only. No INSERT logic: pg_dump never stores that.
-- Reference material for writing 03, 04 and 05. Not part of the pipeline.

CREATE SCHEMA analytics;

CREATE SCHEMA raw;

CREATE SCHEMA staging;

CREATE TABLE raw.category_translation (
    product_category_name character varying(100) NOT NULL,
    product_category_name_english character varying(100) NOT NULL
);

CREATE TABLE raw.customers (
    customer_id character varying(50) NOT NULL,
    customer_unique_id character varying(50) NOT NULL,
    customer_zip_code_prefix integer NOT NULL,
    customer_city character varying(100) NOT NULL,
    customer_state character(2) NOT NULL
);

CREATE TABLE raw.geolocation (
    geolocation_id bigint NOT NULL,
    geolocation_zip_code_prefix integer NOT NULL,
    geolocation_lat numeric(10,7) NOT NULL,
    geolocation_lng numeric(10,7) NOT NULL,
    geolocation_city character varying(100) NOT NULL,
    geolocation_state character(2) NOT NULL
);

CREATE TABLE raw.order_items (
    order_id character varying(50) NOT NULL,
    order_item_id integer NOT NULL,
    product_id character varying(50) NOT NULL,
    seller_id character varying(50) NOT NULL,
    shipping_limit_date timestamp without time zone NOT NULL,
    price numeric(12,2) NOT NULL,
    freight_value numeric(12,2) NOT NULL
);

CREATE TABLE raw.order_payments (
    order_id character varying(50) NOT NULL,
    payment_sequential integer NOT NULL,
    payment_type character varying(30) NOT NULL,
    payment_installments integer NOT NULL,
    payment_value numeric(12,2) NOT NULL
);

CREATE TABLE raw.order_reviews (
    review_id character varying(50) NOT NULL,
    order_id character varying(50) NOT NULL,
    review_score integer NOT NULL,
    review_comment_title character varying(500),
    review_comment_message text,
    review_creation_date timestamp without time zone,
    review_answer_timestamp timestamp without time zone,
    CONSTRAINT chk_review_score CHECK (((review_score >= 1) AND (review_score <= 5)))
);

CREATE TABLE raw.orders (
    order_id character varying(50) NOT NULL,
    customer_id character varying(50) NOT NULL,
    order_status character varying(30) NOT NULL,
    order_purchase_timestamp timestamp without time zone NOT NULL,
    order_approved_at timestamp without time zone,
    order_delivered_carrier_date timestamp without time zone,
    order_delivered_customer_date timestamp without time zone,
    order_estimated_delivery_date timestamp without time zone NOT NULL
);

CREATE TABLE raw.products (
    product_id character varying(50) NOT NULL,
    product_category_name character varying(100),
    product_name_length integer,
    product_description_length integer,
    product_photos_qty integer,
    product_weight_g numeric,
    product_length_cm numeric,
    product_height_cm numeric,
    product_width_cm numeric
);

CREATE TABLE raw.sellers (
    seller_id character varying(50) NOT NULL,
    seller_zip_code_prefix integer NOT NULL,
    seller_city character varying(100) NOT NULL,
    seller_state character(2) NOT NULL
);

CREATE TABLE staging.customers (
    customer_id character varying(50) NOT NULL,
    customer_unique_id character varying(50) NOT NULL,
    customer_zip_code_prefix integer NOT NULL,
    customer_city character varying(100) NOT NULL,
    customer_state character(2) NOT NULL
);

CREATE TABLE staging.geolocation (
    geolocation_zip_code_prefix integer NOT NULL,
    avg_latitude numeric(10,7) NOT NULL,
    avg_longitude numeric(10,7) NOT NULL,
    representative_city character varying(100),
    representative_state character(2)
);

CREATE TABLE staging.order_items (
    order_id character varying(50) NOT NULL,
    order_item_id integer NOT NULL,
    product_id character varying(50) NOT NULL,
    seller_id character varying(50) NOT NULL,
    shipping_limit_date timestamp without time zone NOT NULL,
    price numeric(12,2) NOT NULL,
    freight_value numeric(12,2) NOT NULL,
    product_category_name character varying(100),
    product_category_name_english character varying(100),
    seller_city character varying(100),
    seller_state character(2),
    item_total_value numeric(12,2) NOT NULL
);

CREATE TABLE staging.order_payments (
    order_id character varying(50) NOT NULL,
    payment_sequential integer NOT NULL,
    payment_type character varying(30) NOT NULL,
    payment_installments integer NOT NULL,
    payment_value numeric(12,2) NOT NULL
);

CREATE TABLE staging.order_reviews (
    review_id character varying(50) NOT NULL,
    order_id character varying(50) NOT NULL,
    review_score integer NOT NULL,
    review_comment_title character varying(500),
    review_comment_message text,
    review_creation_date timestamp without time zone,
    review_answer_timestamp timestamp without time zone,
    has_comment boolean NOT NULL,
    review_response_delay_hours numeric(10,2),
    review_score_category character varying(20) NOT NULL,
    CONSTRAINT chk_staging_review_score CHECK (((review_score >= 1) AND (review_score <= 5)))
);

CREATE TABLE staging.orders (
    order_id character varying(50) NOT NULL,
    customer_id character varying(50) NOT NULL,
    order_status character varying(30) NOT NULL,
    order_purchase_timestamp timestamp without time zone NOT NULL,
    order_approved_at timestamp without time zone,
    order_delivered_carrier_date timestamp without time zone,
    order_delivered_customer_date timestamp without time zone,
    order_estimated_delivery_date timestamp without time zone NOT NULL,
    approval_delay_hours numeric(10,2),
    carrier_delay_hours numeric(10,2),
    delivery_time_hours numeric(10,2),
    delivery_vs_estimated_hours numeric(10,2)
);

CREATE TABLE staging.products (
    product_id character varying(50) NOT NULL,
    product_category_name character varying(100),
    product_category_name_english character varying(100),
    product_name_length integer,
    product_description_length integer,
    product_photos_qty integer,
    product_weight_g numeric,
    product_length_cm numeric,
    product_height_cm numeric,
    product_width_cm numeric,
    category_translation_status character varying(20) NOT NULL
);

CREATE TABLE staging.sellers (
    seller_id character varying(50) NOT NULL,
    seller_zip_code_prefix integer NOT NULL,
    seller_city character varying(100) NOT NULL,
    seller_state character(2) NOT NULL
);

CREATE TABLE analytics.dim_customer (
    customer_id character varying(50) NOT NULL,
    customer_unique_id character varying(50) NOT NULL,
    customer_zip_code_prefix integer NOT NULL,
    customer_city character varying(100) NOT NULL,
    customer_state character(2) NOT NULL,
    latitude numeric(10,7),
    longitude numeric(10,7)
);

CREATE TABLE analytics.dim_date (
    date_key integer NOT NULL,
    full_date date NOT NULL,
    year integer NOT NULL,
    quarter integer NOT NULL,
    month integer NOT NULL,
    month_name character varying(20) NOT NULL,
    week integer NOT NULL,
    day integer NOT NULL,
    day_name character varying(20) NOT NULL,
    is_weekend boolean NOT NULL
);

CREATE TABLE analytics.dim_geography (
    geolocation_zip_code_prefix integer NOT NULL,
    latitude numeric(10,7) NOT NULL,
    longitude numeric(10,7) NOT NULL,
    city character varying(100),
    state character(2)
);

CREATE TABLE analytics.dim_product (
    product_id character varying(50) NOT NULL,
    product_category_name character varying(100),
    product_category_name_english character varying(100),
    product_name_length integer,
    product_description_length integer,
    product_photos_qty integer,
    product_weight_g numeric,
    product_length_cm numeric,
    product_height_cm numeric,
    product_width_cm numeric,
    category_translation_status character varying(20) NOT NULL
);

CREATE TABLE analytics.dim_seller (
    seller_id character varying(50) NOT NULL,
    seller_zip_code_prefix integer NOT NULL,
    seller_city character varying(100) NOT NULL,
    seller_state character(2) NOT NULL,
    latitude numeric(10,7),
    longitude numeric(10,7)
);

CREATE TABLE analytics.fact_order_items (
    order_id character varying(50) NOT NULL,
    order_item_id integer NOT NULL,
    product_id character varying(50) NOT NULL,
    seller_id character varying(50) NOT NULL,
    purchase_date_key integer NOT NULL,
    price numeric(12,2) NOT NULL,
    freight_value numeric(12,2) NOT NULL,
    item_total_value numeric(12,2) NOT NULL
);

CREATE TABLE analytics.fact_orders (
    order_id character varying(50) NOT NULL,
    customer_id character varying(50) NOT NULL,
    purchase_date_key integer NOT NULL,
    order_status character varying(30) NOT NULL,
    approval_delay_hours numeric(10,2),
    carrier_delay_hours numeric(10,2),
    delivery_time_hours numeric(10,2),
    delivery_vs_estimated_hours numeric(10,2),
    delivered_late boolean
);

CREATE TABLE analytics.fact_payments (
    order_id character varying(50) NOT NULL,
    payment_sequential integer NOT NULL,
    payment_type character varying(30) NOT NULL,
    payment_installments integer NOT NULL,
    payment_value numeric(12,2) NOT NULL
);

CREATE TABLE analytics.fact_reviews (
    review_id character varying(50) NOT NULL,
    order_id character varying(50) NOT NULL,
    review_score integer NOT NULL,
    review_score_category character varying(20) NOT NULL,
    has_comment boolean NOT NULL,
    review_response_delay_hours numeric(10,2),
    review_creation_date_key integer
);

CREATE TABLE analytics.order_summary (
    order_id character varying(50) NOT NULL,
    customer_id character varying(50) NOT NULL,
    purchase_date_key integer NOT NULL,
    order_status character varying(30) NOT NULL,
    item_count integer NOT NULL,
    product_value numeric(12,2) NOT NULL,
    freight_value numeric(12,2) NOT NULL,
    item_total_value numeric(12,2) NOT NULL,
    payment_total numeric(12,2) NOT NULL,
    delivered_late boolean,
    delivery_time_hours numeric(10,2),
    delivery_vs_estimated_hours numeric(10,2),
    reconciliation_status character varying(40),
    reconciliation_difference numeric(12,2)
);

CREATE TABLE public.orders (
    order_id character varying(50) NOT NULL,
    customer_id character varying(50),
    order_status character varying(30),
    order_purchase_timestamp timestamp without time zone,
    order_approved_at timestamp without time zone,
    order_delivered_carrier_date timestamp without time zone,
    order_delivered_customer_date timestamp without time zone,
    order_estimated_delivery_date timestamp without time zone
);

CREATE SEQUENCE raw.geolocation_geolocation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE raw.geolocation_geolocation_id_seq OWNED BY raw.geolocation.geolocation_id;

ALTER TABLE ONLY raw.geolocation ALTER COLUMN geolocation_id SET DEFAULT nextval('raw.geolocation_geolocation_id_seq'::regclass);

ALTER TABLE ONLY raw.category_translation
    ADD CONSTRAINT category_translation_pkey PRIMARY KEY (product_category_name);

ALTER TABLE ONLY raw.customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (customer_id);

ALTER TABLE ONLY raw.geolocation
    ADD CONSTRAINT geolocation_pkey PRIMARY KEY (geolocation_id);

ALTER TABLE ONLY raw.order_items
    ADD CONSTRAINT pk_order_items PRIMARY KEY (order_id, order_item_id);

ALTER TABLE ONLY raw.order_payments
    ADD CONSTRAINT pk_order_payments PRIMARY KEY (order_id, payment_sequential);

ALTER TABLE ONLY raw.order_reviews
    ADD CONSTRAINT pk_order_reviews PRIMARY KEY (review_id, order_id);

ALTER TABLE ONLY raw.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (order_id);

ALTER TABLE ONLY raw.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (product_id);

ALTER TABLE ONLY raw.sellers
    ADD CONSTRAINT sellers_pkey PRIMARY KEY (seller_id);

ALTER TABLE ONLY staging.customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (customer_id);

ALTER TABLE ONLY staging.geolocation
    ADD CONSTRAINT geolocation_pkey PRIMARY KEY (geolocation_zip_code_prefix);

ALTER TABLE ONLY staging.order_items
    ADD CONSTRAINT pk_staging_order_items PRIMARY KEY (order_id, order_item_id);

ALTER TABLE ONLY staging.order_payments
    ADD CONSTRAINT pk_staging_order_payments PRIMARY KEY (order_id, payment_sequential);

ALTER TABLE ONLY staging.order_reviews
    ADD CONSTRAINT pk_staging_order_reviews PRIMARY KEY (review_id, order_id);

ALTER TABLE ONLY staging.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (order_id);

ALTER TABLE ONLY staging.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (product_id);

ALTER TABLE ONLY staging.sellers
    ADD CONSTRAINT sellers_pkey PRIMARY KEY (seller_id);

ALTER TABLE ONLY analytics.dim_customer
    ADD CONSTRAINT dim_customer_pkey PRIMARY KEY (customer_id);

ALTER TABLE ONLY analytics.dim_date
    ADD CONSTRAINT dim_date_full_date_key UNIQUE (full_date);

ALTER TABLE ONLY analytics.dim_date
    ADD CONSTRAINT dim_date_pkey PRIMARY KEY (date_key);

ALTER TABLE ONLY analytics.dim_geography
    ADD CONSTRAINT dim_geography_pkey PRIMARY KEY (geolocation_zip_code_prefix);

ALTER TABLE ONLY analytics.dim_product
    ADD CONSTRAINT dim_product_pkey PRIMARY KEY (product_id);

ALTER TABLE ONLY analytics.dim_seller
    ADD CONSTRAINT dim_seller_pkey PRIMARY KEY (seller_id);

ALTER TABLE ONLY analytics.fact_order_items
    ADD CONSTRAINT pk_fact_order_items PRIMARY KEY (order_id, order_item_id);

ALTER TABLE ONLY analytics.fact_orders
    ADD CONSTRAINT fact_orders_pkey PRIMARY KEY (order_id);

ALTER TABLE ONLY analytics.fact_payments
    ADD CONSTRAINT pk_fact_payments PRIMARY KEY (order_id, payment_sequential);

ALTER TABLE ONLY analytics.fact_reviews
    ADD CONSTRAINT pk_fact_reviews PRIMARY KEY (review_id, order_id);

ALTER TABLE ONLY analytics.order_summary
    ADD CONSTRAINT order_summary_pkey PRIMARY KEY (order_id);

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (order_id);

ALTER TABLE ONLY raw.order_items
    ADD CONSTRAINT fk_order_items_order FOREIGN KEY (order_id) REFERENCES raw.orders(order_id);

ALTER TABLE ONLY raw.order_items
    ADD CONSTRAINT fk_order_items_product FOREIGN KEY (product_id) REFERENCES raw.products(product_id);

ALTER TABLE ONLY raw.order_items
    ADD CONSTRAINT fk_order_items_seller FOREIGN KEY (seller_id) REFERENCES raw.sellers(seller_id);

ALTER TABLE ONLY raw.order_payments
    ADD CONSTRAINT fk_order_payments_order FOREIGN KEY (order_id) REFERENCES raw.orders(order_id);

ALTER TABLE ONLY raw.order_reviews
    ADD CONSTRAINT fk_order_reviews_order FOREIGN KEY (order_id) REFERENCES raw.orders(order_id);

ALTER TABLE ONLY raw.orders
    ADD CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES raw.customers(customer_id);

ALTER TABLE ONLY staging.order_items
    ADD CONSTRAINT fk_staging_order_items_order FOREIGN KEY (order_id) REFERENCES staging.orders(order_id);

ALTER TABLE ONLY staging.order_items
    ADD CONSTRAINT fk_staging_order_items_product FOREIGN KEY (product_id) REFERENCES staging.products(product_id);

ALTER TABLE ONLY staging.order_items
    ADD CONSTRAINT fk_staging_order_items_seller FOREIGN KEY (seller_id) REFERENCES staging.sellers(seller_id);

ALTER TABLE ONLY staging.order_payments
    ADD CONSTRAINT fk_staging_order_payments_order FOREIGN KEY (order_id) REFERENCES staging.orders(order_id);

ALTER TABLE ONLY staging.order_reviews
    ADD CONSTRAINT fk_staging_order_reviews_order FOREIGN KEY (order_id) REFERENCES staging.orders(order_id);

ALTER TABLE ONLY analytics.fact_order_items
    ADD CONSTRAINT fk_fact_order_items_date FOREIGN KEY (purchase_date_key) REFERENCES analytics.dim_date(date_key);

ALTER TABLE ONLY analytics.fact_order_items
    ADD CONSTRAINT fk_fact_order_items_order FOREIGN KEY (order_id) REFERENCES analytics.fact_orders(order_id);

ALTER TABLE ONLY analytics.fact_order_items
    ADD CONSTRAINT fk_fact_order_items_product FOREIGN KEY (product_id) REFERENCES analytics.dim_product(product_id);

ALTER TABLE ONLY analytics.fact_order_items
    ADD CONSTRAINT fk_fact_order_items_seller FOREIGN KEY (seller_id) REFERENCES analytics.dim_seller(seller_id);

ALTER TABLE ONLY analytics.fact_orders
    ADD CONSTRAINT fk_fact_orders_customer FOREIGN KEY (customer_id) REFERENCES analytics.dim_customer(customer_id);

ALTER TABLE ONLY analytics.fact_orders
    ADD CONSTRAINT fk_fact_orders_purchase_date FOREIGN KEY (purchase_date_key) REFERENCES analytics.dim_date(date_key);

ALTER TABLE ONLY analytics.fact_payments
    ADD CONSTRAINT fk_fact_payments_order FOREIGN KEY (order_id) REFERENCES analytics.fact_orders(order_id);

ALTER TABLE ONLY analytics.fact_reviews
    ADD CONSTRAINT fk_fact_reviews_creation_date FOREIGN KEY (review_creation_date_key) REFERENCES analytics.dim_date(date_key);

ALTER TABLE ONLY analytics.fact_reviews
    ADD CONSTRAINT fk_fact_reviews_order FOREIGN KEY (order_id) REFERENCES analytics.fact_orders(order_id);

