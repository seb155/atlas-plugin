---
name: test-orchestrator
description: "Orchestrate full ecosystem test pyramid from Claude Code. Use when running tests, checking coverage, or verifying test health."
model: sonnet
---

# Test Orchestrator

**Principle**: Never claim tests pass without running them. Always show actual output.

## Subcommands

| Command | Suite | Approx. time | When to use |
|---------|-------|--------------|-------------|
| `/atlas test smoke` | Backend smoke + Frontend vitest | ~30s | After every change |
| `/atlas test unit` | All backend + frontend unit tests | ~2min | Before PR |
| `/atlas test integration` | DB integration tests | ~3min | Local only (needs DB) |
| `/atlas test e2e` | Playwright E2E suite | ~5min | UI feature changes |
| `/atlas test security` | Security test suite | ~1min | Before merge to main |
| `/atlas test plugin` | Atlas Plugin structural + build tests | ~20s | After editing skills/hooks |
| `/atlas test infra` | Infrastructure health checks | ~30s | After Docker/infra changes |
| `/atlas test full` | Complete pyramid (all above) | ~10min | Release, major refactor |
| `/atlas test coverage` | Coverage report + threshold check | ~3min | Sprint review |

## Exact Commands

### `/atlas test smoke`
```bash
# Backend smoke — fastest health check
docker exec synapse-backend bash -c "cd /app && python -m pytest tests/ -x -q --tb=short -m smoke 2>/dev/null || python -m pytest tests/ -x -q --tb=short --co -q 2>&1 | head -5 && python -m pytest tests/test_health.py tests/test_api_instruments.py -x -q --tb=short 2>/dev/null || python -m pytest tests/ -x -q --tb=short -k 'health or smoke'"

# Frontend vitest — unit + type check
cd /home/sgagnon/workspace_atlas/projects/atlas/synapse/frontend && bunx vitest --run --reporter=verbose 2>&1 | tail -20
cd /home/sgagnon/workspace_atlas/projects/atlas/synapse/frontend && bun run type-check 2>&1 | tail -10
```

### `/atlas test unit`
```bash
# Backend — full unit suite (not integration)
docker exec synapse-backend bash -c "cd /app && python -m pytest tests/ -x -q --tb=short --ignore=tests/integration"

# Frontend — vitest + type-check
cd /home/sgagnon/workspace_atlas/projects/atlas/synapse/frontend && bunx vitest --run && bun run type-check
```

### `/atlas test integration`
```bash
# Requires: Docker stack running (db:5433, backend:8001)
# Local only — NEVER run on ATL-dev (no Docker)
docker exec synapse-backend bash -c "cd /app && python -m pytest tests/integration/ -x -q --tb=short"
```

### `/atlas test e2e`
```bash
# Full Playwright QA suite
cd /home/sgagnon/workspace_atlas/projects/atlas/synapse/frontend && bunx playwright test e2e/qa-*.spec.ts

# Single spec (faster iteration)
cd /home/sgagnon/workspace_atlas/projects/atlas/synapse/frontend && bunx playwright test e2e/qa-instruments.spec.ts
```

### `/atlas test security`
```bash
# Backend security tests
docker exec synapse-backend bash -c "cd /app && python -m pytest tests/ -x -q --tb=short -k 'security or rbac or auth'"

# Frontend — grep for risky patterns
grep -r "localStorage.*[Tt]oken" /home/sgagnon/workspace_atlas/projects/atlas/synapse/frontend/src/ && echo "WARNING: token in localStorage" || echo "OK: no token in localStorage"
grep -r "allow_origins.*\*" /home/sgagnon/workspace_atlas/projects/atlas/synapse/backend/ && echo "WARNING: CORS wildcard" || echo "OK: no CORS wildcard"
```

### `/atlas test plugin`
```bash
# Atlas Plugin structural tests (no Docker needed)
cd /home/sgagnon/workspace_atlas/projects/atlas/synapse/atlas-plugin && python -m pytest tests/ -x -q --tb=short
```

### `/atlas test infra`
```bash
# Docker stack health
docker compose -f /home/sgagnon/workspace_atlas/projects/atlas/synapse/compose.yml ps --format "{{.Name}} {{.Status}}"

# API health
curl -s http://localhost:8001/health | python3 -m json.tool

# Frontend responding
curl -s -o /dev/null -w "Frontend HTTP %{http_code}\n" http://localhost:4000

# DB connectivity
docker exec synapse-backend bash -c "cd /app && python -c 'from app.db import get_db; print(\"DB OK\")'"
```

### `/atlas test full`
```bash
# Run all suites sequentially (fail-fast at each level)
# Step 1: Environment health
docker compose -f /home/sgagnon/workspace_atlas/projects/atlas/synapse/compose.yml ps --format "{{.Name}} {{.Status}}"
curl -sf http://localhost:8001/health > /dev/null && echo "Backend OK" || echo "Backend DOWN"

# Step 2: Plugin (fastest, no Docker)
cd /home/sgagnon/workspace_atlas/projects/atlas/synapse/atlas-plugin && python -m pytest tests/ -x -q --tb=short

# Step 3: Backend unit
docker exec synapse-backend bash -c "cd /app && python -m pytest tests/ -x -q --tb=short --ignore=tests/integration"

# Step 4: Frontend unit + types
cd /home/sgagnon/workspace_atlas/projects/atlas/synapse/frontend && bunx vitest --run && bun run type-check

# Step 5: Integration
docker exec synapse-backend bash -c "cd /app && python -m pytest tests/integration/ -x -q --tb=short"

# Step 6: E2E
cd /home/sgagnon/workspace_atlas/projects/atlas/synapse/frontend && bunx playwright test e2e/qa-*.spec.ts
```

### `/atlas test coverage`
```bash
# Backend coverage (check thresholds in .atlas/test-config.yaml)
docker exec synapse-backend bash -c "cd /app && python -m pytest tests/ -q --tb=short --ignore=tests/integration --cov=app --cov-report=term-missing --cov-fail-under=15"

# Frontend coverage
cd /home/sgagnon/workspace_atlas/projects/atlas/synapse/frontend && bunx vitest --run --coverage

# Plugin coverage
cd /home/sgagnon/workspace_atlas/projects/atlas/synapse/atlas-plugin && python -m pytest tests/ -q --tb=short --cov=. --cov-report=term-missing --cov-fail-under=100 -k 'frontmatter or schema or structure'
```

## Coverage Thresholds

See `.atlas/test-config.yaml` for authoritative thresholds.

| Suite | Current floor | Target |
|-------|--------------|--------|
| Backend | 15% | 25% |
| Frontend | 8% | 15% |
| Plugin structural | 100% | 100% |

## Output Format

Always report results in this format:

```
TEST PYRAMID REPORT
Plugin:      PASS/FAIL  {n} passed ({n} failed) — {duration}
Backend:     PASS/FAIL  {n} passed ({n} failed) — {duration}
Frontend:    PASS/FAIL  {n} passed, type-check PASS/FAIL — {duration}
Integration: PASS/FAIL  {n} passed ({n} failed) — {duration}
E2E:         PASS/FAIL  {n} scenarios — {duration}
Coverage:    BE {n}% / FE {n}% / Plugin {n}%
OVERALL: PASS/FAIL
```

## Safe Flags

| Flag | Behavior |
|------|----------|
| `-x` | Stop at first failure (ALWAYS use with pytest) |
| `-q` | Quiet output |
| `--tb=short` | Short traceback (NEVER `--tb=long`) |
| `--run` | Single vitest run (NEVER `--watch`) |

## Never

- NEVER use `--pdb`, `-s`, `--watch`, `nodemon` (interactive = hang)
- NEVER run `tests/` without `-x` on a large suite — test one file first
- NEVER skip type-check (`bun run type-check`) when frontend tests pass
- NEVER run integration tests on `ATL-dev` (no Docker)
