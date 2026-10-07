"""
Load the nine Olist CSVs into the raw schema.

Every raw table is emptied and reloaded inside one transaction,
so the load is rerun safe and all or nothing: if any table fails,
raw is left exactly as it was before the run.

Run on its own with:  python src/load_raw.py
"""

import io
import time
from pathlib import Path

import pandas as pd

from database import get_connection


PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_ROOT / "data"


# One entry per raw table. Order matters: each table is loaded
# after every table its foreign keys point to.
#
#   rename        source column names to fix (Olist misspells two)
#   date_columns  parsed so bad values become NULL, not load errors
#   int_columns   whole numbers that can be missing; pandas would
#                 otherwise turn them into floats like 40.0
#   chunksize     read the file in pieces to limit memory
RAW_TABLES = [
    {
        "table": "raw.customers",
        "csv": "olist_customers_dataset.csv",
        "columns": [
            "customer_id", "customer_unique_id", "customer_zip_code_prefix",
            "customer_city", "customer_state",
        ],
    },
    {
        "table": "raw.sellers",
        "csv": "olist_sellers_dataset.csv",
        "columns": [
            "seller_id", "seller_zip_code_prefix", "seller_city", "seller_state",
        ],
    },
    {
        "table": "raw.category_translation",
        "csv": "product_category_name_translation.csv",
        "columns": ["product_category_name", "product_category_name_english"],
    },
    {
        "table": "raw.products",
        "csv": "olist_products_dataset.csv",
        "rename": {
            "product_name_lenght": "product_name_length",
            "product_description_lenght": "product_description_length",
        },
        "int_columns": [
            "product_name_length", "product_description_length",
            "product_photos_qty",
        ],
        "columns": [
            "product_id", "product_category_name", "product_name_length",
            "product_description_length", "product_photos_qty",
            "product_weight_g", "product_length_cm", "product_height_cm",
            "product_width_cm",
        ],
    },
    {
        "table": "raw.geolocation",
        "csv": "olist_geolocation_dataset.csv",
        "chunksize": 50_000,
        "columns": [
            "geolocation_zip_code_prefix", "geolocation_lat", "geolocation_lng",
            "geolocation_city", "geolocation_state",
        ],
    },
    {
        "table": "raw.orders",
        "csv": "olist_orders_dataset.csv",
        "date_columns": [
            "order_purchase_timestamp", "order_approved_at",
            "order_delivered_carrier_date", "order_delivered_customer_date",
            "order_estimated_delivery_date",
        ],
        "columns": [
            "order_id", "customer_id", "order_status",
            "order_purchase_timestamp", "order_approved_at",
            "order_delivered_carrier_date", "order_delivered_customer_date",
            "order_estimated_delivery_date",
        ],
    },
    {
        "table": "raw.order_items",
        "csv": "olist_order_items_dataset.csv",
        "date_columns": ["shipping_limit_date"],
        "columns": [
            "order_id", "order_item_id", "product_id", "seller_id",
            "shipping_limit_date", "price", "freight_value",
        ],
    },
    {
        "table": "raw.order_payments",
        "csv": "olist_order_payments_dataset.csv",
        "columns": [
            "order_id", "payment_sequential", "payment_type",
            "payment_installments", "payment_value",
        ],
    },
    {
        "table": "raw.order_reviews",
        "csv": "olist_order_reviews_dataset.csv",
        "date_columns": ["review_creation_date", "review_answer_timestamp"],
        "columns": [
            "review_id", "order_id", "review_score", "review_comment_title",
            "review_comment_message", "review_creation_date",
            "review_answer_timestamp",
        ],
    },
]


def read_csv(spec):
    """Yield the CSV for one table as cleaned DataFrames (one per chunk)."""
    # utf-8-sig strips a byte order mark if the file has one
    # (product_category_name_translation.csv does).
    result = pd.read_csv(
        DATA_DIR / spec["csv"],
        encoding="utf-8-sig",
        chunksize=spec.get("chunksize"),
    )
    chunks = result if spec.get("chunksize") else [result]

    for df in chunks:
        df = df.rename(columns=spec.get("rename", {}))
        for column in spec.get("date_columns", []):
            df[column] = pd.to_datetime(df[column], errors="coerce")
        for column in spec.get("int_columns", []):
            df[column] = df[column].astype("Int64")
        yield df


def copy_dataframe(cursor, df, table, columns):
    """Stream a DataFrame into a table with COPY. Returns rows loaded."""
    buffer = io.StringIO()
    df[columns].to_csv(buffer, index=False, header=False, na_rep="\\N")
    buffer.seek(0)

    cursor.copy_expert(
        f"COPY {table} ({', '.join(columns)}) "
        f"FROM STDIN WITH (FORMAT CSV, NULL '\\N')",
        buffer,
    )
    return len(df)


def load_raw_tables(connection):
    """Empty and reload every raw table. Caller commits or rolls back."""
    counts = {}
    with connection.cursor() as cursor:
        # All tables in one TRUNCATE, because they reference each other.
        # RESTART IDENTITY resets geolocation_id so ids are the same
        # on every run.
        all_tables = ", ".join(spec["table"] for spec in RAW_TABLES)
        cursor.execute(f"TRUNCATE {all_tables} RESTART IDENTITY")

        for spec in RAW_TABLES:
            start = time.perf_counter()
            rows = sum(
                copy_dataframe(cursor, df, spec["table"], spec["columns"])
                for df in read_csv(spec)
            )
            seconds = time.perf_counter() - start
            counts[spec["table"]] = rows
            print(f"  {spec['table']:<26} {rows:>10,} rows  {seconds:6.1f}s")

    return counts


def main():
    connection = get_connection()
    try:
        load_raw_tables(connection)
        connection.commit()
        print("Raw load committed")
    except Exception:
        connection.rollback()
        print("Raw load failed, rolled back")
        raise
    finally:
        connection.close()


if __name__ == "__main__":
    main()
