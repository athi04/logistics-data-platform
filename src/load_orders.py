from extract import extract_orders
from transform import transform_orders
from validate import validate_orders
from load_raw import load_dataframe_to_postgres


orders = extract_orders(
    "data/olist_orders_dataset.csv"
)

orders = transform_orders(orders)

orders = validate_orders(orders)


columns = [
    "order_id",
    "customer_id",
    "order_status",
    "order_purchase_timestamp",
    "order_approved_at",
    "order_delivered_carrier_date",
    "order_delivered_customer_date",
    "order_estimated_delivery_date"
]


load_dataframe_to_postgres(
    df=orders,
    table_name="raw.orders",
    columns=columns
)