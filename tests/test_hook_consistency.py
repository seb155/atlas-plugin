"""
test_hook_consistency.py — Cross-reference validation between hooks.json, profiles, and scripts.

Checks:
- Every executable in hooks/ (except hooks.json, lib/, ts/) is referenced in hooks.json
- Every hook in profile YAML hooks: lists exists as a script in hooks/
- Plugin settings.json does NOT contain a 'hooks' block (hooks belong in hooks.json)
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest
import yaml

from conftest import HOOKS_DIR, PLUGIN_ROOT

HOOKS_JSON = HOOKS_DIR / "hooks.json"
PROFILES_DIR = PLUGIN_ROOT / "profiles"

# CLI helpers: scripts in hooks/ that are invoked on-demand by skills (not by CC events).
# These are intentionally NOT registered in hooks.json as they don't respond to any event.
# v6.0.0-alpha.12: added autonomy-gate.sh (Phase 5 Approved-Mode helper).
# v6.1.0: added atlas-lock-acquire/release (invoked from scripts/atlas-modules/session.sh)
CLI_HELPERS = {
    "run-hook.sh", "autonomy-gate.sh",
    "atlas-lock-acquire", "atlas-lock-release",
    "ci-audit-log",  # v6.1.0 — invoked from workflows, not CC events
}

# Directories/files to skip when scanning hooks/
SKIP_NAMES = {"hooks.json", "lib", "ts", "__pycache__"} | CLI_HELPERS


def _load_hooks_json() -> dict:
    return json.loads(HOOKS_JSON.read_text(encoding="utf-8"))


def _extract_script_names_from_hooks_json() -> set[str]:
    """Extract all script basenames referenced in hooks.json commands."""
    data = _load_hooks_json()
    names: set[str] = set()
    for entries in data["hooks"].values():
        for entry in entries:
            for hook in entry.get("hooks", []):
                cmd = hook.get("command", "")
                if "${CLAUDE_PLUGIN_ROOT}/hooks/" in cmd:
                    # Handle: "${CLAUDE_PLUGIN_ROOT}/hooks/script-name" arg1
                    parts = cmd.split('" ')
                    script_part = parts[0].strip('"')
                    name = script_part.split("/hooks/")[-1]
                    names.add(name)
                # Handle run-hook.sh subcommands
                if "run-hook.sh" in cmd:
                    parts = cmd.split('" ')
                    if len(parts) > 1:
                        subcommand = parts[1].strip()
                        names.add(f"run-hook.sh:{subcommand}")
    return names


def _get_hook_scripts_on_disk() -> set[str]:
    """Get all executable scripts in hooks/ (excluding skipped names)."""
    scripts: set[str] = set()
    for item in HOOKS_DIR.iterdir():
        if item.name in SKIP_NAMES:
            continue
        if item.is_dir():
            # Support directory-based hooks (e.g., ci-auto-monitor/handler.sh)
            if (item / "handler.sh").exists():
                scripts.add(item.name)
            continue
        if item.is_file():
            scripts.add(item.name)
    return scripts


def _extract_run_hook_subcommands() -> set[str]:
    """Extract subcommand names invoked via run-hook.sh."""
    data = _load_hooks_json()
    subs: set[str] = set()
    for entries in data["hooks"].values():
        for entry in entries:
            for hook in entry.get("hooks", []):
                cmd = hook.get("command", "")
                if "run-hook.sh" in cmd:
                    parts = cmd.split('" ')
                    if len(parts) > 1:
                        subs.add(parts[1].strip())
    return subs


def _get_profile_hook_lists() -> dict[str, list[str]]:
    """Read all profile YAMLs and return {tier: [hook_names]}."""
    result: dict[str, list[str]] = {}
    for profile in sorted(PROFILES_DIR.glob("*.yaml")):
        data = yaml.safe_load(profile.read_text())
        if data and "hooks" in data:
            result[profile.stem] = data["hooks"]
    return result


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


class TestHookConsistency:

    def test_all_scripts_referenced_in_hooks_json(self) -> None:
        """Every script in hooks/ should be referenced in hooks.json (no orphans)."""
        on_disk = _get_hook_scripts_on_disk()
        in_json = _extract_script_names_from_hooks_json()

        orphans = on_disk - in_json
        # Directory-based hooks (e.g. ci-auto-monitor/) are registered via profile YAML,
        # not hooks.json — exclude them from orphan check
        dir_hooks = {d.name for d in HOOKS_DIR.iterdir() if d.is_dir() and d.name not in ("lib", "ts")}
        orphans -= dir_hooks
        assert not orphans, (
            f"Orphaned hook scripts (on disk but not in hooks.json): {orphans}\n"
            f"These scripts should either be referenced in hooks.json or removed."
        )

    def test_all_profile_hooks_exist_on_disk_or_as_subcommand(self) -> None:
        """Every hook in profile YAML hooks: must exist as script OR run-hook.sh subcommand."""
        profiles = _get_profile_hook_lists()
        on_disk = _get_hook_scripts_on_disk()
        # Also collect run-hook.sh subcommands from hooks.json
        run_hook_subs = _extract_run_hook_subcommands()

        for tier, hooks in profiles.items():
            for hook_name in hooks:
                exists_as_script = hook_name in on_disk
                exists_as_subcommand = hook_name in run_hook_subs
                assert exists_as_script or exists_as_subcommand, (
                    f"Profile '{tier}' references hook '{hook_name}' "
                    f"but not found as script in hooks/ or as run-hook.sh subcommand"
                )

    def test_plugin_settings_has_no_hooks_block(self) -> None:
        """Plugin settings.json must NOT contain 'hooks' — they belong in hooks.json."""
        settings_path = PLUGIN_ROOT / "settings.json"
        if not settings_path.exists():
            pytest.skip("No settings.json in plugin root")
        data = json.loads(settings_path.read_text())
        assert "hooks" not in data, (
            "Plugin settings.json contains a 'hooks' block. "
            "Hooks must be defined in hooks/hooks.json, not in settings.json."
        )

    def test_hooks_json_scripts_exist_on_disk(self) -> None:
        """Every script referenced in hooks.json must exist in hooks/."""
        data = _load_hooks_json()
        missing: list[str] = []
        for event, entries in data["hooks"].items():
            for entry in entries:
                for hook in entry.get("hooks", []):
                    cmd = hook.get("command", "")
                    if "${CLAUDE_PLUGIN_ROOT}/hooks/" in cmd and "run-hook.sh" not in cmd:
                        parts = cmd.split('" ')
                        script_part = parts[0].strip('"')
                        name = script_part.split("/hooks/")[-1]
                        script_path = HOOKS_DIR / name
                        if not script_path.exists():
                            missing.append(f"{event}: {name}")
        assert not missing, (
            f"hooks.json references scripts that don't exist: {missing}"
        )
