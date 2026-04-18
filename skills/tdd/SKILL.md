---
name: tdd
description: "Test-Driven Development. Failing test → minimal implementation → pass → commit. Strict cycle. Never write implementation without a failing test first."
effort: medium
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [verification-before-completion, systematic-debugging]
thinking_mode: adaptive
---

<HARD-GATE>
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST.
This is not a recommendation. This is an Iron Law.
Write code before the test? Delete it. Start over.
</HARD-GATE>

<red-flags>

| Thought | Reality |
|---|---|
| "I'll add tests after the implementation works" | STOP. Delete any uncommitted implementation. Restart with Red-Green-Refactor. Watch the test fail for the RIGHT reason before writing any code. |
| "This test is trivial, don't need to write it" | Write the test. 30 seconds of effort prevents hour-long debugging later. 'Too simple to test' is the #1 excuse preceding production bugs. |
| "I already manually tested all the edge cases" | Convert each manual check into an automated test. Run the suite. Commit tests + code. Now regressions are impossible, not just unlikely. |

</red-flags>

# Test-Driven Development

## The Cycle (STRICT — no shortcuts)

```
1. Write the FAILING test
2. Run it → verify it FAILS (with expected error message)
3. Write MINIMAL code to make it pass
4. Run it → verify it PASSES
5. Refactor if needed (keep tests green)
6. Commit
```

**Never skip step 2.** A test that passes without implementation is wrong.

## Test First, Always

Before writing ANY implementation code:
1. Think: "What should this function/component do?"
2. Write a test that asserts that behavior
3. Run it — it MUST fail
4. Only THEN write the implementation

## Test Conventions

### Backend (Python/pytest)
```bash
# ALWAYS use these flags:
docker exec synapse-backend bash -c "cd /app && python -m pytest tests/{path} -x -q --tb=short"

# -x = stop at first failure
# -q = quiet output
# --tb=short = short traceback
# NEVER: --pdb, -s, --watch (interactive modes = hang)
```

### Frontend (TypeScript/vitest)
```bash
cd frontend && bunx vitest --run  # single run, no watch
cd frontend && bun run type-check  # TypeScript strict
```

### E2E (Playwright)
```bash
cd frontend && bunx playwright test e2e/qa-*.spec.ts
```

## What Makes a Good Test

- **Descriptive name**: `test_valve_accessory_assigned_to_p050_package`
- **Arrange-Act-Assert**: Setup → Execute → Verify
- **One assertion per concept** (multiple asserts OK if testing same concept)
- **Test behavior, not implementation**
- **Edge cases**: null, empty, boundary values

## Commit After Each Cycle

```bash
git add -A && git commit -m "test(scope): describe what the test verifies"
# Then:
git add -A && git commit -m "feat(scope): implement to pass test"
```

## When to NOT TDD

- Configuration files (JSON, YAML, env)
- Pure UI styling (CSS changes)
- Documentation updates
- One-line type fixes

Even then, verify manually that nothing breaks.
