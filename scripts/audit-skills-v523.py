#!/usr/bin/env python3
"""
Audit ATLAS skills for v6.0 migration readiness.

Scans all skills/*/SKILL.md and produces CSV with frontmatter/body attributes.
Determines tier (core/dev/admin) from profiles/*.yaml inheritance.
Outputs: tests/inventory/skills-audit-v5.23.csv + summary markdown.
"""
from __future__ import annotations
import csv
import re
import sys
from pathlib import Path

PLUGIN_ROOT = Path("/home/sgagnon/workspace_atlas/projects/atlas-dev-plugin-wt/v6-sprint1")
SKILLS_DIR = PLUGIN_ROOT / "skills"
PROFILES_DIR = PLUGIN_ROOT / "profiles"
OUT_CSV = PLUGIN_ROOT / "tests" / "inventory" / "skills-audit-v5.23.csv"
OUT_MD = PLUGIN_ROOT / "tests" / "inventory" / "skills-audit-v5.23-summary.md"
METADATA_YAML = SKILLS_DIR / "_metadata.yaml"


FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)
HARD_GATE_RE = re.compile(r"<HARD-GATE>", re.IGNORECASE)
RED_FLAGS_TAG_RE = re.compile(r"<red-flags>", re.IGNORECASE)
RED_FLAGS_TABLE_RE = re.compile(r"\|\s*Thought\s*\|\s*Reality\s*\|", re.IGNORECASE)


def parse_yaml_list_of_skills(yaml_path: Path) -> list[str]:
    """Very light YAML parse: extract `skills:` block entries (strings)."""
    if not yaml_path.exists():
        return []
    text = yaml_path.read_text(encoding="utf-8")
    skills: list[str] = []
    in_skills = False
    for raw in text.splitlines():
        line = raw.rstrip()
        if not line:
            continue
        stripped = line.lstrip()
        # Detect `skills:` section start
        if re.match(r"^skills\s*:\s*(#.*)?$", stripped) and not raw.startswith(" "):
            in_skills = True
            continue
        if in_skills:
            # Section ends when we hit another top-level key (no leading whitespace, has colon)
            if raw and not raw.startswith((" ", "\t", "-", "#")) and ":" in raw:
                in_skills = False
                continue
            m = re.match(r"^\s*-\s*([A-Za-z0-9_\-]+)\s*(#.*)?$", raw)
            if m:
                skills.append(m.group(1))
    return skills


def parse_metadata(yaml_path: Path) -> dict[str, dict[str, str]]:
    """Extract per-skill emoji+category from skills/_metadata.yaml (light parser)."""
    if not yaml_path.exists():
        return {}
    text = yaml_path.read_text(encoding="utf-8")
    result: dict[str, dict[str, str]] = {}
    current_skill: str | None = None
    in_skills_section = False
    # Matches indent=2 spaces for skill names under `skills:`
    for raw in text.splitlines():
        if re.match(r"^skills\s*:\s*(#.*)?$", raw):
            in_skills_section = True
            continue
        if not in_skills_section:
            continue
        # New skill: `  name:` (2 spaces + skill name)
        m_skill = re.match(r"^  ([a-zA-Z0-9_\-]+)\s*:\s*$", raw)
        if m_skill:
            current_skill = m_skill.group(1)
            result.setdefault(current_skill, {"emoji": "", "category": ""})
            continue
        if current_skill is None:
            continue
        m_emoji = re.match(r'^    emoji\s*:\s*"([^"]*)"', raw)
        if m_emoji:
            result[current_skill]["emoji"] = m_emoji.group(1)
            continue
        m_cat = re.match(r"^    category\s*:\s*(\S.*)$", raw)
        if m_cat:
            result[current_skill]["category"] = m_cat.group(1).strip().strip('"').strip("'")
    return result


def split_frontmatter(md_text: str) -> tuple[dict[str, str], str]:
    """Return (frontmatter_dict, body). Very light — just key: value lines."""
    m = FRONTMATTER_RE.match(md_text)
    if not m:
        return {}, md_text
    fm_text = m.group(1)
    body = md_text[m.end():]
    fm: dict[str, str] = {}
    # Handle nested keys lazily: only capture top-level `key: value` pairs
    for line in fm_text.splitlines():
        # Top-level key = no leading whitespace, contains colon
        m_kv = re.match(r"^([A-Za-z_][A-Za-z0-9_\-]*)\s*:\s*(.*)$", line)
        if m_kv:
            key = m_kv.group(1)
            value = m_kv.group(2).strip().strip('"').strip("'")
            fm[key] = value
    return fm, body


def determine_tiers_from_profiles() -> dict[str, list[str]]:
    """Return mapping skill_name -> list of tiers it appears in."""
    core = parse_yaml_list_of_skills(PROFILES_DIR / "core.yaml")
    dev = parse_yaml_list_of_skills(PROFILES_DIR / "dev-addon.yaml")
    admin = parse_yaml_list_of_skills(PROFILES_DIR / "admin-addon.yaml")
    mapping: dict[str, list[str]] = {}
    for skill in core:
        mapping.setdefault(skill, []).append("core")
    for skill in dev:
        mapping.setdefault(skill, []).append("dev")
    for skill in admin:
        mapping.setdefault(skill, []).append("admin")
    return mapping


def scan_skill(skill_dir: Path) -> dict | None:
    """Scan one skill directory for its SKILL.md and return audit row dict."""
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.exists():
        return None
    text = skill_md.read_text(encoding="utf-8")
    fm, body = split_frontmatter(text)
    lines_total = len(text.splitlines())
    rel_path = skill_md.relative_to(PLUGIN_ROOT).as_posix()
    skill_name = skill_dir.name

    return {
        "skill_name": skill_name,
        "path_relative": rel_path,
        "lines_total": lines_total,
        "has_frontmatter_name": bool(fm.get("name")),
        "has_frontmatter_description": bool(fm.get("description")),
        "has_frontmatter_effort": bool(fm.get("effort")),
        "has_frontmatter_thinking_mode": bool(fm.get("thinking_mode")),
        "has_frontmatter_see_also": bool(fm.get("see_also")),
        "has_hard_gate_tag": bool(HARD_GATE_RE.search(body)),
        "has_red_flags_table": bool(RED_FLAGS_TAG_RE.search(body) or RED_FLAGS_TABLE_RE.search(body)),
        "has_superpowers_pattern": bool(fm.get("superpowers_pattern")),
        "raw_description": fm.get("description", ""),
    }


def main() -> int:
    if not SKILLS_DIR.exists():
        print(f"skills dir not found: {SKILLS_DIR}", file=sys.stderr)
        return 1
    OUT_CSV.parent.mkdir(parents=True, exist_ok=True)

    tier_map = determine_tiers_from_profiles()
    metadata = parse_metadata(METADATA_YAML)

    # Collect refs/* skills too (reference-only skills, bundled as "refs" in profiles)
    rows = []
    top_level_dirs = [c for c in sorted(SKILLS_DIR.iterdir()) if c.is_dir() and c.name != "refs"]
    refs_dirs: list[Path] = []
    refs_root = SKILLS_DIR / "refs"
    if refs_root.exists():
        refs_dirs = [c for c in sorted(refs_root.iterdir()) if c.is_dir()]

    for child in top_level_dirs + refs_dirs:
        audit = scan_skill(child)
        if not audit:
            continue
        name = audit["skill_name"]
        # Tier: join list if skill appears in multiple profiles (e.g. dev+admin)
        is_ref = child.parent.name == "refs"
        tiers = tier_map.get(name, [])
        if is_ref:
            tier_str = "refs"
        else:
            tier_str = "|".join(tiers) if tiers else "shared"
        meta = metadata.get(name, {})
        category = meta.get("category", "")
        emoji = meta.get("emoji", "")
        rows.append(
            {
                "skill_name": name,
                "tier": tier_str,
                "path_relative": audit["path_relative"],
                "lines_total": audit["lines_total"],
                "has_frontmatter_name": audit["has_frontmatter_name"],
                "has_frontmatter_description": audit["has_frontmatter_description"],
                "has_frontmatter_effort": audit["has_frontmatter_effort"],
                "has_frontmatter_thinking_mode": audit["has_frontmatter_thinking_mode"],
                "has_frontmatter_see_also": audit["has_frontmatter_see_also"],
                "has_hard_gate_tag": audit["has_hard_gate_tag"],
                "has_red_flags_table": audit["has_red_flags_table"],
                "has_superpowers_pattern": audit["has_superpowers_pattern"],
                "category": category,
                "emoji": emoji,
                "_raw_description": audit["raw_description"],  # for summary report only
            }
        )

    # Write CSV (excluding _raw_description)
    cols = [
        "skill_name",
        "tier",
        "path_relative",
        "lines_total",
        "has_frontmatter_name",
        "has_frontmatter_description",
        "has_frontmatter_effort",
        "has_frontmatter_thinking_mode",
        "has_frontmatter_see_also",
        "has_hard_gate_tag",
        "has_red_flags_table",
        "has_superpowers_pattern",
        "category",
        "emoji",
    ]
    with OUT_CSV.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=cols, quoting=csv.QUOTE_MINIMAL)
        writer.writeheader()
        for row in rows:
            writer.writerow({k: row[k] for k in cols})

    # Compute summary metrics
    total = len(rows)
    by_tier_counts = {"core": 0, "dev": 0, "admin": 0, "shared_other": 0, "refs": 0}
    for r in rows:
        t = r["tier"]
        if t == "refs":
            by_tier_counts["refs"] += 1
            continue
        if "core" in t:
            by_tier_counts["core"] += 1
        if "dev" in t:
            by_tier_counts["dev"] += 1
        if "admin" in t:
            by_tier_counts["admin"] += 1
        if t in ("", "shared"):
            by_tier_counts["shared_other"] += 1

    def pct(key: str) -> float:
        return round(100.0 * sum(1 for r in rows if r[key]) / total, 1) if total else 0.0

    pct_effort = pct("has_frontmatter_effort")
    pct_thinking = pct("has_frontmatter_thinking_mode")
    pct_see_also = pct("has_frontmatter_see_also")
    pct_superpowers = pct("has_superpowers_pattern")
    pct_hard_gate = pct("has_hard_gate_tag")
    pct_red_flags = pct("has_red_flags_table")
    pct_description_present = pct("has_frontmatter_description")

    # Top 10 longest
    top_long = sorted(rows, key=lambda r: r["lines_total"], reverse=True)[:10]
    # Top 10 with short/missing description
    short_desc = [r for r in rows if len(r["_raw_description"]) < 20]
    short_desc_sorted = sorted(short_desc, key=lambda r: len(r["_raw_description"]))[:10]

    # Markdown summary
    md_lines: list[str] = []
    md_lines.append("# Skills Audit v5.23 — Baseline Summary")
    md_lines.append("")
    md_lines.append("> Source: `skills/*/SKILL.md` + `profiles/*.yaml` inheritance")
    md_lines.append("> Generated for v6.0 migration baseline (plan regarde-comment-adapter-atlas-compressed-wave Task 1.1)")
    md_lines.append("")
    md_lines.append("## Counts per tier (profile-listed, overlaps counted in each)")
    md_lines.append("")
    md_lines.append("| Tier | Skills | Expected |")
    md_lines.append("|---|---:|---:|")
    md_lines.append(f"| core | {by_tier_counts['core']} | 28 |")
    md_lines.append(f"| dev-addon | {by_tier_counts['dev']} | 36 |")
    md_lines.append(f"| admin-addon | {by_tier_counts['admin']} | 67 |")
    md_lines.append(f"| refs (reference docs) | {by_tier_counts['refs']} | — |")
    md_lines.append(f"| unclassified / shared | {by_tier_counts['shared_other']} | — |")
    md_lines.append(f"| **unique SKILL.md files** | **{total}** | ≥120 |")
    md_lines.append("")
    md_lines.append("## Frontmatter coverage (v6.0 migration baseline)")
    md_lines.append("")
    md_lines.append("| Field | Coverage | Target v6.0 | Baseline expected |")
    md_lines.append("|---|---:|---:|---:|")
    md_lines.append(f"| description | {pct_description_present}% | 100% | ~100% |")
    md_lines.append(f"| effort | {pct_effort}% | 100% | 0% (ALREADY STARTED — ~94% of non-refs) |")
    md_lines.append(f"| thinking_mode | {pct_thinking}% | 100% | 0% |")
    md_lines.append(f"| see_also | {pct_see_also}% | ≥50% | 0% |")
    md_lines.append(f"| superpowers_pattern | {pct_superpowers}% | ≥25% | 0% |")
    md_lines.append(f"| `<HARD-GATE>` in body | {pct_hard_gate}% | ≥8% (10 Tier-1) | 0% |")
    md_lines.append(f"| red-flags / Thought vs Reality | {pct_red_flags}% | ≥20% | 0% |")
    md_lines.append("")
    md_lines.append("## Top 10 longest skills (lines_total)")
    md_lines.append("")
    md_lines.append("| Skill | Lines | Tier |")
    md_lines.append("|---|---:|---|")
    for r in top_long:
        md_lines.append(f"| {r['skill_name']} | {r['lines_total']} | {r['tier']} |")
    md_lines.append("")
    md_lines.append("## Skills with short/missing description (<20 chars, top 10)")
    md_lines.append("")
    if not short_desc_sorted:
        md_lines.append("_None found — all frontmatter descriptions are ≥20 chars._")
    else:
        md_lines.append("| Skill | Description length | Preview |")
        md_lines.append("|---|---:|---|")
        for r in short_desc_sorted:
            preview = r["_raw_description"].replace("|", "\\|")[:40]
            md_lines.append(f"| {r['skill_name']} | {len(r['_raw_description'])} | {preview} |")

    md_lines.append("")
    md_lines.append(f"_CSV: `{OUT_CSV.relative_to(PLUGIN_ROOT).as_posix()}` — {total} rows._")
    OUT_MD.write_text("\n".join(md_lines) + "\n", encoding="utf-8")

    # Console summary
    print(f"Wrote: {OUT_CSV}")
    print(f"Wrote: {OUT_MD}")
    print(f"Rows: {total}  core={by_tier_counts['core']} dev={by_tier_counts['dev']} admin={by_tier_counts['admin']}")
    print(
        f"effort={pct_effort}% thinking_mode={pct_thinking}% see_also={pct_see_also}% "
        f"superpowers_pattern={pct_superpowers}% hard_gate={pct_hard_gate}% red_flags={pct_red_flags}%"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
