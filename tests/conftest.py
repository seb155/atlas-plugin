"""
Shared fixtures for ATLAS Plugin test suite.
All paths are resolved from PLUGIN_ROOT so tests are portable.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

import pytest
import yaml


# ---------------------------------------------------------------------------
# Root resolution
# ---------------------------------------------------------------------------

PLUGIN_ROOT = Path(__file__).parent.parent
SKILLS_DIR = PLUGIN_ROOT / "skills"
COMMANDS_DIR = PLUGIN_ROOT / "commands"
AGENTS_DIR = PLUGIN_ROOT / "agents"
HOOKS_DIR = PLUGIN_ROOT / "hooks"
PROFILES_DIR = PLUGIN_ROOT / "profiles"
MANIFEST_PATH = PLUGIN_ROOT / ".claude-plugin" / "plugin.json"
MARKETPLACE_PATH = PLUGIN_ROOT / ".claude-plugin" / "marketplace.json"
VERSION_FILE = PLUGIN_ROOT / "VERSION"

# Directories inside skills/ that are reference collections, not standalone skills.
# Each sub-dir inside refs/ IS a skill (has SKILL.md), but refs/ itself is just a container.
SKILL_CONTAINER_DIRS = {"refs"}


# ---------------------------------------------------------------------------
# Core path fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(scope="session")
def plugin_root() -> Path:
    """Absolute path to the atlas-plugin root directory."""
    assert PLUGIN_ROOT.is_dir(), f"Plugin root not found: {PLUGIN_ROOT}"
    return PLUGIN_ROOT


@pytest.fixture(scope="session")
def all_skill_dirs() -> list[Path]:
    """
    All skill directories (each must contain SKILL.md).
    Expands refs/* sub-dirs; excludes the refs/ container itself.
    """
    dirs: list[Path] = []
    for d in sorted(SKILLS_DIR.iterdir()):
        if not d.is_dir():
            continue
        if d.name in SKILL_CONTAINER_DIRS:
            # Expand sub-dirs
            for sub in sorted(d.iterdir()):
                if sub.is_dir():
                    dirs.append(sub)
        else:
            dirs.append(d)
    return dirs


@pytest.fixture(scope="session")
def all_skill_mds(all_skill_dirs: list[Path]) -> list[Path]:
    """All SKILL.md file paths."""
    return [d / "SKILL.md" for d in all_skill_dirs]


@pytest.fixture(scope="session")
def all_command_mds() -> list[Path]:
    """All command .md file paths."""
    return sorted(COMMANDS_DIR.glob("*.md"))


@pytest.fixture(scope="session")
def all_agent_mds() -> list[Path]:
    """All AGENT.md file paths (one per agent sub-directory)."""
    paths: list[Path] = []
    for d in sorted(AGENTS_DIR.iterdir()):
        if d.is_dir():
            agent_md = d / "AGENT.md"
            paths.append(agent_md)
    return paths


@pytest.fixture(scope="session")
def profiles() -> dict[str, dict[str, Any]]:
    """Dict of tier → parsed YAML profile."""
    result: dict[str, dict[str, Any]] = {}
    for path in sorted(PROFILES_DIR.glob("*.yaml")):
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
        tier = data.get("tier", path.stem)
        result[tier] = data
    return result


# ---------------------------------------------------------------------------
# Helper functions (available as fixtures for parametrized tests)
# ---------------------------------------------------------------------------


def parse_frontmatter(path: Path) -> dict[str, Any]:
    """
    Extract YAML frontmatter (between opening and closing ---) from a .md file.
    Returns empty dict if no frontmatter is found.
    """
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---"):
        return {}
    # Find closing ---
    end = text.find("\n---", 3)
    if end == -1:
        return {}
    fm_text = text[3:end].strip()
    data = yaml.safe_load(fm_text)
    return data if isinstance(data, dict) else {}


@pytest.fixture(scope="session")
def parse_frontmatter_fn():
    """Fixture that exposes parse_frontmatter as a callable."""
    return parse_frontmatter


def resolved_tier(tier: str) -> dict[str, set[str]]:
    """
    Recursively resolve profile inheritance and return combined
    skills, commands, and agents for a given tier.
    """
    profile_path = PROFILES_DIR / f"{tier}.yaml"
    if not profile_path.exists():
        return {"skills": set(), "commands": set(), "agents": set()}

    data = yaml.safe_load(profile_path.read_text(encoding="utf-8"))

    # Base from parent (if inherits)
    parent = data.get("inherits")
    if parent:
        base = resolved_tier(parent)
    else:
        base = {"skills": set(), "commands": set(), "agents": set()}

    combined: dict[str, set[str]] = {
        "skills": base["skills"] | set(data.get("skills", [])),
        "commands": base["commands"] | set(data.get("commands", [])),
        "agents": base["agents"] | set(data.get("agents", [])),
    }
    return combined


@pytest.fixture(scope="session")
def resolved_tier_fn():
    """Fixture that exposes resolved_tier as a callable."""
    return resolved_tier


# ---------------------------------------------------------------------------
# Disk-level skill name sets (used by profile validation)
# ---------------------------------------------------------------------------


@pytest.fixture(scope="session")
def skills_on_disk() -> set[str]:
    """
    All skill names available on disk (including refs/* sub-dirs).
    Name = directory name (not path).
    """
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


@pytest.fixture(scope="session")
def commands_on_disk() -> set[str]:
    """All command names on disk (stem of .md files in commands/)."""
    return {p.stem for p in COMMANDS_DIR.glob("*.md")}
