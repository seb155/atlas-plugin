---
name: skill-security-audit
description: "Scan ATLAS skills and hooks for security anti-patterns: eval injection, unquoted vars, secrets, HITL bypass, overly broad permissions. Produces severity report. Triggers on: 'audit skills', 'skill security', 'plugin security'."
effort: medium
triggers: ["audit skills", "skill security", "plugin security", "scan hooks"]
---

# Skill Security Auditor — Plugin Self-Scan

Scan ATLAS plugin skills, hooks, and agents for security anti-patterns.
Distinct from `security-audit` (which scans the application). This scans the **plugin itself**.

## When to Use

- Before publishing a plugin version to marketplace
- After adding a new hook or skill
- Periodic hygiene check (monthly recommended)
- Before opening marketplace to external contributors

## Scan Categories

### 1. Hook Scripts (`hooks/*`)

| Check | Severity | Pattern |
|-------|----------|---------|
| `eval` usage | CRITICAL | `eval $` or `eval "` — command injection risk |
| Unquoted variables | HIGH | `$VAR` instead of `"$VAR"` in commands |
| Pipe to shell | CRITICAL | `curl ... \| bash` or `wget ... \| sh` |
| Missing safety | MEDIUM | No `set -euo pipefail` at script start |
| Hardcoded secrets | CRITICAL | Patterns: `password=`, `token=`, `secret=`, `api_key=` |
| Unsafe temp files | MEDIUM | `mktemp` without cleanup trap |
| World-readable output | LOW | Writing to `/tmp` without restricted permissions |

### 2. SKILL.md Files (`skills/*/SKILL.md`)

| Check | Severity | Pattern |
|-------|----------|---------|
| HITL bypass instructions | HIGH | "skip HITL", "no confirmation needed", "auto-approve" |
| Unrestricted file writes | MEDIUM | Instructions to write outside project dir |
| Credential handling | HIGH | Instructions to read/store passwords, tokens |
| External URL fetching | MEDIUM | Instructions to fetch from hardcoded external URLs |
| Privilege escalation | HIGH | Instructions to use `sudo`, `chmod 777`, etc. |

### 3. Agent Definitions (`agents/*/agent.md`)

| Check | Severity | Pattern |
|-------|----------|---------|
| Overly broad tool access | MEDIUM | "All tools" without explicit exclusions |
| Missing scope restrictions | LOW | No `cwd` or `allowed_paths` constraints |
| Network access without justification | MEDIUM | WebFetch/WebSearch without clear reason |

## Process

1. **Scan hooks directory**:
   ```bash
   cd "${CLAUDE_PLUGIN_ROOT}"
   for f in hooks/*; do
     [ -f "$f" ] || continue
     # Run checks against each hook script
   done
   ```

2. **Scan skills**:
   ```bash
   for f in skills/*/SKILL.md; do
     [ -f "$f" ] || continue
     # Run checks against each SKILL.md
   done
   ```

3. **Scan agents**:
   ```bash
   for f in agents/*/agent.md; do
     [ -f "$f" ] || continue
     # Run checks against each agent definition
   done
   ```

4. **Produce report**:
   ```
   ## ATLAS Plugin Security Audit Report
   **Date**: {YYYY-MM-DD HH:MM TZ}
   **Version**: {VERSION}
   **Scanned**: {X} hooks, {Y} skills, {Z} agents

   ### Findings

   | # | Severity | File | Check | Line | Detail |
   |---|----------|------|-------|------|--------|
   | 1 | CRITICAL | hooks/example | eval usage | L42 | eval "$INPUT" |
   | 2 | HIGH | skills/x/SKILL.md | HITL bypass | L30 | "skip confirmation" |

   ### Summary
   - CRITICAL: {count}
   - HIGH: {count}
   - MEDIUM: {count}
   - LOW: {count}

   ### Verdict: {PASS | FAIL}
   FAIL if any CRITICAL or 3+ HIGH findings.
   ```

## Automated Test Integration

The scan is also available as a pytest test:
```bash
python -m pytest tests/test_skill_security.py -x -q --tb=short
```
This test fails on CRITICAL findings, warns on HIGH.

## Notes

- This is a **static analysis** tool — it checks patterns, not runtime behavior
- False positives are expected for some patterns (e.g., `eval` in comments)
- Always review findings manually before acting
- The test is part of CI pipeline (warn-only, not blocking)

$ARGUMENTS
