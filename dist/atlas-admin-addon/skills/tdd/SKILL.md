---
name: tdd
description: "Test-Driven Development cycle. This skill should be used when the user asks to implement any feature or bugfix, 'TDD this', 'write tests first', '/a-tdd', or before writing implementation code that has no failing test yet."
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

## Red Flags (rationalization check)

Before skipping the TDD cycle, ask yourself — are any of these thoughts running? If yes, STOP. You're rationalizing.

| Thought | Reality |
|---------|---------|
| "Just this once, let me code first" | The TDD cycle protects against exactly that. Write the test. |
| "I know what the code should look like" | Knowing ≠ verified. Test first proves it. |
| "The test is obvious — I'll write it after" | Tests-after validate what you wrote, not what you intended. |
| "It's too simple to need a test" | Simple things break in production because nobody tested them. |
| "The feature doesn't have a clear assertion yet" | Then you don't have a feature yet — you have an idea. Refine, then test. |
| "Tests slow me down" | Untested code slows the NEXT session 10x. TDD pays compound interest. |
| "I'll add tests at the end" | Tests-at-end = tests that match buggy code, not the spec. |

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
