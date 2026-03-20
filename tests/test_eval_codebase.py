"""Tests for the codebase evaluation mode — auto-discovery + scoring."""

from __future__ import annotations

from pathlib import Path

import pytest

from conftest import PLUGIN_ROOT

# Use the Synapse repo as a real-world test target
SYNAPSE_ROOT = PLUGIN_ROOT.parent


# ---------------------------------------------------------------------------
# Auto-discovery
# ---------------------------------------------------------------------------


def test_discovery_on_plugin_repo() -> None:
    """Auto-discover the atlas-plugin repo itself."""
    from evals.discovery import auto_discover

    report = auto_discover(PLUGIN_ROOT)

    assert report.repo_path == str(PLUGIN_ROOT.resolve())
    # Plugin repo is Python-based
    assert "python" in report.stack.languages or report.architecture.total_files > 0
    assert report.docs.has_readme
    assert report.security.has_gitignore


def test_discovery_on_synapse_repo() -> None:
    """Auto-discover Synapse if available (full stack repo)."""
    synapse_root = Path("/home/sgagnon/workspace_atlas/projects/atlas/synapse")
    if not synapse_root.is_dir():
        pytest.skip("Synapse repo not found")

    from evals.discovery import auto_discover

    report = auto_discover(synapse_root)

    # Synapse is Python + React
    assert report.stack.backend in ("python-fastapi", "python")
    assert "react" in (report.stack.frontend or "")
    assert report.tests.has_ci
    assert report.docs.has_readme
    assert report.architecture.total_files > 50


# ---------------------------------------------------------------------------
# Codebase scoring
# ---------------------------------------------------------------------------


def test_codebase_eval_on_plugin() -> None:
    """Run codebase eval on the plugin repo."""
    from evals.codebase import evaluate_codebase

    scores = evaluate_codebase(PLUGIN_ROOT)

    # Should have 9 dimension scores
    assert len(scores) == 9

    dim_names = {s.item_name for s in scores}
    expected = {"security", "testing", "code_quality", "architecture", "documentation",
                "dependencies", "api_surface", "observability", "performance"}
    assert dim_names == expected

    # All scores should be reasonable (> 0)
    for score in scores:
        assert score.composite >= 0, f"{score.item_name} has negative score"
        assert score.grade.value in ("A", "B", "C", "D", "F")


def test_codebase_eval_on_synapse() -> None:
    """Run codebase eval on Synapse (full stack project)."""
    synapse_root = Path("/home/sgagnon/workspace_atlas/projects/atlas/synapse")
    if not synapse_root.is_dir():
        pytest.skip("Synapse repo not found")

    from evals.codebase import evaluate_codebase

    scores = evaluate_codebase(synapse_root)

    assert len(scores) == 9

    # Synapse should score well (it's a mature project)
    composites = {s.item_name: s.composite for s in scores}
    assert composites["documentation"] > 50  # Has .blueprint/ + README
    assert composites["testing"] > 50  # Has pytest + vitest + playwright


# ---------------------------------------------------------------------------
# Config override
# ---------------------------------------------------------------------------


def test_codebase_config_override() -> None:
    """Dimension weights should be overridable."""
    from evals.codebase import evaluate_codebase

    # Override security weight to 50%
    scores = evaluate_codebase(
        PLUGIN_ROOT,
        config_override={"dimensions": {"security": 50}},
    )

    security_score = next(s for s in scores if s.item_name == "security")
    # The dimension score itself should have weight 50
    assert security_score.dimensions[0].weight == 50


# ---------------------------------------------------------------------------
# Discovery edge cases
# ---------------------------------------------------------------------------


def test_discovery_nonexistent_raises() -> None:
    """Auto-discover on non-existent path should raise."""
    from evals.discovery import auto_discover

    with pytest.raises(ValueError, match="Not a directory"):
        auto_discover(Path("/nonexistent/path"))


def test_discovery_empty_dir(tmp_path: Path) -> None:
    """Auto-discover on empty dir should return empty report."""
    from evals.discovery import auto_discover

    report = auto_discover(tmp_path)

    assert report.stack.backend == ""
    assert report.stack.frontend == ""
    assert not report.tests.frameworks
    assert not report.docs.has_readme
    assert report.architecture.total_files == 0
