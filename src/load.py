import pandas as pd
from psycopg2.extras import execute_values

from database import get_connection


def load_orders(orders):

    connection = get_connection()
    cursor = connection.cursor()

    insert_query = """
        INSERT INTO orders (
            order_id,
            customer_id,
            order_status,
            order_purchase_timestamp,
            order_approved_at,
            order_delivered_carrier_date,
            order_delivered_customer_date,
            order_estimated_delivery_date
        )
        VALUES %s
    """

    values = []

    for _, row in orders.iterrows():

        row_values = (
            row["order_id"],
            row["customer_id"],
            row["order_status"],
            row["order_purchase_timestamp"],
            row["order_approved_at"],
            row["order_delivered_carrier_date"],
            row["order_delivered_customer_date"],
            row["order_estimated_delivery_date"],
        )

        row_values = tuple(
            None if pd.isna(value) else value
            for value in row_values
        )

        values.append(row_values)

    execute_values(
        cursor,
        insert_query,
        values,
        page_size=1000
    )

    connection.commit()

    cursor.close()
    connection.close()

    print(f"Loaded {len(orders)} orders into PostgreSQL")