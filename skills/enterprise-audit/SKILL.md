---
name: enterprise-audit
description: "14-dimension enterprise readiness audit. This skill should be used when the user asks to '/atlas audit-enterprise', 'enterprise audit', 'due diligence', 'G Mining audit', 'SOC2 readiness', or needs an A-F scored audit of multi-tenancy/security/docs/governance."
effort: high
---

# Enterprise Audit

14-dimension enterprise readiness audit. Designed for G Mining / Eldorado Gold due diligence.
Every finding requires evidence (command output or file reference). HITL gates on scope, report, and all CRITICAL remediations.

## Pipeline

```
SCOPE → CHECK → SCORE → REPORT → RECOMMEND → TRACK
```

---

## Severity Classification

| Severity | SLA | Definition | Examples |
|----------|-----|------------|---------|
| 🔴 CRITICAL | 24h | Blocks enterprise adoption | Auth bypass, data leak, zero test coverage |
| 🟠 HIGH | 72h | Significant readiness gap | Missing RBAC, no backup strategy, bus factor 1 |
| 🟡 MEDIUM | 2w | Exploitable with preconditions | Missing i18n, undocumented APIs, no SLA defined |
| 🔵 LOW | 1mo | Defense-in-depth / polish | Missing JSDoc, minor a11y issues, verbose logs |
| ⚪ INFO | Backlog | Best practice / nice-to-have | Optional compliance extras, tooling upgrades |

---

## Dimension Weights

| # | Dimension | Weight | Delegates to |
|---|-----------|--------|-------------|
| 1 | Security | 20% | `security-audit` skill |
| 2 | Multi-tenancy | 15% | toolkit/audit/tenancy.py |
| 3 | Data integrity | 12% | toolkit/audit/data.py |
| 4 | Deployment | 10% | toolkit/audit/deploy.py |
| 5 | Testing | 10% | `verification` skill |
| 6 | Ops / observability | 8% | toolkit/audit/ops.py |
| 7 | Code quality | 6% | toolkit/audit/code.py |
| 8 | Documentation | 5% | toolkit/audit/docs.py |
| 9 | Dependencies | 5% | toolkit/audit/deps.py |
| 10 | API surface | 4% | toolkit/audit/api.py |
| 11 | i18n / localization | 2% | toolkit/audit/i18n.py |
| 12 | Accessibility | 1% | toolkit/audit/a11y.py |
| 13 | Governance | 1% | toolkit/audit/governance.py |
| 14 | Performance | 1% | toolkit/audit/perf.py |

---

## Workflow

### Phase 1: SCOPE (HITL)

**AskUserQuestion** to confirm:
- Audit type: `full` / `quick` (critical dims only) / `specific` (specify dimensions)
- Target environment: `dev` / `staging` / `prod`
- Reference audit JSON (for delta comparison): path or `none`
- Output formats requested: `md` / `excel` / `pptx` / `none`

Never proceed until scope is confirmed in chat.

### Phase 2: CHECK (DET)

Run the Python checker engine:

```bash
python3 -m toolkit.audit \
  --format json \
  --output /tmp/audit-$(date +%Y%m%d).json \
  --project-root . \
  [--dimensions dim1,dim2] \
  [--compare /path/to/previous.json]
```

**Delegation rules:**
- `security` dimension → invoke `security-audit` skill; import JSON results
  - **Skill supply-chain sub-audit** (per ADR-013): also invoke `scripts/pre-install-skill-check.sh` on every skill directory under `skills/` and `dist/*/skills/`
  - Aggregate skill-lint findings (R01-R10 per OWASP Agentic Top 10)
  - Any TOXIC verdict → CRITICAL severity finding (blocks enterprise readiness)
  - WARN verdicts → MEDIUM severity findings
- `testing` dimension → invoke `verification` skill; import coverage + test counts
- All other dimensions → run toolkit checker directly

**Checker rules:**
- Read-only — no writes to DB, no network mutations
- Capture stdout/stderr for evidence
- Timeout per dimension: 5 minutes max
- On checker not found: fall back to manual checklist (note gap in findings)

### Phase 3: SCORE (DET)

Parse `/tmp/audit-{date}.json`, apply dimension weights from scoring rubric (`references/scoring-rubric.md`):

```
weighted_score = Σ(dimension_score × dimension_weight)
grade = A (≥90) | B (80-89) | C (70-79) | D (60-69) | F (<60)
```

Calculate:
- Overall weighted score + grade
- Per-dimension score + grade
- Finding counts by severity (CRITICAL / HIGH / MEDIUM / LOW / INFO)
- Delta vs previous run (if comparison file provided)

### Phase 4: REPORT (HITL)

Present ASCII summary table in chat:

```
╔═══════════════════════════════════════════════════════════╗
║         SYNAPSE ENTERPRISE AUDIT — {date}                 ║
║  Overall: {score}/100  Grade: {grade}  Target: {env}      ║
╠══════════════════╦═════════╦═══════╦═══════╦═════════════╣
║ Dimension        ║  Score  ║ Grade ║ Delta ║ Findings    ║
╠══════════════════╬═════════╬═══════╬═══════╬═════════════╣
║ Security (20%)   ║   87    ║   B   ║  +2   ║ 0C 1H 3M   ║
║ Multi-tenancy    ║   ...   ║   ... ║  ...  ║ ...         ║
╚══════════════════╩═════════╩═══════╩═══════╩═════════════╝
CRITICAL findings: {count}  |  HIGH: {count}  |  MEDIUM: {count}
```

**HITL Gate**: AskUserQuestion — "Export results to Excel/PPTX? (yes/excel/pptx/no)"
- `excel` → invoke `document-generator` skill with audit data
- `pptx` → invoke `document-generator` skill with executive summary template
- `no` → continue to recommendations

### Phase 5: RECOMMEND (HITL)

Generate top 10 remediations ranked by: severity × dimension_weight × effort_inverse.

For each CRITICAL finding:
- **HITL Gate**: AskUserQuestion — "CRITICAL [{id}] {title}: approve remediation? (yes / manual / accept-risk / false-positive)"
- `yes` → execute fix, re-run specific checker, mark RESOLVED only on clean re-check
- `manual` → document steps, assign owner, set due date
- `accept-risk` → log to `.blueprint/_audit-history/risk-register.md` with rationale
- `false-positive` → add suppression rule, re-score

**Max 2 fix retries per finding** — if still failing after 2 attempts, escalate via AskUserQuestion with full error context.

### Phase 6: TRACK

After report is reviewed and recommendations actioned:

```bash
# Save audit results
mkdir -p .blueprint/_audit-history
cp /tmp/audit-{date}.json .blueprint/_audit-history/audit-{date}-{env}.json

# Update FEATURES.md audit score badge
# Pattern: find "Enterprise Readiness" section, update score + grade + date

# Commit
git add .blueprint/_audit-history/
git add .blueprint/FEATURES.md
git commit -m "audit(enterprise): {env} audit {date} — Grade {grade} ({score}/100)"
```

---

## Subcommands

| Command | Scope | Est. Time | HITL |
|---------|-------|-----------|------|
| `audit-enterprise` | Full 6-phase pipeline (all 14 dims) | ~45 min | Scope + Report + CRITICAL |
| `audit-enterprise --quick` | Critical dimensions only (security, multi-tenancy, data, deployment) | ~15 min | Report only |
| `audit-enterprise --dimension <d1,d2>` | Specific dimensions by name | ~5-15 min | Report only |
| `audit-enterprise report` | Regenerate report from last saved JSON | ~2 min | None |
| `audit-enterprise compare <file.json>` | Delta comparison vs previous run | ~5 min | None |

---

## Integration with Existing Skills

| This skill... | ...delegates to | When |
|---------------|----------------|------|
| security dimension | `security-audit` | Always — do not duplicate |
| testing dimension | `verification` | Always — do not duplicate |
| export: excel | `document-generator` | When user approves Excel export |
| export: pptx | `document-generator` | When user approves PPTX export |
| post-remediation commit | `git-worktrees` pattern | After fixes applied |

---

## HITL Gates Summary

| Gate | Trigger | Options |
|------|---------|---------|
| Scope confirmation | Phase 1 start | Approve / modify scope |
| Report export | Phase 4 complete | excel / pptx / no |
| CRITICAL finding | Each CRITICAL in Phase 5 | yes / manual / accept-risk / false-positive |
| Fix retry limit | 2 failed attempts | Escalate to user |

---

## Error Recovery

| Scenario | Action |
|----------|--------|
| `toolkit.audit` module not found | Note checker gap; run manual checklist from `references/gmining-checklist.md` |
| Dimension checker times out (>5 min) | Skip dim, mark as `TIMEOUT` (score = 0), continue |
| Delta compare file not found | Warn user, skip delta column, continue |
| Fix breaks service | Rollback → `infrastructure-ops restart` → AskUserQuestion with error |
| Max retries reached (2) | AskUserQuestion: "Fix failed twice for [{id}]. Manual intervention required." |
| Score < 60 (Grade F) | AskUserQuestion: "Grade F detected. Recommend aborting G Mining review?" |

---

## Context7 Best Practices Layer (2026-03-19)

Beyond the 14-dimension Python checkers, the audit also validates tech stack best practices:

| Tech | Key Check | Rule |
|------|-----------|------|
| SQLAlchemy | `db.query()` vs `select()` | 2.0 style mandatory for new code |
| FastAPI | `@app.on_event` vs `lifespan` | `lifespan` context manager required |
| Pydantic | `class Config:` vs `model_config` | v2 `ConfigDict` pattern required |
| TanStack Query | inline vs `queryOptions()` | `queryOptions()` pattern for new hooks |
| structlog | `logging.getLogger` vs `structlog.get_logger` | structlog required for correlation IDs |
| Docker | `:latest` tags | Pinned versions required in prod compose |
| Redis/Valkey | `KEYS` command | `SCAN` cursor required |
| Alembic | `compare_type` in env.py | Must be `True` for type change detection |

These rules are enforced via `.claude/rules/enterprise-*.md` and checked in code-review Agent 4.
Full audit: `memory/context7-audit-2026-03-19.md`

## Key Principles

- Read-only checks — never mutate DB, never push code without HITL
- Evidence required for every finding — no speculation
- DB-first: project_id scoped on all tenant checks
- Delegate to existing skills — never duplicate security-audit or verification logic
- Max 2 fix retries → escalate to human
- Scoring rubric in `references/scoring-rubric.md` — single source of truth
- G Mining checklist in `references/gmining-checklist.md` — due diligence alignment
- Context7 best practices in `.claude/rules/enterprise-*.md` — technology-level compliance
