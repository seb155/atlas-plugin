---
name: product-health
description: "Application reality audit (live feature validation). This skill should be used when the user asks to '/atlas health', 'reality audit', 'application health', 'feature validation', 'UI audit', 'API audit', or needs a production-truth reality matrix."
effort: high
---

# Product Health — Application Reality Audit

Live validation of the running application. Tests what ACTUALLY works, not what FEATURES.md claims.
Produces `APPLICATION-REALITY-MATRIX.md` — the ground truth for planning.

## When to Use

- User says "health", "health check", "reality check", "what's broken", "what actually works"
- User says "audit app", "test the app", "check pages", "screenshots"
- Before onboarding new team members (validate the app they'll work on)
- Before sprint planning (know what's real vs. aspirational)
- After major refactors or dependency upgrades
- Periodically (monthly recommended)

## Subcommands

| Command | Mode | Scope |
|---------|------|-------|
| `/atlas health` | **Full** | All checks: API + UI + Tests + DB + Docker |
| `/atlas health api` | **API Only** | Backend endpoint health (curl-based) |
| `/atlas health ui` | **Browser** | Frontend page audit with screenshots + console |
| `/atlas health tests` | **Test Suite** | Run BE + FE tests, report pass/fail |
| `/atlas health matrix` | **Matrix Only** | Generate/refresh APPLICATION-REALITY-MATRIX.md |
| `/atlas health quick` | **Quick** | Docker + API health + test counts (no browser) |

## Pipeline

```
DISCOVER → CHECK → ASSESS → MATRIX → RECOMMEND
```

---

## Phase 1: DISCOVER — Inventory

Collect what to check from project configuration:

1. **Docker services**: Parse `docker-compose.yml` for service names + ports
2. **API routes**: Read backend router files or OpenAPI spec for endpoint list
3. **Frontend pages**: Read router config (React Router) for page paths
4. **Active features**: Read `.blueprint/FEATURES.md` for IN_PROGRESS features
5. **Test files**: Count backend `test_*.py` and frontend `*.test.ts(x)` / `*.spec.ts`

Output: Inventory of what will be checked.

---

## Phase 2: CHECK — Live Validation

### 2.1 Docker Health (~1 min)

```bash
docker compose ps --format json 2>/dev/null
```

For each container, capture: name, status, health, uptime, ports.

### 2.2 Backend API Health (~5 min)

For each core API endpoint:

```bash
# Health endpoint
curl -s -o /dev/null -w "%{http_code}" http://localhost:8001/health

# Per-feature endpoints (with auth token if needed)
curl -s -o /dev/null -w "%{http_code}" http://localhost:8001/api/v1/{endpoint}
```

**Endpoint discovery strategy**:
1. Read `backend/app/api/` router files to find actual paths
2. Test each with GET (or POST with minimal payload for write endpoints)
3. Classify: 200-299 = PASS, 401/403 = AUTH_NEEDED, 404 = NOT_FOUND, 500+ = BROKEN

### 2.3 Frontend Page Audit (~10 min, browser mode)

**Tool selection** (use first available):
1. **MCP Chrome DevTools** (`mcp__chrome-devtools__*`) — if Chrome is connected
2. **MCP Playwright** (`mcp__plugin_playwright_playwright__*`) — if Playwright MCP is available
3. **Claude-in-Chrome** (`mcp__claude-in-chrome__*`) — if Chrome extension is connected
4. **Headless fallback**: `bunx playwright test --reporter=json` — if no browser MCP available

**Per page, execute**:

```
1. Navigate to page URL
2. Wait for load (wait_for network idle or specific element)
3. Take screenshot (save to .blueprint/screenshots/health-{date}/)
4. Take accessibility snapshot (a11y tree)
5. Capture console errors (filter: error, warn)
6. Check for broken elements:
   - Empty data tables (AG Grid with 0 rows when data expected)
   - Error boundaries triggered
   - Missing images / broken links
   - Uncaught exceptions in console
7. Score: WORKS (loads + data + no errors) / PARTIAL (loads but issues) / BROKEN (crash/blank)
```

**Pages to audit** (ordered by priority):

| Priority | Page | URL Pattern | Key Check |
|----------|------|-------------|-----------|
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

**Screenshot naming**: `{priority}-{page-slug}-{date}.png`
Example: `p0-dashboard-2026-03-26.png`

### 2.4 Test Suite Health (~5 min)

```bash
# Backend tests (run inside Docker)
docker exec synapse-backend bash -c "cd /app && python -m pytest tests/ --co -q 2>/dev/null | tail -1"
# ^ Count only (--co = collect only)

docker exec synapse-backend bash -c "cd /app && python -m pytest tests/ -x -q --tb=line 2>&1 | tail -5"
# ^ Run with first-failure stop

# Frontend tests
cd frontend && bunx vitest --run --reporter=json 2>/dev/null | tail -20
cd frontend && bun run type-check 2>&1 | tail -5
```

Capture: total tests, passed, failed, errors, coverage % if available.

### 2.5 Database Health (~1 min)

```bash
# Check connection
docker exec synapse-db psql -U synapse -d synapse -c "SELECT count(*) FROM instruments;" 2>/dev/null

# Check migrations
docker exec synapse-backend bash -c "cd /app && alembic current 2>/dev/null"

# Check real data presence
docker exec synapse-db psql -U synapse -d synapse -c "
  SELECT 'instruments' as tbl, count(*) FROM instruments
  UNION ALL SELECT 'projects', count(*) FROM projects
  UNION ALL SELECT 'rules', count(*) FROM rules;" 2>/dev/null
```

---

## Phase 3: ASSESS — Score

### Per-Feature Health Score

For each IN_PROGRESS feature, cross-reference checks:

| Dimension | Source | Weight |
|-----------|--------|--------|
| API responds | Phase 2.2 endpoint results | 25% |
| UI works | Phase 2.3 page audit | 25% |
| Tests pass | Phase 2.4 test results | 20% |
| Real data | Phase 2.5 DB check | 15% |
| Console clean | Phase 2.3 error count | 15% |

**Health Grade**:
- **A** (90-100): Feature works end-to-end, tests pass, no console errors
- **B** (70-89): Feature works but minor issues (warnings, missing edge cases)
- **C** (50-69): Partially works — API OK but UI broken, or vice versa
- **D** (30-49): Mostly broken — significant issues
- **F** (0-29): Non-functional — crashes, 500s, blank pages

### Overall Application Health

```
App Health = weighted average of all feature health scores
Weights: P0 features × 3, P1 × 2, P2 × 1, P3 × 0.5
```

---

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
| FEAT-NNN {Name} | {icon} | {icon} | {icon} | {icon} | {icon} | {grade} | {fix description} |
...

## Page Screenshots

| Page | Status | Screenshot | Console Errors |
|------|--------|------------|----------------|
| Dashboard | {icon} | [screenshot](screenshots/health-{date}/p0-dashboard.png) | {N} errors |
...

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

---

## Phase 5: RECOMMEND

After generating the matrix, use AskUserQuestion:

1. "The app health is {grade}. Here are the {N} critical issues. What do you want to fix first?"
   - Options based on findings: "Fix API errors", "Fix broken pages", "Fix failing tests", "Generate Forgejo issues", "Skip — just the report"

2. If critical issues found, recommend specific fix order (highest impact first)

---

## Delegation

| Check | Delegates to | When |
|-------|-------------|------|
| Docker + service health | `atlas-doctor` skill (Cat 5: Services) | Always for docker checks |
| Test execution | `verification` skill (L1-L4) | When --deep flag used |
| Security scan | `security-audit` skill | When --security flag used |
| Feature data | `feature-board` skill | For feature list + DoD data |

---

## Output Files

| File | Location | Content |
|------|----------|---------|
| Reality Matrix | `.blueprint/APPLICATION-REALITY-MATRIX.md` | Full audit report |
| Screenshots | `.blueprint/screenshots/health-{date}/` | Page screenshots |
| Raw results | `/tmp/atlas-health-{date}.json` | Machine-readable results |

---

## Configuration

If `.atlas/health.yaml` exists in project root, use it for custom endpoints and pages:

```yaml
# .atlas/health.yaml (optional)
api:
  base_url: http://localhost:8001
  auth_token_env: SYNAPSE_API_TOKEN  # env var name
  endpoints:
    - path: /api/v1/instruments
      method: GET
      expected_status: 200
    - path: /api/v1/rules/evaluate
      method: POST
      body: { "instrument_id": 1 }
      expected_status: 200

pages:
  base_url: http://localhost:4000
  items:
    - path: /
      name: Dashboard
      priority: P0
      wait_for: ".ag-root"  # CSS selector to wait for
    - path: /instruments
      name: Instrument List
      priority: P0
      wait_for: ".ag-row"

thresholds:
  min_grade: C         # Fail audit if below this
  max_console_errors: 5  # Per page
  max_api_failures: 0    # Zero tolerance for core endpoints
```

If no config file exists, auto-discover endpoints and pages from codebase.

---

## Safety Rules

- NEVER modify application code during health check (read-only audit)
- NEVER send real user credentials to API (use test token or skip auth)
- NEVER delete screenshots from previous audits (append, don't replace)
- Always save raw results before generating markdown (recovery)
- If browser tools are unavailable, skip UI audit gracefully (report as "NOT TESTED")
- Respect `--timeout` flag (default: 30s per page, 5s per API call)
