"""Code tests: is the raw loader's configuration consistent?"""

import pandas as pd
import pytest

from load_raw import DATA_DIR, RAW_TABLES


SPEC_IDS = [spec["table"] for spec in RAW_TABLES]


def test_each_table_appears_once():
    assert len(SPEC_IDS) == len(set(SPEC_IDS))


@pytest.mark.parametrize("spec", RAW_TABLES, ids=SPEC_IDS)
def test_spec_is_consistent(spec):
    """Columns named in date_columns, int_columns and rename all
    end up in the list of columns that gets loaded."""
    columns = set(spec["columns"])
    assert set(spec.get("date_columns", [])) <= columns
    assert set(spec.get("int_columns", [])) <= columns
    assert set(spec.get("rename", {}).values()) <= columns


@pytest.mark.parametrize("spec", RAW_TABLES, ids=SPEC_IDS)
def test_csv_has_every_column(spec):
    """After renaming, the CSV header contains every column we load.
    Reads the header only, so it is fast."""
    path = DATA_DIR / spec["csv"]
    if not path.exists():
        pytest.skip(f"{path.name} not downloaded")
    header = pd.read_csv(path, nrows=0, encoding="utf-8-sig")
    header = header.rename(columns=spec.get("rename", {}))
    missing = set(spec["columns"]) - set(header.columns)
    assert not missing, f"missing from CSV: {missing}"


@pytest.mark.parametrize("spec", RAW_TABLES, ids=SPEC_IDS)
def test_columns_match_database(spec, db):
    """Every configured column exists in the database table."""
    schema, table = spec["table"].split(".")
    with db.cursor() as cursor:
        cursor.execute(
            "SELECT column_name FROM information_schema.columns "
            "WHERE table_schema = %s AND table_name = %s",
            (schema, table),
        )
        db_columns = {row[0] for row in cursor.fetchall()}
    missing = set(spec["columns"]) - db_columns
    assert not missing, f"not in {spec['table']}: {missing}"
