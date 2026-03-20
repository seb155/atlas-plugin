"""A/B experiment framework for skill variants.

Run experiments comparing different versions of a SKILL.md to determine
which produces better outputs according to LLM-as-Judge scoring.

Usage:
    python -m evals.runner --experiment evals/experiments/tdd-format-test.yaml
"""

from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass, field
from pathlib import Path

import yaml

from .judge import judge_skill, get_rubric_for_type
from .schema import BehavioralCase, DimensionScore, EvalLevel, SkillType
from .scorer import build_eval_score, compute_behavioral_composite

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Experiment config
# ---------------------------------------------------------------------------


@dataclass
class VariantConfig:
    """A single variant in an experiment."""

    id: str
    source: str  # relative path to SKILL.md


@dataclass
class ExperimentConfig:
    """Complete experiment configuration."""

    name: str
    skill: str
    hypothesis: str = ""
    variants: list[VariantConfig] = field(default_factory=list)
    cases: list[str] = field(default_factory=list)  # case IDs to use
    judge_model: str = "claude-sonnet-4-5-20250514"
    min_cases_per_variant: int = 3
    significance_threshold: float = 0.05
    skill_type: str = "meta"


@dataclass
class VariantResult:
    """Results for a single variant."""

    variant_id: str
    scores: list[float] = field(default_factory=list)  # composite scores per case
    avg_composite: float = 0.0
    dimension_avgs: dict[str, float] = field(default_factory=dict)


@dataclass
class ExperimentReport:
    """Complete experiment results."""

    name: str
    skill: str
    hypothesis: str
    status: str = "completed"  # completed | insufficient_data | error
    variant_results: dict[str, VariantResult] = field(default_factory=dict)
    winner: str | None = None
    statistical_p: float | None = None
    is_significant: bool = False
    summary: str = ""


# ---------------------------------------------------------------------------
# Config loading
# ---------------------------------------------------------------------------


def load_experiment_config(path: Path) -> ExperimentConfig:
    """Load experiment config from YAML."""
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"Invalid experiment config: {path}")

    variants = [
        VariantConfig(id=v["id"], source=v["source"])
        for v in data.get("variants", [])
    ]

    return ExperimentConfig(
        name=data["name"],
        skill=data["skill"],
        hypothesis=data.get("hypothesis", ""),
        variants=variants,
        cases=data.get("cases", []),
        judge_model=data.get("judge_model", "claude-sonnet-4-5-20250514"),
        min_cases_per_variant=data.get("min_cases_per_variant", 3),
        significance_threshold=data.get("significance_threshold", 0.05),
        skill_type=data.get("skill_type", "meta"),
    )


# ---------------------------------------------------------------------------
# Statistical significance (Mann-Whitney U)
# ---------------------------------------------------------------------------


def mann_whitney_u(sample_a: list[float], sample_b: list[float]) -> float:
    """Compute Mann-Whitney U test p-value (two-sided).

    Simple implementation without scipy dependency. Returns approximate p-value.
    For production use, consider scipy.stats.mannwhitneyu.
    """
    if len(sample_a) < 2 or len(sample_b) < 2:
        return 1.0  # Not enough data

    n_a = len(sample_a)
    n_b = len(sample_b)

    # Combine and rank
    combined = [(v, "a") for v in sample_a] + [(v, "b") for v in sample_b]
    combined.sort(key=lambda x: x[0])

    # Assign ranks (handle ties by averaging)
    ranks: list[float] = []
    i = 0
    while i < len(combined):
        j = i
        while j < len(combined) and combined[j][0] == combined[i][0]:
            j += 1
        avg_rank = (i + j + 1) / 2  # 1-indexed average rank
        for _ in range(j - i):
            ranks.append(avg_rank)
        i = j

    # Sum ranks for group A
    rank_sum_a = sum(r for r, (_, g) in zip(ranks, combined) if g == "a")

    # U statistic
    u_a = rank_sum_a - n_a * (n_a + 1) / 2
    u_b = n_a * n_b - u_a

    u = min(u_a, u_b)

    # Normal approximation for p-value
    mu = n_a * n_b / 2
    sigma = (n_a * n_b * (n_a + n_b + 1) / 12) ** 0.5

    if sigma == 0:
        return 1.0

    z = abs((u - mu) / sigma)

    # Approximate two-sided p-value using standard normal
    # Using the complementary error function approximation
    import math

    p = 2 * (1 - 0.5 * (1 + math.erf(z / math.sqrt(2))))
    return max(0.0, min(1.0, p))


# ---------------------------------------------------------------------------
# Experiment runner
# ---------------------------------------------------------------------------


async def run_experiment(
    config: ExperimentConfig,
    plugin_root: Path,
    cases: list[BehavioralCase] | None = None,
) -> ExperimentReport:
    """Run an A/B experiment on skill variants.

    Args:
        config: Experiment configuration
        plugin_root: Path to atlas-plugin root
        cases: Pre-loaded behavioral cases (if None, loads from eval cases)
    """
    report = ExperimentReport(
        name=config.name,
        skill=config.skill,
        hypothesis=config.hypothesis,
    )

    # Load behavioral cases
    if cases is None:
        from .schema import load_eval_case

        cases_dir = plugin_root / "evals" / "cases"
        case_path = cases_dir / f"{config.skill}.yaml"
        if case_path.exists():
            eval_case = load_eval_case(case_path)
            cases = eval_case.behavioral.cases
        else:
            cases = []

    # Filter to requested case IDs
    if config.cases:
        cases = [c for c in cases if c.id in config.cases]

    if len(cases) < config.min_cases_per_variant:
        report.status = "insufficient_data"
        report.summary = (
            f"Need {config.min_cases_per_variant} cases, only found {len(cases)}"
        )
        return report

    rubric = get_rubric_for_type(config.skill_type)

    # Run each variant against all cases
    for variant in config.variants:
        variant_path = plugin_root / variant.source
        if not variant_path.exists():
            logger.warning("Variant %s not found: %s", variant.id, variant_path)
            continue

        skill_body = variant_path.read_text(encoding="utf-8")
        variant_result = VariantResult(variant_id=variant.id)
        dim_accumulators: dict[str, list[float]] = {d: [] for d in rubric}

        for bcase in cases:
            scores = await judge_skill(
                skill_name=config.skill,
                skill_type=config.skill_type,
                skill_body=skill_body,
                test_input=bcase.input,
                expected_contains=bcase.expected_contains,
                ground_truth=bcase.ground_truth,
                rubric=rubric,
                model=config.judge_model,
            )

            # Build dimension scores for composite calculation
            dims = [
                DimensionScore(
                    name=d, score=float(scores.get(d, 3)), weight=100 / len(rubric)
                )
                for d in rubric
            ]
            composite = compute_behavioral_composite(dims)
            variant_result.scores.append(composite)

            for d in rubric:
                dim_accumulators[d].append(float(scores.get(d, 3)))

        # Compute averages
        if variant_result.scores:
            variant_result.avg_composite = round(
                sum(variant_result.scores) / len(variant_result.scores), 2
            )
            variant_result.dimension_avgs = {
                d: round(sum(vals) / len(vals), 2)
                for d, vals in dim_accumulators.items()
                if vals
            }

        report.variant_results[variant.id] = variant_result

    # Statistical comparison (pairwise between first two variants)
    if len(report.variant_results) >= 2:
        variant_ids = list(report.variant_results.keys())
        scores_a = report.variant_results[variant_ids[0]].scores
        scores_b = report.variant_results[variant_ids[1]].scores

        if scores_a and scores_b:
            p_value = mann_whitney_u(scores_a, scores_b)
            report.statistical_p = round(p_value, 4)
            report.is_significant = p_value < config.significance_threshold

            # Determine winner
            avg_a = report.variant_results[variant_ids[0]].avg_composite
            avg_b = report.variant_results[variant_ids[1]].avg_composite

            if report.is_significant:
                report.winner = variant_ids[0] if avg_a > avg_b else variant_ids[1]
                report.status = "completed"
                report.summary = (
                    f"Winner: {report.winner} "
                    f"(p={report.statistical_p}, "
                    f"{variant_ids[0]}={avg_a:.1f} vs {variant_ids[1]}={avg_b:.1f})"
                )
            else:
                report.status = "completed"
                report.summary = (
                    f"No significant difference (p={report.statistical_p}, "
                    f"threshold={config.significance_threshold})"
                )

    return report


# ---------------------------------------------------------------------------
# Console report
# ---------------------------------------------------------------------------


def print_experiment_report(report: ExperimentReport) -> None:
    """Print experiment results to console."""
    print()
    print(f"{'=' * 50}")
    print(f"  EXPERIMENT: {report.name}")
    print(f"{'=' * 50}")
    print(f"  Skill:      {report.skill}")
    print(f"  Hypothesis: {report.hypothesis}")
    print(f"  Status:     {report.status}")
    print(f"{'─' * 50}")

    for vid, vr in report.variant_results.items():
        marker = " ★" if vid == report.winner else ""
        print(f"  {vid}{marker}: avg={vr.avg_composite:.1f}/100 ({len(vr.scores)} cases)")
        for dim, avg in vr.dimension_avgs.items():
            print(f"    {dim}: {avg:.2f}/5")

    if report.statistical_p is not None:
        print(f"{'─' * 50}")
        print(f"  p-value:  {report.statistical_p}")
        print(f"  Significant: {'YES' if report.is_significant else 'NO'}")
        if report.winner:
            print(f"  Winner: {report.winner}")

    print(f"\n  {report.summary}")
    print(f"{'=' * 50}\n")
