"""Data tests: does the built warehouse match the reference figures?

Run after the pipeline. Every figure here also appears in
docs/reference_figures.md.
"""

from decimal import Decimal

import pytest

from quality_checks import load_checks
from run_pipeline import EXPECTED_ROWS


def test_connection(query):
    assert query("SELECT 1") == 1


@pytest.mark.parametrize("table,expected", EXPECTED_ROWS.items())
def test_row_count(query, table, expected):
    assert query(f"SELECT COUNT(*) FROM {table}") == expected


MONEY = {
    "product value": ("SELECT SUM(price) FROM analytics.fact_order_items",
                      "13591643.70"),
    "freight":       ("SELECT SUM(freight_value) FROM analytics.fact_order_items",
                      "2251909.54"),
    "item total":    ("SELECT SUM(item_total_value) FROM analytics.fact_order_items",
                      "15843553.24"),
    "payment total": ("SELECT SUM(payment_value) FROM analytics.fact_payments",
                      "16008872.12"),
    "difference":    ("SELECT SUM(reconciliation_difference) FROM analytics.order_summary",
                      "165318.88"),
}


@pytest.mark.parametrize("name", MONEY)
def test_money_total(query, name):
    sql, expected = MONEY[name]
    # Decimal, not float: money compared exactly, to the centavo
    assert query(sql) == Decimal(expected)


RECONCILIATION = {
    "reconciled": 98_365,
    "payment_without_items": 772,
    "payment_greater_than_items": 264,
    "items_greater_than_payment": 39,
    "items_without_payment": 1,
}


@pytest.mark.parametrize("status,expected", RECONCILIATION.items())
def test_reconciliation(query, status, expected):
    sql = ("SELECT COUNT(*) FROM analytics.order_summary "
           f"WHERE reconciliation_status = '{status}'")
    assert query(sql) == expected


DELIVERY = {
    "on_time_or_early": 89_941,
    "late": 6_535,
    "in_progress": 1_729,
    "not_completed": 1_228,
    "missing_delivery_date": 8,
}


@pytest.mark.parametrize("category,expected", DELIVERY.items())
def test_delivery_category(query, category, expected):
    sql = ("SELECT COUNT(*) FROM marts.delivery_performance "
           f"WHERE delivery_category = '{category}'")
    assert query(sql) == expected


CRITICAL = [c for c in load_checks() if c["level"] == "critical"]


@pytest.mark.parametrize("check", CRITICAL, ids=lambda c: c["name"])
def test_critical_check_passes(query, check):
    assert query(check["sql"]) == 0, check["about"]
