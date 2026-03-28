---
name: self-propose
description: "Self-improvement engine. Aggregates dream reports, retrospectives, workflow analytics, and intuitions to propose system improvements. Monthly or on-demand. HITL on every change. Use when 'self-propose', 'improve yourself', 'what should we fix', 'suggest improvements', 'auto-improve', 'monthly review'."
effort: high
---

# Self-Propose — MAPE-K Self-Improvement Engine

> The system that improves itself. Aggregates all learning signals into ranked
> improvement proposals. HITL gate on every change — the system PROPOSES,
> the human APPROVES.

## When to Use

- Monthly (end of month) or /atlas self-propose
- After a sprint retrospective
- When you feel the workflow is suboptimal
- When dream reports consistently flag the same issues

## Process

### Step 1: Gather Signals

Read all available learning data:

1. **Dream reports** (last 4 cycles):
   ```bash
   ls -t memory/dream-report-*.md | head -4
   ```
   Extract: health scores, D1-D16 trends, recommendations, patterns detected

2. **Session retrospectives** (last 30 days):
   ```bash
   grep -l "retrospective\|handoff" .blueprint/handoffs/handoff-*.md | head -10
   ```
   Extract: "what went wrong", blockers, dead-ends, carry-forward items

3. **Workflow analytics** (if Phase 2.7 data available):
   - Unused skills, high-error skills, slow skills

4. **Intuition files**:
   ```bash
   ls memory/intuition-*.md 2>/dev/null
   ```
   Extract: unvalidated intuitions, especially those with rising confidence

5. **Feedback files** (read-only — never propose modifying):
   ```bash
   ls memory/feedback*.md | wc -l
   ```
   Check: are feedback rules being followed? Any patterns of repeated corrections?

6. **Episode energy trends** (if experiential data exists):
   - Declining energy patterns
   - Frequent blockers
   - Context-switch overload signals

### Step 2: Analyze Patterns

Cross-reference signals to identify improvement themes:

| Theme | Signal Sources | Example |
|-------|---------------|---------|
| Workflow friction | Retro dead-ends + unused skills | "browser-automation never used -> suggest uninstall" |
| Energy management | Episodes + dream patterns | "energy crashes after 3h -> suggest focus-guard threshold" |
| Missing automation | Repeated manual steps in retros | "always run tests before commit -> suggest hookify" |
| Skill gap | Errors in specific skills | "tdd skill errors 30% -> suggest skill update" |
| Context overload | D1 declining + topic count high | "too many active topics -> suggest archival" |

### Step 3: Generate Proposals

For each identified improvement, create a ranked proposal:

```markdown
## Proposal #{N}: {Title}

**Impact**: HIGH / MEDIUM / LOW
**Effort**: {estimated hours}
**Type**: hook | skill | config | memory | workflow

**What**: {Specific change to make}
**Why**: {Evidence from signals — cite specific dream reports, retros, episodes}
**How**: {Exact steps — which file to modify, what to add/change}
**Rollback**: {How to undo if it doesn't work}

**Evidence**:
- Dream report 2026-03-25: D16 scored 4/10 (workflow efficiency low)
- Retrospective 2026-03-22: "tests failed twice because no pre-commit hook"
- Episode 2026-03-23: energy 2/5 after 4 context switches
```

### Step 4: HITL Review

Present ALL proposals via AskUserQuestion (batch):
- Sort by impact (HIGH first)
- Options per proposal: "Approve" / "Reject" / "Defer to next month"
- Show total impact: "3 approved -> estimated +15% workflow efficiency"

### Step 5: Execute Approved

For each approved proposal:
1. **Hook**: Use hookify skill to create/modify hook
2. **Skill**: Use skill-management to create/modify skill
3. **Config**: Modify settings.json via python3
4. **Memory**: Update memory files via Write/Edit
5. **Workflow**: Document change in decisions.jsonl

### Step 6: Log

Write `memory/self-propose-YYYY-MM.md`:
```markdown
---
name: Self-Propose — {Month YYYY}
description: {N} proposals, {M} approved, {K} executed
type: project
---

# Self-Propose Report — {Month YYYY}

## Signals Analyzed
- Dream reports: {N}
- Retrospectives: {N}
- Episodes: {N}
- Intuitions: {N}

## Proposals
| # | Title | Impact | Status | Outcome |
|---|-------|--------|--------|---------|
| 1 | {title} | HIGH | Approved | {result} |
| 2 | {title} | MED | Rejected | {reason} |

## System Delta
- Before: D16={X}, D11={Y}
- After: D16={X'}, D11={Y'}
- Net improvement: {summary}
```

## Rules

1. **HITL on EVERY change** — never auto-modify without approval
2. **Never modify feedback files** — feedback is immutable
3. **Evidence-based only** — every proposal cites specific signals
4. **Max 10 proposals per cycle** — focus on highest impact
5. **Rollback documented** — every proposal has undo steps
6. **Log everything** — self-propose report persists for trend tracking
