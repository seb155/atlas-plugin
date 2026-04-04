"""
test_skill_dependencies.py — Validates the skill dependency graph.

Checks:
- All skills referenced in _dependencies.yaml exist as directories
- All dependencies of a skill are available in the same or parent tier
- No circular dependencies

Marked @pytest.mark.skill for selective execution.
"""

from __future__ import annotations

from pathlib import Path

import pytest
import yaml

from conftest import SKILLS_DIR, PROFILES_DIR

DEPS_FILE = SKILLS_DIR / "_dependencies.yaml"


def _load_dependencies() -> dict:
    """Load skill dependency graph from _dependencies.yaml."""
    if not DEPS_FILE.exists():
        return {}
    with open(DEPS_FILE) as f:
        return yaml.safe_load(f) or {}


def _resolve_tier_skills(tier_name: str) -> set[str]:
    """Resolve all skills available in a tier (including inherited)."""
    profile_path = PROFILES_DIR / f"{tier_name}.yaml"
    if not profile_path.exists():
        return set()
    with open(profile_path) as f:
        profile = yaml.safe_load(f) or {}

    skills = set(profile.get("skills", []))

    # Recursively resolve parent tier
    parent = profile.get("inherits")
    if parent:
        skills |= _resolve_tier_skills(parent)

    return skills


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


@pytest.mark.skill
class TestDependencyFile:
    """Validate the dependency file itself."""

    def test_deps_file_exists(self):
        assert DEPS_FILE.exists(), f"Missing {DEPS_FILE}"

    def test_all_skills_exist(self):
        """Every skill named in dependencies must have a directory."""
        deps = _load_dependencies()
        all_skills = set(deps.keys())
        for skill_deps in deps.values():
            all_skills.update(skill_deps)

        missing = []
        for skill in all_skills:
            if not (SKILLS_DIR / skill).is_dir():
                missing.append(skill)

        assert not missing, f"Skills referenced in _dependencies.yaml but missing: {missing}"

    def test_no_self_dependency(self):
        """No skill should depend on itself."""
        deps = _load_dependencies()
        self_deps = [s for s, d in deps.items() if s in d]
        assert not self_deps, f"Skills with self-dependency: {self_deps}"


@pytest.mark.skill
class TestTierSatisfaction:
    """Verify that each tier has all dependencies satisfied."""

    @pytest.fixture(params=["admin", "dev", "user"])
    def tier(self, request):
        return request.param

    def test_dependencies_satisfied_in_tier(self, tier):
        """For each skill in the tier, all its dependencies must also be in the tier."""
        deps = _load_dependencies()
        tier_skills = _resolve_tier_skills(tier)

        unsatisfied = []
        for skill in tier_skills:
            if skill in deps:
                missing = [d for d in deps[skill] if d not in tier_skills]
                if missing:
                    unsatisfied.append(f"{skill} needs {missing}")

        assert not unsatisfied, (
            f"Tier '{tier}' has unsatisfied dependencies:\n"
            + "\n".join(f"  - {u}" for u in unsatisfied)
        )


@pytest.mark.skill
class TestNoCycles:
    """Verify the dependency graph is a DAG (no cycles)."""

    def test_no_circular_dependencies(self):
        deps = _load_dependencies()

        def _has_cycle(node: str, visited: set, path: set) -> str | None:
            if node in path:
                return node
            if node in visited:
                return None
            visited.add(node)
            path.add(node)
            for dep in deps.get(node, []):
                cycle = _has_cycle(dep, visited, path)
                if cycle:
                    return cycle
            path.discard(node)
            return None

        visited: set[str] = set()
        for skill in deps:
            cycle = _has_cycle(skill, visited, set())
            assert cycle is None, f"Circular dependency detected involving: {cycle}"
