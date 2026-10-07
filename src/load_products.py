import pandas as pd

from load_raw import load_dataframe_to_postgres


df = pd.read_csv(
    "data/olist_products_dataset.csv"
)

# Rename source columns to match our database schema.
# The original Olist dataset contains these spelling errors.
df = df.rename(
    columns={
        "product_name_lenght": "product_name_length",
        "product_description_lenght": "product_description_length"
    }
)

# Convert columns that represent whole numbers to Pandas'
# nullable integer type.
#
# Int64 allows both:
#   40
#   <missing>
#
# without converting the entire column to float.
integer_columns = [
    "product_name_length",
    "product_description_length",
    "product_photos_qty"
]

for column in integer_columns:
    df[column] = df[column].astype("Int64")


columns = [
    "product_id",
    "product_category_name",
    "product_name_length",
    "product_description_length",
    "product_photos_qty",
    "product_weight_g",
    "product_length_cm",
    "product_height_cm",
    "product_width_cm"
]

load_dataframe_to_postgres(
    df=df,
    table_name="raw.products",
    columns=columns
)