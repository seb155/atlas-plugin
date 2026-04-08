# Codebase Audit — 20 Dimensions Reference

> Self-contained scoring reference. Each agent reads ONLY this file to know what to check.
> Weights vary by preset. All presets sum to exactly 100%.

---

### D1: Security 🔒

**Category**: Security
**Agent**: security-agent (Sonnet)

| Preset | Weight |
|--------|--------|
| generic | 5% |
| synapse | 14% |
| saas | 11% |
| library | 3% |

**Key Metrics**:
1. Secret exposure count — `gitleaks detect --source . --no-banner -v 2>&1 | grep -c "Finding"`
2. Known CVEs in dependencies — `trivy fs . --severity HIGH,CRITICAL --quiet`
3. Hardcoded credential patterns — `grep -rnI "password\s*=\|secret\s*=\|api_key\s*=" --include="*.py" --include="*.ts" --include="*.env" .`

**Scoring Rubric**:
| Score | Criteria |
|-------|----------|
| 0-2 | Secrets in git history, no auth on APIs, SQL injection vectors present |
| 3-4 | Auth exists but inconsistent, some endpoints unprotected, no CSP headers |
| 5-6 | Auth on all routes, basic input validation, no HIGH CVEs, CSP present |
| 7-8 | RBAC enforced, parameterized queries everywhere, rate limiting, CORS locked down |
| 9-10 | Zero CVEs, secret rotation policy, WAF/CSP/HSTS, security headers on all responses, pen-test ready |

**Common Findings**:
- P0: Secrets committed to git history (API keys, DB passwords)
- P1: Missing authentication on admin endpoints
- P2: No rate limiting on login routes
- P3: Missing security headers (X-Frame-Options, X-Content-Type-Options)

---

### D2: Testing 🧪

**Category**: Quality
**Agent**: testing-agent (Sonnet)

| Preset | Weight |
|--------|--------|
| generic | 5% |
| synapse | 10% |
| saas | 10% |
| library | 18% |

**Key Metrics**:
1. Line coverage percentage — `pytest --cov --cov-report=term-missing -q 2>&1 | grep "TOTAL"` / `vitest --coverage --run 2>&1 | grep "All files"`
2. Test-to-source ratio — `find . -path "*/test*" -name "*.py" | wc -l` vs `find . -name "*.py" -not -path "*/test*" | wc -l`
3. Test execution time — `pytest --durations=5 -q --tb=no 2>&1 | tail -3`

**Scoring Rubric**:
| Score | Criteria |
|-------|----------|
| 0-2 | Coverage < 20%, no CI test run, test files < 10% of source files |
| 3-4 | Coverage 20-40%, tests exist but many skip/xfail, no integration tests |
| 5-6 | Coverage 40-60%, unit + integration present, CI runs tests on push |
| 7-8 | Coverage 60-80%, mutation testing or property tests, < 5% flaky tests |
| 9-10 | Coverage > 80%, test pyramid balanced, < 60s CI, E2E + visual regression |

**Common Findings**:
- P0: Critical business logic paths untested (auth, payments, data mutations)
- P1: No integration tests for database operations
- P2: Flaky tests that pass inconsistently (timing-dependent)
- P3: Test naming conventions inconsistent across modules

---

### D3: Type Safety 🛡️

**Category**: Quality
**Agent**: testing-agent (Sonnet)

| Preset | Weight |
|--------|--------|
| generic | 5% |
| synapse | 4% |
| saas | 5% |
| library | 10% |

**Key Metrics**:
1. `any` type usage — `grep -rnI "\bany\b" --include="*.ts" --include="*.tsx" . | grep -v node_modules | wc -l`
2. Type check pass rate — `tsc --noEmit 2>&1 | tail -1` / `mypy --strict . 2>&1 | tail -1`
3. Untyped function params — `grep -rnP "def \w+\([^)]*[^:)]\)" --include="*.py" . | grep -v test | wc -l`

**Scoring Rubric**:
| Score | Criteria |
|-------|----------|
| 0-2 | No type checking, > 50 `any` per 1K LOC, no strict mode |
| 3-4 | Types exist but partial, strict mode off, > 20 `any` per 1K LOC |
| 5-6 | Strict mode enabled, < 10 `any` per 1K LOC, models fully typed |
| 7-8 | Zero `any`, strict mypy/tsc pass, runtime validation (Pydantic/Zod) |
| 9-10 | Branded types, discriminated unions, exhaustive matching, zero type suppressions |

**Common Findings**:
- P0: API responses untyped — runtime crashes from shape mismatches
- P1: `# type: ignore` / `@ts-ignore` masking real errors (> 10 instances)
- P2: Function return types missing on public API surface
- P3: Generic `Record<string, any>` instead of precise interfaces

---

### D4: Architecture 🏗️

**Category**: Engineering
**Agent**: architecture-agent (Sonnet)

| Preset | Weight |
|--------|--------|
| generic | 5% |
| synapse | 8% |
| saas | 6% |
| library | 6% |

**Key Metrics**:
1. Max file size (LOC) — `find . -name "*.py" -o -name "*.ts" | xargs wc -l 2>/dev/null | sort -rn | head -10`
2. Cross-layer imports — `grep -rnI "from.*frontend\|import.*backend" --include="*.py" --include="*.ts" . | wc -l`
3. Circular dependency count — `madge --circular --extensions ts src/ 2>/dev/null | wc -l` / `python -c "import importlib; ..."`

**Scoring Rubric**:
| Score | Criteria |
|-------|----------|
| 0-2 | God files > 1K LOC, no module boundaries, circular deps > 10, spaghetti imports |
| 3-4 | Some structure but leaky layers, files > 500 LOC common, shared/ is a dump |
| 5-6 | Clear module boundaries, most files < 300 LOC, layer violations < 5 |
| 7-8 | Clean dependency direction, domain-driven modules, zero circular deps |
| 9-10 | Hexagonal/clean arch, explicit ports/adapters, module dependency graph is a DAG |

**Common Findings**:
- P0: Circular dependency between core modules causing import failures
- P1: God file (> 1K LOC) mixing business logic, DB, and presentation
- P2: Shared utility module growing without boundaries (> 50 exports)
- P3: Inconsistent module naming (mix of feature-based and layer-based)

---

### D5: Code Quality ✨

**Category**: Quality
**Agent**: quality-agent (Sonnet)

| Preset | Weight |
|--------|--------|
| generic | 5% |
| synapse | 5% |
| saas | 6% |
| library | 7% |

**Key Metrics**:
1. Lint violations — `ruff check . --statistics 2>&1 | tail -5` / `eslint . --format compact 2>&1 | grep -c "problem"`
2. TODO/FIXME density — `grep -rnI "TODO\|FIXME\|HACK\|XXX" --include="*.py" --include="*.ts" . | wc -l`
3. Cyclomatic complexity — `radon cc . -a -nc 2>&1 | tail -1` / `npx eslint . --rule '{"complexity": ["warn", 10]}' 2>&1 | grep -c "complexity"`

**Scoring Rubric**:
| Score | Criteria |
|-------|----------|
| 0-2 | No linter, > 100 violations, dead code everywhere, no formatter |
| 3-4 | Linter configured but many ignores, inconsistent formatting, complexity > 15 |
| 5-6 | Linter passes with < 20 warnings, formatter enforced, avg complexity < 10 |
| 7-8 | Zero lint warnings, pre-commit hooks, complexity < 7, dead code < 1% |
| 9-10 | Custom lint rules for domain, pre-commit + CI enforce, all functions < 30 LOC |

**Common Findings**:
- P0: Dead code paths that shadow live functionality
- P1: Functions with cyclomatic complexity > 20
- P2: 50+ TODO/FIXME without linked issues
- P3: Inconsistent naming conventions across modules

---

### D6: Performance ⚡

**Category**: Engineering
**Agent**: performance-agent (Sonnet)

| Preset | Weight |
|--------|--------|
| generic | 5% |
| synapse | 2% |
| saas | 10% |
| library | 5% |

**Key Metrics**:
1. N+1 query patterns — `grep -rnI "for.*in.*\.all()\|\.query\.\|SELECT.*FROM" --include="*.py" . | head -20`
2. Frontend bundle size — `du -sh dist/ build/ .next/ 2>/dev/null` / `npx vite-bundle-visualizer 2>/dev/null`
3. Missing DB indexes — `grep -rnI "filter(\|where(\|ORDER BY" --include="*.py" . | head -10` cross-ref with index definitions

**Scoring Rubric**:
| Score | Criteria |
|-------|----------|
| 0-2 | N+1 queries in hot paths, no caching, bundle > 5MB, no DB indexes on FKs |
| 3-4 | Some caching, bundle 2-5MB, known slow queries, no pagination |
| 5-6 | Pagination present, bundle < 2MB, indexes on FKs, basic query optimization |
| 7-8 | Connection pooling, lazy loading, code splitting, p95 latency < 200ms |
| 9-10 | CDN, edge caching, query plan analysis, Lighthouse > 90, load testing in CI |

**Common Findings**:
- P0: N+1 query in list endpoint serving 1000+ items
- P1: No pagination on collection endpoints (unbounded queries)
- P2: Frontend bundle includes unused dependencies (tree-shaking disabled)
- P3: Missing DB indexes on frequently filtered columns

---

### D7: Observability 📡

**Category**: Operations
**Agent**: observability-agent (Haiku)

| Preset | Weight |
|--------|--------|
| generic | 5% |
| synapse | 4% |
| saas | 5% |
| library | 2% |

**Key Metrics**:
1. Structured logging adoption — `grep -rnI "structlog\|pino\|winston\|logging\.getLogger" --include="*.py" --include="*.ts" . | wc -l`
2. Correlation ID propagation — `grep -rnI "correlation_id\|request_id\|trace_id\|x-request-id" . | wc -l`
3. Health check endpoint — `grep -rnI "health\|readiness\|liveness" --include="*.py" --include="*.ts" . | wc -l`

**Scoring Rubric**:
| Score | Criteria |
|-------|----------|
| 0-2 | No structured logging, print statements for debugging, no health endpoint |
| 3-4 | Basic logging but unstructured, no correlation IDs, health check returns 200 only |
| 5-6 | Structured logging, health check with DB/dependency status, basic metrics |
| 7-8 | Correlation IDs on all requests, distributed tracing, alerting configured |
| 9-10 | OpenTelemetry instrumented, Grafana dashboards, SLO-based alerting, log retention policy |

**Common Findings**:
- P0: No health check endpoint — orchestrator cannot detect failures
- P1: Error logs missing context (no request ID, no user ID)
- P2: No metrics collection (request latency, error rate unknown)
- P3: Log levels inconsistent (INFO used for debug messages)

---

### D8: Documentation 📚

**Category**: Quality
**Agent**: quality-agent (Sonnet)

| Preset | Weight |
|--------|--------|
| generic | 5% |
| synapse | 4% |
| saas | 3% |
| library | 15% |

**Key Metrics**:
1. Essential files present — `ls README.md CHANGELOG.md CONTRIBUTING.md LICENSE 2>/dev/null | wc -l`
2. API doc coverage — `ls docs/openapi.* docs/swagger.* 2>/dev/null` / `grep -rl "openapi\|swagger" . | head -5`
3. Docstring coverage — `grep -rnP "def \w+\(" --include="*.py" . | wc -l` vs `grep -B1 "def \w+" --include="*.py" . | grep -c '"""'`

**Scoring Rubric**:
| Score | Criteria |
|-------|----------|
| 0-2 | No README, no inline docs, no API docs, no CHANGELOG |
| 3-4 | README exists but outdated, < 20% docstring coverage, no API spec |
| 5-6 | README current, OpenAPI spec generated, CHANGELOG maintained, > 40% docstrings |
| 7-8 | CONTRIBUTING guide, architecture docs, > 60% docstrings, examples in README |
| 9-10 | Auto-generated API docs, inline examples, ADRs, onboarding guide < 30 min to first PR |

**Common Findings**:
- P0: No README — new developers cannot onboard
- P1: API endpoints undocumented (no OpenAPI spec)
- P2: CHANGELOG not maintained (no release notes for 6+ months)
- P3: Code comments explain "what" instead of "why"

---

### D9: Developer Experience 🛠️

**Category**: Engineering
**Agent**: dx-agent (Haiku)

| Preset | Weight |
|--------|--------|
| generic | 5% |
| synapse | 3% |
| saas | 8% |
| library | 8% |

**Key Metrics**:
1. Setup step count — `wc -l README.md 2>/dev/null` + check for `docker-compose.yml` / `Makefile` / `justfile`
2. CI pipeline presence — `ls .github/workflows/*.yml .forgejo/workflows/*.yml .gitlab-ci.yml Jenkinsfile 2>/dev/null | wc -l`
3. Build time — `time make build 2>&1` / `time bun run build 2>&1` (estimate from config complexity)

**Scoring Rubric**:
| Score | Criteria |
|-------|----------|
| 0-2 | No CI, > 10 manual setup steps, no containerization, README missing setup |
| 3-4 | CI exists but flaky, setup requires tribal knowledge, > 5 min build |
| 5-6 | Docker Compose for local dev, CI green, < 3 min build, documented setup |
| 7-8 | One-command setup, pre-commit hooks, hot reload, IDE configs committed |
| 9-10 | Dev containers, < 60s build, branch previews, automated dependency updates |

**Common Findings**:
- P0: CI pipeline broken — merges without test validation
- P1: Local setup requires 10+ manual steps with undocumented env vars
- P2: No pre-commit hooks (lint/format failures caught only in CI)
- P3: Missing `.editorconfig` or IDE settings (inconsistent formatting)

---

### D10: Dependency Health 📦

**Category**: Engineering
**Agent**: dx-agent (Haiku)

| Preset | Weight |
|--------|--------|
| generic | 5% |
| synapse | 3% |
| saas | 4% |
| library | 5% |

**Key Metrics**:
1. Vulnerable deps — `pip-audit 2>&1 | grep -c "VULN"` / `npm audit --json 2>&1 | python3 -c "import sys,json; print(json.load(sys.stdin).get('metadata',{}).get('vulnerabilities',{}))"`
2. Outdated major versions — `pip list --outdated --format=json 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)))"` / `npx npm-check-updates 2>&1 | grep -c "→"`
3. Dependency count — `pip freeze | wc -l` / `jq '.dependencies | length' package.json`

**Scoring Rubric**:
| Score | Criteria |
|-------|----------|
| 0-2 | > 5 HIGH CVEs, pinned to EOL versions, no lockfile |
| 3-4 | Lockfile present but stale, 1-5 HIGH CVEs, major version behind > 3 deps |
| 5-6 | Zero HIGH CVEs, lockfile current, < 3 major versions behind |
| 7-8 | Automated dep updates (Dependabot/Renovate), minimal dep tree, audit in CI |
| 9-10 | Zero CVEs, all deps within 1 minor version, SBOM generated, license compliance |

**Common Findings**:
- P0: Dependency with known RCE vulnerability in production
- P1: No lockfile — builds are non-reproducible
- P2: 10+ dependencies with major version upgrades available
- P3: Unused dependencies still in manifest (bloating install)

---

### D11: AI-Readiness 🤖

**Category**: Engineering
**Agent**: dx-agent (Haiku)

| Preset | Weight |
|--------|--------|
| generic | 5% |
| synapse | 3% |
| saas | 2% |
| library | 3% |

**Key Metrics**:
1. CLAUDE.md quality — `wc -w CLAUDE.md 2>/dev/null` (target: 200-800 words, W3H format)
2. Rule file count — `ls .claude/rules/*.md 2>/dev/null | wc -l`
3. Context file structure — `ls .claude/ .cursor/ .github/copilot-instructions.md .blueprint/ 2>/dev/null | wc -l`

**Scoring Rubric**:
| Score | Criteria |
|-------|----------|
| 0-2 | No CLAUDE.md, no AI context files, no structured documentation for AI tools |
| 3-4 | CLAUDE.md exists but < 100 words, no rules, no commands |
| 5-6 | CLAUDE.md with stack + commands + conventions, 1-3 rule files |
| 7-8 | W3H format CLAUDE.md, 5+ rules, custom commands, `.blueprint/` docs |
| 9-10 | Context-engineered repo: CLAUDE.md + rules + commands + skills + hooks, < 5 min AI onboarding |

**Common Findings**:
- P0: No AI context — every AI session wastes 10+ min rediscovering project
- P1: CLAUDE.md exists but outdated (references deleted files/commands)
- P2: No `.claude/rules/` for project-specific conventions
- P3: Missing command shortcuts for common dev workflows

---

### D12: Enterprise Readiness 🏢

**Category**: Enterprise
**Agent**: enterprise-agent (Sonnet)

| Preset | Weight |
|--------|--------|
| generic | 5% |
| synapse | 12% |
| saas | 2% |
| library | 0% |

**Key Metrics**:
1. Multi-tenant isolation — `grep -rnI "project_id\|tenant_id\|org_id" --include="*.py" . | wc -l` vs total query count
2. RBAC config presence — `grep -rlI "role\|permission\|rbac\|authorization" --include="*.py" . | wc -l`
3. Audit trail tables — `grep -rnI "audit_log\|event_log\|created_by\|modified_by" --include="*.py" --include="*.sql" . | wc -l`

**Scoring Rubric**:
| Score | Criteria |
|-------|----------|
| 0-2 | No tenant isolation, no RBAC, no audit trail, single-user design |
| 3-4 | Tenant ID exists but not enforced on all queries, basic role check |
| 5-6 | Tenant isolation on all data queries, role-based access, audit on mutations |
| 7-8 | Row-level security, RBAC with permissions matrix, full audit trail with actor |
| 9-10 | SOC2-ready controls, field-level encryption, SSO/SCIM, data residency support |

**Common Findings**:
- P0: Missing `project_id` filter on data queries — cross-tenant data leak
- P1: Admin endpoints without RBAC check
- P2: Mutations missing audit trail (no `created_by`, `updated_at`)
- P3: No soft-delete — hard deletes prevent data recovery audits

---

### D13: Accessibility ♿

**Category**: Quality
**Agent**: frontend-agent (Haiku)

| Preset | Weight |
|--------|--------|
| generic | 5% |
| synapse | 2% |
| saas | 7% |
| library | 1% |

**Key Metrics**:
1. ARIA attribute usage — `grep -rnI "aria-\|role=" --include="*.tsx" --include="*.jsx" . | wc -l`
2. Alt text coverage — `grep -rnI "<img\b" --include="*.tsx" --include="*.jsx" . | grep -vc "alt="`
3. Keyboard navigation — `grep -rnI "onKeyDown\|onKeyUp\|tabIndex\|focus" --include="*.tsx" . | wc -l`

**Scoring Rubric**:
| Score | Criteria |
|-------|----------|
| 0-2 | No ARIA attributes, images missing alt text, no keyboard navigation |
| 3-4 | Some ARIA labels, inconsistent focus management, no skip-to-content |
| 5-6 | ARIA on interactive elements, alt text on images, basic keyboard nav |
| 7-8 | axe-core in CI, WCAG 2.1 AA compliant, focus traps on modals, screen reader tested |
| 9-10 | WCAG 2.1 AAA, automated a11y regression tests, reduced motion support, live regions |

**Common Findings**:
- P0: Form inputs without associated labels — screen readers cannot identify fields
- P1: Modal dialogs without focus trap — keyboard users get lost
- P2: Color-only status indicators (no icon/text alternative)
- P3: Missing `lang` attribute on `<html>` element

---

### D14: i18n / l10n 🌍

**Category**: Quality
**Agent**: frontend-agent (Haiku)

| Preset | Weight |
|--------|--------|
| generic | 5% |
| synapse | 2% |
| saas | 4% |
| library | 1% |

**Key Metrics**:
1. Hardcoded strings — `grep -rnP ">[A-Z][a-z]+ [a-z]+" --include="*.tsx" --include="*.jsx" . | grep -v "i18n\|t(" | wc -l`
2. Locale file count — `find . -path "*/locales/*" -o -path "*/i18n/*" -o -path "*/translations/*" | wc -l`
3. Translation function usage — `grep -rnI "useTranslation\|t(\|i18n\.\|formatMessage" --include="*.tsx" --include="*.ts" . | wc -l`

**Scoring Rubric**:
| Score | Criteria |
|-------|----------|
| 0-2 | All strings hardcoded, no i18n library, no locale files |
| 3-4 | i18n library installed but < 30% strings extracted, 1 locale only |
| 5-6 | > 60% strings extracted, 2+ locales, date/number formatting locale-aware |
| 7-8 | > 90% strings extracted, RTL support, pluralization rules, CI checks for missing keys |
| 9-10 | 100% extracted, 5+ locales, automated translation pipeline, context for translators |

**Common Findings**:
- P0: User-facing error messages hardcoded in English only
- P1: Date/currency formatting ignoring user locale
- P2: Locale files missing keys present in source (partial translations)
- P3: String concatenation instead of parameterized translations

---

### D15: Infrastructure 🐳

**Category**: Operations
**Agent**: observability-agent (Haiku)

| Preset | Weight |
|--------|--------|
| generic | 5% |
| synapse | 3% |
| saas | 3% |
| library | 0% |

**Key Metrics**:
1. Dockerfile quality — `grep -c "FROM.*:latest\|ADD \.\|RUN pip install" Dockerfile 2>/dev/null` (anti-patterns)
2. IaC presence — `ls terraform/ pulumi/ cdk/ ansible/ 2>/dev/null | wc -l` + `find . -name "*.tf" -o -name "Pulumi.*" | wc -l`
3. Container security — `grep -c "USER\|HEALTHCHECK\|--no-cache\|--no-install-recommends" Dockerfile 2>/dev/null`

**Scoring Rubric**:
| Score | Criteria |
|-------|----------|
| 0-2 | No Dockerfile, `:latest` tags, no IaC, manual server provisioning |
| 3-4 | Dockerfile exists but `:latest` base, no multi-stage, no health check |
| 5-6 | Pinned base images, multi-stage build, docker-compose for local dev |
| 7-8 | Non-root user, health checks, IaC for all infra, secrets via vault/env |
| 9-10 | Distroless/scratch images, signed images, IaC with drift detection, GitOps CD |

**Common Findings**:
- P0: `:latest` tag on production base image — builds non-reproducible
- P1: Container running as root — container escape = host access
- P2: No HEALTHCHECK instruction in Dockerfile
- P3: Secrets passed as build args (visible in image layers)

---

### D16: Technical Debt Velocity 📉

**Category**: Engineering
**Agent**: architecture-agent (Sonnet)

| Preset | Weight |
|--------|--------|
| generic | 5% |
| synapse | 3% |
| saas | 3% |
| library | 3% |

**Key Metrics**:
1. TODO/FIXME trend — `git log --all --oneline --diff-filter=A --since="90 days" -p | grep -c "TODO\|FIXME"` vs `grep -rnI "TODO\|FIXME" . | wc -l`
2. Hotspot files (churn) — `git log --since="90 days" --pretty=format: --name-only | sort | uniq -c | sort -rn | head -10`
3. Dead code indicators — `grep -rnI "deprecated\|DEPRECATED\|# unused\|// unused" --include="*.py" --include="*.ts" . | wc -l`

**Scoring Rubric**:
| Score | Criteria |
|-------|----------|
| 0-2 | TODOs growing > 10/month, hotspot files > 500 LOC, no debt tracking |
| 3-4 | Debt acknowledged but no plan, hotspots identified but not refactored |
| 5-6 | TODOs linked to issues, hotspots < 300 LOC, debt sprint every 3 months |
| 7-8 | Debt velocity negative (reducing), automated hotspot alerts, refactor budget allocated |
| 9-10 | Zero stale TODOs, all debt items tracked with effort, continuous refactoring culture |

**Common Findings**:
- P0: Hotspot file with 50+ changes in 90 days and > 800 LOC (merge conflict magnet)
- P1: 100+ TODOs with no linked issues (invisible debt)
- P2: Deprecated code still called from 5+ locations
- P3: Copy-pasted code blocks across 3+ files (DRY violation)

---

### D17: API Design 🔌

**Category**: Enterprise
**Agent**: enterprise-agent (Sonnet)

| Preset | Weight |
|--------|--------|
| generic | 5% |
| synapse | 3% |
| saas | 5% |
| library | 12% |

**Key Metrics**:
1. OpenAPI spec validity — `ls docs/openapi.* openapi.* swagger.* 2>/dev/null` + `python3 -c "import yaml; yaml.safe_load(open('openapi.yaml'))" 2>&1`
2. Route naming consistency — `grep -rnI "@app\.\|@router\.\|app\.get\|app\.post" --include="*.py" --include="*.ts" . | head -20`
3. Error response standardization — `grep -rnI "HTTPException\|status_code\|error.*response\|ApiError" --include="*.py" --include="*.ts" . | head -10`

**Scoring Rubric**:
| Score | Criteria |
|-------|----------|
| 0-2 | No API spec, inconsistent route naming, no error schema, mixed REST verbs |
| 3-4 | Some routes documented, error responses vary per endpoint, no versioning |
| 5-6 | OpenAPI spec exists, consistent error format, REST conventions followed |
| 7-8 | API versioned, pagination standardized, rate limit headers, HATEOAS links |
| 9-10 | Contract-first design, breaking change detection in CI, SDK auto-generation |

**Common Findings**:
- P0: Breaking API changes without versioning
- P1: No standardized error response format (each endpoint returns different shapes)
- P2: Missing pagination on list endpoints
- P3: Inconsistent route naming (`/getUsers` mixed with `/users`)

---

### D18: Data Integrity 🗄️

**Category**: Enterprise
**Agent**: enterprise-agent (Sonnet)

| Preset | Weight |
|--------|--------|
| generic | 5% |
| synapse | 10% |
| saas | 1% |
| library | 0% |

**Key Metrics**:
1. FK constraint coverage — `grep -rnI "ForeignKey\|REFERENCES\|foreign_key" --include="*.py" --include="*.sql" . | wc -l`
2. Migration chain integrity — `ls alembic/versions/*.py migrations/*.py 2>/dev/null | wc -l` + check for linear chain
3. Backup configuration — `grep -rnI "backup\|pg_dump\|mongodump\|BACKUP" docker-compose*.yml *.sh 2>/dev/null | wc -l`

**Scoring Rubric**:
| Score | Criteria |
|-------|----------|
| 0-2 | No FK constraints, no migrations (raw SQL), no backups, orphan records possible |
| 3-4 | Some FKs but inconsistent, migrations exist but gaps in chain, manual backups |
| 5-6 | FKs on all relationships, linear migration chain, scheduled backups |
| 7-8 | Cascading rules defined, migration tests, point-in-time recovery, data validation layer |
| 9-10 | CDC for audit, migration rollback tested, backup restore verified weekly, checksums on exports |

**Common Findings**:
- P0: Missing FK constraints — orphan records accumulate silently
- P1: Migration chain has gaps (out-of-order or missing downgrade)
- P2: No automated backup schedule for production database
- P3: No unique constraints on natural keys (duplicate data possible)

---

### D19: Compliance 📋

**Category**: Security
**Agent**: security-agent (Sonnet)

| Preset | Weight |
|--------|--------|
| generic | 5% |
| synapse | 4% |
| saas | 2% |
| library | 0% |

**Key Metrics**:
1. Policy documents present — `ls SECURITY.md PRIVACY.md docs/compliance/ 2>/dev/null | wc -l`
2. Data classification markers — `grep -rnI "PII\|SENSITIVE\|CONFIDENTIAL\|GDPR\|data_classification" --include="*.py" --include="*.ts" . | wc -l`
3. License compliance — `ls LICENSE* 2>/dev/null` + `pip-licenses 2>/dev/null | grep -c "GPL"` / `npx license-checker --onlyAllow "MIT;Apache-2.0;BSD" 2>&1`

**Scoring Rubric**:
| Score | Criteria |
|-------|----------|
| 0-2 | No LICENSE, no SECURITY.md, no data handling policy, GPL deps in proprietary code |
| 3-4 | LICENSE present, basic security policy, no data classification, unknown dep licenses |
| 5-6 | SECURITY.md with disclosure process, data fields classified, license audit clean |
| 7-8 | SOC2 controls mapped, PII fields annotated, privacy-by-design, incident response plan |
| 9-10 | Automated compliance checks in CI, GDPR/CCPA controls, regular pen-test schedule, SBOM |

**Common Findings**:
- P0: GPL dependency in proprietary codebase — license violation
- P1: No SECURITY.md — no vulnerability disclosure process
- P2: PII fields stored without classification or encryption markers
- P3: Missing data retention policy documentation

---

### D20: Cost Efficiency 💰

**Category**: Operations
**Agent**: performance-agent (Sonnet)

| Preset | Weight |
|--------|--------|
| generic | 5% |
| synapse | 1% |
| saas | 3% |
| library | 1% |

**Key Metrics**:
1. Unused resource detection — `grep -rnI "import " --include="*.py" --include="*.ts" . | sort | uniq -c | sort -rn | head -10` (unused imports)
2. CI resource usage — check CI config for runner size, parallelism, caching strategy
3. Container resource limits — `grep -rnI "mem_limit\|cpus:\|resources:" docker-compose*.yml 2>/dev/null`

**Scoring Rubric**:
| Score | Criteria |
|-------|----------|
| 0-2 | No resource limits, CI runs > 30 min, unused services running, no build caching |
| 3-4 | Some limits set, CI 15-30 min, build cache partial, oversized containers |
| 5-6 | Resource limits on all containers, CI < 15 min, build cache effective |
| 7-8 | Right-sized containers, CI < 5 min, dependency caching, auto-scaling configured |
| 9-10 | Cost monitoring dashboards, spot instances, CI parallelism optimized, < 2 min builds |

**Common Findings**:
- P0: Production container without memory limit — OOM kills other services
- P1: CI pipeline running 30+ min due to no caching
- P2: Unused Docker services still running (consuming RAM)
- P3: Dev dependencies bundled in production image (oversized by > 2x)

---

## Weight Verification

| Preset | Sum | Valid |
|--------|-----|-------|
| generic | 100% | ✅ |
| synapse | 100% | ✅ |
| saas | 100% | ✅ |
| library | 100% | ✅ |
