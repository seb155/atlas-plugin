---
name: context-discovery
description: "Auto-discover project context + context engineering toolkit. 8-phase scan + audit + codemap + patterns + sync-plan + CLAUDE.md management (W3H). Run before any plan creation."
effort: medium
---

# Context Discovery

Run BEFORE any plan creation. Produces a context report that pre-fills enterprise plan sections (A-B, H-M).
Generic — works with any tech stack/framework/language.

**Announce:** "Running context discovery..."

## 8 Discovery Phases

| # | Phase | Scan targets | Output |
|---|-------|-------------|--------|
| 1 | **Stack** | `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`, `Gemfile`, `docker-compose.yml`, `alembic/`, `prisma/` | `Stack: {FE} + {BE} + {DB} + {infra}` |
| 2 | **Docs** | `CLAUDE.md`, `.blueprint/`, `.claude/rules/`, `memory/`, `docs/`, `.cursor/`, `.windsurf/` | `Docs: {N} files, key: {list}` |
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
