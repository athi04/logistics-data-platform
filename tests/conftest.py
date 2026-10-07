"""
Shared test setup. pytest loads this file automatically.

Tests that need the database ask for the `db` fixture. If the
database cannot be reached they are skipped, not failed, so the
code tests still run on a machine without Postgres.
"""

import psycopg2
import pytest

from database import get_connection


@pytest.fixture(scope="session")
def db():
    """One read only connection shared by every database test."""
    try:
        connection = get_connection()
    except psycopg2.OperationalError as error:
        pytest.skip(f"database not available: {error}")
    connection.set_session(readonly=True, autocommit=True)
    yield connection
    connection.close()


@pytest.fixture
def query(db):
    """Run a query and return its single value."""
    def run(sql):
        with db.cursor() as cursor:
            cursor.execute(sql)
            return cursor.fetchone()[0]
    return run
