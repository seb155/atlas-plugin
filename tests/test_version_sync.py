"""
test_version_sync.py — Version consistency across VERSION, plugin.json, marketplace.json.

Known drift is documented (not silently ignored):
- VERSION is the canonical source of truth (used by build.sh)
- plugin.json version should match VERSION
- marketplace.json version is updated separately (may lag) — flagged as a warning
  but does not fail CI so releases can proceed without a synchronous marketplace update.

If you intentionally allow version drift, document it here and mark the test
with pytest.mark.xfail(strict=False, reason="...").
"""

from __future__ import annotations

import json
import re
from pathlib import Path

import pytest

from conftest import VERSION_FILE, MANIFEST_PATH, MARKETPLACE_PATH


def _read_version_file() -> str:
    """Read and strip VERSION file."""
    return VERSION_FILE.read_text(encoding="utf-8").strip()


def _read_plugin_json_version() -> str:
    data = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    return data.get("version", "")


def _read_marketplace_version() -> str:
    """Read the first plugin's version from marketplace.json."""
    data = json.loads(MARKETPLACE_PATH.read_text(encoding="utf-8"))
    plugins = data.get("plugins", [])
    if not plugins:
        return ""
    return plugins[0].get("version", "")


SEMVER_RE = re.compile(r"^\d+\.\d+\.\d+$")


class TestVersionFile:

    def test_version_file_exists(self) -> None:
        assert VERSION_FILE.exists(), f"VERSION file not found: {VERSION_FILE}"

    def test_version_file_non_empty(self) -> None:
        content = VERSION_FILE.read_text(encoding="utf-8").strip()
        assert content, "VERSION file is empty"

    def test_version_file_is_semver(self) -> None:
        version = _read_version_file()
        assert SEMVER_RE.match(version), (
            f"VERSION file '{version}' is not valid semver (X.Y.Z)"
        )

    def test_version_file_single_line(self) -> None:
        """VERSION file should contain exactly one non-empty line."""
        lines = [
            line.strip()
            for line in VERSION_FILE.read_text(encoding="utf-8").splitlines()
            if line.strip()
        ]
        assert len(lines) == 1, (
            f"VERSION file should have exactly 1 line, found {len(lines)}: {lines}"
        )


class TestPluginJsonVersionSync:

    def test_plugin_json_version_is_semver(self) -> None:
        version = _read_plugin_json_version()
        assert SEMVER_RE.match(version), (
            f"plugin.json version '{version}' is not valid semver"
        )

    def test_plugin_json_version_matches_version_file(self) -> None:
        """plugin.json version must match VERSION file (aligned since v3.1.0)."""
        version_file = _read_version_file()
        plugin_version = _read_plugin_json_version()
        assert plugin_version == version_file, (
            f"Version namespace drift:\n"
            f"  VERSION file:   {version_file}\n"
            f"  plugin.json:    {plugin_version}\n"
            f"This is expected. See test docstring for explanation."
        )


class TestMarketplaceVersionSync:

    def test_marketplace_version_is_semver(self) -> None:
        version = _read_marketplace_version()
        if not version:
            pytest.skip("No plugins in marketplace.json")
        assert SEMVER_RE.match(version), (
            f"marketplace.json version '{version}' is not valid semver"
        )

    def test_marketplace_version_matches_version_file(self) -> None:
        """marketplace.json version must match VERSION file (aligned since v3.1.0)."""
        version_file = _read_version_file()
        marketplace_version = _read_marketplace_version()
        assert marketplace_version == version_file, (
            f"marketplace.json version '{marketplace_version}' "
            f"differs from VERSION '{version_file}'"
        )
