import pandas as pd

from load_raw import load_dataframe_to_postgres


df = pd.read_csv(
    "data/product_category_name_translation.csv"
)

columns = [
    "product_category_name",
    "product_category_name_english"
]

load_dataframe_to_postgres(
    df=df,
    table_name="raw.category_translation",
    columns=columns
)