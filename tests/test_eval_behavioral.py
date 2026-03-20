"""Tests for the behavioral eval pipeline — rubrics, judge prompt, scoring."""

from __future__ import annotations

from pathlib import Path

import pytest
import yaml

from conftest import PLUGIN_ROOT

RUBRICS_DIR = PLUGIN_ROOT / "evals" / "rubrics"


# ---------------------------------------------------------------------------
# Rubric validation
# ---------------------------------------------------------------------------


def _collect_rubric_files() -> list[Path]:
    if not RUBRICS_DIR.exists():
        return []
    return sorted(RUBRICS_DIR.glob("*.yaml"))


@pytest.mark.parametrize(
    "rubric_path",
    _collect_rubric_files(),
    ids=[p.stem for p in _collect_rubric_files()],
)
def test_rubric_yaml_valid(rubric_path: Path) -> None:
    """Every rubric YAML must be valid and have required structure."""
    data = yaml.safe_load(rubric_path.read_text(encoding="utf-8"))
    assert isinstance(data, dict), f"Rubric {rubric_path.name} is not a dict"
    assert "name" in data, f"Rubric {rubric_path.name} missing 'name'"
    assert "dimensions" in data, f"Rubric {rubric_path.name} missing 'dimensions'"

    dims = data["dimensions"]
    assert isinstance(dims, dict), f"Rubric {rubric_path.name} dimensions must be a dict"

    # Weights must sum to 100
    total_weight = sum(dims.values())
    assert total_weight == 100, (
        f"Rubric {rubric_path.name} dimensions weight sum = {total_weight}, expected 100"
    )

    # Criteria must match dimensions
    if "criteria" in data:
        criteria = data["criteria"]
        for dim_name in dims:
            assert dim_name in criteria, (
                f"Rubric {rubric_path.name} missing criteria for dimension '{dim_name}'"
            )


# ---------------------------------------------------------------------------
# Judge prompt construction
# ---------------------------------------------------------------------------


def test_judge_prompt_build() -> None:
    """Judge prompt should include all required sections."""
    from evals.judge import build_judge_prompt

    prompt = build_judge_prompt(
        skill_name="tdd",
        skill_type="code-generation",
        skill_body="# TDD Skill\n## Cycle\n1. Write test\n2. Run\n3. Implement",
        test_input="Create a validator function using TDD",
        expected_contains=["test_", "assert"],
        ground_truth="Test first, then implement",
        rubric={"correctness": "Is it correct?", "adherence": "Follows TDD?"},
    )

    assert "tdd" in prompt
    assert "code-generation" in prompt
    assert "TDD Skill" in prompt
    assert "Create a validator" in prompt
    assert "test_" in prompt
    assert "CORRECTNESS" in prompt
    assert "ADHERENCE" in prompt
    assert "JSON" in prompt


def test_judge_rubric_for_type() -> None:
    """Rubric selection by skill type should return correct dimensions."""
    from evals.judge import get_rubric_for_type

    code_rubric = get_rubric_for_type("code-generation")
    assert "correctness" in code_rubric
    assert "adherence" in code_rubric

    plan_rubric = get_rubric_for_type("planning")
    assert "structure" in plan_rubric
    assert "feasibility" in plan_rubric

    review_rubric = get_rubric_for_type("review")
    assert "thoroughness" in review_rubric
    assert "accuracy" in review_rubric


def test_default_scores_when_no_api_key() -> None:
    """Judge should return neutral scores when API key is missing."""
    import asyncio
    import os

    from evals.judge import judge_skill

    # Ensure no API key
    old_key = os.environ.pop("ANTHROPIC_API_KEY", None)
    try:
        result = asyncio.run(
            judge_skill(
                skill_name="test",
                skill_type="meta",
                skill_body="test body",
                test_input="test input",
                expected_contains=[],
                ground_truth="test truth",
            )
        )
        assert "reasoning" in result
        assert result.get("_judge_model") is None
        # All dimension scores should be 3 (neutral)
        for key, val in result.items():
            if not key.startswith("_") and key != "reasoning":
                assert val == 3, f"Expected neutral score 3 for {key}, got {val}"
    finally:
        if old_key:
            os.environ["ANTHROPIC_API_KEY"] = old_key


# ---------------------------------------------------------------------------
# Scorer behavioral conversion
# ---------------------------------------------------------------------------


def test_behavioral_to_100_conversion() -> None:
    """Behavioral 1-5 scale should convert correctly to 0-100."""
    from evals.scorer import behavioral_to_100

    assert behavioral_to_100(1) == 0.0
    assert behavioral_to_100(2) == 25.0
    assert behavioral_to_100(3) == 50.0
    assert behavioral_to_100(4) == 75.0
    assert behavioral_to_100(5) == 100.0


def test_compute_behavioral_composite() -> None:
    """Weighted behavioral composite should be correct."""
    from evals.schema import DimensionScore
    from evals.scorer import compute_behavioral_composite

    dims = [
        DimensionScore(name="correctness", score=5.0, weight=30),
        DimensionScore(name="adherence", score=4.0, weight=25),
        DimensionScore(name="completeness", score=3.0, weight=20),
        DimensionScore(name="style", score=4.0, weight=15),
        DimensionScore(name="safety", score=5.0, weight=10),
    ]
    composite = compute_behavioral_composite(dims)
    # Weighted: (5*30 + 4*25 + 3*20 + 4*15 + 5*10) / 100 = 4.2
    # behavioral_to_100(4.2) = (4.2-1)*25 = 80.0
    assert composite == 80.0


# ---------------------------------------------------------------------------
# Golden dataset coverage
# ---------------------------------------------------------------------------


def test_priority_skills_have_behavioral_cases() -> None:
    """P0 priority skills must have behavioral test cases."""
    p0_skills = ["tdd", "plan-builder", "code-review", "verification"]
    cases_dir = PLUGIN_ROOT / "evals" / "cases"

    for skill_name in p0_skills:
        case_path = cases_dir / f"{skill_name}.yaml"
        assert case_path.exists(), f"P0 skill {skill_name} missing eval case file"

        data = yaml.safe_load(case_path.read_text(encoding="utf-8"))
        behavioral = data.get("behavioral", {})
        cases = behavioral.get("cases", [])
        assert len(cases) >= 1, (
            f"P0 skill {skill_name} needs at least 1 behavioral case, has {len(cases)}"
        )
