---
name: context-discovery
description: "Auto-discover project context before planning. This skill should be used when the user asks to 'discover context', 'audit context', 'codemap', 'sync plan', '/atlas context', or before creating any new engineering plan."
effort: medium
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [plan-builder, brainstorming]
thinking_mode: adaptive
---

<HARD-GATE>
Do NOT invoke any implementation skill, write any code, scaffold any project, or take any implementation action until you have presented a design and the user has approved it.
This applies to EVERY project regardless of perceived simplicity.
Context discovery MUST run before any plan creation or major refactor.
</HARD-GATE>

<red-flags>

| Thought | Reality |
|---|---|
| "This feature is too simple to need a plan" | Simple projects are where unexamined assumptions cause the most wasted work. The plan can be short, but it MUST exist and be approved. 'Too simple to plan' precedes 90% of scope-drift incidents. |
| "Let me just start coding and see where it goes" | Coding without a plan = architecting in your prefrontal cortex under tool-use latency. You will burn 10x tokens exploring paths a 15-min plan would have rejected. STOP. Invoke brainstorming skill. Present 2-3 approaches via AskUserQuestion. Wait for design approval. THEN invoke plan-builder. THEN code. |
| "I know the pattern from last sprint, same plan applies" | Patterns repeat but CONTEXT does not. Tables, personas, constraints, API shape — all different. Reusing a plan verbatim skips the discovery where the gotcha lives. Run context-discovery FIRST. |
| "I know this codebase, no need to audit" | You know what was true at your last read. Files moved, patterns evolved, new constraints were added. The 30-second audit catches the 3-hour surprise. |
| "It's obvious what to do, skip the discovery" | "Obvious" is the label you give to the thing that later breaks in ways you did not see. Discovery is cheap. Rework is not. |

</red-flags>

# Context Discovery

Run BEFORE any plan creation. Produces a context report that pre-fills enterprise plan sections (A-B, H-M).
Generic — works with any tech stack/framework/language.

**Announce:** "Running context discovery..."

## Red Flags (rationalization check)

Before skipping context-discovery, ask yourself — are any of these thoughts running? If yes, STOP. Memory drifts; filesystem wins (per `feedback_ultrathink_plan_staleness_pattern.md`).

| Thought | Reality |
|---------|---------|
| "I remember this project" | Memory drifts across compactions. Re-scan — 6/6 stale plans caught 2026-04-18 prove it. |
| "We explored this subsystem yesterday" | Yesterday ≠ today. Commits, plans, docs change hourly. Re-scan. |
| "I'll discover as I plan" | Discovery pre-fills sections A-B, H-M. Discovering mid-plan = 2x rework. |
| "Trivial task, no context needed" | Trivial tasks trip on stack conventions (bun not npm, kebab-case files, etc). Check stack. |
| "I'll just grep for what I need" | 8-phase scan catches architecture, security, observability patterns grep misses. |
| "The CLAUDE.md has everything" | CLAUDE.md W3H is ≤100 lines by design. `.blueprint/` holds the detail. Load both. |
| "Skip the plan INDEX — I know the active plans" | INDEX is SSoT. Active/archived/deferred status changes between sessions. |

## 8 Discovery Phases

| # | Phase | Scan targets | Output |
|---|-------|-------------|--------|
| 1 | **Stack** | `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`, `Gemfile`, `docker-compose.yml`, `alembic/`, `prisma/` | `Stack: {FE} + {BE} + {DB} + {infra}` |
| 2 | **Docs** | `CLAUDE.md`, `.blueprint/`, `.blueprint/designs/`, `.claude/rules/`, `memory/`, `docs/`, `.cursor/`, `.windsurf/` | `Docs: {N} files, key: {list}. Designs: {N} design docs` |
| 3 | **Domain** | CLAUDE.md keywords, model/service names, domain-specific libs | `Domain: {type}` |
| 4 | **Architecture** | `routes/`, `services/`, `models/`, `components/`, `hooks/`, `tests/` — count files per category | `Architecture: {N} endpoints, {M} services, {K} models, {J} components` |
| 5 | **Deploy** | `docker-compose.yml`, `Dockerfile`, `.github/workflows/`, `.forgejo/workflows/`, `scripts/`, `.env.example` | `Deploy: {method}, CI: {platform}, Envs: {list}` |
| 6 | **Security** | Grep: JWT/OAuth/SSO/passport, roles/permissions/guards, bcrypt/argon2, .env/vault/KMS | `Security: Auth={method}, RBAC={roles}` |
| 7 | **Observability** | Grep: winston/structlog/pino, /health endpoints, prometheus/datadog/opentelemetry, jaeger/zipkin | `Observability: Logging={type}, Metrics={system}` |
| 8 | **Performance** | Docker resource limits, migration count, bundle config, cache config, rate limiting | `Performance: Cache={type}, Scale={estimate}` |

## Context Report Format

```
# Context Discovery Report
📦 Stack | 📁 Docs | 🏢 Domain | 🏗️ Architecture | 🚀 Deploy | 🔒 Security | 📊 Observability | ⚡ Performance
## Existing Plans — from .blueprint/plans/INDEX.md
## Reusable Patterns Found — hooks, components, utilities
## Key Constraints — from CLAUDE.md, rules, docs
```

## When to Skip
- Project explored recently in this session
- User provides all context explicitly
- Trivial task (complexity < 3)

## Architecture Perspective Mapping

Map subsystems to layers: **Data Pipeline** | **Engineering Chain** | **Procurement & Outputs** | **Visualization** | **Platform**

## Plan Builder Integration

Report pre-fills: A (Vision/layer), B (Inventaire/files), H (Personas), I (Security), J (AI-Native), K (Infra), L (Reusability), M (Traceability).

---

## Context Engineering Toolkit

### Subcommands

| Command | Purpose | HITL |
|---------|---------|------|
| `audit` | Score project doc quality (W3H, .blueprint/, rules) → 0-10 score | No |
| `apply` | Bootstrap context kit (CLAUDE.md W3H + .blueprint/ skeleton) | Yes — confirm stack/domain/conventions |
| `codemap` | Scan dirs → generate `.blueprint/MODULES.md` (module registry) | No |
| `patterns` | Extract 4-6 recurring code patterns → `.blueprint/PATTERNS.md` with `{PLACEHOLDER}` templates | No |
| `sync-plan` | Sync plan decisions into .blueprint/ docs (APPEND only, idempotent) | Yes — confirm doc list |

### Audit Scoring

| Criteria | Points |
|----------|--------|
| CLAUDE.md exists | 1 |
| CLAUDE.md <= 100 lines | 1 |
| W3H sections (WHAT/WHY/HOW/RULES) | 1 per section (max 4) |
| `.blueprint/` exists | 1 |
| MODULES.md exists | 1 |
| PATTERNS.md exists | 1 |
| `.claude/rules/` exists | 1 |

### CLAUDE.md W3H Framework

```
CLAUDE.md (<=100 lines)
├── WHAT: Stack, metrics, structure (15 lines)
├── WHY: Business context, constraints (10 lines)
├── HOW: Commands, workflow, lazy-load index (40 lines)
└── RULES: 5-7 non-negotiable rules (20 lines)

.blueprint/ (lazy-loaded): MODULES.md, PATTERNS.md, NAVIGATION-MAP.md, AI-COLLABORATION.md, DECISIONS.md
```

### Setup Detection

On new project entry, check for: CLAUDE.md, .blueprint/, .claude/rules/, memory files, .claude/settings.json. Present findings via AskUserQuestion.
