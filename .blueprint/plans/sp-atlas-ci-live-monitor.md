# SP-ATLAS-CI-LIVE-MONITOR — Rich CI Monitoring with Live Progress + Freeze Detection

**Plan ID**: `sp-atlas-ci-live-monitor`
**Effort**: 3-4h
**Sprint**: Next available
**Parent**: User request during SP-TEST-SOTA N2 session (2026-04-14 NIGHT-3)
**Status**: STUB — to be expanded pre-implementation

## Context

Current `atlas ci` monitoring (and the ad-hoc Monitor polling we used this session) only reports **pass/fail at the end**. User pain points:
- No visibility into which step is currently running
- No log tail from active step
- No progress indicators (tests done / total for pytest / vitest)
- Can't distinguish "frozen" from "slow but progressing"
- JSON parse errors on Woodpecker API control chars interrupt polling

Needs: live, readable, freeze-aware CI monitor.

## Scope

New command `atlas ci watch <pipeline>` (or enhance `atlas ci monitor`) with:
- Step-by-step timeline with durations
- Log tail from currently-running step (last N lines)
- Framework-aware progress parsing (pytest `[X/Y]`, vitest `✓ N passed`, bun counts)
- Freeze detection (no new stdout for > threshold seconds)
- Color-coded states
- Graceful handling of Woodpecker API hiccups (control char tolerance, retry on 5xx)
- Exit on terminal state (success/failure/killed) with concise summary

## ASCII mockup

```
╭─ atlas ci watch 218 ─────────────────────────────────────╮
│ Pipeline #218 | feat/sp-migration-hygiene-01 | 5aba90f17 │
│                                                          │
│ ci-backend      ▶ RUNNING  2m12s                         │
│   ✓ clone              3s                                │
│   ✓ postgres          20s                                │
│   ✓ backend-lint      48s                                │
│   ● backend-tests    1m1s    [running...]                │
│     └─ pytest tests/unit/ -n auto                        │
│     └─ [last line] "tests/unit/test_foo.py::test_bar..." │
│     └─ Progress: 4521/6474 (70%)                         │
│   ○ docs             pending                             │
│                                                          │
│ ci-frontend     ● SUCCESS   2m55s                        │
│ security        ▶ RUNNING  2m12s                         │
│                                                          │
│ ⚠ Freeze detector: no output from ci-backend for 45s     │
│                                                          │
│ [q]uit  [l]ogs  [r]efresh  [f]ocus step                  │
╰──────────────────────────────────────────────────────────╯
```

## Phases

| Phase | Task | Effort |
|-------|------|--------|
| P1 | Extend `scripts/atlas-modules/ci.sh` with `_atlas_ci_watch` function | 45min |
| P2 | Woodpecker API poll loop + control-char-tolerant JSON parser (Python helper) | 30min |
| P3 | Step timeline renderer (sorted by pid, color-coded states) | 45min |
| P4 | Log tail: poll `/api/repos/{id}/logs/{pipeline}/{step_id}` for running step, extract last N lines (base64 decode) | 45min |
| P5 | Progress parsers: pytest `N passed, M skipped`, vitest `✓ N passed`, configurable via env | 30min |
| P6 | Freeze detection: compare stdout timestamps, warn if delta > threshold (default 60s) | 30min |
| P7 | TTY detection — TUI if terminal, plain stream otherwise | 20min |
| P8 | Skill MD (`skills/ci-monitoring-live/SKILL.md`) | 15min |
| P9 | bats tests with mocked API responses | 30min |

## Data model

```bash
# Per-step state
step_name, step_id, state, duration, last_stdout_ts, progress_str

# Per-pipeline
pipeline_number, commit_sha, overall_state
workflows: [{name, state, steps: [...]}]
```

## Framework-aware progress parsers

| Framework | Pattern |
|-----------|---------|
| pytest | `N passed, M skipped, K failed in T.Ts` OR `[N/M]` in xdist |
| vitest | `✓ N passed` OR `Tests N failed \| M passed` |
| bun test | `N pass, M skip, K fail` |
| playwright | `N passed, M failed (Xms)` |
| generic | fall back to "running..." |

## Verification

```bash
# Happy path
atlas ci watch 218
# Expected: updates every 5s, shows steps progressing, exits on green with summary

# Failure path — watch a known-failed pipeline
atlas ci watch 197
# Expected: identifies which step failed, shows last log lines from failed step, exits red

# Freeze detection
# Simulate a hanging step (mock via test harness)
# Expected: after 60s no output → ⚠ warning emitted
```

## Cross-references

- Lesson: `memory/lesson_verify_tests_locally_first.md` (know what to expect locally first)
- Existing module: `scripts/atlas-modules/ci.sh` (baseline `_atlas_ci_cmd`, `_atlas_ci_logs_decode`)
- API reference: `skills/ci-management/references/woodpecker-api-paths.md`
- Session that motivated this: `memory/handoff-2026-04-14-sp-test-sota-n2-migration-archaeology.md`
- Sibling plan: `.blueprint/plans/sp-database-migration-audit.md` (DB audit)
