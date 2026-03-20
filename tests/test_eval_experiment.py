"""Tests for the A/B experiment framework."""

from __future__ import annotations

import pytest

from conftest import PLUGIN_ROOT


def test_mann_whitney_u_basic() -> None:
    """Mann-Whitney U should detect significant difference."""
    from evals.experiment import mann_whitney_u

    # Very different distributions
    sample_a = [90.0, 92.0, 88.0, 91.0, 89.0]
    sample_b = [50.0, 52.0, 48.0, 51.0, 49.0]

    p = mann_whitney_u(sample_a, sample_b)
    assert p < 0.05, f"Expected significant difference, got p={p}"


def test_mann_whitney_u_similar() -> None:
    """Mann-Whitney U should not flag similar distributions."""
    from evals.experiment import mann_whitney_u

    sample_a = [80.0, 82.0, 81.0, 79.0, 83.0]
    sample_b = [81.0, 80.0, 82.0, 80.0, 81.0]

    p = mann_whitney_u(sample_a, sample_b)
    assert p > 0.05, f"Expected no significant difference, got p={p}"


def test_mann_whitney_u_insufficient_data() -> None:
    """Mann-Whitney U should return 1.0 with insufficient data."""
    from evals.experiment import mann_whitney_u

    assert mann_whitney_u([1.0], [2.0]) == 1.0
    assert mann_whitney_u([], []) == 1.0


def test_experiment_config_load() -> None:
    """Load experiment config from YAML."""
    from pathlib import Path
    import yaml

    from evals.experiment import load_experiment_config

    # Create temp config
    config_data = {
        "name": "test-experiment",
        "skill": "tdd",
        "hypothesis": "Test hypothesis",
        "variants": [
            {"id": "control", "source": "skills/tdd/SKILL.md"},
            {"id": "variant-a", "source": "skills/tdd/SKILL.md"},
        ],
        "cases": ["tdd-001"],
        "judge_model": "claude-haiku-4-5-20251001",
        "skill_type": "code-generation",
    }

    # Write to temp location
    temp_dir = PLUGIN_ROOT / "evals" / "experiments"
    temp_dir.mkdir(parents=True, exist_ok=True)
    temp_file = temp_dir / "_test_experiment.yaml"

    try:
        with open(temp_file, "w") as f:
            yaml.dump(config_data, f)

        config = load_experiment_config(temp_file)
        assert config.name == "test-experiment"
        assert config.skill == "tdd"
        assert len(config.variants) == 2
        assert config.variants[0].id == "control"
        assert config.skill_type == "code-generation"
    finally:
        temp_file.unlink(missing_ok=True)


def test_experiment_report_structure() -> None:
    """ExperimentReport should have correct default structure."""
    from evals.experiment import ExperimentReport, VariantResult

    report = ExperimentReport(
        name="test",
        skill="tdd",
        hypothesis="test hyp",
    )
    assert report.status == "completed"
    assert report.winner is None
    assert report.statistical_p is None
    assert not report.is_significant


def test_print_experiment_report() -> None:
    """Print should not crash with valid report."""
    from evals.experiment import ExperimentReport, VariantResult, print_experiment_report

    report = ExperimentReport(
        name="test-exp",
        skill="tdd",
        hypothesis="Structured format is better",
        variant_results={
            "control": VariantResult(
                variant_id="control",
                scores=[75.0, 80.0, 77.0],
                avg_composite=77.3,
                dimension_avgs={"correctness": 4.0, "adherence": 3.5},
            ),
            "variant-a": VariantResult(
                variant_id="variant-a",
                scores=[85.0, 88.0, 82.0],
                avg_composite=85.0,
                dimension_avgs={"correctness": 4.5, "adherence": 4.2},
            ),
        },
        winner="variant-a",
        statistical_p=0.03,
        is_significant=True,
        summary="Winner: variant-a (p=0.03)",
    )
    # Should not raise
    print_experiment_report(report)
