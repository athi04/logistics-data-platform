"""
Build the whole warehouse from the CSVs in data/.

    python src/run_pipeline.py

Steps run in order and the run stops at the first failure.
Every step is rerun safe, so running it twice gives the same
result as running it once.
"""

import sys
import time
from pathlib import Path

from database import get_connection
from load_raw import load_raw_tables


PROJECT_ROOT = Path(__file__).resolve().parent.parent
SQL_DIR = PROJECT_ROOT / "sql"


# Reference row counts. If the rebuild disagrees with any of
# these, the run is reported as failed.
EXPECTED_ROWS = {
    "raw.orders": 99_441,
    "raw.geolocation": 1_000_163,
    "staging.geolocation": 19_015,
    "analytics.dim_date": 800,
    "analytics.dim_customer": 99_441,
    "analytics.dim_seller": 3_095,
    "analytics.dim_product": 32_951,
    "analytics.dim_geography": 19_015,
    "analytics.fact_orders": 99_441,
    "analytics.fact_order_items": 112_650,
    "analytics.fact_payments": 103_886,
    "analytics.fact_reviews": 99_224,
    "analytics.order_summary": 99_441,
    "marts.delivery_performance": 99_441,
}


def run_sql_file(filename):
    """Run one SQL file. Autocommit lets the file's own BEGIN and
    COMMIT control its transactions."""
    sql = (SQL_DIR / filename).read_text(encoding="utf-8")
    connection = get_connection()
    connection.autocommit = True
    try:
        with connection.cursor() as cursor:
            cursor.execute(sql)
    finally:
        connection.close()


def run_raw_load():
    """Load the CSVs as one transaction: all tables or none."""
    connection = get_connection()
    try:
        load_raw_tables(connection)
        connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()


STEPS = [
    ("Create schemas",         lambda: run_sql_file("01_create_schemas.sql")),
    ("Create raw tables",      lambda: run_sql_file("02_create_raw_tables.sql")),
    ("Load raw from CSV",      run_raw_load),
    ("Build staging",          lambda: run_sql_file("03_create_staging_tables.sql")),
    ("Build dimensions",       lambda: run_sql_file("04_create_analytics_dimensions.sql")),
    ("Build facts",            lambda: run_sql_file("05_create_analytics_facts.sql")),
    ("Build marts",            lambda: run_sql_file("06_create_marts.sql")),
]


def check_row_counts():
    """Compare table sizes with EXPECTED_ROWS. Returns True if all match."""
    connection = get_connection()
    all_ok = True
    try:
        with connection.cursor() as cursor:
            for table, expected in EXPECTED_ROWS.items():
                cursor.execute(f"SELECT COUNT(*) FROM {table}")
                actual = cursor.fetchone()[0]
                ok = actual == expected
                all_ok &= ok
                mark = "ok" if ok else f"EXPECTED {expected:,}"
                print(f"  {table:<28} {actual:>10,}  {mark}")
    finally:
        connection.close()
    return all_ok


def main():
    run_start = time.perf_counter()

    for number, (name, step) in enumerate(STEPS, start=1):
        print(f"[{number}/{len(STEPS)}] {name}")
        start = time.perf_counter()
        try:
            step()
        except Exception as error:
            print(f"\nFAILED at step {number}: {name}\n{error}")
            sys.exit(1)
        print(f"      done in {time.perf_counter() - start:.1f}s")

    print("\nRow counts")
    counts_ok = check_row_counts()

    total = time.perf_counter() - run_start
    if counts_ok:
        print(f"\nPipeline succeeded in {total:.1f}s")
    else:
        print(f"\nPipeline ran in {total:.1f}s but row counts do not match")
        sys.exit(1)


if __name__ == "__main__":
    main()
