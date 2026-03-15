---
name: verification
description: "Complete verification: L1-L4 tests + E2E persona tests + security scan + performance benchmarks. Evidence before assertions."
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
