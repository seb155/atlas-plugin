---
name: systematic-debugging
description: "Structured debugging: observe → hypothesize → test → fix. Max 2 fix attempts, then escalate. Never guess-and-check randomly."
effort: medium
---

# Systematic Debugging

## Process (STRICT ORDER)

### 1. OBSERVE — What exactly is happening?
- Read the error message/stack trace completely
- Reproduce the issue (run the failing test/command)
- Note: what is EXPECTED vs what is ACTUAL
- Check: when did it last work? What changed?

#### Centralized Log Query (AXOIQ/Synapse projects)
Before SSH + docker logs, query Loki for structured errors (ref: `refs/observability-api`):
1. Error count by container: identifies which service is the hotspot
2. Recent errors for the suspected service: exact error messages with timestamps
3. If trace_id visible → trace correlation query to follow the request across services
4. Prometheus `up` query to check if any scrape target is down

### 1.5 LSP — Semantic context (if available)

If `ENABLE_LSP_TOOL=1` and bash/python/yaml LSP installed, use LSP
BEFORE hypothesizing — it gives semantic (not grep-level) context
at ~50ms vs 45s:

```
LSP(operation: "goToDefinition", filePath: "{error_file}", line: {error_line})
# Jumps to the definition — reveals if error is call-site or definition-site.

LSP(operation: "findReferences", filePath: "{file}", line: {line})
# Lists all call sites — helps scope the blast radius.

LSP(operation: "hover", filePath: "{file}", line: {line})
# Shows type/signature — catches type-level mismatches.
```

Skip LSP for domain errors (business logic, config) — it helps most
with type errors, import errors, undefined references.

### 2. HYPOTHESIZE — What could cause this?
- List 2-3 possible causes ranked by likelihood
- For each: what evidence would confirm/deny it?

```
🔍 Hypotheses:
1. {most likely} — evidence needed: {check X}
2. {second} — evidence needed: {check Y}
3. {least likely} — evidence needed: {check Z}
```

### 3. TEST — Verify the hypothesis
- Test ONE hypothesis at a time
- Use the LEAST invasive check first (read logs, check data, print values)
- Don't change code to test — observe first

### 4. FIX — Apply the minimal fix
- Fix the ROOT CAUSE, not the symptom
- Write a test that reproduces the bug FIRST (TDD)
- Apply the fix
- Run the test — it must pass
- Run ALL related tests — no regressions

### 5. VERIFY — Confirm the fix
- Run the original failing scenario
- Run the broader test suite
- Check for side effects

## Retry Cap (NON-NEGOTIABLE)

- **Attempt 1**: Observe → Hypothesize → Test → Fix → Verify
- **Attempt 2**: If first fix didn't work → new hypothesis → Fix → Verify
- **After 2 attempts**: STOP. Use AskUserQuestion with:
  - (a) What you observed
  - (b) What you tried
  - (c) 2-3 alternative approaches

**Never loop endlessly trying fixes.** 2 attempts maximum.

## 🛑 Archaeology Escape Rule (3 pivots = STOP + reframe)

When debugging a workflow (CI, deploy, migration, long test), track **distinct pivots**: each new approach after the previous one failed for a new reason. This is different from the 2-attempt retry cap above — an "attempt" is same-hypothesis retry; a "pivot" is a whole approach change.

**After 3 pivots on the same sub-plan → STOP**. The premise is likely wrong.

### Pivot counter example

Session SP-TEST-SOTA N2 (2026-04-14 NIGHT-3) made these pivots on "make CI backend-migrate pass":

1. Fix 10 alembic heads → merge migration shipped
2. Fix 10th head missed by regex → edited merge tuple
3. Fix orphan tables (topological order) → create_all migration
4. Fix circular FK (projects needed first) → 3-stage alembic flow
5. Fix pip install heavy deps → raw SQL CREATE TABLE
6. Fix missing model imports → Base.metadata.create_all full

6 pivots. Net value shipped via cherry-pick: 3 commits (alembic merge + orphan migration + stubs). Everything else = wasted iteration.

### Escape options at pivot #3

When triggered, present via `AskUserQuestion`:

1. **Honest handoff** — park sub-plan, write plan stubs for prerequisites, fresh session later
2. **Cherry-pick value** — extract useful commits into standalone PR, close archaeology branch
3. **Scope split** — define prerequisite sub-plans that must ship first, defer original work
4. **Question premise** — use `ultrathink` / verify-premise-before-debug pattern (see `lesson_ultrathink_premise_check.md` + `lesson_verify_tests_locally_first.md`)

### Anti-patterns (avoid)

- "Just one more fix" loop
- Force-pushing history rewrites to hide archaeology
- Not counting pivots — losing track of how far you've strayed
- Claiming partial progress when sub-plan goal is still blocked

### Premise check (pivot #2 warning)

Before the 3rd pivot, do a **premise check** — verify the foundational assumption independently:

| Debug target | Foundational premise | How to verify independently |
|--------------|----------------------|------------------------------|
| CI tests | Tests pass locally | `docker exec ... pytest ... --tb=no \| tail -3` |
| CI build | Build succeeds locally | `make build 2>&1 \| tail -5` |
| Deploy | Image starts healthy locally | `docker run ... && curl localhost:PORT/health` |
| Migration | Schema applies on fresh DB | `docker compose down -v && up -d && alembic upgrade head` |

If premise check FAILS locally → the CI/deploy/etc isn't the problem; fix the premise first. If premise check PASSES → the delta between local and CI is the bug. Focus there, not on the output.

See also:
- `lesson_ultrathink_premise_check.md` — question fundamentals, not symptoms
- `lesson_verify_tests_locally_first.md` — always verify inputs before debugging pipeline
- `lesson_ci_archaeology_escape_rule.md` — full escape rule details

## Common Debugging Patterns

### "It works locally but fails in CI"
- Check: environment variables, Docker volumes, port conflicts
- Check: database state (migrations applied?)
- Check: file permissions, path differences

### "Test passes alone but fails in suite"
- Check: shared state between tests (DB not cleaned up)
- Check: import side effects
- Check: test order dependency

### "TypeError: X is not a function"
- Check: import path (default vs named export)
- Check: circular dependencies
- Check: version mismatch

## Output Format

```
🐛 Bug: {one-line description}

📋 Observation:
- Expected: {X}
- Actual: {Y}
- Last worked: {when}

🔍 Hypothesis 1: {description}
- Evidence: {what I checked}
- Result: {confirmed/denied}

🔧 Fix: {description}
- File: {path:line}
- Change: {before → after}

✅ Verified: {test command + result}
```
