"""Regression test: hooks.json entries must be declared in profiles/*.yaml.

Prevents the v5.6.1 silent-drop bug where hooks registered in hooks.json
but not declared in a profile's `hooks:` array get filtered out by
filter-hooks-json.py during dist build.

Lesson: feedback_profile_yaml_hook_declaration.md (2026-04-13 PM-6).
"""
from __future__ import annotations

import json
import re
from pathlib import Path

import pytest
import yaml


PLUGIN_ROOT = Path(__file__).resolve().parent.parent
HOOKS_JSON = PLUGIN_ROOT / "hooks" / "hooks.json"
PROFILES_DIR = PLUGIN_ROOT / "profiles"

# Known tech-debt baseline: hooks present in hooks.json but not declared in
# any profile YAML (getting silently dropped by filter-hooks-json.py).
# To be fixed in Phase 6 of v5.7.0 (code quality SOTA).
# New hooks added AFTER v5.7.0 MUST be declared in a profile or this test fails.
KNOWN_UNDECLARED_BASELINE: set[str] = {
    "tdd-guard",
    "task-created-log",
    "run-hook",
    "claudemd-lint",
    "context-budget-guardian",
    "session-replay-logger",
    "session-state-writer",
    "detect-stale-git",
    "atlas-status-writer",
    "feature-drift-detector",
}


def _extract_hook_script_names_from_hooks_json() -> set[str]:
    """Read hooks.json and extract all hook script names referenced in commands.

    Returns set of script base names (no path, no extension).
    Skips inline commands and run-hook.sh wrapper subcommands.
    """
    data = json.loads(HOOKS_JSON.read_text())
    scripts: set[str] = set()
    for _event, matchers in data.get("hooks", {}).items():
        for matcher in matchers:
            for entry in matcher.get("hooks", []):
                cmd = entry.get("command", "")
                # Direct hook: "${CLAUDE_PLUGIN_ROOT}/hooks/<name>"
                m = re.search(r'/hooks/([\w-]+)', cmd)
                if m:
                    scripts.add(m.group(1))
    # Filter out the wrapper itself + shell primitives
    scripts.discard("run-hook.sh")
    return scripts


def _extract_declared_hooks_from_profile(profile_path: Path) -> set[str]:
    """Read a profile YAML and return set of declared hook names."""
    data = yaml.safe_load(profile_path.read_text())
    return set(data.get("hooks", []) or [])


@pytest.fixture
def all_declared_hooks() -> set[str]:
    """Union of hooks declared across all profile YAMLs."""
    declared: set[str] = set()
    for profile in PROFILES_DIR.glob("*.yaml"):
        declared |= _extract_declared_hooks_from_profile(profile)
    return declared


def test_all_hooks_json_scripts_declared_in_some_profile(all_declared_hooks):
    """Every hook referenced in hooks.json must appear in at least one profile.

    Exception: KNOWN_UNDECLARED_BASELINE for pre-v5.7.0 tech debt (to be fixed
    in Phase 6 of sleepy-tumbling-hennessy.md).
    """
    registered = _extract_hook_script_names_from_hooks_json()
    missing = (registered - all_declared_hooks) - KNOWN_UNDECLARED_BASELINE
    assert not missing, (
        f"Hooks registered in hooks.json but NOT declared in any profile: {missing}\n"
        f"These hooks will be silently dropped by filter-hooks-json.py.\n"
        f"Add them to the `hooks:` array in the appropriate profile YAML.\n"
        f"(Baseline of pre-v5.7.0 tech debt: {len(KNOWN_UNDECLARED_BASELINE)} hooks, fix in Phase 6.)"
    )


def test_baseline_is_accurate():
    """The KNOWN_UNDECLARED_BASELINE should only contain hooks that are
    actually undeclared — nothing more, nothing less. If an entry in the
    baseline gets declared in a profile, remove it from the baseline.
    """
    registered = _extract_hook_script_names_from_hooks_json()
    declared: set[str] = set()
    for profile in PROFILES_DIR.glob("*.yaml"):
        declared |= _extract_declared_hooks_from_profile(profile)
    actual_gap = registered - declared
    stale_in_baseline = KNOWN_UNDECLARED_BASELINE - actual_gap
    assert not stale_in_baseline, (
        f"Baseline contains hooks that ARE now declared (remove from baseline): {stale_in_baseline}"
    )


def test_all_profile_hooks_have_scripts_or_are_handled(all_declared_hooks):
    """Every declared hook should have a corresponding script file.

    Accepts: hooks/{name}, hooks/{name}.sh, hooks/{name}/handler.sh, hooks/ts/{name}.ts.
    """
    hooks_dir = PLUGIN_ROOT / "hooks"
    top_level_files = {f.name for f in hooks_dir.iterdir() if f.is_file()}
    ts_hooks = {f.stem for f in (hooks_dir / "ts").glob("*.ts")} if (hooks_dir / "ts").is_dir() else set()

    orphaned = []
    for hook in all_declared_hooks:
        # Direct script (bash/plain)
        if hook in top_level_files or f"{hook}.sh" in top_level_files:
            continue
        # TypeScript hook (hooks/ts/)
        if hook in ts_hooks:
            continue
        # Subdir wrapper (hooks/ci-auto-monitor/handler.sh)
        hook_dir = hooks_dir / hook
        if hook_dir.is_dir() and (hook_dir / "handler.sh").exists():
            continue
        orphaned.append(hook)
    assert not orphaned, (
        f"Profile declares hooks without corresponding script: {orphaned}\n"
        f"Create the hook script OR remove from profile YAML."
    )
