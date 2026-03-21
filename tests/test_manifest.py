"""
test_manifest.py — Validates plugin.json and marketplace.json manifests.

Both files live under .claude-plugin/ and define the plugin identity.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from conftest import MANIFEST_PATH, MARKETPLACE_PATH, VERSION_FILE


# ---------------------------------------------------------------------------
# plugin.json
# ---------------------------------------------------------------------------


class TestPluginJson:

    def test_file_exists(self) -> None:
        assert MANIFEST_PATH.exists(), f"plugin.json not found: {MANIFEST_PATH}"

    def test_is_valid_json(self) -> None:
        try:
            json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            pytest.fail(f"plugin.json is not valid JSON: {exc}")

    def test_has_name_field(self) -> None:
        data = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        assert "name" in data, "plugin.json must have a 'name' field"

    def test_name_non_empty(self) -> None:
        data = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        assert isinstance(data["name"], str) and data["name"].strip()

    def test_has_version_field(self) -> None:
        data = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        assert "version" in data, "plugin.json must have a 'version' field"

    def test_version_is_semver(self) -> None:
        import re
        data = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        version = data.get("version", "")
        assert re.match(r"^\d+\.\d+\.\d+", version), (
            f"plugin.json version '{version}' does not look like semver (X.Y.Z)"
        )

    def test_has_description(self) -> None:
        data = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        assert "description" in data, "plugin.json should have a 'description' field"

    def test_has_author(self) -> None:
        data = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        assert "author" in data, "plugin.json should have an 'author' field"

    def test_author_has_name(self) -> None:
        data = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        author = data.get("author", {})
        assert "name" in author, "plugin.json author must have a 'name' field"

    def test_has_license(self) -> None:
        data = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        assert "license" in data, "plugin.json should declare a 'license'"

    def test_keywords_is_list_if_present(self) -> None:
        data = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        if "keywords" in data:
            assert isinstance(data["keywords"], list), (
                "plugin.json 'keywords' must be a list"
            )


# ---------------------------------------------------------------------------
# marketplace.json
# ---------------------------------------------------------------------------


class TestMarketplaceJson:

    def test_file_exists(self) -> None:
        assert MARKETPLACE_PATH.exists(), (
            f"marketplace.json not found: {MARKETPLACE_PATH}"
        )

    def test_is_valid_json(self) -> None:
        try:
            json.loads(MARKETPLACE_PATH.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            pytest.fail(f"marketplace.json is not valid JSON: {exc}")

    def test_has_name_field(self) -> None:
        data = json.loads(MARKETPLACE_PATH.read_text(encoding="utf-8"))
        assert "name" in data, "marketplace.json must have a 'name' field"

    def test_has_plugins_list(self) -> None:
        data = json.loads(MARKETPLACE_PATH.read_text(encoding="utf-8"))
        assert "plugins" in data, "marketplace.json must have a 'plugins' list"
        assert isinstance(data["plugins"], list)

    def test_plugins_list_non_empty(self) -> None:
        data = json.loads(MARKETPLACE_PATH.read_text(encoding="utf-8"))
        assert len(data.get("plugins", [])) > 0, (
            "marketplace.json 'plugins' list must not be empty"
        )

    def test_each_plugin_has_name(self) -> None:
        data = json.loads(MARKETPLACE_PATH.read_text(encoding="utf-8"))
        for i, plugin in enumerate(data.get("plugins", [])):
            assert "name" in plugin, f"Plugin at index {i} missing 'name'"

    def test_each_plugin_has_version(self) -> None:
        data = json.loads(MARKETPLACE_PATH.read_text(encoding="utf-8"))
        for i, plugin in enumerate(data.get("plugins", [])):
            assert "version" in plugin, f"Plugin at index {i} missing 'version'"

    def test_each_plugin_has_source(self) -> None:
        data = json.loads(MARKETPLACE_PATH.read_text(encoding="utf-8"))
        for i, plugin in enumerate(data.get("plugins", [])):
            assert "source" in plugin, f"Plugin at index {i} missing 'source'"
