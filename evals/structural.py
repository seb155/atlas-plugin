"""Structural evaluator — automated skill quality scoring (no LLM needed).

Evaluates SKILL.md files on 9 dimensions using static analysis:
body quality, coherence, completeness, progressive disclosure,
cross-reference integrity, token budget, HITL coverage, tool patterns,
enterprise compliance.
"""

from __future__ import annotations

import re
from pathlib import Path

from .schema import (
    DimensionScore,
    EvalCase,
    EvalLevel,
    EvalScore,
    SkillType,
    StructuralCriteria,
)
from .scorer import build_eval_score


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# Approximate tokens per character (rough estimate for English text)
CHARS_PER_TOKEN = 4

# Section heading pattern (## or ###)
HEADING_RE = re.compile(r"^#{2,3}\s+.+", re.MULTILINE)

# Code block pattern
CODE_BLOCK_RE = re.compile(r"```[\s\S]*?```", re.MULTILINE)

# HITL gate indicators
HITL_PATTERNS = [
    "AskUserQuestion",
    "HITL",
    "human-in-the-loop",
    "user approval",
    "user confirmation",
    "confirm with user",
    "ask the user",
]

# Tool mention patterns
TOOL_PATTERNS = {
    "code-generation": ["Write", "Edit", "Bash", "pytest", "vitest", "test"],
    "planning": ["Read", "Glob", "Grep", "Agent", "AskUserQuestion"],
    "review": ["Read", "Grep", "Glob", "Bash", "git"],
    "ops": ["Bash", "docker", "ssh", "curl", "deploy"],
    "research": ["WebSearch", "WebFetch", "Read", "Grep"],
    "meta": ["Read", "Write", "TaskCreate", "TaskUpdate"],
}

# Enterprise rule keywords
ENTERPRISE_KEYWORDS = [
    "project_id",
    "RBAC",
    "audit",
    "security",
    "multi-tenant",
    "observab",
    "structlog",
    "backup",
]


# ---------------------------------------------------------------------------
# Dimension evaluators
# ---------------------------------------------------------------------------


def _eval_body_quality(body: str, criteria: StructuralCriteria) -> DimensionScore:
    """Evaluate body text quality: line count, sections, code blocks."""
    lines = body.strip().split("\n")
    line_count = len(lines)
    sections = len(HEADING_RE.findall(body))
    code_blocks = len(CODE_BLOCK_RE.findall(body))

    score = 100.0
    details_parts = []

    # Line count check
    if line_count < criteria.min_body_lines:
        penalty = min(30, (criteria.min_body_lines - line_count) * 3)
        score -= penalty
        details_parts.append(f"body too short ({line_count} < {criteria.min_body_lines} lines)")
    else:
        details_parts.append(f"{line_count} lines")

    # Section count (at least 2 expected)
    if sections < 2:
        score -= 15
        details_parts.append(f"few sections ({sections})")
    else:
        details_parts.append(f"{sections} sections")

    # Code blocks (helpful but not required)
    if code_blocks > 0:
        details_parts.append(f"{code_blocks} code blocks")

    return DimensionScore(
        name="body_quality",
        score=max(0, score),
        weight=15,
        details="; ".join(details_parts),
    )


def _eval_coherence(body: str) -> DimensionScore:
    """Evaluate structural coherence: headings order, orphan references."""
    headings = HEADING_RE.findall(body)
    score = 100.0
    details_parts = []

    # At least one H2 heading
    h2_count = sum(1 for h in headings if h.startswith("## ") and not h.startswith("### "))
    if h2_count == 0:
        score -= 20
        details_parts.append("no H2 headings")

    # Check for common orphan patterns (references to non-existent things)
    orphan_patterns = [
        (r"\bTODO\b", "has TODO"),
        (r"\bFIXME\b", "has FIXME"),
        (r"\bHACK\b", "has HACK"),
    ]
    for pattern, label in orphan_patterns:
        if re.search(pattern, body):
            score -= 5
            details_parts.append(label)

    if not details_parts:
        details_parts.append("coherent structure")

    return DimensionScore(
        name="coherence",
        score=max(0, score),
        weight=10,
        details="; ".join(details_parts),
    )


def _eval_completeness(
    body: str, criteria: StructuralCriteria
) -> DimensionScore:
    """Evaluate completeness: required sections present."""
    score = 100.0
    details_parts = []
    missing = []

    body_lower = body.lower()
    for section in criteria.required_sections:
        if section.lower() not in body_lower:
            missing.append(section)

    if missing:
        penalty = min(50, len(missing) * 15)
        score -= penalty
        details_parts.append(f"missing sections: {', '.join(missing)}")
    else:
        details_parts.append(f"all {len(criteria.required_sections)} required sections present")

    return DimensionScore(
        name="completeness",
        score=max(0, score),
        weight=15,
        details="; ".join(details_parts),
    )


def _eval_progressive_disclosure(body: str, criteria: StructuralCriteria) -> DimensionScore:
    """Evaluate progressive disclosure: overview → detail → edge cases."""
    score = 100.0
    details_parts = []

    headings = HEADING_RE.findall(body)
    h2_count = sum(1 for h in headings if h.startswith("## ") and not h.startswith("### "))
    h3_count = sum(1 for h in headings if h.startswith("### "))

    # Level 1: overview (at least one H2)
    # Level 2: detail (H3 subsections)
    # Level 3: edge cases / references / examples
    levels = 0
    if h2_count >= 1:
        levels += 1
    if h3_count >= 1:
        levels += 1
    if any(kw in body.lower() for kw in ["edge case", "exception", "when not to", "example", "reference"]):
        levels += 1

    target = criteria.progressive_disclosure_levels
    if levels < target:
        penalty = (target - levels) * 20
        score -= penalty
        details_parts.append(f"{levels}/{target} disclosure levels")
    else:
        details_parts.append(f"{levels} disclosure levels (target: {target})")

    return DimensionScore(
        name="progressive_disclosure",
        score=max(0, score),
        weight=10,
        details="; ".join(details_parts),
    )


def _eval_cross_references(
    body: str, criteria: StructuralCriteria, skills_on_disk: set[str]
) -> DimensionScore:
    """Evaluate cross-reference integrity: all mentioned skills/agents exist."""
    score = 100.0
    details_parts = []

    # Check explicitly required cross-refs
    missing_refs = []
    for ref in criteria.cross_references:
        if ref not in body:
            missing_refs.append(ref)

    if missing_refs:
        penalty = min(40, len(missing_refs) * 10)
        score -= penalty
        details_parts.append(f"missing refs: {', '.join(missing_refs)}")

    # Check backtick skill mentions resolve to real skills
    skill_mentions = re.findall(r"`(\w[\w-]+)`", body)
    broken = [m for m in skill_mentions if m in skills_on_disk and m not in body]
    # Only penalize if we find clearly broken references
    if broken:
        score -= len(broken) * 5
        details_parts.append(f"broken refs: {', '.join(broken)}")

    if not details_parts:
        details_parts.append("all references valid")

    return DimensionScore(
        name="cross_references",
        score=max(0, score),
        weight=10,
        details="; ".join(details_parts),
    )


def _eval_token_budget(body: str, criteria: StructuralCriteria) -> DimensionScore:
    """Evaluate token budget: estimated context cost."""
    estimated_tokens = len(body) // CHARS_PER_TOKEN
    score = 100.0
    details_parts = [f"~{estimated_tokens} tokens"]

    if estimated_tokens > criteria.max_token_estimate:
        overshoot = estimated_tokens - criteria.max_token_estimate
        penalty = min(40, overshoot // 100)
        score -= penalty
        details_parts.append(f"over budget by ~{overshoot} tokens")

    return DimensionScore(
        name="token_budget",
        score=max(0, score),
        weight=10,
        details="; ".join(details_parts),
    )


def _eval_hitl_coverage(body: str, criteria: StructuralCriteria) -> DimensionScore:
    """Evaluate HITL gate coverage: high-effort skills should have gates."""
    score = 100.0
    details_parts = []

    has_hitl = any(p.lower() in body.lower() for p in HITL_PATTERNS)

    if criteria.requires_hitl_gates and not has_hitl:
        score -= 30
        details_parts.append("requires HITL gates but none found")
    elif has_hitl:
        hitl_count = sum(1 for p in HITL_PATTERNS if p.lower() in body.lower())
        details_parts.append(f"{hitl_count} HITL gate indicators")
    else:
        details_parts.append("no HITL required")

    return DimensionScore(
        name="hitl_coverage",
        score=max(0, score),
        weight=10,
        details="; ".join(details_parts),
    )


def _eval_tool_patterns(body: str, skill_type: SkillType) -> DimensionScore:
    """Evaluate tool usage: skill references appropriate tools for its type."""
    score = 100.0
    details_parts = []

    expected_tools = TOOL_PATTERNS.get(skill_type.value, [])
    if not expected_tools:
        return DimensionScore(
            name="tool_patterns", score=100, weight=10, details="no specific tools expected"
        )

    found = [t for t in expected_tools if t.lower() in body.lower()]
    coverage = len(found) / len(expected_tools) if expected_tools else 1.0

    if coverage < 0.5:
        score -= 25
        details_parts.append(f"low tool coverage: {len(found)}/{len(expected_tools)}")
    else:
        details_parts.append(f"tools: {', '.join(found)} ({len(found)}/{len(expected_tools)})")

    return DimensionScore(
        name="tool_patterns",
        score=max(0, score),
        weight=10,
        details="; ".join(details_parts),
    )


def _eval_enterprise_compliance(body: str) -> DimensionScore:
    """Evaluate enterprise rule compliance: security, multi-tenant, observability."""
    score = 100.0
    details_parts = []

    found = [kw for kw in ENTERPRISE_KEYWORDS if kw.lower() in body.lower()]

    # Enterprise compliance is a bonus, not a penalty for most skills
    if found:
        details_parts.append(f"enterprise keywords: {', '.join(found)}")
    else:
        # Only minor penalty — not all skills need enterprise keywords
        score -= 10
        details_parts.append("no enterprise keywords found")

    return DimensionScore(
        name="enterprise_compliance",
        score=max(0, score),
        weight=10,
        details="; ".join(details_parts),
    )


# ---------------------------------------------------------------------------
# Main evaluator
# ---------------------------------------------------------------------------


def evaluate_skill_structural(
    skill_md_path: Path,
    eval_case: EvalCase | None = None,
    skills_on_disk: set[str] | None = None,
) -> EvalScore:
    """Run structural evaluation on a single SKILL.md.

    Args:
        skill_md_path: Path to the SKILL.md file
        eval_case: Optional eval case with specific criteria. Uses defaults if None.
        skills_on_disk: Set of known skill names for cross-ref validation.

    Returns:
        EvalScore with 9 dimension scores.
    """
    if not skill_md_path.exists():
        return build_eval_score(
            item_name=skill_md_path.parent.name,
            eval_level=EvalLevel.STRUCTURAL,
            dimensions=[],
            reasoning=f"SKILL.md not found: {skill_md_path}",
        )

    text = skill_md_path.read_text(encoding="utf-8")

    # Strip frontmatter
    body = text
    if text.startswith("---"):
        end = text.find("\n---", 3)
        if end != -1:
            body = text[end + 4:].strip()

    skill_name = skill_md_path.parent.name
    criteria = eval_case.structural if eval_case else StructuralCriteria()
    skill_type = eval_case.type if eval_case else SkillType.META

    dimensions = [
        _eval_body_quality(body, criteria),
        _eval_coherence(body),
        _eval_completeness(body, criteria),
        _eval_progressive_disclosure(body, criteria),
        _eval_cross_references(body, criteria, skills_on_disk or set()),
        _eval_token_budget(body, criteria),
        _eval_hitl_coverage(body, criteria),
        _eval_tool_patterns(body, skill_type),
        _eval_enterprise_compliance(body),
    ]

    return build_eval_score(
        item_name=skill_name,
        eval_level=EvalLevel.STRUCTURAL,
        dimensions=dimensions,
        reasoning=f"Structural eval of {skill_name}: {len(dimensions)} dimensions",
    )
