"""Result formatting — console, JSON, JSONL output.

Used by the runner to display eval results and save them for CI/API submission.
"""

from __future__ import annotations

import json
from pathlib import Path

from .schema import EvalResult, EvalScore, Grade


# ---------------------------------------------------------------------------
# Grade colors (ANSI)
# ---------------------------------------------------------------------------

_GRADE_COLOR = {
    Grade.A: "\033[32m",  # green
    Grade.B: "\033[36m",  # cyan
    Grade.C: "\033[33m",  # yellow
    Grade.D: "\033[31m",  # red
    Grade.F: "\033[91m",  # bright red
}
_RESET = "\033[0m"


def _colored_grade(grade: Grade) -> str:
    return f"{_GRADE_COLOR.get(grade, '')}{grade.value}{_RESET}"


# ---------------------------------------------------------------------------
# Console output
# ---------------------------------------------------------------------------


def print_console_report(result: EvalResult) -> None:
    """Print a human-readable eval report to stdout."""
    print()
    print(f"{'=' * 60}")
    print(f"  ATLAS EVAL REPORT — {result.mode.value.upper()} MODE")
    print(f"{'=' * 60}")
    print(f"  Target:    {result.target_name or 'N/A'}")
    print(f"  Suite:     {result.suite_name}")
    print(f"  Level:     {result.level.value}")
    if result.plugin_version:
        print(f"  Version:   {result.plugin_version}")
    if result.branch:
        print(f"  Branch:    {result.branch}")
    print(f"{'─' * 60}")
    print(f"  Items:     {result.total_items}")
    print(f"  Struct:    {result.structural_avg:.1f}/100")
    print(f"  Behav:     {result.behavioral_avg:.1f}/100")
    print(f"  Composite: {result.composite_avg:.1f}/100")
    print(f"  Grade:     {_colored_grade(result.grade)}")
    if result.regression_count > 0:
        print(f"  Regressions: \033[91m{result.regression_count}\033[0m")
    print(f"{'─' * 60}")

    # Per-item breakdown
    if result.scores:
        print(f"\n  {'Item':<30} {'Level':<12} {'Score':>7} {'Grade':>6} {'Delta':>7}")
        print(f"  {'─' * 30} {'─' * 12} {'─' * 7} {'─' * 6} {'─' * 7}")
        for score in sorted(result.scores, key=lambda s: s.item_name):
            delta_str = ""
            if score.delta is not None:
                sign = "+" if score.delta >= 0 else ""
                delta_str = f"{sign}{score.delta:.1f}"
            regression_marker = " !!" if score.is_regression else ""
            print(
                f"  {score.item_name:<30} "
                f"{score.eval_level.value:<12} "
                f"{score.composite:>7.1f} "
                f"{_colored_grade(score.grade):>6} "
                f"{delta_str:>7}{regression_marker}"
            )

    print(f"\n{'=' * 60}\n")


# ---------------------------------------------------------------------------
# JSON output
# ---------------------------------------------------------------------------


def _score_to_dict(score: EvalScore) -> dict:
    """Serialize an EvalScore to a JSON-safe dict."""
    return {
        "item_name": score.item_name,
        "eval_level": score.eval_level.value,
        "case_id": score.case_id,
        "composite": score.composite,
        "dimensions": [
            {"name": d.name, "score": d.score, "weight": d.weight, "details": d.details}
            for d in score.dimensions
        ],
        "grade": score.grade.value,
        "reasoning": score.reasoning,
        "judge_model": score.judge_model,
        "judge_tokens": score.judge_tokens,
        "baseline_composite": score.baseline_composite,
        "delta": score.delta,
        "is_regression": score.is_regression,
    }


def result_to_dict(result: EvalResult) -> dict:
    """Serialize a full EvalResult to a JSON-safe dict."""
    return {
        "mode": result.mode.value,
        "level": result.level.value,
        "suite_name": result.suite_name,
        "target_name": result.target_name,
        "plugin_version": result.plugin_version,
        "branch": result.branch,
        "commit_sha": result.commit_sha,
        "total_items": result.total_items,
        "structural_avg": result.structural_avg,
        "behavioral_avg": result.behavioral_avg,
        "composite_avg": result.composite_avg,
        "grade": result.grade.value,
        "regression_count": result.regression_count,
        "scores": [_score_to_dict(s) for s in result.scores],
    }


def save_json(result: EvalResult, path: Path) -> None:
    """Save eval result as JSON."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(result_to_dict(result), indent=2), encoding="utf-8")


def save_jsonl(result: EvalResult, path: Path) -> None:
    """Save eval scores as JSONL (one line per score)."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        for score in result.scores:
            f.write(json.dumps(_score_to_dict(score)) + "\n")


# ---------------------------------------------------------------------------
# Baseline comparison
# ---------------------------------------------------------------------------


def load_baseline(path: Path) -> dict[str, float]:
    """Load baseline scores as {item_name: composite} dict."""
    if not path.exists():
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    baselines: dict[str, float] = {}
    for score_dict in data.get("scores", []):
        key = score_dict["item_name"]
        if score_dict.get("eval_level") == "behavioral" and score_dict.get("case_id"):
            key = f"{key}:{score_dict['case_id']}"
        baselines[key] = score_dict["composite"]
    return baselines
