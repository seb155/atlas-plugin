"""Main eval orchestrator — dual-mode (plugin + codebase).

Usage:
    python -m evals.runner --mode plugin --level structural --output /tmp/eval.json
    python -m evals.runner --mode codebase --output /tmp/eval.json
    python -m evals.runner --suite core --level behavioral --output /tmp/eval.json
    python -m evals.runner --baseline --output evals/baselines/v3.2.0.json
"""

from __future__ import annotations

import argparse
import asyncio
import logging
import subprocess
import sys
from pathlib import Path

from .reporter import load_baseline, print_console_report, result_to_dict, save_json
from .schema import (
    EvalCase,
    EvalLevel,
    EvalMode,
    EvalResult,
    EvalScore,
    load_eval_case,
    load_suite,
)
from .scorer import compute_run_aggregates
from .structural import evaluate_skill_structural

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Path resolution
# ---------------------------------------------------------------------------


def _find_plugin_root() -> Path:
    """Find the atlas-plugin root by walking up from this file."""
    current = Path(__file__).parent.parent
    if (current / "skills").is_dir() and (current / "profiles").is_dir():
        return current
    raise FileNotFoundError("Cannot find atlas-plugin root (expected skills/ + profiles/)")


def _get_skills_on_disk(plugin_root: Path) -> set[str]:
    """Collect all skill names from disk."""
    skills_dir = plugin_root / "skills"
    names: set[str] = set()
    for d in skills_dir.iterdir():
        if not d.is_dir():
            continue
        if d.name == "refs":
            for sub in d.iterdir():
                if sub.is_dir():
                    names.add(sub.name)
        else:
            names.add(d.name)
    return names


def _get_skill_md_path(plugin_root: Path, skill_name: str) -> Path:
    """Resolve a skill name to its SKILL.md path."""
    direct = plugin_root / "skills" / skill_name / "SKILL.md"
    if direct.exists():
        return direct
    # Check refs/
    ref = plugin_root / "skills" / "refs" / skill_name / "SKILL.md"
    if ref.exists():
        return ref
    return direct  # Return expected path even if missing


def _get_git_info() -> tuple[str, str]:
    """Get current branch and commit SHA."""
    branch = ""
    sha = ""
    try:
        branch = subprocess.check_output(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
        sha = subprocess.check_output(
            ["git", "rev-parse", "HEAD"],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
    except Exception:
        pass
    return branch, sha


# ---------------------------------------------------------------------------
# Plugin mode runner
# ---------------------------------------------------------------------------


def run_plugin_structural(
    plugin_root: Path,
    skills: list[str] | None = None,
    baseline: dict[str, float] | None = None,
) -> list[EvalScore]:
    """Run structural evals on plugin skills.

    Args:
        plugin_root: Path to atlas-plugin root
        skills: Specific skills to evaluate, or None for all
        baseline: Optional baseline scores for regression detection
    """
    skills_on_disk = _get_skills_on_disk(plugin_root)
    cases_dir = plugin_root / "evals" / "cases"

    # Determine which skills to evaluate
    target_skills = skills if skills else sorted(skills_on_disk)

    scores: list[EvalScore] = []
    for skill_name in target_skills:
        skill_md = _get_skill_md_path(plugin_root, skill_name)

        # Load eval case if available
        case_path = cases_dir / f"{skill_name}.yaml"
        eval_case = load_eval_case(case_path) if case_path.exists() else None

        score = evaluate_skill_structural(
            skill_md_path=skill_md,
            eval_case=eval_case,
            skills_on_disk=skills_on_disk,
        )

        # Apply baseline comparison
        if baseline and skill_name in baseline:
            base_val = baseline[skill_name]
            score.baseline_composite = base_val
            score.delta = round(score.composite - base_val, 1)
            score.is_regression = score.delta < -3.0

        scores.append(score)

    return scores


async def run_plugin_behavioral(
    plugin_root: Path,
    skills: list[str] | None = None,
    judge_model: str = "claude-haiku-4-5-20251001",
    baseline: dict[str, float] | None = None,
) -> list[EvalScore]:
    """Run behavioral evals using LLM-as-Judge.

    Args:
        plugin_root: Path to atlas-plugin root
        skills: Specific skills to evaluate
        judge_model: Model for LLM judge
        baseline: Optional baseline for regression detection
    """
    from .judge import get_rubric_for_type, judge_skill
    from .schema import DimensionScore

    cases_dir = plugin_root / "evals" / "cases"
    golden_dir = plugin_root / "evals" / "golden"
    skills_on_disk = _get_skills_on_disk(plugin_root)

    target_skills = skills if skills else sorted(skills_on_disk)
    scores: list[EvalScore] = []

    for skill_name in target_skills:
        skill_md = _get_skill_md_path(plugin_root, skill_name)
        if not skill_md.exists():
            continue

        skill_body = skill_md.read_text(encoding="utf-8")

        # Load eval case for behavioral cases
        case_path = cases_dir / f"{skill_name}.yaml"
        if not case_path.exists():
            continue

        eval_case = load_eval_case(case_path)
        if not eval_case.behavioral.cases:
            # Also check golden directory
            golden_path = golden_dir / skill_name / "cases.yaml"
            if golden_path.exists():
                golden_data = load_eval_case(golden_path)
                eval_case.behavioral = golden_data.behavioral

        if not eval_case.behavioral.cases:
            continue

        rubric = get_rubric_for_type(eval_case.type.value)

        for bcase in eval_case.behavioral.cases:
            result = await judge_skill(
                skill_name=skill_name,
                skill_type=eval_case.type.value,
                skill_body=skill_body,
                test_input=bcase.input,
                expected_contains=bcase.expected_contains,
                ground_truth=bcase.ground_truth,
                rubric=rubric,
                model=judge_model,
            )

            # Build dimension scores from judge result
            dims = []
            for dim_name in rubric:
                dim_score = result.get(dim_name, 3)
                # Merge rubric overrides
                if bcase.rubric_overrides and dim_name in bcase.rubric_overrides:
                    dim_score = bcase.rubric_overrides[dim_name]
                dims.append(
                    DimensionScore(
                        name=dim_name,
                        score=float(dim_score),
                        weight=100 / len(rubric),  # Equal weight by default
                    )
                )

            from .scorer import build_eval_score

            baseline_key = f"{skill_name}:{bcase.id}"
            baseline_val = baseline.get(baseline_key) if baseline else None

            score = build_eval_score(
                item_name=skill_name,
                eval_level=EvalLevel.BEHAVIORAL,
                dimensions=dims,
                case_id=bcase.id,
                reasoning=result.get("reasoning", ""),
                judge_model=result.get("_judge_model"),
                judge_tokens=result.get("_judge_tokens", 0),
                baseline_composite=baseline_val,
            )
            scores.append(score)

    return scores


# ---------------------------------------------------------------------------
# Main run function
# ---------------------------------------------------------------------------


async def run_eval(
    mode: EvalMode = EvalMode.PLUGIN,
    level: EvalLevel = EvalLevel.FULL,
    suite_name: str = "full",
    skills: list[str] | None = None,
    output: Path | None = None,
    baseline_path: Path | None = None,
    is_baseline: bool = False,
    plugin_root: Path | None = None,
) -> EvalResult:
    """Run a complete evaluation.

    Args:
        mode: plugin or codebase
        level: structural, behavioral, or full
        suite_name: name of the suite to run
        skills: specific skills to evaluate (None = all in suite)
        output: path to save JSON results
        baseline_path: path to baseline JSON for regression detection
        is_baseline: if True, save result as baseline
        plugin_root: override plugin root path
    """
    if plugin_root is None:
        plugin_root = _find_plugin_root()

    # Load suite config
    suite_path = plugin_root / "evals" / "suites" / f"{suite_name}.yaml"
    suite = load_suite(suite_path) if suite_path.exists() else None

    # Resolve skills from suite
    if suite and skills is None and suite.skills != ["*"]:
        skills = suite.skills

    # Load baseline
    baseline: dict[str, float] = {}
    if baseline_path and baseline_path.exists():
        baseline = load_baseline(baseline_path)
    elif not is_baseline:
        # Auto-detect latest baseline
        baselines_dir = plugin_root / "evals" / "baselines"
        if baselines_dir.exists():
            baseline_files = sorted(baselines_dir.glob("*.json"), reverse=True)
            if baseline_files:
                baseline = load_baseline(baseline_files[0])

    # Determine judge model
    judge_model = suite.judge_model if suite else "claude-haiku-4-5-20251001"

    # Run evaluations
    all_scores: list[EvalScore] = []

    if mode == EvalMode.PLUGIN:
        if level in (EvalLevel.STRUCTURAL, EvalLevel.FULL):
            structural_scores = run_plugin_structural(plugin_root, skills, baseline)
            all_scores.extend(structural_scores)

        if level in (EvalLevel.BEHAVIORAL, EvalLevel.FULL):
            behavioral_scores = await run_plugin_behavioral(
                plugin_root, skills, judge_model, baseline
            )
            all_scores.extend(behavioral_scores)

    elif mode == EvalMode.CODEBASE:
        from .codebase import evaluate_codebase

        repo_path = plugin_root  # Default: evaluate current directory
        codebase_scores = evaluate_codebase(repo_path, baseline=baseline)
        all_scores.extend(codebase_scores)

    # Compute aggregates
    branch, sha = _get_git_info()
    version = ""
    version_file = plugin_root / "VERSION"
    if version_file.exists():
        version = version_file.read_text().strip()

    structural_avg, behavioral_avg, composite_avg, grade, regression_count = compute_run_aggregates(all_scores)

    # Collect unique skill names
    item_names = set()
    for s in all_scores:
        item_names.add(s.item_name)

    result = EvalResult(
        mode=mode,
        level=level,
        suite_name=suite_name,
        target_name="atlas-plugin" if mode == EvalMode.PLUGIN else "",
        plugin_version=version,
        branch=branch,
        commit_sha=sha,
        total_items=len(item_names),
        structural_avg=structural_avg,
        behavioral_avg=behavioral_avg,
        composite_avg=composite_avg,
        grade=grade,
        regression_count=regression_count,
        scores=all_scores,
    )

    # Output
    print_console_report(result)

    if output:
        save_json(result, output)
        logger.info("Results saved to %s", output)

    return result


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------


def main() -> None:
    """CLI entry point: python -m evals.runner ..."""
    parser = argparse.ArgumentParser(description="ATLAS Eval Runner")
    parser.add_argument("--mode", choices=["plugin", "codebase"], default="plugin")
    parser.add_argument("--level", choices=["structural", "behavioral", "full"], default="full")
    parser.add_argument("--suite", default="full", help="Suite name (e.g., full, core)")
    parser.add_argument("--skill", action="append", help="Specific skill(s) to evaluate")
    parser.add_argument("--output", "-o", type=Path, help="Output JSON path")
    parser.add_argument("--baseline", action="store_true", help="Save result as baseline")
    parser.add_argument("--compare", type=Path, help="Baseline JSON to compare against")
    parser.add_argument("--experiment", type=Path, help="Run A/B experiment from config YAML")
    parser.add_argument("--plugin-root", type=Path, help="Override plugin root path")
    parser.add_argument("-v", "--verbose", action="store_true")

    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(levelname)s: %(message)s",
    )

    # Experiment mode
    if args.experiment:
        from .experiment import load_experiment_config, print_experiment_report, run_experiment

        config = load_experiment_config(args.experiment)
        root = args.plugin_root or _find_plugin_root()
        report = asyncio.run(run_experiment(config, root))
        print_experiment_report(report)
        if report.status != "completed":
            sys.exit(1)
        return

    result = asyncio.run(
        run_eval(
            mode=EvalMode(args.mode),
            level=EvalLevel(args.level),
            suite_name=args.suite,
            skills=args.skill,
            output=args.output,
            baseline_path=args.compare,
            is_baseline=args.baseline,
            plugin_root=args.plugin_root,
        )
    )

    # Exit with non-zero if grade is below C
    if result.grade.value in ("D", "F"):
        sys.exit(1)


if __name__ == "__main__":
    main()
