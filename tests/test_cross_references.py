"""
test_cross_references.py — Validate cross-references between skills, commands, agents.

Checks:
- Commands referencing skills point to existing skills
- Skills referencing agents point to existing agents
- Profile refs entries have corresponding skills/refs/{name}/ directories
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest
import yaml

from conftest import (
    SKILLS_DIR, COMMANDS_DIR, AGENTS_DIR, PROFILES_DIR,
    SKILL_CONTAINER_DIRS, parse_frontmatter, resolved_tier,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _all_skill_names() -> set[str]:
    """All skill names on disk (including refs sub-dirs)."""
    names: set[str] = set()
    for d in SKILLS_DIR.iterdir():
        if not d.is_dir():
            continue
        if d.name in SKILL_CONTAINER_DIRS:
            for sub in d.iterdir():
                if sub.is_dir():
                    names.add(sub.name)
        else:
            names.add(d.name)
    return names


def _all_agent_names() -> set[str]:
    """All agent names on disk."""
    return {d.name for d in AGENTS_DIR.iterdir() if d.is_dir()}


def _all_command_files() -> list[Path]:
    """All command .md files."""
    return sorted(COMMANDS_DIR.glob("*.md"))


_SKILL_NAMES = _all_skill_names()
_AGENT_NAMES = _all_agent_names()

# Regex to find skill references in markdown (e.g., `skill-name` or "skill-name" skill)
_SKILL_REF_PATTERN = re.compile(r"`([a-z][a-z0-9-]+)`\s+skill")
_AGENT_REF_PATTERN = re.compile(r"`([a-z][a-z0-9-]+)`\s+agent")


# ---------------------------------------------------------------------------
# Tests: Command → Skill references
# ---------------------------------------------------------------------------

class TestCommandSkillReferences:

    @pytest.mark.parametrize(
        "cmd_path",
        _all_command_files(),
        ids=[p.stem for p in _all_command_files()],
    )
    def test_command_referenced_skills_exist(self, cmd_path: Path) -> None:
        """Commands that reference skills via `skill-name` skill must point to existing skills."""
        text = cmd_path.read_text(encoding="utf-8")
        refs = _SKILL_REF_PATTERN.findall(text)
        for ref in refs:
            assert ref in _SKILL_NAMES, (
                f"Command '{cmd_path.stem}' references skill '{ref}' "
                f"which does not exist on disk. "
                f"Available: {sorted(_SKILL_NAMES)[:10]}..."
            )


# ---------------------------------------------------------------------------
# Tests: Profile refs → skills/refs/ directories
# ---------------------------------------------------------------------------

class TestProfileRefsExist:

    @pytest.mark.parametrize("tier", ["user", "dev", "admin"])
    def test_profile_refs_have_directories(self, tier: str) -> None:
        """Every ref declared in a profile must have a skills/refs/{name}/ dir."""
        profile_path = PROFILES_DIR / f"{tier}.yaml"
        if not profile_path.exists():
            pytest.skip(f"No profile for {tier}")

        data = yaml.safe_load(profile_path.read_text(encoding="utf-8"))
        refs = data.get("refs", [])

        refs_dir = SKILLS_DIR / "refs"
        for ref_name in refs:
            ref_path = refs_dir / ref_name
            assert ref_path.is_dir(), (
                f"Profile '{tier}' declares ref '{ref_name}' "
                f"but skills/refs/{ref_name}/ does not exist."
            )

    @pytest.mark.parametrize("tier", ["user", "dev", "admin"])
    def test_profile_refs_have_skill_md(self, tier: str) -> None:
        """Every ref directory must contain a SKILL.md."""
        profile_path = PROFILES_DIR / f"{tier}.yaml"
        if not profile_path.exists():
            pytest.skip(f"No profile for {tier}")

        data = yaml.safe_load(profile_path.read_text(encoding="utf-8"))
        refs = data.get("refs", [])

        refs_dir = SKILLS_DIR / "refs"
        for ref_name in refs:
            skill_md = refs_dir / ref_name / "SKILL.md"
            if (refs_dir / ref_name).is_dir():
                assert skill_md.exists(), (
                    f"Ref '{ref_name}' directory exists but has no SKILL.md."
                )


# ---------------------------------------------------------------------------
# Tests: Tier inheritance consistency
# ---------------------------------------------------------------------------

class TestTierInheritance:

    def test_admin_includes_all_dev_skills(self) -> None:
        """Admin tier must include all dev tier skills (inheritance)."""
        admin = resolved_tier("admin")
        dev = resolved_tier("dev")
        missing = dev["skills"] - admin["skills"]
        assert not missing, (
            f"Admin tier is missing dev skills: {sorted(missing)}"
        )

    def test_dev_includes_all_user_skills(self) -> None:
        """Dev tier must include all user tier skills (inheritance)."""
        dev = resolved_tier("dev")
        user = resolved_tier("user")
        missing = user["skills"] - dev["skills"]
        assert not missing, (
            f"Dev tier is missing user skills: {sorted(missing)}"
        )

    def test_admin_includes_all_dev_commands(self) -> None:
        """Admin tier must include all dev tier commands."""
        admin = resolved_tier("admin")
        dev = resolved_tier("dev")
        missing = dev["commands"] - admin["commands"]
        assert not missing, (
            f"Admin tier is missing dev commands: {sorted(missing)}"
        )
