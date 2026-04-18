---
name: verification
description: "Complete verification: L1-L6 tests + quality gates pipeline (build→types→lint→tests→security→diff) + E2E persona tests + security scan + performance benchmarks + checkpoints. Evidence before assertions."
effort: medium
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [tdd, systematic-debugging, code-review]
thinking_mode: adaptive
---

# Verification

**Principle**: Evidence before assertions. NEVER claim work passes without running commands and confirming output.

<HARD-GATE>
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE.
If you have not run the verification command in this message, you cannot claim it passes.
Evidence before assertions, always.
</HARD-GATE>

**Iron Law**: `LAW-VERIFY-001` (evidence-before-assertions). Override requires HITL AskUserQuestion. Source: `scripts/execution-philosophy/iron-laws.yaml`.

<red-flags>
| Thought | Reality |
|---|---|
| "Tests should pass now, committing" | "Should pass" is a wish, not evidence. Confidence is not verification. Until the command runs and the output is read, you do not know — you hope. |
| "Good enough, we can refactor later" | "Later" is the cemetery where good intentions go. Code merged ships to production. Every refactor-later is a mortgage with compound interest paid in incident reviews. |
| "YAGNI — nobody will notice this edge case" | YAGNI means "don't build speculative features", not "don't handle real inputs". Edge cases happen IN PRODUCTION to REAL users, not in your head. |
| "The agent reported success, task is done" | Agent reports are NOT evidence. Agents can claim success while leaving an empty diff, broken tests, or uncommitted files. Trust but verify — always check the VCS diff independently. |
| "Trust me, I've done this pattern 20 times" | Experience speeds recognition, not verification. The 20 previous times had 20 different contexts. This one has its own gotcha you have not met yet. |
</red-flags>

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

## Environment Health Checks (run BEFORE L1-L6)

Before running any verification, check the runtime environment is healthy:

| Check | Command | Fix if broken |
|-------|---------|---------------|
| **Docker containers up** | `docker compose ps --format "{{.Name}} {{.Status}}"` | `docker compose up -d` |
| **Workspace packages synced** | `docker exec synapse-frontend ls node_modules/@axoiq/` | `docker exec synapse-frontend bun install && docker restart synapse-frontend` |
| **Vite dev server responding** | `curl -s -o /dev/null -w "%{http_code}" http://localhost:4000` | `docker restart synapse-frontend` |
| **Backend API healthy** | `curl -s http://localhost:8001/health` | `docker restart synapse-backend` |
| **Vite cache stale** | Check if `node_modules/.vite` is outdated after package changes | `docker exec synapse-frontend rm -rf node_modules/.vite && docker restart synapse-frontend` |

**When to run**:
- After adding/modifying workspace packages (`frontend/packages/*`)
- After `bun install` or `bun.lock` changes
- After Docker container rebuild
- When you see `Failed to resolve import "@axoiq/*"` errors

**Auto-fix pattern** (for finishing-branch skill):
```bash
# If workspace packages changed in this commit:
if git diff --cached --name-only | grep -q "^frontend/packages/"; then
  docker exec synapse-frontend bun install
  docker restart synapse-frontend
  sleep 5
  curl -sf http://localhost:4000 > /dev/null || echo "⚠️ Frontend not responding after package sync"
fi
```

## DoD Tier Check (after L1-L6)

After completing verification levels, compute the DoD tier from the feature's validation matrix:

| Tier | Score | Meaning |
|------|-------|---------|
| CODED (20%) | Only code-level layers pass (BE Unit, FE Unit, Type Check, etc.) | Not ready for review |
| VALIDATING (21-80%) | Some validation layers pass (E2E, HITL, Security, etc.) | In progress |
| VALIDATED (81-99%) | Most layers pass but not shipped | Ready for deploy |
| SHIPPED (100%) | All 13 layers PASS | Production-ready |

**After L1-L6, report DoD tier**:
```
DoD Score: {score}/100% → {tier_icon} {tier}
  CODED:     {tier1_score}/20%
  VALIDATED: {tier2_score}/60%
  SHIPPED:   {tier3_score}/20%
```

NEVER claim a feature is "done" if DoD tier < VALIDATED. NEVER report progress > 20% if only Tier 1 passes.

## File Coverage Check (after DoD)

```bash
curl -s $BACKEND/api/v1/admin/atlas-dev/features/coverage \
  -H "X-Admin-Token: $ADMIN_TOKEN" | python3 -c "
import json, sys
data = json.load(sys.stdin)
pct = data['coverage_pct']['overall']
orphans = len(data['orphans'].get('backend',[])) + len(data['orphans'].get('frontend',[]))
print(f'Coverage: {pct}% | Orphans: {orphans}')
if pct < 80: print('WARNING: File coverage below 80%')
"
```

- Source Files section required for features at VALIDATING tier or above
- Before claiming "BE Unit PASS", verify tests exist for files in Source Files

## Never Skip
- NEVER claim "tests pass" without running them
- NEVER claim "it works" without verifying
- ALWAYS show actual output
- ALWAYS run type-check
