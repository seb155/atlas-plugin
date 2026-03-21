"""
test_no_hardcoded_paths.py — Compliance: no absolute user paths in hook scripts.

Rules:
- No /home/<user> hardcoded in hook scripts (use ${HOME} instead)
- No /Users/<user> (macOS paths) hardcoded
- No hardcoded machine-specific paths (/var/lib/..., /opt/specific/...)
- ${CLAUDE_PLUGIN_ROOT} must be used for plugin-relative paths
- ${HOME} is the correct idiom for user home references

Allowed patterns:
- ${HOME}/...
- ${CLAUDE_PLUGIN_ROOT}/...
- Relative paths (./scripts/...)
- /tmp (not user-specific)
- /usr/bin, /usr/local (system paths)
- /etc (system config)
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest

from conftest import HOOKS_DIR, PLUGIN_ROOT

# Patterns that indicate hardcoded user-specific paths
HARDCODED_HOME_PATTERNS = [
    re.compile(r"/home/[a-zA-Z][a-zA-Z0-9_-]+/"),  # /home/username/
    re.compile(r"/Users/[a-zA-Z][a-zA-Z0-9_-]+/"),  # /Users/username/ (macOS)
    re.compile(r"/root/(?!\.claude)"),               # /root/ (except /root/.claude which is ok)
]

# Allowed exceptions that look like home paths but are not
ALLOWED_EXCEPTIONS = [
    "${HOME}",
    "$HOME",
    "# /home/",   # comments
    "# /Users/",  # comments
]


def _collect_hook_scripts() -> list[Path]:
    """All executable scripts in hooks/ (excluding hooks.json)."""
    scripts: list[Path] = []
    for path in sorted(HOOKS_DIR.iterdir()):
        if path.is_file() and not path.suffix and path.name != "hooks.json":
            scripts.append(path)
    return scripts


_ALL_HOOK_SCRIPTS = _collect_hook_scripts()


def _collect_shell_scripts() -> list[Path]:
    """All .sh scripts in scripts/ directory."""
    scripts_dir = PLUGIN_ROOT / "scripts"
    if not scripts_dir.exists():
        return []
    return sorted(scripts_dir.glob("*.sh"))


_ALL_SHELL_SCRIPTS = _collect_shell_scripts()
_ALL_SCRIPTS = _ALL_HOOK_SCRIPTS + _ALL_SHELL_SCRIPTS


# ---------------------------------------------------------------------------
# Hardcoded home path tests
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "script_path",
    _ALL_SCRIPTS,
    ids=[p.name for p in _ALL_SCRIPTS],
)
class TestNoHardcodedPaths:

    def test_no_hardcoded_home_path(self, script_path: Path) -> None:
        """Script must not contain hardcoded /home/<user> paths."""
        if not script_path.exists():
            pytest.skip(f"Script not found: {script_path}")
        text = script_path.read_text(encoding="utf-8")
        lines = text.splitlines()

        violations: list[str] = []
        for lineno, line in enumerate(lines, start=1):
            # Skip comment lines
            stripped = line.strip()
            if stripped.startswith("#"):
                continue
            for pattern in HARDCODED_HOME_PATTERNS:
                if pattern.search(line):
                    # Check if it's an allowed exception
                    if not any(exc in line for exc in ALLOWED_EXCEPTIONS):
                        violations.append(f"  Line {lineno}: {line.rstrip()}")

        assert not violations, (
            f"Hardcoded user paths found in {script_path.name}:\n"
            + "\n".join(violations)
            + "\n\nUse ${{HOME}} or ${{CLAUDE_PLUGIN_ROOT}} instead."
        )

    def test_uses_claude_plugin_root_for_plugin_paths(self, script_path: Path) -> None:
        """
        If script references plugin-internal paths, it must use ${CLAUDE_PLUGIN_ROOT}.
        Checks that absolute paths to the plugin are not hardcoded.
        """
        if not script_path.exists():
            pytest.skip(f"Script not found: {script_path}")
        text = script_path.read_text(encoding="utf-8")
        lines = text.splitlines()

        # Look for absolute paths that contain typical plugin dir names
        # (skills/, commands/, agents/, hooks/) but are NOT using variables
        plugin_path_pattern = re.compile(
            r"/(?:atlas-plugin|synapse/atlas-plugin)/(?:skills|commands|agents|hooks)/"
        )
        violations: list[str] = []
        for lineno, line in enumerate(lines, start=1):
            stripped = line.strip()
            if stripped.startswith("#"):
                continue
            if plugin_path_pattern.search(line):
                # OK if it's preceded by a variable expansion
                if "${CLAUDE_PLUGIN_ROOT}" not in line and "$PLUGIN_ROOT" not in line:
                    violations.append(f"  Line {lineno}: {line.rstrip()}")
        assert not violations, (
            f"Hardcoded plugin paths in {script_path.name}:\n"
            + "\n".join(violations)
            + "\nUse ${{CLAUDE_PLUGIN_ROOT}}/skills/... instead."
        )

    def test_no_hardcoded_macos_paths(self, script_path: Path) -> None:
        """Script must not contain macOS-specific /Users/ paths."""
        if not script_path.exists():
            pytest.skip(f"Script not found: {script_path}")
        text = script_path.read_text(encoding="utf-8")
        lines = text.splitlines()

        for lineno, line in enumerate(lines, start=1):
            stripped = line.strip()
            if stripped.startswith("#"):
                continue
            if re.search(r"/Users/[a-zA-Z][a-zA-Z0-9_-]+/", line):
                if "${HOME}" not in line and "$HOME" not in line:
                    pytest.fail(
                        f"macOS hardcoded path at line {lineno} in {script_path.name}: "
                        f"{line.rstrip()}"
                    )


# ---------------------------------------------------------------------------
# Positive compliance: expected variable usage
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "script_path",
    _ALL_HOOK_SCRIPTS,
    ids=[p.name for p in _ALL_HOOK_SCRIPTS],
)
class TestVariableCompliance:

    def test_plugin_root_variable_set_or_used(self, script_path: Path) -> None:
        """
        Hook scripts that reference CLAUDE_PLUGIN_ROOT should set a default.
        Pattern: PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-...}"
        """
        if not script_path.exists():
            pytest.skip()
        text = script_path.read_text(encoding="utf-8")

        if "CLAUDE_PLUGIN_ROOT" not in text:
            # Script doesn't need it — skip
            return

        # If it uses the var, there should be a safe default expansion
        has_safe_default = (
            "${CLAUDE_PLUGIN_ROOT:-" in text
            or "PLUGIN_ROOT=" in text
        )
        assert has_safe_default, (
            f"{script_path.name} uses CLAUDE_PLUGIN_ROOT but has no fallback default.\n"
            "Use: PLUGIN_ROOT=\"${{CLAUDE_PLUGIN_ROOT:-$(cd ...)}}\" "
        )
