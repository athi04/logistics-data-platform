import pandas as pd

from load_raw import load_dataframe_to_postgres

df = pd.read_csv(
    "data/olist_order_reviews_dataset.csv"
)

date_columns = [
    "review_creation_date",
    "review_answer_timestamp"
]

for column in date_columns:
    df[column] = pd.to_datetime(
        df[column],
        errors="coerce"
    )

columns = [
    "review_id",
    "order_id",
    "review_score",
    "review_comment_title",
    "review_comment_message",
    "review_creation_date",
    "review_answer_timestamp"
]

load_dataframe_to_postgres(
    df=df,
    table_name="raw.order_reviews",
    columns=columns
)