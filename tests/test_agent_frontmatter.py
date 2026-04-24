"""
test_agent_frontmatter.py — Structural validation of every AGENT.md.

Agents require: name (kebab-case), description, model (one of opus/sonnet/haiku).
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest

from conftest import AGENTS_DIR, parse_frontmatter

# v6.0.0-alpha.12 (2026-04-23 P1-0): Accept canonical model IDs per schema.
# Schema source of truth: .blueprint/schemas/agent-frontmatter-v6.md
# Includes both shortcuts (opus/sonnet/haiku) AND full IDs with optional [1m] variant suffix.
# Full IDs mandated for Opus 4.7 to avoid silent 256K fallback (user concern #1, Sprint 0 P0-1).
_VALID_MODELS = {
    # Shortcuts (legacy, still accepted)
    "sonnet", "opus", "haiku", "inherit",
    # Canonical full IDs (v6.0+)
    "claude-opus-4-7", "claude-opus-4-7[1m]",
    "claude-sonnet-4-6",
    "claude-haiku-4-5", "claude-haiku-4-5-20251001",
}


def _collect_agent_mds() -> list[Path]:
    paths: list[Path] = []
    for d in sorted(AGENTS_DIR.iterdir()):
        if d.is_dir():
            paths.append(d / "AGENT.md")
    return paths


_ALL_AGENT_MDS = _collect_agent_mds()


def _agent_id(path: Path) -> str:
    return path.parent.name


@pytest.mark.parametrize(
    "agent_md", _ALL_AGENT_MDS, ids=[_agent_id(p) for p in _ALL_AGENT_MDS]
)
class TestAgentFrontmatter:
    """One test class parametrized per AGENT.md file."""

    def test_file_exists(self, agent_md: Path) -> None:
        """AGENT.md must exist in every agent directory."""
        assert agent_md.exists(), f"Missing AGENT.md: {agent_md}"

    def test_file_non_empty(self, agent_md: Path) -> None:
        """AGENT.md must not be empty."""
        assert agent_md.stat().st_size > 0, f"Empty AGENT.md: {agent_md}"

    def test_has_frontmatter(self, agent_md: Path) -> None:
        """AGENT.md must have YAML frontmatter."""
        text = agent_md.read_text(encoding="utf-8")
        assert text.startswith("---"), f"No frontmatter in {agent_md}"
        assert "\n---" in text[3:], f"No closing frontmatter in {agent_md}"

    def test_name_field_exists(self, agent_md: Path) -> None:
        """Frontmatter must contain 'name'."""
        fm = parse_frontmatter(agent_md)
        assert "name" in fm, f"Missing 'name' in {agent_md}"

    def test_name_is_kebab_case(self, agent_md: Path) -> None:
        """Agent name must be kebab-case."""
        fm = parse_frontmatter(agent_md)
        name = fm.get("name", "")
        assert isinstance(name, str) and len(name) > 0
        assert re.match(r"^[a-z][a-z0-9-]*$", name), (
            f"Agent name '{name}' is not kebab-case in {agent_md}"
        )

    def test_name_matches_directory(self, agent_md: Path) -> None:
        """Agent name must match its containing directory name."""
        fm = parse_frontmatter(agent_md)
        name = fm.get("name", "")
        dir_name = agent_md.parent.name
        assert name == dir_name, (
            f"Frontmatter name '{name}' != directory '{dir_name}' in {agent_md}"
        )

    def test_description_field_exists(self, agent_md: Path) -> None:
        """Frontmatter must contain 'description'."""
        fm = parse_frontmatter(agent_md)
        assert "description" in fm, f"Missing 'description' in {agent_md}"

    def test_description_non_empty(self, agent_md: Path) -> None:
        """description must be a non-empty string."""
        fm = parse_frontmatter(agent_md)
        desc = fm.get("description", "")
        assert isinstance(desc, str) and len(desc.strip()) > 0, (
            f"Empty description in {agent_md}"
        )

    def test_model_field_exists(self, agent_md: Path) -> None:
        """Agents must explicitly declare a model."""
        fm = parse_frontmatter(agent_md)
        assert "model" in fm, (
            f"Missing 'model' in {agent_md}. "
            f"Agents must specify model (one of: {_VALID_MODELS})"
        )

    def test_model_field_valid(self, agent_md: Path) -> None:
        """model must be one of the allowed values."""
        fm = parse_frontmatter(agent_md)
        model = fm.get("model", "")
        assert model in _VALID_MODELS, (
            f"Invalid model '{model}' in {agent_md}. Must be one of: {_VALID_MODELS}"
        )

    def test_body_non_empty(self, agent_md: Path) -> None:
        """Body after frontmatter must exist."""
        text = agent_md.read_text(encoding="utf-8")
        end = text.find("\n---", 3)
        body = text[end + 4:].strip() if end != -1 else ""
        assert len(body) > 10, f"Body too short in {agent_md}"
