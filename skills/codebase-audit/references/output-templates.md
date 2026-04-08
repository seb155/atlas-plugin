# Output Templates — Codebase Audit Skill

> Canonical templates for all audit output formats.
> Variable injection points use `{variable_name}` syntax.

---

## 1. Chat Summary Template

The lead agent presents this in chat after scoring:

```
╔═════════════════════════════════════════════════════════════════╗
║              CODEBASE AUDIT — {date}                            ║
║  Stack: {stack}  |  Preset: {preset}  |  LOC: {loc}            ║
║  Overall: {score}/10  Grade: {grade}  Delta: {delta}            ║
╠══════════════════════╦═══════╦═══════╦═══════╦═════════════════╣
║ Dimension            ║ Score ║ Grade ║ Delta ║ Findings        ║
╠══════════════════════╬═══════╬═══════╬═══════╬═════════════════╣
║ 🔒 Security (14%)   ║  8.2  ║  B+   ║  +0.5 ║ 0P0 1P1 2P2    ║
║ 🧪 Testing (10%)    ║  5.0  ║  D    ║  --   ║ 0P0 2P1 3P2    ║
║ ... (all 20 dims)    ║       ║       ║       ║                 ║
╠══════════════════════╬═══════╬═══════╬═══════╬═════════════════╣
║ OVERALL              ║  7.3  ║  B-   ║  +0.2 ║ 2P0 8P1 15P2   ║
╚══════════════════════╩═══════╩═══════╩═══════╩═════════════════╝

Top Findings:
 🔴 P0: SQL injection in entity_serializer.py:165 (Security)
 🔴 P0: Docker socket mounted in dev compose (Infrastructure)
 🟠 P1: Frontend test coverage 12% (Testing)
 🟠 P1: 6 hardcoded IPs in config (Security)

Report: .blueprint/AUDIT-{date}.md
History: .blueprint/_audit-history/codebase-audit-{date}.json
```

---

## 2. MD Report Template

Full report written to `.blueprint/AUDIT-{YYYY-MM-DD}.md`:

```markdown
# Codebase Audit Report

| Field | Value |
|-------|-------|
| Date | {YYYY-MM-DD} |
| Stack | {backend} + {frontend} + {database} |
| Preset | {preset} |
| LOC | {total_loc} ({backend_loc} backend + {frontend_loc} frontend) |
| Files | {total_files} |
| Overall Score | {score}/10 |
| Grade | {grade} |
| Delta | {delta vs previous or "--"} |

## Executive Summary

{2-3 sentence ultrathink synthesis — what's strong, what's weak, what's the single most important thing to fix}

## Score Dashboard

{ASCII table identical to chat summary}

## Cross-Dimension Analysis

{Compound risks identified in Phase 6 SYNTHESIZE:}
- {risk 1}: {dim A} finding + {dim B} gap = compound risk
- {risk 2}: ...

## Industry Comparison

| Metric | This Codebase | Median | Top 10% | Top 1% |
|--------|--------------|--------|---------|--------|
| Overall | {score} | 5.0 | 7.5 | 9.0 |
| {top weighted dim} | {score} | ... | ... | ... |

## Dimension Details

### D1: Security 🔒 (Score: {X}/10, Grade: {G})

**Weight**: {W}% ({preset})

#### Findings
| # | Sev | Check | File:Line | Issue | Evidence |
|---|-----|-------|-----------|-------|----------|
| 1 | P0 | secrets.hardcoded | config.py:42 | Hardcoded DB URL | `DATABASE_URL = "postgresql://..."` |

#### Positive Signals
- gitleaks integrated in CI
- RBAC on all API endpoints

{Repeat for all 20 dimensions}

## Remediation Roadmap

### Phase 1: Immediate (Week 1) — {N} P0 findings, ~{H}h
| # | Dim | Finding | Effort | Action |
|---|-----|---------|--------|--------|

### Phase 2: Short-term (Week 2-3) — {N} P1 findings, ~{H}h
| # | Dim | Finding | Effort | Action |
|---|-----|---------|--------|--------|

### Phase 3: Medium-term (Month 1) — {N} P2 findings, ~{H}h
| # | Dim | Finding | Effort | Action |
|---|-----|---------|--------|--------|

### Phase 4: Ongoing — {N} P3 + INFO findings
| # | Dim | Finding | Effort | Action |
|---|-----|---------|--------|--------|

## Audit Metadata

| Field | Value |
|-------|-------|
| Duration | {minutes} min |
| Agents | {count} ({sonnet} Sonnet + {haiku} Haiku) |
| Mode | {full/quick/custom} |
| Config | {config_path or "auto-detected"} |
| Previous | {previous_path or "none"} |
| Git SHA | {sha} |
| Git Branch | {branch} |
```

---

## 3. JSON History Schema

Full audit result saved to `.blueprint/_audit-history/codebase-audit-{date}.json`:

```json
{
  "version": "1.0",
  "date": "2026-04-08T15:30:00Z",
  "git_sha": "abc1234def",
  "git_branch": "main",
  "preset": "synapse",
  "stack": {
    "backend": "python-fastapi",
    "frontend": "react-typescript",
    "database": "postgresql",
    "infra": "docker"
  },
  "loc": {
    "total": 479188,
    "backend": 285000,
    "frontend": 194188
  },
  "overall_score": 7.34,
  "grade": "B-",
  "mode": "full",
  "dimensions": {
    "security": {
      "score": 8.2,
      "grade": "B+",
      "weight_pct": 0.14,
      "weighted_contribution": 1.148,
      "findings": {
        "p0": 0,
        "p1": 1,
        "p2": 2,
        "p3": 3
      },
      "agent": "security-agent",
      "model": "sonnet",
      "positive_signals": ["gitleaks CI", "RBAC endpoints"]
    }
  },
  "cross_dimension_risks": [
    "SQL injection (security) + missing error handling (quality) + no monitoring (observability)"
  ],
  "total_findings": {
    "p0": 2,
    "p1": 8,
    "p2": 15,
    "p3": 12,
    "info": 5
  },
  "remediation_hours": {
    "phase1_immediate": 22,
    "phase2_short": 64,
    "phase3_medium": 136,
    "phase4_ongoing": 106,
    "total": 328
  },
  "metadata": {
    "duration_seconds": 720,
    "agents_dispatched": 9,
    "agents_completed": 9,
    "agents_timeout": 0,
    "config_path": ".blueprint/audit-config.yaml"
  },
  "delta": {
    "previous_date": "2026-03-25",
    "previous_sha": "def5678",
    "overall_delta": 0.34,
    "new_findings": 3,
    "resolved_findings": 5,
    "dimension_deltas": {
      "security": 0.5,
      "testing": -0.2
    }
  }
}
```

---

## 4. JSONL History Line

One line per audit appended to `.blueprint/_audit-history/codebase-audit-history.jsonl`:

```json
{"date":"2026-04-08","sha":"abc1234","preset":"synapse","score":7.34,"grade":"B-","p0":2,"p1":8,"p2":15,"p3":12,"mode":"full","agents":9,"duration_s":720}
```

---

## 5. HITL Finding Review Format

For each P0 CRITICAL finding presented via AskUserQuestion:

```
🔴 P0 CRITICAL [{dim_id}:{finding_id}] {title}

File: {path}:{line}
Evidence: {truncated command output or code excerpt, max 3 lines}
Effort: ~{hours}h to remediate
Recommendation: {brief action}
```

Options: Confirm severity / Override to P1 / False positive / Accept risk

---

## 6. Config YAML Template

Default config generated when none exists:

```yaml
# .blueprint/audit-config.yaml
# Generated by codebase-audit — edit weights or toggle dimensions
audit:
  version: "1.0"
  preset: "{auto_detected}"

  dimensions:
    mode: "all"       # all | quick | custom
    # custom_list: [security, testing, architecture]  # when mode=custom

  paths:
    exclude:
      - node_modules
      - .git
      - dist
      - __pycache__
      - "*.min.js"
      - venv
      - .venv

  agents:
    heavy_model: "sonnet"
    light_model: "haiku"
    max_parallel: 9
    timeout_minutes: 10

  output:
    path: ".blueprint/AUDIT-{date}.md"
    history: ".blueprint/_audit-history/"
    include_evidence: true
    include_positive: true

  compare:
    previous: null     # path to previous JSON for delta
    track_history: true
```
