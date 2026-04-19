---
name: atlas-ci
description: "Woodpecker CI live dashboard and pipeline monitor. Use when the user says 'atlas ci live', 'atlas ci status', 'ci monitor', 'pipeline status', 'watch CI', or 'show pipelines'. Provides a real-time ANSI TUI (live mode) and one-shot snapshots."
triggers:
  - "atlas ci live"
  - "atlas ci status"
  - "ci monitor"
  - "pipeline status"
  - "watch CI"
  - "show pipelines"
  - "atlas ci dashboard"
model: haiku
tier: dev
---

# atlas ci — Woodpecker CI Dashboard (v5.19.0+)

Real-time ANSI TUI for Woodpecker CI pipeline monitoring. Polls the REST API
every N seconds, renders a compact 80-col dashboard with workflow breakdown.

## Sub-commands

| Command | Description |
|---------|-------------|
| `atlas ci live` | Auto-refresh dashboard (default: 5s, top 5 pipelines) |
| `atlas ci status` | Legacy one-shot summary (short, no workflow detail) |
| `atlas ci logs <N> [--step <name>]` | Fetch + decode step logs |
| `atlas ci help` | Full usage reference |

## Usage

```bash
# Default: auto-refresh every 5s, top 5 pipelines
atlas ci live

# Custom interval and pipeline count
atlas ci live --interval 10 --count 8

# One-shot snapshot (scriptable, exits immediately)
atlas ci live --once

# Combine with watch for single pipeline deep-dive
atlas ci watch 856 --live --tail 5
```

## Output Layout

```
╭─ ATLAS CI Live ──────────────────── ci.axoiq.com/axoiq/synapse ─╮
│  Auto-refresh: 5s  │  Last update: 17:34:52  │  Ctrl+C to exit  │
├─────────────────────────────────────────────────────────────────╯

  🔄 #856   main                50ed617  fix(prod): unblock deploy  3:21  push
     🔄 ci-frontend             8/11 steps (8 ok, 0 fail, 3 pending)
     ✅ ci-backend              5/5 steps
     ⏸  deploy-prod            5 steps
     ⏸  security               6 steps

  ✅ #853   main                89501d5  fix(prod): unblock deploy  3:02  pr
     ✅ ci-backend              5/5 steps
     ...
╰─────────────────────────────────────────────────────────────────╯
```

## Status Icons

| Icon | Status |
|------|--------|
| ✅ | success |
| ❌ | failure / error |
| 🔄 | running |
| ⏸  | pending |
| ⏭  | skipped |
| ⊗  | killed |

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `WP_TOKEN` | Yes | read from `~/.env` | Woodpecker Bearer token. Generate at `ci.axoiq.com/user/tokens` |
| `ATLAS_CI_URL` | No | `https://ci.axoiq.com` | Override CI base URL |
| `ATLAS_CI_REPO_ID` | No | `1` | Override repo ID (1 = synapse) |

## V2 DevPortal /ci Perspective (Monday)

See `memory/sp-devportal-ci-perspective-plan.md` for the planned V2 evolution:
- Embedded in DevPortal web UI at `/ci` route
- Real-time SSE stream from backend pushing pipeline events
- Clickable step names → inline log viewer
- Failure trend charts per workflow
- Integration with `atlas dp chat "why did #856 fail?"`

## Related Skills

- `ci-management` — detailed logs, secrets, agent fleet, rerun
- `ci-feedback-loop` — automated push → wait for CI green workflow
- `ci-health` — aggregate health metrics and trend analysis
