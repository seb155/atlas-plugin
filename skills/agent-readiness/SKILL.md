---
name: agent-readiness
description: "Factory.ai 9-Pillar Agent Readiness scoring. This skill should be used when the user asks to '/atlas readiness', 'agent readiness', 'Factory.ai score', 'codebase AI readiness', or needs a 9-pillar audit of AI-agent-effectiveness."
effort: low
---

# Agent Readiness -- Factory.ai 9-Pillar Scoring

Automated scoring of the codebase against the Factory.ai Agent Readiness framework.
Measures how well the codebase supports AI agent workflows across 9 technical pillars.

## When to Use

- User says "readiness", "agent readiness", "readiness score", "readiness check"
- User says "how agent-ready is this codebase", "can agents work here"
- Before onboarding a new AI agent to the project
- After infrastructure or tooling changes
- Periodically (monthly recommended) to track progression
- When planning improvements to agent workflow support

## Subcommands

| Command | Mode | Description |
|---------|------|-------------|
| `/atlas readiness` | **Full Scan** | Score all 9 pillars, generate report |
| `/atlas readiness --pillar N` | **Single Pillar** | Deep-dive on one pillar (1-9) |
| `/atlas readiness --json` | **JSON Output** | Machine-readable output for CI |
| `/atlas readiness compare` | **Compare** | Diff current vs. previous report in git |

## Pipeline

```
SCAN --> SCORE --> COMPARE --> DISPLAY --> RECOMMEND
```

---

## Phase 1: SCAN -- Run the Scoring Script

Run the automated checker from the project root:

```bash
# Full scan (all 9 pillars)
bash scripts/agent-readiness-check.sh

# Single pillar
bash scripts/agent-readiness-check.sh --pillar 7

# JSON for CI integration
bash scripts/agent-readiness-check.sh --json
```

The script checks real artifacts (config files, test counts, tool presence) -- no subjective scoring.

---

## Phase 2: SCORE -- Interpret Results

### 9 Pillars (Factory.ai Standard)

| # | Pillar | What it measures |
|---|--------|------------------|
| 1 | **Style & Validation** | Linters (ruff, biome), formatters, pre-commit hooks, SAST |
| 2 | **Build System** | Docker, Makefile, health checks, CI, provisioning |
| 3 | **Testing** | Test counts (BE+FE+E2E), markers, coverage, golden tests |
| 4 | **Documentation** | CLAUDE.md, .blueprint/, rules, plans, feature registry |
| 5 | **Dev Environment** | Docker Compose, .env.example, multi-env, devcontainer |
| 6 | **Code Quality** | TypeScript strict, mypy, enterprise rules, boundaries |
| 7 | **Observability** | structlog, correlation IDs, OTel, Sentry, dashboards |
| 8 | **Security & Governance** | gitleaks, RBAC, project_id, CODEOWNERS, dep scanning |
| 9 | **Task Discovery** | FEATURES.md, sub-plans, HITL gates, mega plan |

### 5 Maturity Levels

| Score | Level | Description |
|-------|-------|-------------|
| 1 | Functional | Basic operational capabilities |
| 2 | Documented | Documentation exists but inconsistent |
| 3 | Standardized | E2E tests, maintained docs, security scanning |
| 4 | Optimized | Comprehensive CI/CD, extensive tests, security |
| 5 | Autonomous | Maximum agent independence |

### Overall Score Thresholds

| Range | Assessment |
|-------|-----------|
| 9-18 | Agents struggle -- significant investment needed |
| 19-27 | Agents can assist -- gaps in critical areas |
| 28-36 | Agents productive -- minor gaps remain |
| 37-42 | Agents highly effective -- near autonomous |
| 43-45 | Fully autonomous agent support |

---

## Phase 3: COMPARE -- Track Progression

Compare current scores with the previous git-committed report:

```bash
git diff HEAD -- .blueprint/AGENT-READINESS-REPORT.md
```

Show delta per pillar. Highlight improvements and regressions.

If no previous report exists, this is the baseline.

---

## Phase 4: DISPLAY -- Present Results

Display results using this format:

```
+------------------------------------------+
| Agent Readiness -- Factory.ai 9-Pillar   |
+------------------------------------------+
| Date:  YYYY-MM-DD HH:MM TZ              |
| Score: NN/45 (X.X/5)                     |
| Level: LEVEL_NAME                        |
| Delta: +N from previous                  |
+------------------------------------------+

# Pillar  Name                    Score  Level
  1       Style & Validation      5/5    Autonomous
  2       Build System            4/5    Optimized
  ...

Gaps:
  P2: No HEALTHCHECK in Dockerfile
  P7: OTel deps installed but not fully wired
  P8: No CODEOWNERS file
```

---

## Phase 5: RECOMMEND -- Suggest Actions

For each pillar scoring below 5, suggest specific actions:

| Pillar | Gap | Fix | Effort |
|--------|-----|-----|--------|
| P2 | No HEALTHCHECK | Add `HEALTHCHECK CMD curl -f http://localhost:8001/health` to Dockerfile | 15min |
| P3 | No golden tests | Create `tests/golden/` with known-good fixtures | 2h |
| P7 | OTel not wired | Wire TracerProvider in `app/core/telemetry.py` | 2-3h |
| P8 | No CODEOWNERS | Create `CODEOWNERS` mapping modules to owners | 30min |

Prioritize fixes by impact-to-effort ratio. Quick wins first.

---

## Rules

- ALWAYS run the actual script -- never estimate scores manually
- ALWAYS show evidence (file counts, tool versions, config presence)
- ALWAYS compare with previous scores when available
- Report file location: `.blueprint/AGENT-READINESS-REPORT.md`
- Script location: `scripts/agent-readiness-check.sh`
- Source framework: Factory.ai (ref: `data/transcripts/sota-agentic-engineering-2026.md`)
