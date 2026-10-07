"""
Build the whole warehouse from the CSVs in data/.

    python src/run_pipeline.py

Steps run in order and the run stops at the first failure.
Every step is rerun safe, so running it twice gives the same
result as running it once. Each run is recorded in
meta.pipeline_runs.
"""

import sys
import time
from pathlib import Path

from database import get_connection
from load_raw import load_raw_tables
from quality_checks import run_checks


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
    "marts.category_performance": 74,
    "marts.customer_performance": 96_096,
    "marts.payment_analysis": 99_441,
}


# ---------------------------------------------------------
# Steps
# ---------------------------------------------------------

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
        counts = load_raw_tables(connection)
        connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()
    return {"rows_loaded": sum(counts.values())}


# A step may return a dict of numbers; they are added up across
# the run and saved in the run log.
STEPS = [
    ("Create schemas",         lambda: run_sql_file("01_create_schemas.sql")),
    ("Create raw tables",      lambda: run_sql_file("02_create_raw_tables.sql")),
    ("Load raw from CSV",      run_raw_load),
    ("Check raw",              lambda: run_checks("raw")),
    ("Build staging",          lambda: run_sql_file("03_create_staging_tables.sql")),
    ("Check staging",          lambda: run_checks("staging")),
    ("Build dimensions",       lambda: run_sql_file("04_create_analytics_dimensions.sql")),
    ("Build facts",            lambda: run_sql_file("05_create_analytics_facts.sql")),
    ("Check analytics",        lambda: run_checks("analytics")),
    ("Build marts",            lambda: run_sql_file("06_create_marts.sql")),
    ("Check marts",            lambda: run_checks("marts")),
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


# ---------------------------------------------------------
# Run log
# ---------------------------------------------------------

def start_run():
    """Create the log table if needed and open a 'running' row."""
    run_sql_file("00_create_run_log.sql")
    connection = get_connection()
    connection.autocommit = True
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                "INSERT INTO meta.pipeline_runs (status) "
                "VALUES ('running') RETURNING run_id"
            )
            return cursor.fetchone()[0]
    finally:
        connection.close()


def finish_run(run_id, status, seconds, totals, failed_step=None, error=None):
    """Record how the run ended."""
    connection = get_connection()
    connection.autocommit = True
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                UPDATE meta.pipeline_runs
                SET finished_at      = now(),
                    status           = %s,
                    failed_step      = %s,
                    error_message    = %s,
                    duration_seconds = %s,
                    rows_loaded      = %s,
                    warnings         = %s
                WHERE run_id = %s
                """,
                (status, failed_step, error, round(seconds, 1),
                 totals["rows_loaded"], totals["warnings"], run_id),
            )
    finally:
        connection.close()


# ---------------------------------------------------------
# Main
# ---------------------------------------------------------

def main():
    run_start = time.perf_counter()
    run_id = start_run()
    totals = {"rows_loaded": 0, "warnings": 0}
    print(f"Run {run_id}")

    for number, (name, step) in enumerate(STEPS, start=1):
        print(f"[{number}/{len(STEPS)}] {name}")
        start = time.perf_counter()
        try:
            result = step()
        except Exception as error:
            print(f"\nFAILED at step {number}: {name}\n{error}")
            finish_run(run_id, "failed", time.perf_counter() - run_start,
                       totals, failed_step=name, error=str(error))
            sys.exit(1)
        for key, value in (result or {}).items():
            totals[key] += value
        print(f"      done in {time.perf_counter() - start:.1f}s")

    print("\nRow counts")
    counts_ok = check_row_counts()
    total = time.perf_counter() - run_start

    if counts_ok:
        finish_run(run_id, "succeeded", total, totals)
        print(f"\nRun {run_id} succeeded in {total:.1f}s "
              f"({totals['rows_loaded']:,} rows loaded, "
              f"{totals['warnings']} warnings)")
    else:
        finish_run(run_id, "failed", total, totals,
                   failed_step="Row counts", error="Row counts do not match")
        print(f"\nRun {run_id} ran in {total:.1f}s but row counts do not match")
        sys.exit(1)


if __name__ == "__main__":
    main()
