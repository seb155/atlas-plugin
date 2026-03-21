"""
test_command_structure.py — Validates structure of every command .md file.

Rules:
- File must be non-empty
- Must contain at least one H1 heading (# ...)
- H1 that starts with '/' must match the pattern # /command-name or # command-name
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest

from conftest import COMMANDS_DIR


def _collect_command_mds() -> list[Path]:
    return sorted(COMMANDS_DIR.glob("*.md"))


_ALL_COMMAND_MDS = _collect_command_mds()


def _cmd_id(path: Path) -> str:
    return path.stem


@pytest.mark.parametrize(
    "command_md", _ALL_COMMAND_MDS, ids=[_cmd_id(p) for p in _ALL_COMMAND_MDS]
)
class TestCommandStructure:
    """Parametrized over every command .md file."""

    def test_file_exists(self, command_md: Path) -> None:
        """Command file must exist."""
        assert command_md.exists(), f"Command file not found: {command_md}"

    def test_file_non_empty(self, command_md: Path) -> None:
        """Command file must not be empty."""
        assert command_md.stat().st_size > 0, f"Empty command file: {command_md}"

    def test_has_h1_or_invoke_pattern(self, command_md: Path) -> None:
        """
        Command file must either:
        - Contain at least one H1 heading (# /command-name), OR
        - Use the 'Invoke the `skill-name` skill' delegation pattern.

        Both are valid command structures in the ATLAS plugin.
        """
        text = command_md.read_text(encoding="utf-8")
        h1_lines = [line for line in text.splitlines() if line.startswith("# ")]
        has_invoke = "Invoke the `" in text and "skill" in text
        assert len(h1_lines) > 0 or has_invoke, (
            f"No H1 heading or Invoke pattern found in {command_md}. "
            "Commands must either start with '# /command-name' or use "
            "'Invoke the `skill-name` skill with the following arguments: $ARGUMENTS'"
        )

    def test_h1_heading_format(self, command_md: Path) -> None:
        """H1 headings with '/' prefix must follow the /command-name pattern."""
        text = command_md.read_text(encoding="utf-8")
        for line in text.splitlines():
            if not line.startswith("# "):
                continue
            heading = line[2:].strip()
            if heading.startswith("/"):
                # Must be: /word-chars (kebab-case command name, optional args)
                assert re.match(r"^/[a-z][a-zA-Z0-9_-]*", heading), (
                    f"Malformed /command heading '{heading}' in {command_md}"
                )

    def test_minimum_content_length(self, command_md: Path) -> None:
        """Command must have meaningful content (> 20 chars total)."""
        text = command_md.read_text(encoding="utf-8")
        assert len(text.strip()) > 20, f"Content too short in {command_md}"

    def test_no_broken_template_vars(self, command_md: Path) -> None:
        """Must not contain unresolved template variables like ${UNDEFINED}."""
        text = command_md.read_text(encoding="utf-8")
        # Allow known legitimate vars: $ARGUMENTS, $CLAUDE_PLUGIN_ROOT
        known_vars = {"ARGUMENTS", "CLAUDE_PLUGIN_ROOT", "ATLAS_ROLE"}
        broken = re.findall(r"\$\{([A-Z_]+)\}", text)
        unknown = [v for v in broken if v not in known_vars]
        assert not unknown, (
            f"Unknown template vars {unknown} in {command_md}"
        )
