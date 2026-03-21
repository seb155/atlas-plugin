"""
test_regression_gate.py — Ensure component counts never decrease.

These are hard gates that prevent accidental removal of skills, commands,
agents, or hooks. Update MINIMUM_COUNTS when intentionally adding components.
"""

from __future__ import annotations

import os
from pathlib import Path

import pytest

from conftest import PLUGIN_ROOT, SKILLS_DIR, COMMANDS_DIR, AGENTS_DIR, HOOKS_DIR


# ---------------------------------------------------------------------------
# Minimum counts — update when adding components (NEVER decrease)
# ---------------------------------------------------------------------------

MINIMUM_COUNTS = {
    "skills": 42,       # v3.4.0: 44 on disk (including refs sub-dirs)
    "agents": 6,        # v3.3.0: 6 agents
    "commands": 40,     # v3.4.0: 42 commands
    "hook_scripts": 7,  # v3.3.0: 7 executable hook scripts
    "test_files": 13,   # v3.4.0: 16 test files (13 original + 3 new)
    "profiles": 3,      # user, dev, admin
}


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

class TestRegressionGate:
    """Hard gates — fail if counts drop below minimum."""

    def test_skill_count(self):
        """Skill count must not decrease."""
        skills = list(SKILLS_DIR.rglob("SKILL.md"))
        assert len(skills) >= MINIMUM_COUNTS["skills"], (
            f"REGRESSION: {len(skills)} skills < minimum {MINIMUM_COUNTS['skills']}. "
            f"Did you accidentally delete a skill?"
        )

    def test_command_count(self):
        """Command count must not decrease."""
        commands = list(COMMANDS_DIR.glob("*.md"))
        assert len(commands) >= MINIMUM_COUNTS["commands"], (
            f"REGRESSION: {len(commands)} commands < minimum {MINIMUM_COUNTS['commands']}"
        )

    def test_agent_count(self):
        """Agent count must not decrease."""
        agents = list(AGENTS_DIR.rglob("AGENT.md"))
        assert len(agents) >= MINIMUM_COUNTS["agents"], (
            f"REGRESSION: {len(agents)} agents < minimum {MINIMUM_COUNTS['agents']}"
        )

    def test_hook_script_count(self):
        """Hook script count must not decrease."""
        hooks = [
            f for f in HOOKS_DIR.iterdir()
            if f.is_file() and f.name != "hooks.json" and os.access(f, os.X_OK)
        ]
        assert len(hooks) >= MINIMUM_COUNTS["hook_scripts"], (
            f"REGRESSION: {len(hooks)} hook scripts < minimum {MINIMUM_COUNTS['hook_scripts']}"
        )

    def test_profile_count(self):
        """Profile count must not decrease."""
        profiles = list((PLUGIN_ROOT / "profiles").glob("*.yaml"))
        assert len(profiles) >= MINIMUM_COUNTS["profiles"], (
            f"REGRESSION: {len(profiles)} profiles < minimum {MINIMUM_COUNTS['profiles']}"
        )

    def test_test_file_count(self):
        """Test file count must not decrease."""
        test_files = list((PLUGIN_ROOT / "tests").glob("test_*.py"))
        assert len(test_files) >= MINIMUM_COUNTS["test_files"], (
            f"REGRESSION: {len(test_files)} test files < minimum {MINIMUM_COUNTS['test_files']}"
        )

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
        assert len(rules) >= 3, (
            f"REGRESSION: only {len(rules)} rule files (need >= 3)"
        )
