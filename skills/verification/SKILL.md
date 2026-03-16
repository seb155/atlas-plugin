---
name: verification
description: "Complete verification: L1-L6 tests + quality gates pipeline (build→types→lint→tests→security→diff) + E2E persona tests + security scan + performance benchmarks + checkpoints. Evidence before assertions."
---

# Verification

## Principle

**Evidence before assertions.** NEVER claim work is complete, fixed, or passing without running verification commands and confirming output.

## Verification Levels

### L1: Unit Tests (Backend)
```bash
docker exec synapse-backend bash -c "cd /app && python -m pytest tests/{specific_path} -x -q --tb=short"
```
- Run specific test file first (fast feedback)
- Then run broader suite if specific passes

### L2: Unit Tests (Frontend)
```bash
cd frontend && bunx vitest --run
cd frontend && bun run type-check
```
- vitest for logic tests
- TypeScript strict for type safety

### L3: E2E Tests (Playwright)
```bash
cd frontend && bunx playwright test e2e/qa-*.spec.ts
```
- Only if plan Section O specifies E2E scenarios
- Run against real dev environment

### L4: Persona-Based Validation
For each persona identified in plan Section H:

```
Persona: {role}
Pre-condition: {project state}
1. {action as this persona would do}
2. {verify expected result}
3. {verify RBAC — can they see/do what they should?}
4. {verify performance — acceptable speed?}
```

This can be done via:
- Browser automation (Playwright MCP or Claude in Chrome)
- Manual check (describe what to verify, user confirms)
- API testing (curl commands as different auth roles)

### L5: Security Check
```bash
# Input validation test
# RBAC enforcement test (try accessing as wrong role)
# Check no secrets in responses/logs
```

### L6: Performance Benchmark
```bash
# API response time
time curl -s "localhost:8001/api/v1/{pid}/resource?size=500"
# Target: < 200ms

# Frontend build
cd frontend && bunx vite build
# Check bundle size
```

## Output Format

```
✅ VERIFICATION REPORT

L1 Backend: ✅ 247 passed (0 failed)
L2 Frontend: ✅ 89 passed, type-check clean
L3 E2E: ✅ 12 scenarios passed
L4 Persona:
  - I&C Eng: ✅ CRUD + filters + export working
  - PM: ✅ Read-only view correct
  - Admin: ✅ Seed + config working
L5 Security: ✅ RBAC enforced, no secrets leaked
L6 Performance: ✅ API < 200ms, build 2.1MB

OVERALL: ✅ ALL CHECKS PASS
```

## If Verification Fails

1. Identify which level failed
2. Use systematic-debugging skill
3. Max 2 fix attempts
4. If still failing → AskUserQuestion with:
   - What failed
   - What you tried
   - 2-3 alternatives

## Never Skip

- NEVER claim "tests pass" without running them
- NEVER claim "it works" without verifying
- ALWAYS show the actual output
- ALWAYS run type-check (catches many bugs statically)

---

## Quality Gates Pipeline (from /a-verify)

Sequential checks performed in order. **First failure stops the pipeline (fail-fast).**

### Gate Sequence

| Gate | Command | Purpose |
|------|---------|---------|
| **Build** | `bun run build` (or project equivalent) | Compilation check |
| **Types** | `bun run typecheck` | Type safety validation |
| **Lint** | `bun run lint` | Code style & quality |
| **Tests** | `bun test` / `pytest` | Unit & integration tests |
| **Security** | Pattern scan (see below) | Detect secrets, console.log |
| **Diff** | `git status --short` + `git diff --stat` | Show changed files |

### 1. Detect Project Configuration

Before running gates, detect what's available:

```bash
# Check what commands are available in package.json / pyproject.toml
if grep -q '"build"' package.json 2>/dev/null; then HAS_BUILD=true; fi
if grep -q '"typecheck"' package.json 2>/dev/null; then HAS_TYPECHECK=true; fi
if grep -q '"lint"' package.json 2>/dev/null; then HAS_LINT=true; fi
```

If a script is missing, that gate is skipped (marked as ⏭️ in the report).

### 2. Run Gates (Sequential, Stop on First Failure)

**CRITICAL**: Stop on first failure. Do NOT continue if a gate fails.

For each gate:
1. Announce which gate is running
2. Execute the command
3. Record pass/fail/skip status
4. If fail → stop pipeline, report

### 3. Security Scan Gate

```bash
# Check for console.log in source files (not tests, not comments)
git diff --cached --name-only | grep -E '\.(ts|tsx|js|jsx|py)$' | \
  xargs grep -n 'console\.log' | grep -v '^\s*//' | grep -v '\.test\.'

# Check for potential secrets in staged changes
git diff --cached | grep -iE '(api_key|password|secret|token)\s*=\s*["\x27]'

# Check for .env files being committed
git diff --cached --name-only | grep -E '\.env(\.|$)'

# Check for private keys
git diff --cached --name-only | grep -E '\.(pem|key|p12|pfx)$'
```

**Hard fail** on: secrets detected, .env files staged, private keys staged.
**Warning** on: console.log statements found.

### 4. Generate Verification Report

Format output as a structured table:

```
## Verification Results

| Check | Status | Details |
|-------|:------:|---------|
| Build | ✅/❌/⏭️ | <message> |
| Types | ✅/❌/⏭️ | <message> |
| Lint | ✅/❌/⚠️ | <message> |
| Tests | ✅/❌ | <passed>/<total> passed |
| Security | ✅/⚠️/❌ | <issues found> |
| Changes | 📊 | <file count> files modified |

### Summary
Ready to commit: YES/NO
```

**Status Indicators**:
- ✅ Passed
- ❌ Failed (blocking)
- ⚠️ Warning (non-blocking)
- ⏭️ Skipped (not configured)

### Flags

| Flag | Behavior |
|------|----------|
| `--quick` | Skip long-running tests, run smoke tests only |
| `--fix` | Auto-fix linting issues with `--fix` flag |
| `--verbose` | Show full output from each command |
| `--no-security` | Skip security scan (not recommended) |

### Checkpoint Subcommands

Save and compare verification state over time:

```
checkpoint save [name]      # Save current verification state
checkpoint compare [name]   # Compare with saved checkpoint
checkpoint list             # List saved checkpoints
checkpoint diff <a> <b>     # Compare two checkpoints
```

Each checkpoint captures: test counts, type errors, lint errors, security issues, coverage %, file checksums.

**Regression Detection**: Comparison flags when test pass count decreases, type errors increase, or security issues increase.

### HITL Gate: After Verification

If ALL gates pass → present result and ask:
```
AskUserQuestion: "All quality gates pass. Ready to proceed with commit/ship?"
```

If ANY gate fails → present failures and ask:
```
AskUserQuestion: "Gate {X} failed. Options:
(a) Fix the issues (show errors above)
(b) Skip this gate (if non-blocking)
(c) Abort — I'll fix manually"
```

### Integration with Other Skills

| Workflow | Usage |
|----------|-------|
| Pre-commit | verification → finishing-branch |
| Pre-PR | verification → `git push` |
| After refactor | verification `--fix` then review |
| Full pipeline | context-discovery → plan-builder → tdd → verification → finishing-branch |
