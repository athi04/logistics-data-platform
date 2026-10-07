import pandas as pd

from load_raw import load_dataframe_to_postgres


df = pd.read_csv(
    "data/olist_order_payments_dataset.csv"
)

columns = [
    "order_id",
    "payment_sequential",
    "payment_type",
    "payment_installments",
    "payment_value"
]

load_dataframe_to_postgres(
    df=df,
    table_name="raw.order_payments",
    columns=columns
)