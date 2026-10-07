import io
from pathlib import Path

import pandas as pd

from database import get_connection


DATA_DIR = Path("data")


def load_dataframe_to_postgres(
    df,
    table_name,
    columns,
    chunk_name=None
):
    """
    Load a pandas DataFrame into PostgreSQL using COPY.
    """

    connection = get_connection()

    try:
        cursor = connection.cursor()

        buffer = io.StringIO()

        df[columns].to_csv(
            buffer,
            index=False,
            header=True,
            na_rep="\\N"
        )

        buffer.seek(0)

        column_list = ", ".join(columns)

        copy_sql = f"""
            COPY {table_name} ({column_list})
            FROM STDIN
            WITH (
                FORMAT CSV,
                HEADER TRUE,
                NULL '\\N'
            )
        """

        cursor.copy_expert(copy_sql, buffer)

        connection.commit()

        label = chunk_name if chunk_name else table_name

        print(
            f"Loaded {len(df):,} rows into {label}"
        )

    except Exception:
        connection.rollback()
        raise

    finally:
        cursor.close()
        connection.close()