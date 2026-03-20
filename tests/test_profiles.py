"""
test_profiles.py — Profile YAML integrity and inheritance chain validation.

Validates:
- Each profile has required fields: tier, skills, commands
- All skill names resolve to directories on disk
- All command names resolve to .md files in commands/
- Inheritance chain: dev inherits user, admin inherits dev
- Resolved (merged) tiers contain all expected items
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import pytest
import yaml

from conftest import (
    PROFILES_DIR,
    SKILLS_DIR,
    COMMANDS_DIR,
    AGENTS_DIR,
    SKILL_CONTAINER_DIRS,
    resolved_tier,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _load_profile(tier: str) -> dict[str, Any]:
    path = PROFILES_DIR / f"{tier}.yaml"
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def _skills_on_disk() -> set[str]:
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


def _commands_on_disk() -> set[str]:
    return {p.stem for p in COMMANDS_DIR.glob("*.md")}


def _agents_on_disk() -> set[str]:
    return {d.name for d in AGENTS_DIR.iterdir() if d.is_dir()}


SKILLS_ON_DISK = _skills_on_disk()
COMMANDS_ON_DISK = _commands_on_disk()
AGENTS_ON_DISK = _agents_on_disk()
KNOWN_TIERS = ["user", "dev", "admin"]


# ---------------------------------------------------------------------------
# Per-profile required field tests
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("tier", KNOWN_TIERS)
class TestProfileRequiredFields:

    def test_profile_file_exists(self, tier: str) -> None:
        path = PROFILES_DIR / f"{tier}.yaml"
        assert path.exists(), f"Profile not found: {path}"

    def test_tier_field_matches_filename(self, tier: str) -> None:
        data = _load_profile(tier)
        assert "tier" in data, f"Missing 'tier' field in {tier}.yaml"
        assert data["tier"] == tier, (
            f"tier field '{data['tier']}' does not match filename '{tier}'"
        )

    def test_has_skills_list(self, tier: str) -> None:
        data = _load_profile(tier)
        assert "skills" in data, f"Missing 'skills' in {tier}.yaml"
        assert isinstance(data["skills"], list), f"'skills' must be a list in {tier}.yaml"

    def test_has_commands_list(self, tier: str) -> None:
        data = _load_profile(tier)
        assert "commands" in data, f"Missing 'commands' in {tier}.yaml"
        assert isinstance(data["commands"], list), f"'commands' must be a list in {tier}.yaml"

    def test_has_description(self, tier: str) -> None:
        data = _load_profile(tier)
        assert "description" in data, f"Missing 'description' in {tier}.yaml"
        assert isinstance(data["description"], str) and data["description"].strip()

    def test_has_persona(self, tier: str) -> None:
        data = _load_profile(tier)
        assert "persona" in data, f"Missing 'persona' in {tier}.yaml"

    def test_has_pipeline(self, tier: str) -> None:
        data = _load_profile(tier)
        assert "pipeline" in data, f"Missing 'pipeline' in {tier}.yaml"


# ---------------------------------------------------------------------------
# Skill / command resolution tests (own tier only, not inherited)
# ---------------------------------------------------------------------------


def _collect_skill_params() -> list[tuple[str, str]]:
    """All (tier, skill_name) pairs from tier-own skill lists."""
    params = []
    for tier in KNOWN_TIERS:
        data = _load_profile(tier)
        for skill in data.get("skills", []):
            params.append((tier, skill))
    return params


def _collect_command_params() -> list[tuple[str, str]]:
    params = []
    for tier in KNOWN_TIERS:
        data = _load_profile(tier)
        for cmd in data.get("commands", []):
            params.append((tier, cmd))
    return params


def _collect_agent_params() -> list[tuple[str, str]]:
    params = []
    for tier in KNOWN_TIERS:
        data = _load_profile(tier)
        for agent in data.get("agents", []):
            params.append((tier, agent))
    return params


_SKILL_PARAMS = _collect_skill_params()
_COMMAND_PARAMS = _collect_command_params()
_AGENT_PARAMS = _collect_agent_params()


@pytest.mark.parametrize(
    "tier,skill_name",
    _SKILL_PARAMS,
    ids=[f"{t}/{s}" for t, s in _SKILL_PARAMS],
)
def test_profile_skill_exists_on_disk(tier: str, skill_name: str) -> None:
    """Every skill declared in a profile must have a directory on disk."""
    assert skill_name in SKILLS_ON_DISK, (
        f"Profile '{tier}' references skill '{skill_name}' "
        f"but it was not found under skills/"
    )


@pytest.mark.parametrize(
    "tier,cmd_name",
    _COMMAND_PARAMS,
    ids=[f"{t}/{c}" for t, c in _COMMAND_PARAMS],
)
def test_profile_command_exists_on_disk(tier: str, cmd_name: str) -> None:
    """Every command declared in a profile must have a .md file in commands/."""
    assert cmd_name in COMMANDS_ON_DISK, (
        f"Profile '{tier}' references command '{cmd_name}' "
        f"but commands/{cmd_name}.md does not exist"
    )


# Agents declared in profiles but not yet implemented (WIP).
# These are planned agents awaiting implementation — not a structural error.
# When an agent is implemented, remove it from this set so the test gate it.
_WIP_AGENTS: set[str] = set()  # All agents now implemented (synced from dev-plugin v3.1.0)


@pytest.mark.parametrize(
    "tier,agent_name",
    _AGENT_PARAMS,
    ids=[f"{t}/{a}" for t, a in _AGENT_PARAMS],
)
def test_profile_agent_exists_on_disk(tier: str, agent_name: str) -> None:
    """Every agent declared in a profile must have a directory in agents/."""
    if agent_name in _WIP_AGENTS:
        pytest.xfail(
            f"Agent '{agent_name}' is declared in '{tier}' profile "
            f"but not yet implemented (WIP). "
            f"Remove from _WIP_AGENTS when agents/{agent_name}/ is created."
        )
    assert agent_name in AGENTS_ON_DISK, (
        f"Profile '{tier}' references agent '{agent_name}' "
        f"but agents/{agent_name}/ does not exist"
    )


# ---------------------------------------------------------------------------
# Inheritance chain tests
# ---------------------------------------------------------------------------


class TestProfileInheritance:

    def test_dev_inherits_user(self) -> None:
        data = _load_profile("dev")
        assert data.get("inherits") == "user", (
            f"dev profile must declare 'inherits: user', got: {data.get('inherits')}"
        )

    def test_admin_inherits_dev(self) -> None:
        data = _load_profile("admin")
        assert data.get("inherits") == "dev", (
            f"admin profile must declare 'inherits: dev', got: {data.get('inherits')}"
        )

    def test_user_has_no_inherits(self) -> None:
        data = _load_profile("user")
        # user is the base tier
        assert "inherits" not in data or data.get("inherits") is None, (
            "user profile should not inherit from any other tier"
        )

    def test_resolved_dev_contains_user_skills(self) -> None:
        user_data = _load_profile("user")
        resolved = resolved_tier("dev")
        for skill in user_data.get("skills", []):
            assert skill in resolved["skills"], (
                f"Resolved dev tier missing user skill '{skill}'"
            )

    def test_resolved_dev_contains_user_commands(self) -> None:
        user_data = _load_profile("user")
        resolved = resolved_tier("dev")
        for cmd in user_data.get("commands", []):
            assert cmd in resolved["commands"], (
                f"Resolved dev tier missing user command '{cmd}'"
            )

    def test_resolved_admin_contains_dev_skills(self) -> None:
        dev_data = _load_profile("dev")
        resolved = resolved_tier("admin")
        for skill in dev_data.get("skills", []):
            assert skill in resolved["skills"], (
                f"Resolved admin tier missing dev skill '{skill}'"
            )

    def test_resolved_admin_contains_user_skills(self) -> None:
        user_data = _load_profile("user")
        resolved = resolved_tier("admin")
        for skill in user_data.get("skills", []):
            assert skill in resolved["skills"], (
                f"Resolved admin tier missing user skill '{skill}'"
            )

    def test_resolved_admin_contains_all_commands(self) -> None:
        """Admin should have the broadest command set (superset of dev and user)."""
        dev_resolved = resolved_tier("dev")
        admin_resolved = resolved_tier("admin")
        missing = dev_resolved["commands"] - admin_resolved["commands"]
        assert not missing, (
            f"Admin resolved tier is missing commands from dev: {missing}"
        )

    def test_no_duplicate_skills_in_profile_lists(self) -> None:
        """Each profile's own skill list should have no duplicates."""
        for tier in KNOWN_TIERS:
            data = _load_profile(tier)
            skills = data.get("skills", [])
            assert len(skills) == len(set(skills)), (
                f"Duplicate skills in {tier}.yaml: "
                f"{[s for s in skills if skills.count(s) > 1]}"
            )

    def test_no_duplicate_commands_in_profile_lists(self) -> None:
        """Each profile's own command list should have no duplicates."""
        for tier in KNOWN_TIERS:
            data = _load_profile(tier)
            commands = data.get("commands", [])
            assert len(commands) == len(set(commands)), (
                f"Duplicate commands in {tier}.yaml"
            )
