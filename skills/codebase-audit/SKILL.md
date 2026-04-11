---
name: codebase-audit
description: "20-dimension codebase analysis via 9-agent parallel team. Architecture, security, testing, performance, DX, enterprise, and 14 more dimensions. Weighted scoring 0-10, configurable presets (generic/synapse/saas/library), HITL gates, phased remediation roadmap. This skill should be used when the user asks to 'audit codebase', 'analyze codebase', 'codebase health', 'quality audit', or 'ultrathink audit'."
effort: high
model: opus
context: fork
agent: context-scanner
---

# Codebase Ultrathink Audit

20-dimension, 9-agent parallel codebase analysis. Works on any codebase (Python, TypeScript, Go, Rust, Java).
Configurable presets with weighted scoring. HITL gates on scope, critical findings, and export. Every finding requires evidence.

Read `references/dimensions.md` for the 20 scoring rubrics.
Read `references/agent-prompts.md` for the 9 agent prompt templates.
Read `references/scoring-methodology.md` for weights, grades, and presets.
Read `references/output-templates.md` for report and JSON schemas.

## Pipeline

```
CONFIG → DISCOVER → METRICS → SCOPE(HITL) → DISPATCH → COLLECT → SYNTHESIZE → SCORE → ROADMAP → REPORT(HITL)
```

## Agent Team (dispatched in Phase 4)

| Agent | Model | Dimensions | Checks |
|-------|-------|-----------|--------|
| 🔒 security-agent | Sonnet | Security, Compliance | ~15 |
| 🏗️ architecture-agent | Sonnet | Architecture, Tech Debt | ~12 |
| 🧪 testing-agent | Sonnet | Testing, Type Safety | ~12 |
| ⚡ performance-agent | Sonnet | Performance, Cost Efficiency | ~10 |
| 🔍 quality-agent | Sonnet | Code Quality, Documentation | ~12 |
| 🏢 enterprise-agent | Sonnet | Enterprise, API Design, Data Integrity | ~15 |
| 🛠️ dx-agent | Haiku | DX, AI-Readiness, Dependencies | ~12 |
| 🌐 frontend-agent | Haiku | Accessibility, i18n | ~8 |
| 📡 observability-agent | Haiku | Observability, Infrastructure | ~10 |

All agents use `subagent_type: "general-purpose"` and `run_in_background: true`.
Dispatch ALL 9 in a **single message** with parallel Agent tool calls.

## Severity Classification

| Severity | SLA | Deduction | Definition |
|----------|-----|-----------|------------|
| 🔴 P0 CRITICAL | 24h | -2.0 | Blocks production, immediate security/data risk |
| 🟠 P1 HIGH | 72h | -1.0 | Significant gap undermining dimension purpose |
| 🟡 P2 MEDIUM | 2w | -0.5 | Incomplete coverage, exploitable with preconditions |
| 🔵 P3 LOW | 1mo | -0.2 | Defense-in-depth, polish, best practice |
| ⚪ INFO | Backlog | 0 | Nice-to-have, no operational impact |

## Workflow

### Phase 0: CONFIG

Check for `.blueprint/audit-config.yaml`. If found, load and present for confirmation.
If not found, proceed to auto-detection in Phase 1 and select preset via AskUserQuestion.

### Phase 1: DISCOVER (DET)

Auto-detect stack via bash:

```bash
# Tech stack detection
ls package.json pyproject.toml go.mod Cargo.toml pom.xml Gemfile composer.json 2>/dev/null
# Framework detection
grep -l "fastapi\|django\|flask\|express\|next\|react\|vue\|angular" package.json pyproject.toml 2>/dev/null
# DB detection
grep -rl "postgresql\|mysql\|sqlite\|mongodb" docker-compose*.yml .env* 2>/dev/null | head -5
# Container detection
ls Dockerfile docker-compose*.yml 2>/dev/null
```

Output: stack summary (backend, frontend, database, infra).

### Phase 2: METRICS (DET)

Collect quantitative baseline:

```bash
# LOC by language
find . -name "*.py" -not -path "*/node_modules/*" -not -path "*/.git/*" | xargs wc -l 2>/dev/null | tail -1
find . \( -name "*.ts" -o -name "*.tsx" \) -not -path "*/node_modules/*" | xargs wc -l 2>/dev/null | tail -1
# File counts
find . -name "*.py" -not -path "*/node_modules/*" -not -path "*/.git/*" | wc -l
find . \( -name "*.ts" -o -name "*.tsx" \) -not -path "*/node_modules/*" | wc -l
# Test counts
find . -path "*/test*" -name "*.py" -not -path "*/node_modules/*" | wc -l
find . -name "*.test.*" -o -name "*.spec.*" | grep -v node_modules | wc -l
# Dependency counts
python3 -c "import json; d=json.load(open('package.json')); print('deps:', len(d.get('dependencies',{})), 'devDeps:', len(d.get('devDependencies',{})))" 2>/dev/null
# Git stats
git log --oneline --since="90 days ago" | wc -l
git shortlog -sn --since="90 days ago" | head -5
```

Store all metrics for agent injection.

### Phase 3: SCOPE (HITL)

**AskUserQuestion** to confirm:
- **Audit mode**: `full` (all 20 dims, 9 agents) / `quick` (top 8 dims, 4 agents) / `custom` (user picks)
- **Preset**: `generic` / `synapse` / `saas` / `library` / `custom`
- **Excluded paths**: default `node_modules, .git, dist, __pycache__, *.min.js, venv`
- **Previous audit** for delta: path or `none`
- **Estimated cost**: show agent count + model allocation

Never dispatch agents until scope is confirmed.

### Phase 4: DISPATCH

Read `references/agent-prompts.md` for templates. For each agent, build the prompt by injecting:
1. Dimension definitions + rubrics from `references/dimensions.md`
2. Detected stack from Phase 1
3. File inventory relevant to their dimensions
4. Pre-collected metrics from Phase 2
5. Preset weights from `references/scoring-methodology.md`

**Dispatch all 9 agents in a single message** using 9 parallel `Agent` tool calls.

Each agent prompt MUST include:
- Dimension assignment with weights and rubrics
- Explicit instruction to use Glob, Grep, Read, and Bash (read-only) tools
- Standardized output format (from `references/output-templates.md`)
- Rule: evidence required for EVERY finding — file:line + command output
- Rule: max 800 words output per agent
- Rule: score each dimension independently using the deduction formula

**Quick mode**: dispatch only 4 agents (security, testing, architecture, enterprise) covering top 8 weighted dims.

### Phase 5: COLLECT

Wait for all background agents to complete. Read each agent's output.
If any agent fails or times out (10 min), mark its dimensions as `TIMEOUT` (score = 0) and continue.

### Phase 6: SYNTHESIZE (Opus ultrathink)

Cross-dimension analysis that individual agents cannot do:
- Correlate security findings with architecture weaknesses
- Map testing gaps to high-risk code paths identified by other agents
- Identify systemic patterns (e.g., all new code lacks tests, all APIs missing rate limiting)
- Flag compound risks (security issue + no error handling + no monitoring = P0)
- Compare against preset benchmarks from `references/scoring-methodology.md`

Use maximum thinking effort for this phase.

### Phase 7: SCORE (DET)

Apply scoring from `references/scoring-methodology.md`:

```
per_dim_score = max(0, 10.0 - deductions + bonuses)
weighted_overall = Σ(dim_score × dim_weight_pct)
grade = A+ (≥9.5) | A (≥9.0) | ... | F (<5.0)
```

If grade = F: **HITL Gate** — AskUserQuestion: "Grade F detected. Continue / Abort / Re-scope?"

### Phase 8: ROADMAP

Generate phased remediation:
- **Phase 1 (1 week)**: All P0 findings — immediate action
- **Phase 2 (2-3 weeks)**: P1 findings in top-5 weighted dimensions
- **Phase 3 (1 month)**: Remaining P1 + P2 in top-10 dimensions
- **Phase 4 (ongoing)**: P3 + INFO + continuous improvement

Include effort estimates (hours) per finding based on typical remediation patterns.

### Phase 9: REPORT (HITL)

Write report to `.blueprint/AUDIT-{YYYY-MM-DD}.md` using template from `references/output-templates.md`.
Save JSON to `.blueprint/_audit-history/codebase-audit-{date}.json` for delta tracking.
Append to `.blueprint/_audit-history/codebase-audit-history.jsonl` for trend analysis.

Present ASCII summary in chat (score dashboard table).

**HITL Gate**: Review each P0 CRITICAL finding individually:
- AskUserQuestion per finding: "P0 [{dim}:{id}] {title} — Confirm / Override-severity / False-positive / Accept-risk"

**HITL Gate**: Export format: "Export to Excel/PPTX? (md-only / excel / pptx / none)"
- `excel` / `pptx` → delegate to `document-generator` skill

## Subcommands

| Command | Mode | Agents | Est. Time | HITL |
|---------|------|--------|-----------|------|
| `audit-codebase` | Full (20 dims) | 9 | ~15 min | Scope + P0 review + Export |
| `audit-codebase --quick` | Quick (8 dims) | 4 | ~8 min | P0 review only |
| `audit-codebase --dim security,testing` | Specific dims | 1-2 | ~5 min | P0 review only |
| `audit-codebase report` | Regenerate from last JSON | 0 | ~2 min | None |
| `audit-codebase compare <file.json>` | Delta comparison | 0 | ~3 min | None |

## Integration

| Reuses pattern from | What |
|--------------------|------|
| `code-review` | Parallel agent dispatch (9 agents in one message) |
| `enterprise-audit` | Severity classification, scoring rubric, HITL gate pattern |
| `context-discovery` | Stack auto-detection (Phase 1) |
| `execution-strategy` | Cost estimation heuristics |
| `document-generator` | Excel/PPTX export delegation |

## Error Recovery

| Scenario | Action |
|----------|--------|
| Agent timeout (>10 min) | Mark dimensions as TIMEOUT (score 0), continue with remaining |
| Agent returns empty/malformed | Re-dispatch single agent with simplified prompt; if fails again, manual checklist |
| Score < 5.0 (Grade F) | HITL: "Grade F detected. Continue / Abort / Re-scope?" |
| No matching preset | Default to `generic` (all dims at 5%) |
| Stack not detected | AskUserQuestion for manual stack input |
| Agent count exceeds resources | Config `max_parallel: 4` for 2-wave dispatch |

## Key Principles

- **Read-only**: Agents never mutate DB, push code, or write files (lead writes report)
- **Evidence required**: Every finding needs file:line + command output. No speculation.
- **Deterministic where possible**: Bash metrics (LOC, CVEs, lint counts) are reproducible
- **Generic by default**: Works on any Git repo. Presets optimize weights per project type.
- **Max 2 fix retries**: If remediation fails twice, escalate to human via AskUserQuestion
- **Score history**: JSON persisted for delta tracking across audit runs
- **Agent independence**: Agents don't communicate — lead consolidates all results
