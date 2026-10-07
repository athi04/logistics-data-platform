"""
Run the data quality checks in sql/07_data_quality_checks.sql.

Checks run between pipeline stages. A critical check that finds
failing rows stops the pipeline; a warning is reported and the
run carries on.

Run every stage on its own with:  python src/quality_checks.py
"""

import sys
from pathlib import Path

from database import get_connection


PROJECT_ROOT = Path(__file__).resolve().parent.parent
CHECKS_FILE = PROJECT_ROOT / "sql" / "07_data_quality_checks.sql"
STAGES = ["raw", "staging", "analytics", "marts"]


class QualityCheckFailed(Exception):
    """Raised when one or more critical checks find failing rows."""


def load_checks():
    """Read the checks file into a list of dicts.

    A new check starts at each '-- @check' line. Lines starting
    '-- @' are settings; everything else that is not a comment is
    the check's SQL.
    """
    checks = []
    current = None

    for line in CHECKS_FILE.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()

        if stripped.startswith("-- @"):
            key, _, value = stripped[4:].partition(" ")
            if key == "check":
                current = {"name": value.strip(), "sql": ""}
                checks.append(current)
            elif current is not None:
                current[key] = value.strip()

        elif current is not None and stripped and not stripped.startswith("--"):
            current["sql"] += line + "\n"

    return checks


def run_checks(stage):
    """Run every check for one stage. Raise if any critical check fails."""
    checks = [c for c in load_checks() if c["stage"] == stage]
    critical_failures = []

    connection = get_connection()
    try:
        with connection.cursor() as cursor:
            for check in checks:
                cursor.execute(check["sql"])
                failing = cursor.fetchone()[0]

                if failing == 0:
                    status = "pass"
                elif check["level"] == "critical":
                    status = "FAIL"
                    critical_failures.append(check["name"])
                else:
                    status = "warn"

                print(f"  {status:<5} {failing:>7,}  {check['name']}")
    finally:
        connection.close()

    if critical_failures:
        raise QualityCheckFailed(
            f"{len(critical_failures)} critical check(s) failed: "
            + ", ".join(critical_failures)
        )


def main():
    failed = False
    for stage in STAGES:
        print(f"\n{stage}")
        try:
            run_checks(stage)
        except QualityCheckFailed as error:
            print(f"  {error}")
            failed = True
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
