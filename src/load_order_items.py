import pandas as pd

from load_raw import load_dataframe_to_postgres


df = pd.read_csv(
    "data/olist_order_items_dataset.csv"
)

# Convert shipping date from text to a proper timestamp.
df["shipping_limit_date"] = pd.to_datetime(
    df["shipping_limit_date"],
    errors="coerce"
)

columns = [
    "order_id",
    "order_item_id",
    "product_id",
    "seller_id",
    "shipping_limit_date",
    "price",
    "freight_value"
]

load_dataframe_to_postgres(
    df=df,
    table_name="raw.order_items",
    columns=columns
)