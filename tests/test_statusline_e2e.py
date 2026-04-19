"""Pytest wrapper for the bash-based status line E2E regression test.

The real assertions live in tests/statusline-e2e.sh — this file only exists to
hook the shell test into the existing Woodpecker l1-structural step, which runs
pytest. That respects the .claude/rules/ci-config-freeze-week1.md freeze
(no modifications to .woodpecker/*.yml during the Week 1 window ending
2026-04-24) while still shipping regression coverage.

The shell test is the authoritative source; this wrapper MUST stay a thin
subprocess.run — do not duplicate assertion logic.

ADR: docs/ADR/ADR-019-statusline-sota-v2-unification.md
"""

from __future__ import annotations

import subprocess
from pathlib import Path


def test_statusline_e2e_ci_mode() -> None:
    """Runs tests/statusline-e2e.sh in 'ci' (hermetic) mode.

    Hermetic mode builds a tmp HOME and exercises the full chain:
    wrapper → resolver → plugin statusline-command.sh. Asserts the output
    contains '🏛️ ATLAS {VERSION}' AND a model token that proves the
    plugin script actually ran (not a fallback string).

    This is the test that would have caught v4.44.0, v5.0.2, v5.5.1, v5.30.0,
    and v5.30.1 regressions — none existed before v5.36.0.
    """
    script_path = Path(__file__).parent / "statusline-e2e.sh"
    assert script_path.is_file(), f"E2E shell script missing at {script_path}"

    result = subprocess.run(
        ["bash", str(script_path), "ci"],
        capture_output=True,
        text=True,
        timeout=30,
    )

    assert result.returncode == 0, (
        "statusline-e2e.sh ci failed — the deployed wrapper did not render "
        "the expected '🏛️ ATLAS {VERSION}' + model token output.\n"
        f"stdout:\n{result.stdout}\n"
        f"stderr:\n{result.stderr}"
    )
