"""
test_skill_coverage.py — No orphans, no missing skills.

Rules:
- Every directory under skills/ (except refs/ itself) must contain SKILL.md
- Every directory under refs/ must contain SKILL.md
- Every skill referenced in any profile must exist on disk
- No skill directory on disk is completely unreferenced by all profiles combined
  (informational — reported as a warning, not a hard failure, to allow WIP skills)
"""

from __future__ import annotations

from pathlib import Path

import pytest
import yaml

from conftest import (
    SKILLS_DIR,
    PROFILES_DIR,
    SKILL_CONTAINER_DIRS,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _all_skill_dirs() -> list[Path]:
    """Expand skills/ dirs including refs/* sub-dirs."""
    dirs: list[Path] = []
    for d in sorted(SKILLS_DIR.iterdir()):
        if not d.is_dir():
            continue
        if d.name in SKILL_CONTAINER_DIRS:
            for sub in sorted(d.iterdir()):
                if sub.is_dir():
                    dirs.append(sub)
        else:
            dirs.append(d)
    return dirs


def _all_skills_in_profiles() -> set[str]:
    """All skill names across all profiles (own + refs lists)."""
    names: set[str] = set()
    for path in PROFILES_DIR.glob("*.yaml"):
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
        names.update(data.get("skills", []))
        names.update(data.get("refs", []))
    return names


def _container_dirs_only() -> list[Path]:
    """Directories that ARE skill containers (refs/) — their own SKILL.md is optional."""
    return [SKILLS_DIR / name for name in SKILL_CONTAINER_DIRS]


ALL_SKILL_DIRS = _all_skill_dirs()
ALL_SKILLS_IN_PROFILES = _all_skills_in_profiles()


# ---------------------------------------------------------------------------
# Test: every skill dir has SKILL.md
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "skill_dir",
    ALL_SKILL_DIRS,
    ids=[d.name for d in ALL_SKILL_DIRS],
)
def test_skill_dir_has_skill_md(skill_dir: Path) -> None:
    """Every directory inside skills/ (including refs/* sub-dirs) must have SKILL.md."""
    skill_md = skill_dir / "SKILL.md"
    assert skill_md.exists(), (
        f"Orphaned skill directory (missing SKILL.md): {skill_dir}\n"
        f"Either add a SKILL.md or remove the empty directory."
    )


# ---------------------------------------------------------------------------
# Test: skill dirs are not empty (SKILL.md + at least itself)
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "skill_dir",
    ALL_SKILL_DIRS,
    ids=[d.name for d in ALL_SKILL_DIRS],
)
def test_skill_dir_not_empty(skill_dir: Path) -> None:
    """Skill directory must contain at least SKILL.md (not a completely empty dir)."""
    contents = list(skill_dir.iterdir())
    assert len(contents) >= 1, f"Skill directory is empty: {skill_dir}"


# ---------------------------------------------------------------------------
# Test: profile skills exist on disk
# ---------------------------------------------------------------------------


def _collect_profile_skill_params() -> list[tuple[str, str]]:
    """(tier, skill_name) for all skill declarations across all profiles."""
    params: list[tuple[str, str]] = []
    skill_names_on_disk = {d.name for d in ALL_SKILL_DIRS}
    for path in sorted(PROFILES_DIR.glob("*.yaml")):
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
        tier = data.get("tier", path.stem)
        for skill in data.get("skills", []):
            params.append((tier, skill))
    return params


_PROFILE_SKILL_PARAMS = _collect_profile_skill_params()


@pytest.mark.parametrize(
    "tier,skill_name",
    _PROFILE_SKILL_PARAMS,
    ids=[f"{t}/{s}" for t, s in _PROFILE_SKILL_PARAMS],
)
def test_profile_skill_has_directory(tier: str, skill_name: str) -> None:
    """Every skill listed in a profile must have a corresponding directory on disk."""
    disk_names = {d.name for d in ALL_SKILL_DIRS}
    assert skill_name in disk_names, (
        f"Profile '{tier}' references skill '{skill_name}' "
        f"but skills/{skill_name}/ does not exist"
    )


# ---------------------------------------------------------------------------
# Informational: detect unreferenced (WIP) skill directories
# ---------------------------------------------------------------------------


def test_orphaned_skills_report() -> None:
    """
    Report skills that exist on disk but are not referenced in any profile.
    This is NOT a hard failure (skills may be WIP), but it surfaces drift.
    """
    disk_names = {d.name for d in ALL_SKILL_DIRS}
    profile_names = ALL_SKILLS_IN_PROFILES
    orphans = disk_names - profile_names

    # Informational only — print but don't fail
    if orphans:
        import warnings
        warnings.warn(
            f"Skills on disk not referenced in any profile: {sorted(orphans)}\n"
            "These may be WIP skills. Add them to a profile when ready.",
            stacklevel=2,
        )
    # Always passes — this is a coverage report, not a gate
    assert True


# ---------------------------------------------------------------------------
# Test: refs profile entries resolve to dirs under skills/refs/
# ---------------------------------------------------------------------------


def _collect_refs_params() -> list[tuple[str, str]]:
    """(tier, ref_name) for all refs declarations across profiles."""
    params: list[tuple[str, str]] = []
    for path in sorted(PROFILES_DIR.glob("*.yaml")):
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
        tier = data.get("tier", path.stem)
        for ref in data.get("refs", []):
            params.append((tier, ref))
    return params


_REFS_PARAMS = _collect_refs_params()


@pytest.mark.parametrize(
    "tier,ref_name",
    _REFS_PARAMS,
    ids=[f"{t}/{r}" for t, r in _REFS_PARAMS],
)
def test_profile_ref_has_directory(tier: str, ref_name: str) -> None:
    """Every refs entry in a profile must exist as a sub-dir under skills/refs/."""
    refs_base = SKILLS_DIR / "refs"
    ref_dir = refs_base / ref_name
    assert ref_dir.is_dir(), (
        f"Profile '{tier}' declares ref '{ref_name}' "
        f"but skills/refs/{ref_name}/ does not exist"
    )
