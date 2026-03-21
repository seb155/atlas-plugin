"""
test_skill_frontmatter.py — Structural integrity of every SKILL.md.

Parametrized over all skills: validates required frontmatter fields,
allowed model values, and absence of broken template references.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest

from conftest import SKILLS_DIR, parse_frontmatter

# ---------------------------------------------------------------------------
# Collect parametrize IDs at module import time (conftest fixtures not yet
# available for parametrize decorators, so we replicate the collection here)
# ---------------------------------------------------------------------------

SKILL_CONTAINER_DIRS = {"refs"}
_VALID_MODELS = {"sonnet", "opus", "haiku", "inherit"}


def _collect_skill_mds() -> list[Path]:
    paths: list[Path] = []
    for d in sorted(SKILLS_DIR.iterdir()):
        if not d.is_dir():
            continue
        if d.name in SKILL_CONTAINER_DIRS:
            for sub in sorted(d.iterdir()):
                if sub.is_dir():
                    paths.append(sub / "SKILL.md")
        else:
            paths.append(d / "SKILL.md")
    return paths


_ALL_SKILL_MDS = _collect_skill_mds()


def _skill_id(path: Path) -> str:
    """Human-readable test ID from SKILL.md path."""
    parts = path.parts
    # e.g.  skills/tdd/SKILL.md  →  tdd
    #        skills/refs/web-design-guidelines/SKILL.md  →  refs/web-design-guidelines
    try:
        idx = list(parts).index("skills")
        return "/".join(parts[idx + 1 : -1])
    except ValueError:
        return path.parent.name


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("skill_md", _ALL_SKILL_MDS, ids=[_skill_id(p) for p in _ALL_SKILL_MDS])
class TestSkillFrontmatter:
    """One test class parametrized per SKILL.md file."""

    def test_file_exists(self, skill_md: Path) -> None:
        """SKILL.md file must exist on disk."""
        assert skill_md.exists(), f"Missing SKILL.md: {skill_md}"

    def test_file_non_empty(self, skill_md: Path) -> None:
        """SKILL.md must not be an empty file."""
        assert skill_md.stat().st_size > 0, f"Empty SKILL.md: {skill_md}"

    def test_has_frontmatter(self, skill_md: Path) -> None:
        """SKILL.md must have YAML frontmatter (--- delimiters)."""
        text = skill_md.read_text(encoding="utf-8")
        assert text.startswith("---"), f"No frontmatter opening '---' in {skill_md}"
        assert "\n---" in text[3:], f"No frontmatter closing '---' in {skill_md}"

    def test_name_field_exists(self, skill_md: Path) -> None:
        """Frontmatter must contain 'name' field."""
        fm = parse_frontmatter(skill_md)
        assert "name" in fm, f"Missing 'name' in frontmatter: {skill_md}"

    def test_name_is_kebab_case(self, skill_md: Path) -> None:
        """name must match kebab-case pattern (lowercase, hyphens allowed)."""
        fm = parse_frontmatter(skill_md)
        name = fm.get("name", "")
        assert isinstance(name, str) and len(name) > 0, f"Empty name in {skill_md}"
        assert re.match(r"^[a-z][a-z0-9-]*$", name), (
            f"name '{name}' is not kebab-case in {skill_md}"
        )

    def test_name_matches_directory(self, skill_md: Path) -> None:
        """
        name in frontmatter should match the containing directory name.

        Exception: skills under refs/ use a 'ref-' prefix convention to avoid
        name collisions (e.g. directory 'composition-patterns' → name 'ref-composition-patterns').
        Both the bare name and the ref-prefixed name are accepted for refs skills.
        """
        fm = parse_frontmatter(skill_md)
        name = fm.get("name", "")
        dir_name = skill_md.parent.name
        # Check if this is a refs skill (parent's parent is refs/)
        is_refs_skill = skill_md.parent.parent.name == "refs"

        if is_refs_skill:
            # Allow either 'dir-name' or 'ref-dir-name'
            accepted = {dir_name, f"ref-{dir_name}"}
            assert name in accepted, (
                f"Refs skill name '{name}' does not match directory '{dir_name}' "
                f"(expected one of: {accepted}) in {skill_md}"
            )
        else:
            assert name == dir_name, (
                f"Frontmatter name '{name}' does not match directory '{dir_name}' in {skill_md}"
            )

    def test_description_field_exists(self, skill_md: Path) -> None:
        """Frontmatter must contain 'description' field."""
        fm = parse_frontmatter(skill_md)
        assert "description" in fm, f"Missing 'description' in frontmatter: {skill_md}"

    def test_description_non_empty(self, skill_md: Path) -> None:
        """description must be a non-empty string."""
        fm = parse_frontmatter(skill_md)
        desc = fm.get("description", "")
        assert isinstance(desc, str) and len(desc.strip()) > 0, (
            f"Empty description in {skill_md}"
        )

    def test_body_non_empty(self, skill_md: Path) -> None:
        """Body content after frontmatter must be non-trivial (> 10 chars)."""
        text = skill_md.read_text(encoding="utf-8")
        # Find end of frontmatter
        end = text.find("\n---", 3)
        body = text[end + 4:].strip() if end != -1 else ""
        assert len(body) > 10, f"Body too short or empty after frontmatter in {skill_md}"

    def test_model_field_valid_if_present(self, skill_md: Path) -> None:
        """If 'model' is present in frontmatter, it must be one of the allowed values."""
        fm = parse_frontmatter(skill_md)
        if "model" not in fm:
            return
        model = fm["model"]
        assert model in _VALID_MODELS, (
            f"Invalid model '{model}' in {skill_md}. Must be one of: {_VALID_MODELS}"
        )

    def test_no_broken_skill_dir_references(self, skill_md: Path) -> None:
        """
        SKILL.md must not contain unresolved '${CLAUDE_SKILL_DIR}' used as a real
        path reference (i.e., as an argument to a command or script).

        Exception: documentation tables that show '${CLAUDE_SKILL_DIR}' as a named
        variable (e.g., '| `${CLAUDE_SKILL_DIR}` | ...') are intentional and allowed.
        """
        text = skill_md.read_text(encoding="utf-8")
        if "${CLAUDE_SKILL_DIR}" not in text:
            return
        # Check each occurrence: if every occurrence is inside a markdown table row
        # (line contains '|'), it's documentation — not a broken reference.
        for line in text.splitlines():
            if "${CLAUDE_SKILL_DIR}" in line:
                # Table row: contains '|' on both sides of the variable
                if "|" in line:
                    continue  # Documentation table — OK
                # Code block or backtick inline (documentation purposes)
                if line.strip().startswith("`") or "``" in line:
                    continue
                pytest.fail(
                    f"Broken template reference '${{CLAUDE_SKILL_DIR}}' "
                    f"used outside a documentation table in {skill_md}:\n"
                    f"  {line.rstrip()}"
                )
