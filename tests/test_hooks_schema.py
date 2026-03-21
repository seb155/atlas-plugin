"""
test_hooks_schema.py — Validates hooks.json schema and referenced scripts.

Checks:
- hooks.json is valid JSON
- Top-level structure has 'hooks' key
- All event types are from the known CC event type set
- All referenced hook scripts exist and are executable
"""

from __future__ import annotations

import json
import os
import stat
from pathlib import Path

import pytest

from conftest import HOOKS_DIR, PLUGIN_ROOT

HOOKS_JSON = HOOKS_DIR / "hooks.json"

# Known Claude Code event types (as of CC 2.x)
KNOWN_EVENT_TYPES = {
    "SessionStart",
    "SessionEnd",
    "PreCompact",
    "PostCompact",
    "PostToolUse",
    "PreToolUse",
    "PermissionRequest",
    "UserPromptSubmit",
    "Stop",
    "SubagentStop",
    "Notification",
}


def _load_hooks_json() -> dict:
    """Load and parse hooks.json, raising on invalid JSON."""
    return json.loads(HOOKS_JSON.read_text(encoding="utf-8"))


def _resolve_hook_command(command: str) -> Path:
    """
    Resolve a hook command string to a real path.
    Commands use: "${CLAUDE_PLUGIN_ROOT}/hooks/script-name"
    """
    resolved = command.strip('"').replace("${CLAUDE_PLUGIN_ROOT}", str(PLUGIN_ROOT))
    return Path(resolved)


# ---------------------------------------------------------------------------
# Schema-level tests
# ---------------------------------------------------------------------------


class TestHooksJsonSchema:
    """Validates the overall hooks.json structure."""

    def test_hooks_json_exists(self) -> None:
        assert HOOKS_JSON.exists(), f"hooks.json not found at {HOOKS_JSON}"

    def test_hooks_json_is_valid_json(self) -> None:
        try:
            data = json.loads(HOOKS_JSON.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            pytest.fail(f"hooks.json is not valid JSON: {exc}")
        assert isinstance(data, dict)

    def test_hooks_json_has_hooks_key(self) -> None:
        data = _load_hooks_json()
        assert "hooks" in data, "hooks.json must have a top-level 'hooks' key"

    def test_hooks_value_is_dict(self) -> None:
        data = _load_hooks_json()
        assert isinstance(data["hooks"], dict), "'hooks' must be a dict of event → config"

    def test_all_event_types_are_known(self) -> None:
        data = _load_hooks_json()
        unknown = set(data["hooks"].keys()) - KNOWN_EVENT_TYPES
        assert not unknown, (
            f"Unknown event types in hooks.json: {unknown}. "
            f"Known types: {KNOWN_EVENT_TYPES}"
        )

    def test_each_event_has_hooks_list(self) -> None:
        data = _load_hooks_json()
        for event, entries in data["hooks"].items():
            assert isinstance(entries, list), (
                f"Event '{event}' must map to a list of hook configs"
            )

    def test_each_hook_entry_has_hooks_list(self) -> None:
        data = _load_hooks_json()
        for event, entries in data["hooks"].items():
            for i, entry in enumerate(entries):
                assert "hooks" in entry, (
                    f"Entry {i} under '{event}' is missing 'hooks' list"
                )
                assert isinstance(entry["hooks"], list), (
                    f"Entry {i} under '{event}'.hooks must be a list"
                )

    def test_each_hook_has_type_field(self) -> None:
        data = _load_hooks_json()
        for event, entries in data["hooks"].items():
            for entry in entries:
                for hook in entry.get("hooks", []):
                    assert "type" in hook or "command" in hook, (
                        f"Hook under '{event}' missing 'type' or 'command': {hook}"
                    )

    def test_command_hooks_have_command_field(self) -> None:
        data = _load_hooks_json()
        for event, entries in data["hooks"].items():
            for entry in entries:
                for hook in entry.get("hooks", []):
                    if hook.get("type") == "command":
                        assert "command" in hook, (
                            f"Hook type=command under '{event}' missing 'command'"
                        )


# ---------------------------------------------------------------------------
# Script existence + executability
# ---------------------------------------------------------------------------

def _collect_referenced_scripts() -> list[tuple[str, Path]]:
    """Return list of (event_name, resolved_script_path) for command-type hooks."""
    if not HOOKS_JSON.exists():
        return []
    data = _load_hooks_json()
    results: list[tuple[str, Path]] = []
    for event, entries in data["hooks"].items():
        for entry in entries:
            for hook in entry.get("hooks", []):
                cmd = hook.get("command", "")
                if "${CLAUDE_PLUGIN_ROOT}" in cmd or cmd.startswith('"'):
                    resolved = _resolve_hook_command(cmd)
                    # Only include if it looks like a real script reference
                    if "/hooks/" in str(resolved):
                        results.append((event, resolved))
    return results


_REFERENCED_SCRIPTS = _collect_referenced_scripts()


@pytest.mark.parametrize(
    "event,script_path",
    _REFERENCED_SCRIPTS,
    ids=[f"{ev}:{p.name}" for ev, p in _REFERENCED_SCRIPTS],
)
class TestHookScripts:
    """Validates each referenced hook script on disk."""

    def test_script_exists(self, event: str, script_path: Path) -> None:
        """Referenced hook script must exist on disk."""
        assert script_path.exists(), (
            f"Hook script referenced by '{event}' not found: {script_path}"
        )

    def test_script_is_executable(self, event: str, script_path: Path) -> None:
        """Referenced hook script must be executable."""
        assert os.access(str(script_path), os.X_OK), (
            f"Hook script '{script_path}' (event: {event}) is not executable. "
            f"Run: chmod +x {script_path}"
        )

    def test_script_has_shebang(self, event: str, script_path: Path) -> None:
        """Hook script must start with a shebang line."""
        if not script_path.exists():
            pytest.skip("Script does not exist (tested separately)")
        first_line = script_path.read_text(encoding="utf-8").splitlines()[0]
        assert first_line.startswith("#!"), (
            f"Script '{script_path.name}' missing shebang line (got: '{first_line}')"
        )


# ---------------------------------------------------------------------------
# Build artifact validation (dist/)
# ---------------------------------------------------------------------------

DIST_DIR = PLUGIN_ROOT / "dist"


def _collect_dist_hook_refs() -> list[tuple[str, str, Path]]:
    """
    Scan each dist/atlas-{tier}/hooks/hooks.json and collect
    (tier, event, resolved_script_path) for command-type hooks.
    """
    if not DIST_DIR.exists():
        return []
    results: list[tuple[str, str, Path]] = []
    for tier_dir in sorted(DIST_DIR.iterdir()):
        if not tier_dir.is_dir():
            continue
        hooks_json = tier_dir / "hooks" / "hooks.json"
        if not hooks_json.exists():
            continue
        data = json.loads(hooks_json.read_text(encoding="utf-8"))
        for event, entries in data.get("hooks", {}).items():
            for entry in entries:
                for hook in entry.get("hooks", []):
                    cmd = hook.get("command", "")
                    if "${CLAUDE_PLUGIN_ROOT}" in cmd:
                        # Resolve against the tier directory (simulates runtime)
                        resolved = cmd.strip('"').replace(
                            "${CLAUDE_PLUGIN_ROOT}", str(tier_dir)
                        )
                        if "/hooks/" in resolved:
                            results.append((tier_dir.name, event, Path(resolved)))
    return results


_DIST_HOOK_REFS = _collect_dist_hook_refs()


@pytest.mark.skipif(not DIST_DIR.exists(), reason="dist/ not built yet")
@pytest.mark.parametrize(
    "tier,event,script_path",
    _DIST_HOOK_REFS,
    ids=[f"{t}:{ev}:{p.name}" for t, ev, p in _DIST_HOOK_REFS],
)
class TestDistHookScripts:
    """Validates hook scripts in built dist/ artifacts (catches cache/build bugs)."""

    def test_dist_script_exists(self, tier: str, event: str, script_path: Path) -> None:
        """Hook script referenced in dist hooks.json must exist in that tier."""
        assert script_path.exists(), (
            f"[{tier}] Hook script referenced by '{event}' not found: {script_path}\n"
            f"The hooks.json references a script that was never created or copied."
        )

    def test_dist_script_is_executable(self, tier: str, event: str, script_path: Path) -> None:
        """Hook script in dist must be executable."""
        if not script_path.exists():
            pytest.skip("Script missing (tested separately)")
        assert os.access(str(script_path), os.X_OK), (
            f"[{tier}] Hook script '{script_path.name}' (event: {event}) is not executable"
        )
