import pandas as pd

from load_raw import load_dataframe_to_postgres


df = pd.read_csv(
    "data/olist_customers_dataset.csv"
)

columns = [
    "customer_id",
    "customer_unique_id",
    "customer_zip_code_prefix",
    "customer_city",
    "customer_state"
]

load_dataframe_to_postgres(
    df=df,
    table_name="raw.customers",
    columns=columns
)