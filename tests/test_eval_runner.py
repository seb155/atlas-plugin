"""Tests for the eval runner — structural evaluation of real skills."""

from __future__ import annotations

from pathlib import Path

import pytest

from conftest import PLUGIN_ROOT


# ---------------------------------------------------------------------------
# Structural eval on real skills
# ---------------------------------------------------------------------------


def test_structural_eval_single_skill() -> None:
    """Run structural eval on the TDD skill — should produce valid scores."""
    from evals.structural import evaluate_skill_structural

    skill_md = PLUGIN_ROOT / "skills" / "tdd" / "SKILL.md"
    assert skill_md.exists(), "TDD SKILL.md must exist"

    score = evaluate_skill_structural(skill_md)

    assert score.item_name == "tdd"
    assert score.eval_level.value == "structural"
    assert len(score.dimensions) == 9
    assert 0 <= score.composite <= 100
    assert score.grade.value in ("A", "B", "C", "D", "F")


def test_structural_eval_missing_skill() -> None:
    """Structural eval on non-existent skill should return empty score."""
    from evals.structural import evaluate_skill_structural

    fake_path = PLUGIN_ROOT / "skills" / "nonexistent" / "SKILL.md"
    score = evaluate_skill_structural(fake_path)

    assert score.item_name == "nonexistent"
    assert score.composite == 0.0
    assert len(score.dimensions) == 0


def test_structural_eval_all_skills_above_threshold() -> None:
    """All real skills should score above minimum threshold (40/100)."""
    from evals.structural import evaluate_skill_structural

    skills_dir = PLUGIN_ROOT / "skills"
    min_score = 40.0  # Generous threshold for initial baseline
    failures = []

    for d in sorted(skills_dir.iterdir()):
        if not d.is_dir():
            continue
        if d.name == "refs":
            for sub in sorted(d.iterdir()):
                if sub.is_dir():
                    md = sub / "SKILL.md"
                    if md.exists():
                        score = evaluate_skill_structural(md)
                        if score.composite < min_score:
                            failures.append(f"{sub.name}: {score.composite:.1f}")
        else:
            md = d / "SKILL.md"
            if md.exists():
                score = evaluate_skill_structural(md)
                if score.composite < min_score:
                    failures.append(f"{d.name}: {score.composite:.1f}")

    assert not failures, f"Skills below {min_score}: {', '.join(failures)}"


# ---------------------------------------------------------------------------
# Runner integration
# ---------------------------------------------------------------------------


def test_runner_plugin_structural() -> None:
    """Run the full plugin structural pipeline."""
    from evals.runner import run_plugin_structural

    scores = run_plugin_structural(PLUGIN_ROOT, skills=["tdd", "code-review"])
    assert len(scores) == 2
    assert all(s.eval_level.value == "structural" for s in scores)
    assert all(s.composite > 0 for s in scores)


def test_runner_plugin_structural_all() -> None:
    """Run structural on all skills — no crashes."""
    from evals.runner import run_plugin_structural

    scores = run_plugin_structural(PLUGIN_ROOT)
    # Should have at least 40 skills (some may be in refs/)
    assert len(scores) >= 40


# ---------------------------------------------------------------------------
# Reporter
# ---------------------------------------------------------------------------


def test_reporter_json_roundtrip(tmp_path: Path) -> None:
    """JSON save + load roundtrip for baseline comparison."""
    from evals.reporter import load_baseline, save_json
    from evals.schema import EvalLevel, EvalMode, EvalResult, EvalScore, Grade

    result = EvalResult(
        mode=EvalMode.PLUGIN,
        level=EvalLevel.STRUCTURAL,
        suite_name="test",
        target_name="test-plugin",
        total_items=2,
        structural_avg=85.0,
        composite_avg=85.0,
        grade=Grade.B,
        scores=[
            EvalScore(item_name="skill-a", eval_level=EvalLevel.STRUCTURAL, composite=90.0, grade=Grade.A),
            EvalScore(item_name="skill-b", eval_level=EvalLevel.STRUCTURAL, composite=80.0, grade=Grade.B),
        ],
    )

    out_path = tmp_path / "test-result.json"
    save_json(result, out_path)
    assert out_path.exists()

    baseline = load_baseline(out_path)
    assert baseline["skill-a"] == 90.0
    assert baseline["skill-b"] == 80.0


# ---------------------------------------------------------------------------
# Gate
# ---------------------------------------------------------------------------


def test_gate_passes(tmp_path: Path) -> None:
    """Gate should pass when scores meet thresholds."""
    import json

    from evals.gate import check_gates

    data = {
        "structural_avg": 85.0,
        "behavioral_avg": 70.0,
        "grade": "B",
        "regression_count": 0,
        "scores": [],
    }
    path = tmp_path / "good.json"
    path.write_text(json.dumps(data))

    assert check_gates(path, min_structural=70, min_behavioral=60, max_regressions=0)


def test_gate_fails_structural(tmp_path: Path) -> None:
    """Gate should fail when structural score is below threshold."""
    import json

    from evals.gate import check_gates

    data = {
        "structural_avg": 55.0,
        "behavioral_avg": 70.0,
        "grade": "D",
        "regression_count": 0,
        "scores": [],
    }
    path = tmp_path / "bad.json"
    path.write_text(json.dumps(data))

    assert not check_gates(path, min_structural=70)


def test_gate_fails_regressions(tmp_path: Path) -> None:
    """Gate should fail when regressions exceed threshold."""
    import json

    from evals.gate import check_gates

    data = {
        "structural_avg": 85.0,
        "behavioral_avg": 70.0,
        "grade": "B",
        "regression_count": 2,
        "scores": [],
    }
    path = tmp_path / "regressed.json"
    path.write_text(json.dumps(data))

    assert not check_gates(path, max_regressions=0)
