---
name: context-discovery
description: "Auto-discover project context for planning. 8-phase scan: stack, docs, domain, architecture, deployment, security, observability, performance. Run before any plan creation."
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

## Integration with Plan Builder
The context report is passed to the plan-builder skill, which uses it to pre-fill:
- Section H (Personas) from docs
- Section I (Security) from security detection
- Section J (AI-Native) from observability detection
- Section K (Infrastructure) from deployment detection
- Section L (Reusability) from architecture patterns
- Section M (Traceability) from observability + security
