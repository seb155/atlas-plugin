"""Tests for eval YAML schema validation and data models."""

from __future__ import annotations

from pathlib import Path

import pytest
import yaml

from conftest import PLUGIN_ROOT

EVALS_DIR = PLUGIN_ROOT / "evals"
CASES_DIR = EVALS_DIR / "cases"
SUITES_DIR = EVALS_DIR / "suites"


# ---------------------------------------------------------------------------
# Suite validation
# ---------------------------------------------------------------------------


def _collect_suite_files() -> list[Path]:
    if not SUITES_DIR.exists():
        return []
    return sorted(SUITES_DIR.glob("*.yaml"))


@pytest.mark.parametrize(
    "suite_path",
    _collect_suite_files(),
    ids=[p.stem for p in _collect_suite_files()],
)
def test_suite_yaml_valid(suite_path: Path) -> None:
    """Every suite YAML must be parseable and have required fields."""
    data = yaml.safe_load(suite_path.read_text(encoding="utf-8"))
    assert isinstance(data, dict), f"Suite {suite_path.name} is not a dict"
    assert "name" in data, f"Suite {suite_path.name} missing 'name'"
    assert "levels" in data, f"Suite {suite_path.name} missing 'levels'"

    # Levels must be valid
    valid_levels = {"structural", "behavioral", "full"}
    for level in data["levels"]:
        assert level in valid_levels, f"Invalid level '{level}' in {suite_path.name}"


# ---------------------------------------------------------------------------
# Eval case validation
# ---------------------------------------------------------------------------


def _collect_case_files() -> list[Path]:
    if not CASES_DIR.exists():
        return []
    return sorted(CASES_DIR.glob("*.yaml"))


@pytest.mark.parametrize(
    "case_path",
    _collect_case_files(),
    ids=[p.stem for p in _collect_case_files()],
)
def test_case_yaml_valid(case_path: Path) -> None:
    """Every eval case YAML must be parseable and have required fields."""
    data = yaml.safe_load(case_path.read_text(encoding="utf-8"))
    assert isinstance(data, dict), f"Case {case_path.name} is not a dict"
    assert "skill" in data, f"Case {case_path.name} missing 'skill'"

    # Verify skill exists on disk
    skill_name = data["skill"]
    skill_dir = PLUGIN_ROOT / "skills" / skill_name
    ref_dir = PLUGIN_ROOT / "skills" / "refs" / skill_name
    assert skill_dir.is_dir() or ref_dir.is_dir(), (
        f"Case {case_path.name} references non-existent skill '{skill_name}'"
    )

    # Validate type if present
    valid_types = {
        "code-generation", "planning", "review", "ops", "research",
        "meta", "personal", "domain", "workflow", "presentation", "reference",
    }
    if "type" in data:
        assert data["type"] in valid_types, f"Invalid type '{data['type']}' in {case_path.name}"

    # Validate behavioral cases if present
    behavioral = data.get("behavioral", {})
    for case in behavioral.get("cases", []):
        assert "id" in case, f"Behavioral case missing 'id' in {case_path.name}"
        assert "input" in case, f"Behavioral case missing 'input' in {case_path.name}"


# ---------------------------------------------------------------------------
# Schema model tests
# ---------------------------------------------------------------------------


def test_schema_imports() -> None:
    """Verify all schema models can be imported."""
    from evals.schema import (
        BehavioralCase,
        BehavioralCriteria,
        CodebaseDimension,
        CodebaseEvalConfig,
        EvalCase,
        EvalLevel,
        EvalMode,
        EvalResult,
        EvalScore,
        EvalSuite,
        Grade,
        SkillType,
        StructuralCriteria,
    )
    # Just verify they're importable
    assert EvalMode.PLUGIN.value == "plugin"
    assert EvalLevel.STRUCTURAL.value == "structural"
    assert SkillType.CODE_GENERATION.value == "code-generation"
    assert Grade.A.value == "A"


def test_scorer_grade_mapping() -> None:
    """Verify grade thresholds match enterprise-audit pattern."""
    from evals.scorer import score_to_grade, Grade

    assert score_to_grade(95) == Grade.A
    assert score_to_grade(90) == Grade.A
    assert score_to_grade(85) == Grade.B
    assert score_to_grade(80) == Grade.B
    assert score_to_grade(75) == Grade.C
    assert score_to_grade(70) == Grade.C
    assert score_to_grade(65) == Grade.D
    assert score_to_grade(60) == Grade.D
    assert score_to_grade(55) == Grade.F
    assert score_to_grade(0) == Grade.F
