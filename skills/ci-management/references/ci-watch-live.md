# `atlas ci watch --live` — Live CI Monitor

> Rich, freeze-aware Woodpecker pipeline monitor. Replaces the "did it timeout or just slow?" guesswork.
> Available from atlas-plugin v5.18.0 (`scripts/atlas-modules/ci.sh` + `ci_watch_render.py`).

## When to use

| Scenario | Command |
|----------|---------|
| Quick "did it pass?" check | `atlas ci watch <N>` (legacy 20s poll, one line per state change) |
| Active debug session — want to see what's happening | `atlas ci watch <N> --live` |
| Watching a long pytest/vitest run | `atlas ci watch <N> --live --tail 5` |
| Suspect a hang | `atlas ci watch <N> --live --freeze-threshold 30` |

## Visual

```
  Pipeline #218 | feat/sp-migration-hygiene-01 @ 5aba90f1 | running
  ▶ ci-backend                running    2m12s
    ✅ clone                        success    8s
    ✅ backend-lint                 success    7s
    ▶ backend-tests                running    1m1s
      Progress: pytest 4521 pass, 0 skip, 0 fail
      └─ tests/unit/test_foo.py::test_bar PASSED
      └─ tests/unit/test_foo.py::test_baz PASSED
    ⏳ docs                         pending    —
  ✅ ci-frontend              success    2m55s
  ▶ security                  running    2m12s
    ▶ semgrep-sast                 running    1m45s
      ⚠ frozen — no output for 1m30s (threshold 60s)
```

## Flag matrix

| Flag | Default | Meaning |
|------|---------|---------|
| `--live` | off | Enable live TUI (else legacy mode) |
| `--interval S` | 3s with `--live`, 20s without | Poll period in seconds |
| `--tail N` | 3 | Last N decoded log lines per running step (0 disables tail) |
| `--freeze-threshold S` | 60 | Seconds without new stdout to flag a step as frozen |
| `-h`, `--help` | — | Show inline help |

## How it works

```
┌──────────────────────────────────────────────────────────────┐
│ ci.sh _atlas_ci_watch_live                                   │
│   loop:                                                      │
│     curl /pipelines/N      → meta.json                       │
│     for each running step:                                   │
│       curl /logs/N/step_id → logs/<step_id>.json             │
│       update state.json (last_stdout_ts on size change)      │
│     python3 ci_watch_render.py meta.json                     │
│       --logs-dir logs/ --state state.json --tty|--plain      │
│     sleep <interval>                                         │
└──────────────────────────────────────────────────────────────┘
```

- **Bash** drives the polling, curl, state file writes, TTY detection (`[ -t 1 ]`).
- **Python helper** (`ci_watch_render.py`) is stateless: reads the 3 inputs, prints one frame to stdout.
- **State file** lives in `/tmp/atlas-ci-watch-${pipeline}-XXXX/state.json`, cleaned up via trap on EXIT/INT/TERM.
- **TUI mode** clears the screen via `\033[H\033[2J` and emits ANSI 256 colors per state.
- **Plain mode** auto-selected when stdout is not a TTY (logs, CI, pipes) — line stream, no escapes.

## Framework-aware progress

The renderer auto-detects the running step's framework from step name + log content and parses the appropriate progress format:

| Framework | Triggered by | Output |
|-----------|--------------|--------|
| pytest | `pytest`, `tests/unit`, `test_`, `conftest` | `pytest 4521 pass, 1321 skip, 0 fail` or `pytest 42%` (xdist) |
| vitest | `vitest`, `vite test` | `vitest 245 pass, 3 fail` |
| bun test | `bun test`, `bun:test` | `bun 12 pass, 1 skip, 0 fail` |
| playwright | `playwright`, `e2e/`, `.spec.ts` | `playwright 4 pass, 0 fail` |

When no framework matches, only the log tail is shown (no `Progress:` line).

## Verification

```bash
# Unit + integration tests
cd ~/workspace_atlas/projects/atlas-dev-plugin
bats tests/shell/test_ci_watch.bats
# Expected: 18/18 PASS

# Manual smoke against a real pipeline (need WP_TOKEN in ~/.env)
source scripts/atlas-modules/ci.sh
_atlas_ci_watch <N> --live

# Plain mode (CI / log file)
atlas ci watch <N> --live --interval 5 > /tmp/watch.log 2>&1 &
tail -f /tmp/watch.log

# Backward compat — no --live = previous one-line behavior
atlas ci watch <N>
```

## Limitations / out of scope (v1)

- No interactive keys (q/l/r/f) — Ctrl-C only
- No SSE log streaming (`/api/stream/logs/...`) — re-fetch every tick
- Single pipeline at a time (no `--all`)
- Fixed color palette (no theme config)

Defer-list captured in `harmonic-herding-sunset.md` (synapse plan, "Out of scope" section).

## References

- Stub plan: `.blueprint/plans/sp-atlas-ci-live-monitor.md`
- Module: `scripts/atlas-modules/ci.sh` (`_atlas_ci_watch_live` at L500+)
- Renderer: `scripts/atlas-modules/ci_watch_render.py` (~280 LOC)
- API ref: `references/woodpecker-api-paths.md`
- Tests: `tests/shell/test_ci_watch.bats` (18 cases) + 2 fixtures
