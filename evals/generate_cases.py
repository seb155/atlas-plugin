#!/usr/bin/env python3
"""Generate eval case YAML files for all skills.

Run: python3 evals/generate_cases.py
Creates evals/cases/{skill-name}.yaml for each skill.
"""

from pathlib import Path

import yaml

PLUGIN_ROOT = Path(__file__).parent.parent
SKILLS_DIR = PLUGIN_ROOT / "skills"
CASES_DIR = PLUGIN_ROOT / "evals" / "cases"

# ---------------------------------------------------------------------------
# Skill type mapping
# ---------------------------------------------------------------------------

SKILL_TYPE_MAP: dict[str, str] = {
    # code-generation
    "tdd": "code-generation",
    "frontend-design": "code-generation",
    "hookify": "code-generation",
    "plugin-builder": "code-generation",
    # planning
    "plan-builder": "planning",
    "brainstorming": "planning",
    "executing-plans": "planning",
    # review
    "code-review": "review",
    "code-simplify": "review",
    "enterprise-audit": "review",
    "security-audit": "review",
    # ops
    "devops-deploy": "ops",
    "infrastructure-ops": "ops",
    "verification": "ops",
    "finishing-branch": "ops",
    # research
    "deep-research": "research",
    "context-discovery": "research",
    "knowledge-builder": "research",
    "knowledge-manager": "research",
    # meta
    "decision-log": "meta",
    "session-retrospective": "meta",
    "scope-check": "meta",
    "skill-management": "meta",
    "eval-lifecycle": "meta",
    # personal
    "note-capture": "personal",
    "morning-brief": "personal",
    "user-profiler": "personal",
    "reminder-scheduler": "personal",
    # domain
    "engineering-ops": "domain",
    "feature-board": "domain",
    "swimlane-tracker": "domain",
    "opex-dashboard": "domain",
    "rollout-tracker": "domain",
    "resource-planner": "domain",
    # workflow
    "atlas-assist": "workflow",
    "git-worktrees": "workflow",
    "subagent-dispatch": "workflow",
    "experiment-loop": "workflow",
    "test-orchestrator": "workflow",
    "platform-update": "workflow",
    # presentation
    "document-generator": "presentation",
    "browser-automation": "presentation",
    # reference (lighter eval)
    "composition-patterns": "reference",
    "react-best-practices": "reference",
    "web-design-guidelines": "reference",
    "gmining-excel": "reference",
    "systematic-debugging": "ops",
}

# ---------------------------------------------------------------------------
# Structural criteria per type
# ---------------------------------------------------------------------------

STRUCTURAL_DEFAULTS: dict[str, dict] = {
    "code-generation": {
        "min_body_lines": 30,
        "required_sections": ["Test", "Commit"],
        "required_tool_mentions": ["Write", "Edit", "Bash"],
        "max_token_estimate": 3000,
        "requires_hitl_gates": False,
    },
    "planning": {
        "min_body_lines": 40,
        "required_sections": ["Phase", "Output"],
        "required_tool_mentions": ["Read", "Glob", "Agent"],
        "max_token_estimate": 4000,
        "requires_hitl_gates": True,
    },
    "review": {
        "min_body_lines": 30,
        "required_sections": ["Dimension", "Score"],
        "required_tool_mentions": ["Read", "Grep"],
        "max_token_estimate": 4000,
        "requires_hitl_gates": True,
    },
    "ops": {
        "min_body_lines": 25,
        "required_sections": ["Command", "Verification"],
        "required_tool_mentions": ["Bash"],
        "max_token_estimate": 3000,
        "requires_hitl_gates": True,
    },
    "research": {
        "min_body_lines": 25,
        "required_sections": ["Method", "Output"],
        "required_tool_mentions": ["WebSearch", "Read"],
        "max_token_estimate": 3000,
        "requires_hitl_gates": False,
    },
    "meta": {
        "min_body_lines": 15,
        "required_sections": [],
        "required_tool_mentions": [],
        "max_token_estimate": 2000,
        "requires_hitl_gates": False,
    },
    "personal": {
        "min_body_lines": 15,
        "required_sections": [],
        "required_tool_mentions": [],
        "max_token_estimate": 2000,
        "requires_hitl_gates": False,
    },
    "domain": {
        "min_body_lines": 20,
        "required_sections": [],
        "required_tool_mentions": ["Read"],
        "max_token_estimate": 3000,
        "requires_hitl_gates": False,
    },
    "workflow": {
        "min_body_lines": 20,
        "required_sections": [],
        "required_tool_mentions": [],
        "max_token_estimate": 4000,
        "requires_hitl_gates": False,
    },
    "presentation": {
        "min_body_lines": 20,
        "required_sections": [],
        "required_tool_mentions": ["Write"],
        "max_token_estimate": 3000,
        "requires_hitl_gates": True,
    },
    "reference": {
        "min_body_lines": 30,
        "required_sections": [],
        "required_tool_mentions": [],
        "max_token_estimate": 6000,
        "requires_hitl_gates": False,
    },
}

# ---------------------------------------------------------------------------
# Behavioral cases (priority skills get richer cases)
# ---------------------------------------------------------------------------

BEHAVIORAL_CASES: dict[str, list[dict]] = {
    "tdd": [
        {
            "id": "tdd-001",
            "name": "Basic TDD for Python function",
            "input": "Write a function validate_isa_tag(tag) that checks ISA-5.1 tag format XX-NNNN. Use TDD.",
            "expected_contains": ["test_", "assert", "def validate"],
            "expected_order": ["failing test", "implementation"],
            "ground_truth": "Test file first with 3+ cases (valid, invalid, edge), then implementation.",
        },
        {
            "id": "tdd-002",
            "name": "TDD for React hook",
            "input": "Create a useDebounce hook with configurable delay. TDD approach.",
            "expected_contains": ["test", "describe", "useDebounce", "setTimeout"],
            "expected_order": ["test file", "hook implementation"],
            "ground_truth": "Test with vitest/RTL first, then implement hook with cleanup.",
        },
    ],
    "plan-builder": [
        {
            "id": "plan-001",
            "name": "Feature plan for auth system",
            "input": "Plan implementing JWT authentication with refresh tokens for Synapse.",
            "expected_contains": ["Phase", "security", "RBAC", "migration"],
            "ground_truth": "15-section plan with security analysis, DB schema, API endpoints, tests.",
        },
        {
            "id": "plan-002",
            "name": "Refactoring plan",
            "input": "Plan refactoring the import pipeline from monolith to pipeline pattern.",
            "expected_contains": ["Phase", "existing code", "migration", "rollback"],
            "ground_truth": "Inventory of existing code, phased migration, backwards compat strategy.",
        },
    ],
    "code-review": [
        {
            "id": "review-001",
            "name": "Review a FastAPI endpoint",
            "input": "Review this PR: new endpoint POST /api/v1/instruments with CRUD operations.",
            "expected_contains": ["security", "validation", "test", "error handling"],
            "ground_truth": "Check auth, input validation, SQL injection, error responses, test coverage.",
        },
        {
            "id": "review-002",
            "name": "Review React component",
            "input": "Review a new DataGrid component with 500 lines of code.",
            "expected_contains": ["performance", "accessibility", "type safety"],
            "ground_truth": "Check memoization, a11y, TypeScript strict, component size, extract hooks.",
        },
    ],
    "verification": [
        {
            "id": "verify-001",
            "name": "Full verification pipeline",
            "input": "Run full L1-L6 verification on the instruments feature.",
            "expected_contains": ["pytest", "vitest", "type-check", "security"],
            "ground_truth": "Run all 6 levels sequentially, report per-level results, update FEATURES.md.",
        },
    ],
    "enterprise-audit": [
        {
            "id": "audit-001",
            "name": "Full enterprise audit",
            "input": "Run enterprise audit on Synapse for G Mining due diligence.",
            "expected_contains": ["security", "multi-tenant", "grade", "remediation"],
            "ground_truth": "14-dimension audit, weighted scoring, A-F grade, remediation plan.",
        },
    ],
    "security-audit": [
        {
            "id": "security-001",
            "name": "OWASP security scan",
            "input": "Run security audit focusing on OWASP Top 10.",
            "expected_contains": ["injection", "XSS", "authentication", "CRITICAL"],
            "ground_truth": "Check all OWASP categories, severity classification, remediation steps.",
        },
    ],
    "devops-deploy": [
        {
            "id": "deploy-001",
            "name": "Production deployment",
            "input": "Deploy latest changes to production environment.",
            "expected_contains": ["health check", "rollback", "backup"],
            "ground_truth": "Pre-flight checks, deploy, health verify, rollback plan documented.",
        },
    ],
    "frontend-design": [
        {
            "id": "design-001",
            "name": "Implement dashboard card",
            "input": "Create a KPI summary card component for the eval dashboard.",
            "expected_contains": ["syn-", "aria-", "LucideIcon", "loading"],
            "ground_truth": "Use syn-* theme vars, Lucide icons, loading+error+empty states, a11y.",
        },
    ],
}


def get_all_skills() -> list[str]:
    """Collect all skill names from disk."""
    names = []
    for d in sorted(SKILLS_DIR.iterdir()):
        if not d.is_dir():
            continue
        if d.name == "refs":
            for sub in sorted(d.iterdir()):
                if sub.is_dir():
                    names.append(sub.name)
        else:
            names.append(d.name)
    return names


def generate_case(skill_name: str) -> dict:
    """Generate eval case dict for a skill."""
    skill_type = SKILL_TYPE_MAP.get(skill_name, "meta")
    structural_defaults = STRUCTURAL_DEFAULTS.get(skill_type, STRUCTURAL_DEFAULTS["meta"])

    case: dict = {
        "skill": skill_name,
        "version": "1.0",
        "type": skill_type,
        "structural": structural_defaults,
    }

    # Add behavioral cases if available
    if skill_name in BEHAVIORAL_CASES:
        case["behavioral"] = {"cases": BEHAVIORAL_CASES[skill_name]}

    return case


def main() -> None:
    CASES_DIR.mkdir(parents=True, exist_ok=True)

    skills = get_all_skills()
    created = 0
    updated = 0

    for skill_name in skills:
        case_path = CASES_DIR / f"{skill_name}.yaml"
        case_data = generate_case(skill_name)

        if case_path.exists():
            # Don't overwrite existing cases
            print(f"  SKIP {skill_name} (exists)")
            continue

        with open(case_path, "w", encoding="utf-8") as f:
            yaml.dump(case_data, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
        created += 1
        print(f"  CREATE {skill_name}.yaml ({case_data['type']})")

    print(f"\nDone: {created} created, {len(skills) - created} skipped")


if __name__ == "__main__":
    main()
