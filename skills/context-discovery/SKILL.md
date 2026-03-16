---
name: context-discovery
description: "Auto-discover project context + context engineering toolkit. 8-phase scan + audit + codemap + patterns + sync-plan + CLAUDE.md management (W3H). Run before any plan creation."
---

# Context Discovery

## Overview

Systematically explore any project to build a context report that informs planning.
Run this BEFORE starting any plan. The report pre-fills enterprise sections (H-M).
This skill is GENERIC — it works with any tech stack, any framework, any language.

**Announce:** "Running context discovery..."

## 8 Discovery Phases (execute in order)

### Phase 1: Stack Detection
Detect the project's technology stack by reading manifest files.

```
Check for (first match wins per layer):
Frontend: package.json → bun.lock/yarn.lock/pnpm-lock → detect React/Vue/Angular/Svelte/Next/Nuxt
Backend:  requirements.txt/pyproject.toml → Django/FastAPI/Flask
          go.mod → Gin/Echo/Fiber
          Cargo.toml → Actix/Axum
          pom.xml/build.gradle → Spring/Quarkus
          Gemfile → Rails
          package.json (server) → Express/Nest/Fastify
Database: docker-compose.yml → postgres/mysql/mongodb/redis/valkey
          prisma/schema.prisma → Prisma DB
          alembic/ → SQLAlchemy migrations
Infra:    docker-compose.yml/Dockerfile → Docker
          k8s/ → Kubernetes
          vercel.json/netlify.toml → Serverless
          terraform/ → IaC
```

Output: `Stack: {frontend} + {backend} + {db} + {infra}`

### Phase 2: Documentation Detection
Find project documentation that provides context.

```
Check for:
- CLAUDE.md / GEMINI.md / AGENTS.md → project instructions
- .blueprint/ → INDEX.md, MODULES.md, PATTERNS.md
- .claude/rules/ → all rule files
- memory/ → MEMORY.md (Claude Code memory)
- docs/ → README, architecture docs
- .cursor/ .windsurf/ → other AI tool configs
```

Output: `Docs: {N} files found, key docs: {list}`

### Phase 3: Domain Detection
Identify the business domain from docs and code.

```
- Parse CLAUDE.md for domain keywords
- Analyze model/service names for domain patterns
- Check for domain-specific libraries
```

Output: `Domain: {e-commerce|engineering|finance|SaaS|healthcare|...}`

### Phase 4: Architecture Detection
Map the project's architecture by scanning directories.

```
Glob for:
- API: routes/ endpoints/ controllers/ api/
- Services: services/ usecases/ domain/
- Models: models/ schemas/ entities/ types/
- Frontend pages: pages/ views/ app/
- Frontend components: components/ ui/
- Hooks/composables: hooks/ composables/ stores/
- Tests: tests/ __tests__/ spec/ e2e/

Count files per category. Note patterns (naming, structure).
```

Output: `Architecture: {N} endpoints, {M} services, {K} models, {J} components`

### Phase 5: Deployment Detection
Understand how the project is deployed.

```
Check for:
- docker-compose.yml → services, ports, volumes, resource limits
- Dockerfile(s) → base images, multi-stage builds
- .github/workflows/ .forgejo/workflows/ → CI/CD pipelines
- vercel.json / fly.toml / render.yaml → cloud platform
- scripts/ → deploy scripts, provision scripts
- .env.example → environment variables
```

Output: `Deploy: {method}, CI: {platform}, Envs: {list}`

### Phase 6: Security Detection
Identify the security model.

```
Grep for:
- Auth patterns: JWT, OAuth, SSO, session, passport, authlib, clerk
- RBAC: roles, permissions, guards, policies, middleware
- Password: bcrypt, argon2, scrypt hashing
- Secrets: .env patterns, vault config, KMS
```

Output: `Security: Auth={method}, RBAC={roles}, Secrets={management}`

### Phase 7: Observability Detection
Check monitoring and logging setup.

```
Grep for:
- Logging: winston, pino, structlog, slog, log4j, bunyan
- Health: /health, /healthz, /ready endpoints
- Metrics: prometheus, datadog, newrelic, opentelemetry
- Tracing: jaeger, zipkin, opentelemetry spans
- Alerting: pagerduty, opsgenie, slack webhooks
```

Output: `Observability: Logging={type}, Health={endpoint}, Metrics={system}`

### Phase 8: Performance Baseline
Estimate performance characteristics.

```
Check for:
- Docker resource limits (memory, CPU)
- Migration count → estimate table/collection count
- Bundle config → estimate frontend bundle size
- Cache config: redis, memcached, valkey, CDN
- Rate limiting config
```

Output: `Performance: Scale={estimate}, Cache={type}, Bundle={size}`

## Context Report Format

After all 8 phases, compile a report:

```markdown
# Context Discovery Report

📦 **Stack**: {frontend} + {backend} + {db} + {infra}
📁 **Docs**: {N} project docs, {M} rule files, {K} memory files
🏢 **Domain**: {domain type}
🏗️ **Architecture**: {N} endpoints, {M} services, {K} models, {J} components
🚀 **Deploy**: {method}, CI: {platform}, Envs: {list}
🔒 **Security**: Auth={method}, RBAC={roles}
📊 **Observability**: Logging={type}, Metrics={system}
⚡ **Performance**: Cache={type}, Scale={estimate}

## Existing Plans
{List from .blueprint/plans/INDEX.md or similar}

## Reusable Patterns Found
{List hooks, components, utilities that can be reused}

## Key Constraints
{From CLAUDE.md, rules, docs}
```

## When to Skip
- If project was explored recently in this session
- If user provides all context explicitly
- If this is a trivial task (< 3 complexity score)

## Architecture Perspective Mapping

When the project has a `.blueprint/plans/INDEX.md` or `atlas-perspectives.ts`, map discovered subsystems to their architectural layer:

```
📐 Architecture Layers:
- Data Pipeline: import, classification, data ingestion
- Engineering Chain: rule engine, spec grouping, estimation
- Procurement & Outputs: procurement, document generation
- Visualization: UI views, canvas, search
- Platform: auth, multi-tenant, observability, infrastructure
```

This mapping helps the plan-builder skill reference where a subsystem fits in the overall architecture.

## Integration with Plan Builder
The context report is passed to the plan-builder skill, which uses it to pre-fill:
- Section A (Vision) — architectural layer this subsystem belongs to
- Section B (Inventaire) — discovered files, patterns, hooks
- Section H (Personas) from docs
- Section I (Security) from security detection
- Section J (AI-Native) from observability detection
- Section K (Infrastructure) from deployment detection
- Section L (Reusability) from architecture patterns
- Section M (Traceability) from observability + security

---

## Context Engineering Toolkit (from /a-context-engineer)

Extended subcommands for context audit, codemap generation, pattern extraction, CLAUDE.md management, and plan sync.

### Subcommand: `audit`

Audit existing project documentation quality. Measures how well-structured the project context is for AI agents.

**Steps**:
1. Read CLAUDE.md (or report missing)
2. Count lines, check W3H sections (WHAT/WHY/HOW/RULES)
3. Check for `.blueprint/` directory and contents
4. Score lazy-loading tier presence (MODULES.md, PATTERNS.md, DECISIONS.md, etc.)
5. Report findings with prioritized recommendations

**Output**:
```
┌─────────────────────────────────────────────────────────────┐
│ CONTEXT ENGINEERING AUDIT                                    │
├─────────────────────────────────────────────────────────────┤
│ CLAUDE.md: {N} lines (TARGET: <=100)         ✅/❌          │
│ W3H Sections: WHAT ✅/❌ WHY ✅/❌ HOW ✅/❌ RULES ✅/❌   │
│ .blueprint/: {status}                        ✅/❌          │
│ Code map (MODULES.md): ✅/❌                                │
│ Patterns (PATTERNS.md): ✅/❌                               │
│ Lazy-loading: {N}/5 docs                     ✅/❌          │
├─────────────────────────────────────────────────────────────┤
│ SCORE: {N}/10                                                │
│ PRIORITY: {recommendation}                                   │
└─────────────────────────────────────────────────────────────┘
```

**Scoring**:
| Criteria | Points |
|----------|--------|
| CLAUDE.md exists | 1 |
| CLAUDE.md <= 100 lines | 1 |
| W3H sections present (WHAT/WHY/HOW/RULES) | 1 per section (max 4) |
| `.blueprint/` exists | 1 |
| MODULES.md exists | 1 |
| PATTERNS.md exists | 1 |
| Rules files (`.claude/rules/`) exist | 1 |

### Subcommand: `apply`

Apply the context engineering template to a new project.

**Steps**:
1. Check if `.blueprint/` already exists (warn if so)
2. AskUserQuestion about: stack, structure, conventions, domain
3. Pre-fill CLAUDE.md template with project-specific values (W3H format, <=100 lines)
4. Create `.blueprint/` with skeleton docs:
   - `MODULES.md` — Code map skeleton
   - `PATTERNS.md` — Pattern templates skeleton
   - `AI-COLLABORATION.md` — Claude Code limits + session workflow
   - `DECISIONS.md` — ADR template

**HITL Gate**:
```
AskUserQuestion: "I'll create the context engineering kit. Please confirm:
- Stack: {detected or ask}
- Domain: {detected or ask}
- Key conventions: {detected or ask}
Proceed?"
```

### Subcommand: `codemap`

Generate a MODULES.md code map by scanning the project.

**Steps**:
1. Scan key directories: `src/`, `components/`, `routes/`, `stores/`, `api/`, `services/`, `hooks/`, `models/`
2. Identify modules by directory structure
3. Find entry points (`index.ts`, `main.ts`, `App.tsx`, `main.py`, etc.)
4. Document conventions (naming, imports, exports)
5. Write `.blueprint/MODULES.md`

**Output**: Module registry with entry points, key files, role descriptions, and file counts.

```markdown
# MODULES.md — Code Map

## Frontend
| Module | Path | Entry | Files | Role |
|--------|------|-------|-------|------|
| Components | src/components/ | index.ts | 45 | UI components |
| Hooks | src/hooks/ | — | 12 | Reusable logic |
| Pages | src/pages/ | — | 8 | Route pages |

## Backend
| Module | Path | Entry | Files | Role |
|--------|------|-------|-------|------|
| API | api/v1/ | router.py | 15 | REST endpoints |
| Services | services/ | — | 10 | Business logic |
```

### Subcommand: `patterns`

Extract reusable code patterns from the project.

**Steps**:
1. Identify recurring patterns (API calls, state management, component structure, hooks)
2. Find 4-6 most common patterns
3. Create copy-paste templates with `{PLACEHOLDER}` substitution points
4. Document anti-patterns (what NOT to do)
5. Write `.blueprint/PATTERNS.md`

**Output**: Copy-paste code blocks with placeholder substitution points.

### Subcommand: `sync-plan`

Sync decisions from the active plan into `.blueprint/` documentation.

**When to use**: After plan approval, before starting implementation. Captures architectural decisions, new modules, routes, domain knowledge, and phase timelines.

**Steps**:
1. Find active plan in `.claude/plans/*.md` or `.blueprint/plans/*.md` (most recent if multiple)
2. Parse plan sections and extract:
   - **Architectural decisions** → `.blueprint/TECH-DECISIONS.md`
   - **New modules/services/stores** → `.blueprint/MODULES.md`
   - **New routes/pages/nav items** → `.blueprint/NAVIGATION-MAP.md`
   - **Domain concepts** → `.blueprint/DOMAIN-KNOWLEDGE.md`
   - **Phase/sprint timeline** → `.blueprint/STATUS.md`
   - **UX wireframes/mockups** → `.blueprint/UX-VISION.md`
3. For each target doc:
   - Read existing content
   - **APPEND** new sections (never overwrite existing content)
   - Add `<!-- Synced from plan: {plan_filename} on {date} -->` marker
   - Preserve document structure and formatting conventions
4. If a target doc doesn't exist, create it with the plan content + skeleton
5. Report what was synced with a summary table

**Rules**:
- APPEND only — never delete or overwrite existing doc content
- Date-stamp all synced sections with plan reference
- Skip sections that already exist (idempotent — safe to re-run)
- After sync, recommend running `audit` to verify overall doc quality

**HITL Gate**:
```
AskUserQuestion: "Plan sync will update {N} docs from plan {name}:
{list of docs to update}
Proceed with sync?"
```

### CLAUDE.md Management

The W3H framework for CLAUDE.md:

```
CLAUDE.md (<=100 lines, W3H format)
├── WHAT: Stack, metrics, structure (15 lines)
├── WHY: Business context, constraints (10 lines)
├── HOW: Commands, workflow, lazy-load index (40 lines)
└── RULES: 5-7 non-negotiable rules (20 lines)

.blueprint/ (lazy-loaded on demand)
├── MODULES.md         → Code map: file → role (replaces scanning)
├── PATTERNS.md        → Copy-paste code templates
├── NAVIGATION-MAP.md  → UI routes + stores (frontend)
├── AI-COLLABORATION.md → Claude Code limits + session workflow
└── DECISIONS.md       → ADRs: why X not Y
```

**Target**: CLAUDE.md <= 100 lines. Everything else lazy-loaded from `.blueprint/`.

### Context Efficiency Metrics

| Metric | Before Optimization | After Optimization |
|--------|--------------------|--------------------|
| CLAUDE.md size | 500+ lines | <=100 lines |
| Files scanned per session | 50+ | 3-5 |
| Context burn on exploration | 40-60% | 5-10% |
| Time to first code change | 5-10 min | < 1 min |

### Setup Detection (claude-code-setup)

When entering a new project, auto-detect and recommend setup:

1. **Check for CLAUDE.md** — if missing, recommend `apply`
2. **Check for .blueprint/** — if missing, recommend creating
3. **Check for .claude/rules/** — if missing, recommend adding project rules
4. **Check for memory files** — if missing, note that Claude Code memory is not configured
5. **Check for .claude/settings.json** — if missing, recommend creating with allowed tools

Present findings and recommendations via AskUserQuestion before taking any action.
