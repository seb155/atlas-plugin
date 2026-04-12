"""
test_scripts_e2e.py — Execute helper scripts and validate real output.

Tests detect-platform.sh, detect-network.sh, shell-aliases.sh, setup-terminal.sh.
"""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

import pytest

# BROKEN: needs network access (curl/wget) + system tools (docker, bun, yq)
pytestmark = pytest.mark.broken

from conftest import PLUGIN_ROOT

SCRIPTS_DIR = PLUGIN_ROOT / "scripts"


def run_script(name: str, args: list[str] | None = None, timeout: int = 15) -> subprocess.CompletedProcess:
    """Execute a script and return result."""
    script_path = SCRIPTS_DIR / name
    if not script_path.exists():
        pytest.skip(f"Script not found: {name}")
    if not os.access(script_path, os.X_OK):
        pytest.skip(f"Script not executable: {name}")

    cmd = [str(script_path)] + (args or [])
    return subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        timeout=timeout,
        env={**os.environ, "CLAUDE_PLUGIN_ROOT": str(PLUGIN_ROOT)},
    )


# ---------------------------------------------------------------------------
# detect-platform.sh
# ---------------------------------------------------------------------------

class TestDetectPlatform:
    """E2E tests for platform detection script."""

    def test_returns_valid_json(self):
        result = run_script("detect-platform.sh")
        assert result.returncode == 0
        data = json.loads(result.stdout)
        assert data["os"] in ("linux", "macos", "wsl", "windows", "unknown")

    def test_has_required_fields(self):
        result = run_script("detect-platform.sh")
        data = json.loads(result.stdout)
        assert "shell" in data
        assert "terminal" in data
        assert "arch" in data
        assert "hostname" in data
        assert "capabilities" in data

    def test_capabilities_are_booleans(self):
        result = run_script("detect-platform.sh")
        data = json.loads(result.stdout)
        caps = data["capabilities"]
        for key in ("docker", "bun", "yq"):
            assert isinstance(caps[key], bool), f"capability {key} should be bool"


# ---------------------------------------------------------------------------
# detect-network.sh
# ---------------------------------------------------------------------------

class TestDetectNetwork:
    """E2E tests for network detection script."""

    def test_returns_valid_json(self):
        result = run_script("detect-network.sh", timeout=20)
        assert result.returncode == 0
        data = json.loads(result.stdout)
        assert data["network"] in ("local", "external", "offline")

    def test_has_trust_field(self):
        result = run_script("detect-network.sh", timeout=20)
        data = json.loads(result.stdout)
        assert "trust" in data
        assert data["trust"] in ("trusted", "standard", "restricted", "unknown")

    def test_has_geo_fields(self):
        result = run_script("detect-network.sh", timeout=20)
        data = json.loads(result.stdout)
        assert "geo" in data
        geo = data["geo"]
        assert "source" in geo
        assert "city" in geo

    def test_has_wifi_fields(self):
        result = run_script("detect-network.sh", timeout=20)
        data = json.loads(result.stdout)
        assert "wifi" in data


# ---------------------------------------------------------------------------
# shell-aliases.sh
# ---------------------------------------------------------------------------

class TestShellAliases:
    """E2E tests for shell alias generator."""

    def test_generates_atlas_function(self):
        result = run_script("shell-aliases.sh", args=["/tmp/test-workspace"])
        assert result.returncode == 0
        assert "atlas()" in result.stdout

    def test_generates_synapse_function(self):
        result = run_script("shell-aliases.sh", args=["/tmp/test-workspace"])
        assert "atlas-synapse()" in result.stdout

    def test_generates_worktree_variants(self):
        result = run_script("shell-aliases.sh", args=["/tmp/test-workspace"])
        assert "atlas-w()" in result.stdout
        assert "atlas-synapse-w()" in result.stdout

    def test_contains_workspace_path(self):
        result = run_script("shell-aliases.sh", args=["/custom/workspace"])
        assert "/custom/workspace" in result.stdout


# ---------------------------------------------------------------------------
# setup-terminal.sh
# ---------------------------------------------------------------------------

class TestSetupTerminal:
    """E2E tests for terminal setup script."""

    def test_check_mode_runs(self):
        result = run_script("setup-terminal.sh", args=["--check"], timeout=10)
        assert result.returncode == 0
        assert "Score:" in result.stdout

    def test_check_reports_status(self):
        result = run_script("setup-terminal.sh", args=["--check"], timeout=10)
        # Should contain at least some ✅ or ❌
        assert "✅" in result.stdout or "❌" in result.stdout
