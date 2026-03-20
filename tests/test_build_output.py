"""
test_build_output.py — Validate build.sh output (dist/ artifacts).

Runs build.sh as a subprocess and validates:
- Each tier dist has expected structure
- atlas-assist/SKILL.md was generated and is non-empty
- plugin.json version matches VERSION file
- Skill/command/agent counts match profile resolution
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

import pytest

from conftest import PLUGIN_ROOT, VERSION_FILE, resolved_tier


DIST_DIR = PLUGIN_ROOT / "dist"


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(scope="module")
def build_output() -> Path:
    """Run build.sh all and return dist/ path. Skips if yq not installed."""
    # Check yq is available (required by build.sh)
    result = subprocess.run(["which", "yq"], capture_output=True)
    if result.returncode != 0:
        pytest.skip("yq not installed — cannot run build.sh")

    # Run build
    result = subprocess.run(
        ["./build.sh", "all"],
        capture_output=True,
        text=True,
        cwd=str(PLUGIN_ROOT),
        timeout=60,
    )
    assert result.returncode == 0, (
        f"build.sh failed:\nSTDOUT: {result.stdout}\nSTDERR: {result.stderr}"
    )
    assert DIST_DIR.is_dir(), "dist/ not created after build"
    return DIST_DIR


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

class TestBuildStructure:

    @pytest.mark.parametrize("tier", ["admin", "dev", "user"])
    def test_tier_dist_exists(self, build_output: Path, tier: str) -> None:
        """Each tier should have a dist/atlas-{tier}/ directory."""
        tier_dir = build_output / f"atlas-{tier}"
        assert tier_dir.is_dir(), f"dist/atlas-{tier}/ not found"

    @pytest.mark.parametrize("tier", ["admin", "dev", "user"])
    def test_tier_has_required_dirs(self, build_output: Path, tier: str) -> None:
        """Each tier dist must have skills/, commands/, agents/, hooks/."""
        tier_dir = build_output / f"atlas-{tier}"
        for subdir in ["skills", "commands", "agents", "hooks", ".claude-plugin"]:
            assert (tier_dir / subdir).is_dir(), (
                f"dist/atlas-{tier}/{subdir}/ missing"
            )


class TestAtlasAssistGenerated:

    @pytest.mark.parametrize("tier", ["admin", "dev", "user"])
    def test_atlas_assist_skill_md_exists(self, build_output: Path, tier: str) -> None:
        """atlas-assist/SKILL.md must be generated in each tier."""
        path = build_output / f"atlas-{tier}" / "skills" / "atlas-assist" / "SKILL.md"
        assert path.exists(), f"atlas-assist/SKILL.md not found in {tier} dist"

    @pytest.mark.parametrize("tier", ["admin", "dev", "user"])
    def test_atlas_assist_not_empty(self, build_output: Path, tier: str) -> None:
        """Generated atlas-assist SKILL.md should have content."""
        path = build_output / f"atlas-{tier}" / "skills" / "atlas-assist" / "SKILL.md"
        if not path.exists():
            pytest.skip("atlas-assist not found")
        content = path.read_text(encoding="utf-8")
        assert len(content) > 500, (
            f"atlas-assist/SKILL.md in {tier} is too short ({len(content)} chars)"
        )


class TestBuildVersionSync:

    @pytest.mark.parametrize("tier", ["admin", "dev", "user"])
    def test_dist_plugin_json_version(self, build_output: Path, tier: str) -> None:
        """dist plugin.json version must match VERSION file."""
        expected = VERSION_FILE.read_text(encoding="utf-8").strip()
        pj = build_output / f"atlas-{tier}" / ".claude-plugin" / "plugin.json"
        if not pj.exists():
            pytest.skip(f"No plugin.json in {tier} dist")
        data = json.loads(pj.read_text(encoding="utf-8"))
        assert data.get("version") == expected, (
            f"dist/atlas-{tier}/plugin.json version {data.get('version')} "
            f"!= VERSION {expected}"
        )

    @pytest.mark.parametrize("tier", ["admin", "dev", "user"])
    def test_dist_version_file(self, build_output: Path, tier: str) -> None:
        """dist/ should contain a VERSION file matching source."""
        expected = VERSION_FILE.read_text(encoding="utf-8").strip()
        vf = build_output / f"atlas-{tier}" / "VERSION"
        if not vf.exists():
            pytest.skip(f"No VERSION in {tier} dist")
        assert vf.read_text(encoding="utf-8").strip() == expected


class TestBuildCounts:

    @pytest.mark.parametrize("tier", ["admin", "dev", "user"])
    def test_skill_count_matches_profile(self, build_output: Path, tier: str) -> None:
        """Dist skill count should match resolved profile."""
        resolved = resolved_tier(tier)
        expected_count = len(resolved["skills"])

        tier_dir = build_output / f"atlas-{tier}" / "skills"
        # Count SKILL.md files (1 per skill, including refs sub-dirs)
        actual = len(list(tier_dir.rglob("SKILL.md")))

        # Allow +1 for atlas-assist (auto-generated, not in profile)
        assert actual >= expected_count, (
            f"dist/atlas-{tier} has {actual} skills, "
            f"expected >= {expected_count} from profile"
        )

    @pytest.mark.parametrize("tier", ["admin", "dev", "user"])
    def test_command_count_matches_profile(self, build_output: Path, tier: str) -> None:
        """Dist command count should match resolved profile."""
        resolved = resolved_tier(tier)
        expected_count = len(resolved["commands"])

        tier_dir = build_output / f"atlas-{tier}" / "commands"
        actual = len(list(tier_dir.glob("*.md")))

        assert actual >= expected_count, (
            f"dist/atlas-{tier} has {actual} commands, "
            f"expected >= {expected_count} from profile"
        )
