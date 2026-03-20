"""Score calculation, weighting, and A-F grading.

Reuses the enterprise-audit scoring rubric pattern:
- Base score of 100 per dimension
- Weighted average → composite
- Grade mapping A-F
"""

from __future__ import annotations

from .schema import DimensionScore, EvalScore, Grade, EvalLevel


# ---------------------------------------------------------------------------
# Grade mapping (same thresholds as enterprise-audit)
# ---------------------------------------------------------------------------

GRADE_THRESHOLDS: list[tuple[float, Grade]] = [
    (90.0, Grade.A),
    (80.0, Grade.B),
    (70.0, Grade.C),
    (60.0, Grade.D),
    (0.0, Grade.F),
]


def score_to_grade(score: float) -> Grade:
    """Convert a numeric score (0-100) to a letter grade."""
    for threshold, grade in GRADE_THRESHOLDS:
        if score >= threshold:
            return grade
    return Grade.F


# ---------------------------------------------------------------------------
# Structural scoring (0-100 scale)
# ---------------------------------------------------------------------------


def compute_structural_composite(dimensions: list[DimensionScore]) -> float:
    """Weighted average of structural dimension scores (0-100 each)."""
    if not dimensions:
        return 0.0
    total_weight = sum(d.weight for d in dimensions)
    if total_weight == 0:
        return 0.0
    weighted_sum = sum(d.score * d.weight for d in dimensions)
    return round(weighted_sum / total_weight, 1)


# ---------------------------------------------------------------------------
# Behavioral scoring (1-5 scale → normalized to 0-100)
# ---------------------------------------------------------------------------


def behavioral_to_100(score_1_5: float) -> float:
    """Convert a 1-5 behavioral score to 0-100 scale."""
    return round((score_1_5 - 1) * 25, 1)  # 1→0, 2→25, 3→50, 4→75, 5→100


def compute_behavioral_composite(dimensions: list[DimensionScore]) -> float:
    """Weighted average of behavioral dimension scores (1-5 each), returned as 0-100."""
    if not dimensions:
        return 0.0
    total_weight = sum(d.weight for d in dimensions)
    if total_weight == 0:
        return 0.0
    weighted_sum = sum(d.score * d.weight for d in dimensions)
    raw_avg = weighted_sum / total_weight  # 1-5 scale
    return behavioral_to_100(raw_avg)


# ---------------------------------------------------------------------------
# Build EvalScore from dimension list
# ---------------------------------------------------------------------------


def build_eval_score(
    item_name: str,
    eval_level: EvalLevel,
    dimensions: list[DimensionScore],
    case_id: str | None = None,
    reasoning: str = "",
    judge_model: str | None = None,
    judge_tokens: int = 0,
    baseline_composite: float | None = None,
) -> EvalScore:
    """Create a complete EvalScore from a list of dimension scores."""
    if eval_level == EvalLevel.STRUCTURAL:
        composite = compute_structural_composite(dimensions)
    else:
        composite = compute_behavioral_composite(dimensions)

    grade = score_to_grade(composite)

    delta = None
    is_regression = False
    if baseline_composite is not None:
        delta = round(composite - baseline_composite, 1)
        is_regression = delta < -3.0  # > 3 point drop = regression

    return EvalScore(
        item_name=item_name,
        eval_level=eval_level,
        case_id=case_id,
        composite=composite,
        dimensions=dimensions,
        grade=grade,
        reasoning=reasoning,
        judge_model=judge_model,
        judge_tokens=judge_tokens,
        baseline_composite=baseline_composite,
        delta=delta,
        is_regression=is_regression,
    )


# ---------------------------------------------------------------------------
# Aggregate run-level scores
# ---------------------------------------------------------------------------


def compute_run_aggregates(
    scores: list[EvalScore],
) -> tuple[float, float, float, Grade, int]:
    """Compute run-level aggregates from a list of scores.

    Returns: (structural_avg, behavioral_avg, composite_avg, grade, regression_count)
    """
    structural_scores = [s.composite for s in scores if s.eval_level == EvalLevel.STRUCTURAL]
    behavioral_scores = [s.composite for s in scores if s.eval_level == EvalLevel.BEHAVIORAL]

    structural_avg = round(sum(structural_scores) / len(structural_scores), 1) if structural_scores else 0.0
    behavioral_avg = round(sum(behavioral_scores) / len(behavioral_scores), 1) if behavioral_scores else 0.0

    all_composites = structural_scores + behavioral_scores
    composite_avg = round(sum(all_composites) / len(all_composites), 1) if all_composites else 0.0

    grade = score_to_grade(composite_avg)
    regression_count = sum(1 for s in scores if s.is_regression)

    return structural_avg, behavioral_avg, composite_avg, grade, regression_count
