"""E2E Plugin Tests — validates built dist/ artifacts for all tiers.

Assumes dist/ is pre-built (run: ./build.sh all first).
Run: pytest tests/test_e2e_plugin.py -x -q --tb=short -m e2e

Coverage gap vs existing tests:
- test_build_output.py covers structure/version/DEDUP for atlas-{admin,dev,user} only
- test_skill_frontmatter.py covers SOURCE skills/, not dist/
- test_hook_e2e.py runs SOURCE hooks/, not dist/ copies

This file adds:
A) Version consistency for ALL 9 tiers (including optional ones)
B) Dist SKILL.md frontmatter integrity
C) Dist hook executability
D) hooks.json validity + referenced scripts exist
E) _metadata.yaml owner field validity (SP-DEDUP)
"""

from __future__ import annotations

import json
import os
import re
from pathlib import Path

import pytest
import yaml

from conftest import PLUGIN_ROOT, VERSION_FILE

pytestmark = pytest.mark.build  # L2: requires dist/ artifacts from build step

DIST_ROOT = PLUGIN_ROOT / "dist"
METADATA_FILE = PLUGIN_ROOT / "skills" / "_metadata.yaml"

# All tiers produced by build.sh all
ALL_TIERS = [
    "atlas-admin",
    "atlas-core",
    "atlas-dev",
    "atlas-enterprise",
    "atlas-experiential",
    "atlas-frontend",
    "atlas-infra",
    "atlas-user",
    "atlas-worker",
]

# Required plugin.json top-level fields
REQUIRED_PLUGIN_FIELDS = {"name", "version", "description"}

# Valid model values for SKILL.md frontmatter (when present)
VALID_MODELS = {"sonnet", "opus", "haiku", "inherit"}

# Valid owner values in _metadata.yaml (tier names minus "user" — "user" maps to "core")
VALID_OWNERS = {"admin", "dev", "core", "infra", "enterprise", "frontend", "experiential", "worker"}

# Hook files/dirs to skip when checking executability
HOOK_NON_SCRIPT = {"hooks.json", "lib", "ts"}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _tier_dist(tier: str) -> Path:
    return DIST_ROOT / tier


def _plugin_json_path(tier: str) -> Path:
    return _tier_dist(tier) / ".claude-plugin" / "plugin.json"


def _skip_if_not_built(tier: str) -> None:
    if not _tier_dist(tier).exists():
        pytest.skip(f"{tier} not built — run ./build.sh all")


def _parse_frontmatter(path: Path) -> dict:
    """Extract YAML frontmatter between --- delimiters. Returns {} if absent."""
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---"):
        return {}
    end = text.find("\n---", 3)
    if end == -1:
        return {}
    return yaml.safe_load(text[3:end].strip()) or {}


def _iter_skill_dirs(skills_dir: Path):
    """Yield all skill directories, expanding refs/ container."""
    for d in sorted(skills_dir.iterdir()):
        if not d.is_dir():
            continue
        if d.name == "refs":
            for sub in sorted(d.iterdir()):
                if sub.is_dir():
                    yield sub
        else:
            yield d


# ---------------------------------------------------------------------------
# A. Version consistency — ALL tiers
# ---------------------------------------------------------------------------


@pytest.mark.e2e
class TestVersionConsistencyAllTiers:
    """plugin.json version must match VERSION for every built tier.

    test_build_output.py only covers atlas-{admin,dev,user}.
    This extends coverage to the 6 remaining tiers.
    """

    @pytest.mark.parametrize("tier", ALL_TIERS)
    def test_version_matches_version_file(self, tier: str) -> None:
        _skip_if_not_built(tier)
        pj = _plugin_json_path(tier)
        if not pj.exists():
            pytest.skip(f"{tier}/.claude-plugin/plugin.json not found")
        expected = VERSION_FILE.read_text().strip()
        data = json.loads(pj.read_text())
        assert data.get("version") == expected, (
            f"{tier} plugin.json version {data.get('version')!r} != VERSION {expected!r}"
        )

    @pytest.mark.parametrize("tier", ALL_TIERS)
    def test_plugin_json_has_required_fields(self, tier: str) -> None:
        _skip_if_not_built(tier)
        pj = _plugin_json_path(tier)
        if not pj.exists():
            pytest.skip(f"{tier}/.claude-plugin/plugin.json not found")
        data = json.loads(pj.read_text())
        missing = REQUIRED_PLUGIN_FIELDS - data.keys()
        assert not missing, f"{tier} plugin.json missing fields: {sorted(missing)}"


# ---------------------------------------------------------------------------
# B. Dist SKILL.md frontmatter integrity
# ---------------------------------------------------------------------------


@pytest.mark.e2e
class TestDistSkillIntegrity:
    """SKILL.md files in dist/ must have valid frontmatter.

    test_skill_frontmatter.py only validates source skills/.
    This validates the copied/generated dist/ artifacts.
    """

    @pytest.mark.parametrize("tier", ALL_TIERS)
    def test_dist_skills_have_name_and_description(self, tier: str) -> None:
        """Every dist SKILL.md must have non-empty 'name' and 'description'."""
        _skip_if_not_built(tier)
        skills_dir = _tier_dist(tier) / "skills"
        if not skills_dir.exists():
            pytest.skip(f"{tier}/skills/ not found")

        failures: list[str] = []
        for skill_dir in _iter_skill_dirs(skills_dir):
            skill_md = skill_dir / "SKILL.md"
            if not skill_md.exists():
                continue
            fm = _parse_frontmatter(skill_md)
            if not fm:
                failures.append(f"{skill_dir.name}: no frontmatter")
                continue
            for field in ("name", "description"):
                val = fm.get(field, "")
                if not val or not str(val).strip():
                    failures.append(f"{skill_dir.name}: missing/empty '{field}'")

        assert not failures, (
            f"{tier} dist skill frontmatter failures:\n  " + "\n  ".join(failures)
        )

    @pytest.mark.parametrize("tier", ALL_TIERS)
    def test_dist_skills_model_valid_if_present(self, tier: str) -> None:
        """If 'model' is in frontmatter, it must be a known value."""
        _skip_if_not_built(tier)
        skills_dir = _tier_dist(tier) / "skills"
        if not skills_dir.exists():
            pytest.skip(f"{tier}/skills/ not found")

        failures: list[str] = []
        for skill_dir in _iter_skill_dirs(skills_dir):
            skill_md = skill_dir / "SKILL.md"
            if not skill_md.exists():
                continue
            fm = _parse_frontmatter(skill_md)
            model = fm.get("model")
            if model and model not in VALID_MODELS:
                failures.append(f"{skill_dir.name}: invalid model '{model}'")

        assert not failures, (
            f"{tier} dist skill invalid model values:\n  " + "\n  ".join(failures)
        )

    @pytest.mark.parametrize("tier", ALL_TIERS)
    def test_atlas_assist_is_substantial(self, tier: str) -> None:
        """Generated atlas-assist SKILL.md must be non-trivial (>= 500 chars)."""
        _skip_if_not_built(tier)
        assist = _tier_dist(tier) / "skills" / "atlas-assist" / "SKILL.md"
        if not assist.exists():
            pytest.skip(f"{tier} atlas-assist not found")
        size = len(assist.read_text())
        assert size >= 500, (
            f"{tier} atlas-assist/SKILL.md is suspiciously small ({size} chars)"
        )


# ---------------------------------------------------------------------------
# C. Dist hook executability
# ---------------------------------------------------------------------------


@pytest.mark.e2e
class TestDistHookExecutability:
    """Hook scripts in dist/{tier}/hooks/ must be executable files.

    test_hook_e2e.py runs source hooks/. This validates the dist/ copies.
    """

    @pytest.mark.parametrize("tier", ALL_TIERS)
    def test_hook_scripts_are_executable(self, tier: str) -> None:
        _skip_if_not_built(tier)
        hooks_dir = _tier_dist(tier) / "hooks"
        if not hooks_dir.exists():
            pytest.skip(f"{tier}/hooks/ not found")

        non_exec: list[str] = []
        for item in sorted(hooks_dir.iterdir()):
            if item.name in HOOK_NON_SCRIPT or item.is_dir():
                continue
            if not os.access(item, os.X_OK):
                non_exec.append(item.name)

        assert not non_exec, f"{tier} non-executable hook scripts: {non_exec}"


# ---------------------------------------------------------------------------
# D. hooks.json validity + referenced scripts exist
# ---------------------------------------------------------------------------


@pytest.mark.e2e
class TestHooksJsonIntegrity:
    """hooks.json in dist/ must be valid JSON and reference existing scripts."""

    @pytest.mark.parametrize("tier", ALL_TIERS)
    def test_hooks_json_is_valid_json(self, tier: str) -> None:
        _skip_if_not_built(tier)
        hj = _tier_dist(tier) / "hooks" / "hooks.json"
        if not hj.exists():
            pytest.skip(f"{tier}/hooks/hooks.json not found")
        try:
            data = json.loads(hj.read_text())
        except json.JSONDecodeError as exc:
            pytest.fail(f"{tier} hooks.json is invalid JSON: {exc}")
        assert isinstance(data, dict), f"{tier} hooks.json root must be a JSON object"

    @pytest.mark.parametrize("tier", ALL_TIERS)
    def test_hooks_json_has_hooks_key(self, tier: str) -> None:
        _skip_if_not_built(tier)
        hj = _tier_dist(tier) / "hooks" / "hooks.json"
        if not hj.exists():
            pytest.skip(f"{tier}/hooks/hooks.json not found")
        data = json.loads(hj.read_text())
        assert "hooks" in data, f"{tier} hooks.json missing top-level 'hooks' key"

    @pytest.mark.parametrize("tier", ALL_TIERS)
    def test_hooks_json_commands_reference_existing_scripts(self, tier: str) -> None:
        """Hook commands using ${{CLAUDE_PLUGIN_ROOT}} must resolve to existing files."""
        _skip_if_not_built(tier)
        hj = _tier_dist(tier) / "hooks" / "hooks.json"
        if not hj.exists():
            pytest.skip(f"{tier}/hooks/hooks.json not found")

        data = json.loads(hj.read_text())
        tier_dir = _tier_dist(tier)
        hooks_section = data.get("hooks", {})

        missing: list[str] = []
        for event, event_hooks in hooks_section.items():
            for group in event_hooks:
                for hook in group.get("hooks", []):
                    cmd = hook.get("command", "")
                    # Match ${CLAUDE_PLUGIN_ROOT}/relative/path (with or without quotes)
                    match = re.search(
                        r'\$\{CLAUDE_PLUGIN_ROOT\}/([^\s"\'\\]+)', cmd
                    )
                    if match:
                        rel_path = match.group(1)
                        abs_path = tier_dir / rel_path
                        if not abs_path.exists():
                            missing.append(f"[{event}] {rel_path}")

        assert not missing, (
            f"{tier} hooks.json references missing scripts:\n  "
            + "\n  ".join(missing)
        )


# ---------------------------------------------------------------------------
# E. _metadata.yaml owner field validity (SP-DEDUP)
# ---------------------------------------------------------------------------


@pytest.mark.e2e
class TestDedupCompliance:
    """Skills in _metadata.yaml must have valid owner values (SP-DEDUP)."""

    @pytest.fixture(scope="class")
    def metadata(self) -> dict:
        data = yaml.safe_load(METADATA_FILE.read_text(encoding="utf-8"))
        return data.get("skills", {})

    def test_all_skills_have_owner(self, metadata: dict) -> None:
        """Every skill entry must declare an owner."""
        no_owner = [
            name for name, info in metadata.items()
            if isinstance(info, dict) and "owner" not in info
        ]
        assert not no_owner, (
            f"Skills missing 'owner' in _metadata.yaml:\n  " + "\n  ".join(sorted(no_owner))
        )

    def test_owner_values_are_valid(self, metadata: dict) -> None:
        """All owner values must be in the known set."""
        invalid = [
            f"{name}: '{info['owner']}'"
            for name, info in metadata.items()
            if isinstance(info, dict) and info.get("owner") not in VALID_OWNERS
        ]
        assert not invalid, (
            f"Invalid owner values in _metadata.yaml:\n  " + "\n  ".join(sorted(invalid))
        )
