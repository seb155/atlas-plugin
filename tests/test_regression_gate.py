"""
test_regression_gate.py — Ensure plugin structure stays healthy.

Uses STRUCTURAL checks (files exist, non-empty) instead of hardcoded count thresholds.
Counts are logged for visibility but don't block unless they drop to zero.
"""

from __future__ import annotations

import os
from pathlib import Path

import pytest

from conftest import PLUGIN_ROOT, SKILLS_DIR, COMMANDS_DIR, AGENTS_DIR, HOOKS_DIR


class TestRegressionGate:
    """Structural gates — verify plugin integrity without hardcoded counts."""

    def test_has_skills(self):
        """Plugin must have at least one skill."""
        skills = list(SKILLS_DIR.rglob("SKILL.md"))
        assert len(skills) > 0, "REGRESSION: zero skills found"
        print(f"Skills: {len(skills)}")

    def test_has_commands(self):
        """Plugin must have at least one command."""
        commands = list(COMMANDS_DIR.glob("*.md"))
        assert len(commands) > 0, "REGRESSION: zero commands found"
        print(f"Commands: {len(commands)}")

    def test_has_agents(self):
        """Plugin must have at least one agent."""
        agents = list(AGENTS_DIR.rglob("AGENT.md"))
        assert len(agents) > 0, "REGRESSION: zero agents found"
        print(f"Agents: {len(agents)}")

    def test_has_hook_scripts(self):
        """Plugin must have executable hook scripts."""
        hooks = [
            f for f in HOOKS_DIR.iterdir()
            if f.is_file() and f.name != "hooks.json" and os.access(f, os.X_OK)
        ]
        assert len(hooks) > 0, "REGRESSION: zero hook scripts found"
        print(f"Hook scripts: {len(hooks)}")

    def test_has_profiles(self):
        """Plugin must have at least one profile."""
        profiles = list((PLUGIN_ROOT / "profiles").glob("*.yaml"))
        assert len(profiles) > 0, "REGRESSION: zero profiles found"
        print(f"Profiles: {len(profiles)}")

    def test_plugin_has_claude_md(self):
        """Plugin must have its own CLAUDE.md for AI self-development."""
        assert (PLUGIN_ROOT / "CLAUDE.md").exists(), (
            "REGRESSION: CLAUDE.md removed. Plugin needs self-context."
        )

    def test_plugin_has_rules(self):
        """Plugin must have .claude/rules/ for development patterns."""
        rules_dir = PLUGIN_ROOT / ".claude" / "rules"
        assert rules_dir.is_dir(), "REGRESSION: .claude/rules/ removed"
        rules = list(rules_dir.glob("*.md"))
        assert len(rules) >= 1, "REGRESSION: zero rule files"

    # --- Critical component checks (these specific things MUST exist) ---

    def test_atlas_assist_skill_exists(self):
        """The master routing skill must always exist."""
        assert (SKILLS_DIR / "atlas-assist" / "SKILL.md").exists(), (
            "REGRESSION: atlas-assist skill removed (this is the master router)"
        )

    def test_hooks_json_exists(self):
        """hooks.json must exist and be valid JSON."""
        hooks_json = HOOKS_DIR / "hooks.json"
        assert hooks_json.exists(), "REGRESSION: hooks.json removed"
        import json
        with open(hooks_json) as f:
            data = json.load(f)
        assert "hooks" in data, "REGRESSION: hooks.json missing 'hooks' key"

    def test_plugin_json_exists(self):
        """plugin.json must exist with required fields."""
        pj = PLUGIN_ROOT / ".claude-plugin" / "plugin.json"
        assert pj.exists(), "REGRESSION: plugin.json removed"
        import json
        with open(pj) as f:
            data = json.load(f)
        assert "name" in data, "plugin.json missing 'name'"
        assert "version" in data, "plugin.json missing 'version'"

    def test_version_file_exists(self):
        """VERSION file must exist and contain a semver string."""
        vf = PLUGIN_ROOT / "VERSION"
        assert vf.exists(), "REGRESSION: VERSION file removed"
        version = vf.read_text().strip()
        parts = version.split(".")
        assert len(parts) == 3, f"VERSION '{version}' is not semver (expected X.Y.Z)"
