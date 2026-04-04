#!/usr/bin/env python3
"""
content-addressable-store.py — Deduplicate skills across tiers using content hashing.

Instead of copying the same SKILL.md to 4 tiers, store once in a content-addressable
store and create symlinks from each tier's cache.

Usage:
  python3 scripts/content-addressable-store.py analyze        # Show dedup stats
  python3 scripts/content-addressable-store.py build [--dry-run]  # Build store + symlinks
  python3 scripts/content-addressable-store.py verify         # Verify symlinks are valid

Architecture:
  ~/.claude/plugins/skills-store/{hash}/SKILL.md       ← single copy
  ~/.claude/plugins/cache/.../skills/memory-dream/     ← symlink to store

WARNING: Only enable if CC follows symlinks in plugin cache. Test with `verify` first.
"""

import hashlib
import json
import os
import shutil
import sys
from collections import defaultdict
from pathlib import Path

DIST_DIR = Path(__file__).parent.parent / "dist"
STORE_DIR = Path.home() / ".claude" / "plugins" / "skills-store"
CACHE_DIR = Path.home() / ".claude" / "plugins" / "cache" / "atlas-admin-marketplace"


def hash_skill(skill_dir: Path) -> str:
    """Compute content hash of a skill directory."""
    hasher = hashlib.sha256()
    for f in sorted(skill_dir.rglob("*")):
        if f.is_file():
            hasher.update(f.relative_to(skill_dir).as_posix().encode())
            hasher.update(f.read_bytes())
    return hasher.hexdigest()[:12]


def find_all_skills_in_dist() -> dict[str, list[tuple[str, Path]]]:
    """Find all skills across all tier dist directories.
    Returns: {skill_name: [(tier, path), ...]}
    """
    skills: dict[str, list[tuple[str, Path]]] = defaultdict(list)
    for tier_dir in sorted(DIST_DIR.iterdir()):
        if not tier_dir.is_dir():
            continue
        skills_dir = tier_dir / "skills"
        if not skills_dir.exists():
            continue
        for skill_dir in sorted(skills_dir.iterdir()):
            if skill_dir.is_dir() and (skill_dir / "SKILL.md").exists():
                skills[skill_dir.name].append((tier_dir.name, skill_dir))
    return skills


def analyze():
    """Show deduplication statistics."""
    skills = find_all_skills_in_dist()

    total_copies = sum(len(tiers) for tiers in skills.values())
    unique_skills = len(skills)
    duplicated = {name: tiers for name, tiers in skills.items() if len(tiers) > 1}

    # Compute content hashes
    hash_groups: dict[str, list[tuple[str, str]]] = defaultdict(list)  # hash → [(tier, skill)]
    for name, tiers in skills.items():
        for tier_name, path in tiers:
            h = hash_skill(path)
            hash_groups[h].append((tier_name, name))

    # Count truly identical copies
    identical_copies = sum(len(items) - 1 for items in hash_groups.values() if len(items) > 1)

    # Size savings
    total_size = 0
    dedup_size = 0
    seen_hashes = set()
    for name, tiers in skills.items():
        for tier_name, path in tiers:
            size = sum(f.stat().st_size for f in path.rglob("*") if f.is_file())
            total_size += size
            h = hash_skill(path)
            if h not in seen_hashes:
                dedup_size += size
                seen_hashes.add(h)

    print(f"\n{'Content-Addressable Store Analysis':=^60}\n")
    print(f"  Unique skills:        {unique_skills}")
    print(f"  Total copies:         {total_copies}")
    print(f"  Duplicated skills:    {len(duplicated)}")
    print(f"  Identical copies:     {identical_copies}")
    print(f"  Total size:           {total_size / 1024:.1f} KB")
    print(f"  After dedup:          {dedup_size / 1024:.1f} KB")
    print(f"  Savings:              {(total_size - dedup_size) / 1024:.1f} KB ({(1 - dedup_size / max(1, total_size)) * 100:.0f}%)")

    if duplicated:
        print(f"\n  Duplicated skills ({len(duplicated)}):")
        for name, tiers in sorted(duplicated.items()):
            tier_names = ", ".join(t for t, _ in tiers)
            hashes = set(hash_skill(p) for _, p in tiers)
            identical = "identical" if len(hashes) == 1 else f"{len(hashes)} variants"
            print(f"    {name:<30} → {tier_names} ({identical})")

    print()


def build(dry_run: bool = False):
    """Build content-addressable store and create symlinks."""
    skills = find_all_skills_in_dist()

    if dry_run:
        print("[DRY RUN] Would create store at:", STORE_DIR)

    # Build store
    stored = {}  # hash → store_path
    for name, tiers in skills.items():
        for tier_name, path in tiers:
            h = hash_skill(path)
            if h not in stored:
                store_path = STORE_DIR / h
                if not dry_run:
                    store_path.mkdir(parents=True, exist_ok=True)
                    shutil.copytree(path, store_path, dirs_exist_ok=True)
                stored[h] = store_path
                print(f"  STORE: {name} → {h}")
            else:
                print(f"  DEDUP: {name} ({tier_name}) → {h} (already stored)")

    # Create symlinks in cache
    for name, tiers in skills.items():
        for tier_name, path in tiers:
            h = hash_skill(path)
            cache_skill = CACHE_DIR / tier_name / "skills" / name  # version-less for now
            if not dry_run:
                # Only create symlink if the cache dir exists
                if cache_skill.parent.exists():
                    if cache_skill.exists() or cache_skill.is_symlink():
                        if cache_skill.is_symlink():
                            cache_skill.unlink()
                        else:
                            shutil.rmtree(cache_skill)
                    cache_skill.symlink_to(stored[h])
                    print(f"  LINK: {cache_skill} → {stored[h]}")

    # Write store manifest
    manifest = {
        "created": __import__("datetime").datetime.now().isoformat(),
        "entries": {h: str(p) for h, p in stored.items()},
        "total_unique": len(stored),
        "total_copies": sum(len(t) for t in skills.values()),
    }
    manifest_path = STORE_DIR / "manifest.json"
    if not dry_run:
        STORE_DIR.mkdir(parents=True, exist_ok=True)
        with open(manifest_path, "w") as f:
            json.dump(manifest, f, indent=2)
    print(f"\n  Manifest: {manifest_path}")
    print(f"  {len(stored)} unique, {manifest['total_copies']} total copies")


def verify():
    """Verify all symlinks in the cache point to valid store entries."""
    if not STORE_DIR.exists():
        print("No store found at", STORE_DIR)
        return

    broken = []
    valid = 0
    for tier_dir in sorted(CACHE_DIR.iterdir()):
        if not tier_dir.is_dir():
            continue
        # Find versioned skills dir
        for version_dir in tier_dir.iterdir():
            if not version_dir.is_dir():
                continue
            skills_dir = version_dir / "skills"
            if not skills_dir.exists():
                continue
            for skill_dir in skills_dir.iterdir():
                if skill_dir.is_symlink():
                    target = skill_dir.resolve()
                    if target.exists():
                        valid += 1
                    else:
                        broken.append((skill_dir, target))

    print(f"\n  Valid symlinks:  {valid}")
    print(f"  Broken symlinks: {len(broken)}")
    for link, target in broken:
        print(f"    BROKEN: {link} → {target}")


def main():
    if len(sys.argv) < 2:
        print("Usage: content-addressable-store.py [analyze|build|verify]")
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == "analyze":
        analyze()
    elif cmd == "build":
        dry_run = "--dry-run" in sys.argv
        build(dry_run)
    elif cmd == "verify":
        verify()
    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)


if __name__ == "__main__":
    main()
