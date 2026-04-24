---
name: product-health
description: "Application reality audit (live feature validation). This skill should be used when the user asks to '/atlas health', 'reality audit', 'application health', 'feature validation', 'UI audit', 'API audit', or needs a production-truth reality matrix."
effort: high
---

# Product Health — Application Reality Audit

Live validation of running application. Tests what ACTUALLY works, not what FEATURES.md claims. Produces `APPLICATION-REALITY-MATRIX.md` — ground truth for planning.

## When to Use

- "health", "health check", "reality check", "what's broken", "what actually works"
- "audit app", "test the app", "check pages", "screenshots"
- Before onboarding (validate the app team will work on)
- Before sprint planning (real vs aspirational)
- After major refactors / dependency upgrades
- Periodically (monthly)

## Subcommands

| Command | Mode | Scope |
|---------|------|-------|
| `/atlas health` | **Full** | API + UI + Tests + DB + Docker |
| `/atlas health api` | **API Only** | Backend endpoint health (curl) |
| `/atlas health ui` | **Browser** | Frontend pages, screenshots, console |
| `/atlas health tests` | **Test Suite** | Run BE + FE tests |
| `/atlas health matrix` | **Matrix Only** | Generate/refresh APPLICATION-REALITY-MATRIX.md |
| `/atlas health quick` | **Quick** | Docker + API + test counts (no browser) |

## Pipeline

```
DISCOVER → CHECK → ASSESS → MATRIX → RECOMMEND
```

## Phase 1: DISCOVER — Inventory

Collect from project config:

1. **Docker services**: `docker-compose.yml` for service names + ports
2. **API routes**: Backend router files or OpenAPI spec
3. **Frontend pages**: Router config (React Router)
4. **Active features**: `.blueprint/FEATURES.md` IN_PROGRESS
5. **Test files**: Count BE `test_*.py` + FE `*.test.ts(x)` / `*.spec.ts`

## Phase 2: CHECK — Live Validation

### 2.1 Docker Health (~1 min)

```bash
docker compose ps --format json 2>/dev/null
```

Per container: name, status, health, uptime, ports.

### 2.2 Backend API Health (~5 min)

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:8001/health                # Health endpoint
curl -s -o /dev/null -w "%{http_code}" http://localhost:8001/api/v1/{endpoint}     # Per-feature
```

**Discovery**: Read `backend/app/api/` router files for actual paths. Test each with GET (or POST with minimal payload for write).

**Classify**: 200-299 = PASS | 401/403 = AUTH_NEEDED | 404 = NOT_FOUND | 500+ = BROKEN

### 2.3 Frontend Page Audit (~10 min, browser mode)

**Tool selection** (first available): MCP Chrome DevTools (`mcp__chrome-devtools__*`) → MCP Playwright (`mcp__plugin_playwright_playwright__*`) → Claude-in-Chrome (`mcp__claude-in-chrome__*`) → Headless `bunx playwright test --reporter=json`

**Per page**:
1. Navigate to URL
2. Wait for load (network idle / specific element)
3. Screenshot → `.blueprint/screenshots/health-{date}/`
4. A11y snapshot (accessibility tree)
5. Capture console errors (filter: error, warn)
6. Check broken elements: empty data tables (AG Grid 0 rows when data expected), error boundaries triggered, missing images / broken links, uncaught exceptions
7. Score: WORKS (loads + data + clean) / PARTIAL (issues) / BROKEN (crash/blank)

**Pages to audit** (priority order):

| Priority | Page | URL | Key Check |
|----------|------|-----|-----------|
| P0 | Login / Auth | `/login` | SSO redirect works |
| P0 | Dashboard | `/` or `/dashboard` | Loads with project data |
| P0 | Instrument List | `/instruments` | AG Grid renders with rows |
| P1 | Tree Navigation | `/tree` or `/lbs` | Tree nodes expand |
| P1 | SynapseCAD | `/cad` or `/drawings` | Canvas renders |
| P1 | Rules Engine | `/rules` | Rules table loads |
| P1 | Procurement | `/procurement` | FRM/TBE tabs work |
| P2 | Import Pipeline | `/import` | Upload UI renders |
| P2 | Process Simulation | `/process` | Solver UI loads |
| P2 | Equipment Sizer | `/equipment` | Calc form renders |
| P2 | IO Allocation | `/io` | Allocation grid loads |
| P2 | Estimation | `/estimation` | Cost table renders |
| P3 | AI Copilot | `/ai` or `/chat` | Chat UI responds |
| P3 | Settings / Admin | `/settings` | Config forms load |

**Screenshot naming**: `{priority}-{page-slug}-{date}.png` (e.g. `p0-dashboard-2026-03-26.png`)

### 2.4 Test Suite Health (~5 min)

```bash
# Backend (in Docker)
docker exec synapse-backend bash -c "cd /app && python -m pytest tests/ --co -q 2>/dev/null | tail -1"  # Count
docker exec synapse-backend bash -c "cd /app && python -m pytest tests/ -x -q --tb=line 2>&1 | tail -5"  # Run

# Frontend
cd frontend && bunx vitest --run --reporter=json 2>/dev/null | tail -20
cd frontend && bun run type-check 2>&1 | tail -5
```

Capture: total tests, passed, failed, errors, coverage % if available.

### 2.5 Database Health (~1 min)

```bash
docker exec synapse-db psql -U synapse -d synapse -c "SELECT count(*) FROM instruments;" 2>/dev/null  # Connection
docker exec synapse-backend bash -c "cd /app && alembic current 2>/dev/null"                          # Migrations
docker exec synapse-db psql -U synapse -d synapse -c "
  SELECT 'instruments' as tbl, count(*) FROM instruments
  UNION ALL SELECT 'projects', count(*) FROM projects
  UNION ALL SELECT 'rules', count(*) FROM rules;" 2>/dev/null                                         # Real data
```

## Phase 3: ASSESS — Score

### Per-Feature Health

For each IN_PROGRESS feature:

| Dimension | Source | Weight |
|-----------|--------|--------|
| API responds | Phase 2.2 endpoints | 25% |
| UI works | Phase 2.3 page audit | 25% |
| Tests pass | Phase 2.4 results | 20% |
| Real data | Phase 2.5 DB | 15% |
| Console clean | Phase 2.3 errors | 15% |

**Grade**: A (90-100) end-to-end + tests + clean console | B (70-89) works minor issues | C (50-69) partial (API or UI broken) | D (30-49) significant issues | F (0-29) non-functional / crashes

### Overall App Health

```
App Health = weighted avg of feature health scores
Weights: P0 × 3, P1 × 2, P2 × 1, P3 × 0.5
```

## Phase 4: MATRIX — Output

Generate or update `.blueprint/APPLICATION-REALITY-MATRIX.md`:

```markdown
# Application Reality Matrix

> Generated: {date} | Method: {full|api|ui|quick} | App Health: {grade} ({score}/100)

## Summary

| Metric | Value |
|--------|-------|
| Docker containers | {healthy}/{total} |
| API endpoints | {passing}/{tested} |
| Frontend pages | {working}/{audited} |
| Backend tests | {pass}/{total} ({fail} failed) |
| Frontend tests | {pass}/{total} ({fail} failed) |
| Type check | {PASS/FAIL} ({N} errors) |
| DB records | {instrument_count} instruments, {project_count} projects |

## Feature Health Matrix

| Feature | API | UI | Tests | Data | Console | Grade | Action Needed |
|---------|-----|----|----- -|------|---------|-------|---------------|
| FEAT-NNN {Name} | {icon} | {icon} | {icon} | {icon} | {icon} | {grade} | {fix} |

## Page Screenshots

| Page | Status | Screenshot | Console Errors |
|------|--------|------------|----------------|
| Dashboard | {icon} | [link](screenshots/health-{date}/p0-dashboard.png) | {N} errors |

## Broken Items (Action Required)

### Critical (blocks usage)
- {description + file + suggested fix}

### High (degraded experience)
- {description + file + suggested fix}

### Medium (cosmetic / non-blocking)
- {description}

## Test Failures

{paste of failed test output if any}
```

## Phase 5: RECOMMEND

After matrix, AskUserQuestion:

1. "App health is {grade}. {N} critical issues. What to fix first?"
   - Options based on findings: "Fix API errors" / "Fix broken pages" / "Fix failing tests" / "Generate Forgejo issues" / "Skip — just the report"
2. If critical issues: recommend specific fix order (highest impact first)

## Delegation

| Check | Delegates to | When |
|-------|-------------|------|
| Docker + service health | `atlas-doctor` (Cat 5: Services) | Always for docker checks |
| Test execution | `verification` (L1-L4) | `--deep` flag |
| Security scan | `security-audit` | `--security` flag |
| Feature data | `feature-board` | For feature list + DoD data |

## Output Files

| File | Location | Content |
|------|----------|---------|
| Reality Matrix | `.blueprint/APPLICATION-REALITY-MATRIX.md` | Full audit |
| Screenshots | `.blueprint/screenshots/health-{date}/` | Page captures |
| Raw results | `/tmp/atlas-health-{date}.json` | Machine-readable |

## Configuration

If `.atlas/health.yaml` exists, use for custom endpoints/pages:

```yaml
api:
  base_url: http://localhost:8001
  auth_token_env: SYNAPSE_API_TOKEN
  endpoints:
    - { path: /api/v1/instruments, method: GET, expected_status: 200 }
    - { path: /api/v1/rules/evaluate, method: POST, body: {"instrument_id": 1}, expected_status: 200 }

pages:
  base_url: http://localhost:4000
  items:
    - { path: /, name: Dashboard, priority: P0, wait_for: ".ag-root" }
    - { path: /instruments, name: Instrument List, priority: P0, wait_for: ".ag-row" }

thresholds:
  min_grade: C            # Fail audit if below
  max_console_errors: 5   # Per page
  max_api_failures: 0     # Zero tolerance for core
```

No config: auto-discover endpoints + pages from codebase.

## Safety Rules

- NEVER modify application code during health check (read-only)
- NEVER send real user credentials to API (test token or skip auth)
- NEVER delete previous screenshots (append, don't replace)
- Always save raw results before generating markdown (recovery)
- Browser tools unavailable → skip UI gracefully ("NOT TESTED")
- Respect `--timeout` (default: 30s/page, 5s/API call)
