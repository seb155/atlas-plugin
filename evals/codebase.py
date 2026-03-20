"""Codebase evaluation mode — score any repository using configurable rubrics.

Combines auto-discovery with dimension-based scoring. Supports:
- Automated checks (file patterns, coverage, deps)
- LLM-as-Judge for subjective dimensions (architecture, code quality)
- Override via .atlas/eval.yaml
"""

from __future__ import annotations

import logging
from pathlib import Path

import yaml

from .discovery import DiscoveryReport, auto_discover
from .schema import DimensionScore, EvalLevel, EvalScore, Grade
from .scorer import build_eval_score

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Default dimension weights (override via .atlas/eval.yaml)
# ---------------------------------------------------------------------------

DEFAULT_CODEBASE_DIMENSIONS: dict[str, float] = {
    "security": 20,
    "testing": 15,
    "code_quality": 15,
    "architecture": 12,
    "documentation": 10,
    "dependencies": 8,
    "api_surface": 8,
    "observability": 7,
    "performance": 5,
}


# ---------------------------------------------------------------------------
# Dimension scorers
# ---------------------------------------------------------------------------


def _score_security(report: DiscoveryReport) -> DimensionScore:
    """Score security dimension."""
    score = 100.0
    details = []

    if not report.security.has_gitignore:
        score -= 20
        details.append("no .gitignore")

    if report.security.env_files_exposed > 0:
        penalty = min(30, report.security.env_files_exposed * 15)
        score -= penalty
        details.append(f"{report.security.env_files_exposed} exposed .env files")

    if report.security.potential_secrets > 0:
        penalty = min(30, report.security.potential_secrets * 10)
        score -= penalty
        details.append(f"{report.security.potential_secrets} potential secrets detected")

    if report.security.has_secret_scanner:
        score = min(100, score + 5)
        details.append("secret scanner configured")

    if not report.security.dependency_lock:
        score -= 10
        details.append("no dependency lock file")

    if not details:
        details.append("no issues found")

    return DimensionScore(name="security", score=max(0, score), weight=20, details="; ".join(details))


def _score_testing(report: DiscoveryReport) -> DimensionScore:
    """Score testing dimension."""
    score = 100.0
    details = []

    if not report.tests.frameworks:
        score -= 40
        details.append("no test framework detected")
    else:
        details.append(f"frameworks: {', '.join(report.tests.frameworks)}")

    if not report.tests.has_ci:
        score -= 20
        details.append("no CI system")
    else:
        details.append(f"CI: {report.tests.ci_system}")

    if report.tests.coverage_available:
        details.append("coverage reports available")
    else:
        score -= 10
        details.append("no coverage reports")

    return DimensionScore(name="testing", score=max(0, score), weight=15, details="; ".join(details))


def _score_code_quality(report: DiscoveryReport) -> DimensionScore:
    """Score code quality dimension."""
    score = 100.0
    details = []

    # Large files penalty
    large_count = len(report.architecture.large_files)
    if large_count > 0:
        penalty = min(30, large_count * 5)
        score -= penalty
        details.append(f"{large_count} files > 500 lines")

    # Average file size
    if report.architecture.avg_file_lines > 200:
        score -= 15
        details.append(f"avg {report.architecture.avg_file_lines} lines/file (high)")
    elif report.architecture.avg_file_lines > 0:
        details.append(f"avg {report.architecture.avg_file_lines} lines/file")

    if not details:
        details.append("good file sizes")

    return DimensionScore(name="code_quality", score=max(0, score), weight=15, details="; ".join(details))


def _score_architecture(report: DiscoveryReport) -> DimensionScore:
    """Score architecture dimension."""
    score = 100.0
    details = []

    # Module count (more modules = better separation)
    if report.architecture.total_dirs < 3:
        score -= 20
        details.append("few directories (flat structure)")
    else:
        details.append(f"{report.architecture.total_dirs} directories")

    if report.architecture.total_files > 0:
        details.append(f"{report.architecture.total_files} source files")

    return DimensionScore(name="architecture", score=max(0, score), weight=12, details="; ".join(details))


def _score_documentation(report: DiscoveryReport) -> DimensionScore:
    """Score documentation dimension."""
    score = 100.0
    details = []

    if not report.docs.has_readme:
        score -= 30
        details.append("no README")
    else:
        details.append("README present")

    if not report.docs.has_architecture_docs:
        score -= 20
        details.append("no architecture docs")
    else:
        details.append(f"docs in: {', '.join(report.docs.doc_dirs)}")

    if report.docs.has_api_docs:
        details.append("API docs present")
    else:
        score -= 10
        details.append("no API docs")

    if report.docs.has_changelog:
        details.append("CHANGELOG present")

    return DimensionScore(name="documentation", score=max(0, score), weight=10, details="; ".join(details))


def _score_dependencies(report: DiscoveryReport) -> DimensionScore:
    """Score dependencies dimension."""
    score = 100.0
    details = []

    if report.dependencies.total_deps == 0:
        details.append("no dependencies detected")
    else:
        details.append(f"{report.dependencies.total_deps} dependencies")

    if report.dependencies.lock_file:
        details.append(f"lock: {report.dependencies.lock_file}")
    elif report.dependencies.total_deps > 0:
        score -= 20
        details.append("no lock file")

    if report.dependencies.package_manager:
        details.append(f"pm: {report.dependencies.package_manager}")

    return DimensionScore(name="dependencies", score=max(0, score), weight=8, details="; ".join(details))


def _score_api_surface(report: DiscoveryReport) -> DimensionScore:
    """Score API surface dimension."""
    score = 80.0  # Start at 80 — API analysis needs LLM for depth
    details = []

    if report.docs.has_api_docs:
        score += 20
        details.append("API docs present")
    else:
        details.append("no API docs (OpenAPI/Swagger)")

    return DimensionScore(name="api_surface", score=min(100, max(0, score)), weight=8, details="; ".join(details))


def _score_observability(report: DiscoveryReport) -> DimensionScore:
    """Score observability dimension."""
    score = 70.0  # Start at 70 — observability needs deeper analysis
    details = []

    # Check for logging/monitoring patterns in stack
    if report.stack.backend:
        details.append(f"backend: {report.stack.backend}")
    if report.stack.infra:
        details.append(f"infra: {report.stack.infra}")
        score += 10

    if not details:
        details.append("limited observability signals detected")

    return DimensionScore(name="observability", score=min(100, max(0, score)), weight=7, details="; ".join(details))


def _score_performance(report: DiscoveryReport) -> DimensionScore:
    """Score performance dimension."""
    score = 75.0  # Neutral start — performance needs runtime analysis
    details = ["baseline score (no runtime data)"]

    return DimensionScore(name="performance", score=score, weight=5, details="; ".join(details))


# Dimension scorer registry
_DIMENSION_SCORERS = {
    "security": _score_security,
    "testing": _score_testing,
    "code_quality": _score_code_quality,
    "architecture": _score_architecture,
    "documentation": _score_documentation,
    "dependencies": _score_dependencies,
    "api_surface": _score_api_surface,
    "observability": _score_observability,
    "performance": _score_performance,
}


# ---------------------------------------------------------------------------
# Config loading
# ---------------------------------------------------------------------------


def load_codebase_config(repo_path: Path) -> dict:
    """Load .atlas/eval.yaml if it exists, return override config."""
    config_path = repo_path / ".atlas" / "eval.yaml"
    if not config_path.exists():
        return {}
    try:
        data = yaml.safe_load(config_path.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except Exception as e:
        logger.warning("Failed to load %s: %s", config_path, e)
        return {}


# ---------------------------------------------------------------------------
# Main codebase eval
# ---------------------------------------------------------------------------


def evaluate_codebase(
    repo_path: Path,
    config_override: dict | None = None,
    baseline: dict[str, float] | None = None,
) -> list[EvalScore]:
    """Run codebase evaluation on a repository.

    Args:
        repo_path: Path to repository root
        config_override: Optional dimension weight overrides
        baseline: Optional baseline scores for regression detection

    Returns:
        List of EvalScore (one per dimension)
    """
    # Auto-discover
    report = auto_discover(repo_path)

    # Load config (auto-detected defaults + file overrides + param overrides)
    file_config = load_codebase_config(repo_path)
    dimension_weights = dict(DEFAULT_CODEBASE_DIMENSIONS)

    # Apply file config overrides
    if "dimensions" in file_config:
        for dim_name, weight in file_config["dimensions"].items():
            if dim_name in dimension_weights:
                dimension_weights[dim_name] = weight

    # Apply parameter overrides
    if config_override and "dimensions" in config_override:
        for dim_name, weight in config_override["dimensions"].items():
            if dim_name in dimension_weights:
                dimension_weights[dim_name] = weight

    # Score each dimension
    scores: list[EvalScore] = []
    for dim_name, weight in dimension_weights.items():
        scorer = _DIMENSION_SCORERS.get(dim_name)
        if not scorer:
            logger.warning("No scorer for dimension: %s", dim_name)
            continue

        dim_score = scorer(report)
        dim_score.weight = weight  # Apply configured weight

        # Build EvalScore
        baseline_val = baseline.get(dim_name) if baseline else None

        score = build_eval_score(
            item_name=dim_name,
            eval_level=EvalLevel.STRUCTURAL,  # Automated = structural
            dimensions=[dim_score],
            reasoning=dim_score.details,
            baseline_composite=baseline_val,
        )
        scores.append(score)

    return scores
