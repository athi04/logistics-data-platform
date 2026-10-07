import pandas as pd

from load_raw import load_dataframe_to_postgres


df = pd.read_csv(
    "data/olist_sellers_dataset.csv"
)

columns = [
    "seller_id",
    "seller_zip_code_prefix",
    "seller_city",
    "seller_state"
]

load_dataframe_to_postgres(
    df=df,
    table_name="raw.sellers",
    columns=columns
)