"""Code tests: is the checks file well formed?

These read sql/07_data_quality_checks.sql only. No database needed.
"""

import pytest

from quality_checks import STAGES, load_checks


CHECKS = load_checks()


def test_checks_file_is_not_empty():
    assert len(CHECKS) > 0


def test_check_names_are_unique():
    names = [check["name"] for check in CHECKS]
    assert len(names) == len(set(names))


@pytest.mark.parametrize("check", CHECKS, ids=lambda c: c["name"])
def test_check_is_well_formed(check):
    assert check.get("stage") in STAGES
    assert check.get("level") in ("critical", "warning")
    assert check.get("about"), "every check needs a plain words description"
    assert check["sql"].lstrip().upper().startswith("SELECT")


def test_every_stage_has_a_critical_check():
    stages_covered = {c["stage"] for c in CHECKS if c["level"] == "critical"}
    assert stages_covered == set(STAGES)
