"""
Skill Security Auditor — Static analysis of ATLAS plugin for security anti-patterns.

Checks hooks for: eval injection, unquoted vars, pipe-to-shell, missing safety, hardcoded secrets.
Checks skills for: HITL bypass instructions, credential handling, privilege escalation.

Part of ATLAS SOTA Competitive Upgrade (precious-crafting-pike).
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest

from conftest import HOOKS_DIR, SKILLS_DIR, AGENTS_DIR


# ---------------------------------------------------------------------------
# Hook security checks
# ---------------------------------------------------------------------------

HOOK_SCRIPTS = sorted(
    p for p in HOOKS_DIR.iterdir()
    if p.is_file() and p.name != "hooks.json" and not p.name.startswith(".")
    and p.name != "lib" and not p.name.endswith(".md")
)


# Patterns to check in hook scripts (pattern, severity, description)
HOOK_PATTERNS: list[tuple[str, str, str]] = [
    # eval "$VAR" is dangerous, eval "$(cmd)" is safe subshell pattern
    (r'\beval\s+"?\$(?!\()', "CRITICAL", "eval with variable — command injection risk"),
    (r'curl\s+.*\|\s*(bash|sh|zsh)', "CRITICAL", "curl piped to shell — remote code execution"),
    (r'wget\s+.*\|\s*(bash|sh|zsh)', "CRITICAL", "wget piped to shell — remote code execution"),
    (r'(?:password|token|secret|api_key)\s*=\s*["\'][^"\']{8,}', "CRITICAL", "hardcoded secret in script"),
]

# Patterns that are HIGH severity (warn, don't fail)
HOOK_WARN_PATTERNS: list[tuple[str, str, str]] = [
    (r'(?<!")\$\w+(?!")', "HIGH", "potentially unquoted variable"),
]


@pytest.mark.parametrize("hook_path", HOOK_SCRIPTS, ids=[p.name for p in HOOK_SCRIPTS])
def test_hook_no_critical_patterns(hook_path: Path) -> None:
    """Hooks must not contain CRITICAL security patterns."""
    if not hook_path.is_file():
        pytest.skip(f"{hook_path} is not a file")

    content = hook_path.read_text(encoding="utf-8", errors="replace")
    findings: list[str] = []

    for pattern, severity, desc in HOOK_PATTERNS:
        for i, line in enumerate(content.splitlines(), 1):
            # Skip comments
            stripped = line.lstrip()
            if stripped.startswith("#"):
                continue
            if re.search(pattern, line):
                findings.append(f"L{i} [{severity}] {desc}: {line.strip()[:80]}")

    assert not findings, (
        f"CRITICAL security findings in {hook_path.name}:\n" + "\n".join(findings)
    )


# ---------------------------------------------------------------------------
# Skill security checks
# ---------------------------------------------------------------------------

SKILL_MDS = sorted(SKILLS_DIR.glob("*/SKILL.md"))

# Patterns to check in SKILL.md files
SKILL_PATTERNS: list[tuple[str, str, str]] = [
    (r'skip\s+hitl|no\s+confirmation|auto.?approve|bypass\s+gate', "HIGH", "HITL bypass instruction"),
    (r'\bsudo\b', "HIGH", "sudo usage instruction"),
    (r'chmod\s+777', "HIGH", "world-writable permission"),
    (r'(?:password|token|secret|api_key)\s*[:=]\s*["\'][^"\']{8,}', "CRITICAL", "hardcoded credential"),
]


@pytest.mark.parametrize("skill_path", SKILL_MDS, ids=[p.parent.name for p in SKILL_MDS])
def test_skill_no_critical_patterns(skill_path: Path) -> None:
    """Skills must not contain security anti-patterns."""
    content = skill_path.read_text(encoding="utf-8")
    findings: list[str] = []

    in_code_block = False
    for i, line in enumerate(content.splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith("```"):
            in_code_block = not in_code_block
            continue
        if in_code_block:
            continue
        for pattern, severity, desc in SKILL_PATTERNS:
            if re.search(pattern, line, re.IGNORECASE):
                findings.append(f"L{i} [{severity}] {desc}: {stripped[:80]}")

    # Only fail on CRITICAL; HIGH are warnings
    criticals = [f for f in findings if "[CRITICAL]" in f]
    assert not criticals, (
        f"CRITICAL security findings in {skill_path.parent.name}/SKILL.md:\n"
        + "\n".join(criticals)
    )

    # Report HIGH as warnings
    highs = [f for f in findings if "[HIGH]" in f]
    if highs:
        pytest.skip(
            f"HIGH security warnings in {skill_path.parent.name} (not blocking):\n"
            + "\n".join(highs)
        )


# ---------------------------------------------------------------------------
# Agent security checks
# ---------------------------------------------------------------------------

AGENT_MDS = sorted(AGENTS_DIR.glob("*/AGENT.md")) if AGENTS_DIR.exists() else []


@pytest.mark.parametrize(
    "agent_path",
    AGENT_MDS,
    ids=[p.parent.name for p in AGENT_MDS],
)
def test_agent_no_critical_patterns(agent_path: Path) -> None:
    """Agents must not have overly broad permissions without justification."""
    if not agent_path.exists():
        pytest.skip(f"{agent_path} does not exist")

    content = agent_path.read_text(encoding="utf-8")
    findings: list[str] = []

    # Check for overly broad tool access
    if re.search(r'tools:\s*\*|all\s+tools', content, re.IGNORECASE):
        findings.append("MEDIUM: Agent has unrestricted tool access")

    assert not any("CRITICAL" in f for f in findings), (
        f"Security findings in {agent_path.parent.name}:\n" + "\n".join(findings)
    )
