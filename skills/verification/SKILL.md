---
name: verification
description: "Complete verification: L1-L6 tests + quality gates pipeline (build→types→lint→tests→security→diff) + E2E persona tests + security scan + performance benchmarks + checkpoints. Evidence before assertions."
effort: medium
---

# Verification

**Principle**: Evidence before assertions. NEVER claim work passes without running commands and confirming output.

## Verification Levels

| Level | Scope | Command pattern | Notes |
|-------|-------|----------------|-------|
| **L1** | Backend unit | `docker exec synapse-backend bash -c "cd /app && python -m pytest tests/{path} -x -q --tb=short"` | Specific file first, then broader |
| **L2** | Frontend unit + types | `cd frontend && bunx vitest --run` + `bun run type-check` | Independent, can parallelize |
| **L3** | E2E (Playwright) | `cd frontend && bunx playwright test e2e/qa-*.spec.ts` | Only if plan Section O specifies E2E |
| **L4** | Persona validation | Per persona: precondition → action → verify result → check RBAC → check perf | Browser automation, API curl, or manual |
| **L5** | Security | Input validation, RBAC enforcement (wrong role), no secrets in responses/logs | Code review + runtime checks |
| **L6** | Performance | `time curl -s "localhost:8001/api/v1/{pid}/resource"` (target <200ms) + `bunx vite build` (bundle size) | Benchmarks |

## Output Format

```
✅ VERIFICATION REPORT
L1 Backend:  ✅/❌ {passed} passed ({failed} failed)
L2 Frontend: ✅/❌ {passed} passed, type-check {status}
L3 E2E:      ✅/❌ {scenarios} scenarios
L4 Persona:  {role}: ✅/❌ {details} (per persona)
L5 Security: ✅/❌ {details}
L6 Perf:     ✅/❌ API {ms}ms, build {size}
OVERALL: ✅/❌
```

## Parallel Execution

**Sequential first**: DB migrations (`alembic upgrade head`) must complete before any test.

**Then parallel** (3 background calls in same message):
1. pytest (backend) → `/tmp/pytest-results.txt`
2. vitest (frontend) → `/tmp/vitest-results.txt`
3. type-check → `/tmp/typecheck-results.txt`

**Do NOT parallelize**: migration+tests, 2 pytest on same DB, E2E+pytest, security+deploy.

## Quality Gates Pipeline (fail-fast)

| Gate | Command | Hard fail |
|------|---------|-----------|
| **Build** | `bun run build` | Yes |
| **Types** | `bun run typecheck` | Yes |
| **Lint** | `bun run lint` | Yes |
| **Tests** | `bun test` / `pytest` | Yes |
| **Security** | Grep staged: secrets, .env, private keys, console.log | Secrets/keys: yes. console.log: warning |
| **Diff** | `git status --short` + `git diff --stat` | Info only |

Detect available scripts first. Missing gate = ⏭️ skipped. Stop on first failure.

**Status**: ✅ Passed | ❌ Failed (blocking) | ⚠️ Warning | ⏭️ Skipped

## Flags

| Flag | Behavior |
|------|----------|
| `--quick` | Smoke tests only |
| `--fix` | Auto-fix lint |
| `--verbose` | Full output |
| `--no-security` | Skip security scan |

## Checkpoints

`checkpoint save|compare|list|diff` — captures test counts, type errors, lint errors, security issues, coverage %, file checksums. Flags regressions (decreased passes, increased errors).

## On Failure

1. Identify which level failed
2. Use systematic-debugging skill
3. Max 2 fix attempts
4. Still failing → AskUserQuestion: what failed, what tried, 2-3 alternatives

## HITL Gates

- **All pass** → AskUserQuestion: "All gates pass. Ready to commit/ship?"
- **Any fail** → AskUserQuestion: "(a) Fix issues (b) Skip gate (c) Abort — I'll fix manually"

## Never Skip
- NEVER claim "tests pass" without running them
- NEVER claim "it works" without verifying
- ALWAYS show actual output
- ALWAYS run type-check
