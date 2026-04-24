---
name: test-affected
description: "Affected-test runner for pre-push gate. Use when running the G1 pre-push test gate, when the user asks to 'test affected', 'test changes only', 'quick test', or before pushing uncommitted work."
triggers:
  - "/atlas test-affected"
  - "/atlas ta"
  - "test only affected"
  - "test what I changed"
  - "run affected tests"
effort: low
---

# Test-Affected — Fast Pre-Push Gate

Runs **only the tests impacted by your uncommitted (or recently committed)
changes**, with a hard 30-second budget. Splits into backend (pytest-testmon)
and frontend (vitest --changed) streams.

The goal: **sub-30s feedback before `git push`**. Full suite runs in CI.

## Commands

```bash
/atlas test-affected                # Run affected since HEAD~1
/atlas test-affected --since origin/dev    # Compare to branch tip
/atlas test-affected --dry-run      # Print selection, don't execute
/atlas test-affected --budget 60    # Raise budget (default 30s)
/atlas test-affected --only backend # Skip frontend
```

## What it runs

| Change touches | Runs |
|---|---|
| `backend/**/*.py` | `pytest --testmon -x -q -m "not slow and not external"` |
| `frontend/packages/*/src/**` | `bun x vitest run --changed <since>` in the package dir |
| `frontend/src/**` | `bun x vitest run --changed <since>` |
| `.woodpecker/**` / `scripts/**` | syntax validation (`yq` / `shellcheck`) |

## Budget enforcement

- Total wall-clock budget: **30s** (configurable via `--budget`)
- On timeout: SIGTERM the runner, print `Unrun N tests — covered in CI`
- Exit code: `0` green / `1` red / `2` budget exceeded (advisory)

## pytest-testmon fallback chain

1. If `backend/.testmondata` exists → use `--testmon`
2. Else if `.testmondata` missing → fall back to `--lf` (last-failed)
3. Else → select by filepath map (`backend/app/X.py → backend/tests/.../test_X.py`)

## Advisory mode (v1)

This skill is **advisory** — the hook `pre-push-affected` logs results to
`.claude/ci-health.jsonl` but does NOT block the push. Phase 5 of the
hazy-mapping-stallman plan flips this to blocking via `ATLAS_G1_BLOCKING=true`
after 7 days of clean metrics.

## Files

- Implementation: `${CLAUDE_PLUGIN_ROOT}/skills/test-affected/test-affected.sh`
- Hook integration: `${CLAUDE_PLUGIN_ROOT}/hooks/pre-push-affected`
- Related skill: `test-impact-analysis` (PostToolUse hook — upgrade path
  adds `CLAUDE_RUN_AFFECTED=1` env to promote warn→run)

## References

- `.blueprint/plans/hazy-mapping-stallman.md` Section F / T3.2
- pytest-testmon: https://pypi.org/project/pytest-testmon/
- vitest --changed: https://vitest.dev/guide/cli#changed
