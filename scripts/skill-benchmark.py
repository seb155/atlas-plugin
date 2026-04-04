#!/usr/bin/env python3
"""
skill-benchmark.py — Score each skill on 5 quality dimensions.

Usage: python3 scripts/skill-benchmark.py [--json] [--min-score N]

Scoring (0-10 per dimension, 50 max):
  1. Frontmatter completeness (name, description, effort, triggers)
  2. Body richness (sections, examples, code blocks)
  3. Trigger coverage (When to Use section with clear patterns)
  4. Reference density (cross-references to other skills/docs)
  5. Template structure (output format templates, AskUserQuestion patterns)
"""

import json
import re
import sys
from pathlib import Path

SKILLS_DIR = Path(__file__).parent.parent / "skills"
CONTAINER_DIRS = {"refs"}


def find_all_skills() -> list[Path]:
    """Find all skill directories."""
    dirs = []
    for d in sorted(SKILLS_DIR.iterdir()):
        if not d.is_dir() or d.name.startswith("_"):
            continue
        if d.name in CONTAINER_DIRS:
            for sub in sorted(d.iterdir()):
                if sub.is_dir():
                    dirs.append(sub)
        else:
            dirs.append(d)
    return dirs


def score_skill(skill_dir: Path) -> dict:
    """Score a single skill on 5 dimensions."""
    md = skill_dir / "SKILL.md"
    if not md.exists():
        return {"name": skill_dir.name, "total": 0, "scores": {}, "missing": True}

    content = md.read_text()

    # Parse frontmatter
    fm_match = re.match(r"^---\n(.*?)\n---", content, re.DOTALL)
    fm_text = fm_match.group(1) if fm_match else ""
    body = content[fm_match.end():] if fm_match else content

    scores = {}

    # 1. Frontmatter completeness (0-10)
    fm_fields = {"name": 3, "description": 3, "effort": 2}
    fm_score = 0
    for field, weight in fm_fields.items():
        if re.search(rf"^{field}:", fm_text, re.MULTILINE):
            fm_score += weight
    # Bonus for triggers in description
    if "trigger" in fm_text.lower() or "use when" in fm_text.lower():
        fm_score = min(10, fm_score + 2)
    scores["frontmatter"] = min(10, fm_score)

    # 2. Body richness (0-10)
    h2_count = len(re.findall(r"^##\s+", body, re.MULTILINE))
    code_blocks = len(re.findall(r"```", body))
    body_len = len(body)
    richness = min(3, h2_count) + min(3, code_blocks // 2) + min(4, body_len // 500)
    scores["body_richness"] = min(10, richness)

    # 3. Trigger coverage (0-10)
    has_when = bool(re.search(r"when to use|triggers?|use when", body, re.IGNORECASE))
    trigger_patterns = len(re.findall(r"(/atlas|/[a-z-]+|user (says|asks|mentions))", body, re.IGNORECASE))
    trigger_score = (5 if has_when else 0) + min(5, trigger_patterns)
    scores["trigger_coverage"] = min(10, trigger_score)

    # 4. Reference density (0-10)
    cross_refs = len(re.findall(r"`[a-z-]+`", body))  # backtick references
    file_refs = len(re.findall(r"[a-z_-]+\.(md|yaml|json|sh|ts|py)", body))
    ref_score = min(5, cross_refs // 3) + min(5, file_refs)
    scores["reference_density"] = min(10, ref_score)

    # 5. Template structure (0-10)
    has_format = bool(re.search(r"format|template|output", body, re.IGNORECASE))
    has_ask = "AskUserQuestion" in body
    has_process = bool(re.search(r"^### (Step|Phase|Process)", body, re.MULTILINE))
    has_tables = len(re.findall(r"\|.*\|.*\|", body))
    template_score = (
        (3 if has_format else 0)
        + (2 if has_ask else 0)
        + (3 if has_process else 0)
        + min(2, has_tables // 2)
    )
    scores["template_structure"] = min(10, template_score)

    total = sum(scores.values())
    return {"name": skill_dir.name, "total": total, "scores": scores}


def main():
    json_mode = "--json" in sys.argv
    min_score = 0
    for i, arg in enumerate(sys.argv):
        if arg == "--min-score" and i + 1 < len(sys.argv):
            min_score = int(sys.argv[i + 1])

    skills = find_all_skills()
    results = [score_skill(d) for d in skills]
    results.sort(key=lambda r: -r["total"])

    if json_mode:
        print(json.dumps(results, indent=2))
        return

    print(f"\n{'Skill':<35} {'FM':>3} {'Body':>5} {'Trig':>5} {'Refs':>5} {'Tmpl':>5} {'Total':>6}")
    print("─" * 67)

    for r in results:
        if r.get("missing"):
            continue
        s = r["scores"]
        marker = "⚠️" if r["total"] < min_score else "  "
        print(
            f"{marker}{r['name']:<33} {s['frontmatter']:>3} {s['body_richness']:>5} "
            f"{s['trigger_coverage']:>5} {s['reference_density']:>5} "
            f"{s['template_structure']:>5} {r['total']:>6}/50"
        )

    avg = sum(r["total"] for r in results if not r.get("missing")) / max(1, len(results))
    below = sum(1 for r in results if r["total"] < 20 and not r.get("missing"))
    print(f"\n{'Total skills:':<35} {len(results)}")
    print(f"{'Average score:':<35} {avg:.1f}/50")
    print(f"{'Below 20/50:':<35} {below}")


if __name__ == "__main__":
    main()
