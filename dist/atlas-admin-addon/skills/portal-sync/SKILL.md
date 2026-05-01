---
name: portal-sync
description: "DevHub portal sync — push local blueprint/features/docs state to the devhub_db. Use when the user says 'sync portal', 'update devhub', 'regen feature board', '/atlas portal sync', or after bulk edits to FEATURES.md / plan files."
effort: low
see_also: [feature-update, doc-regen, feature-board]
thinking_mode: adaptive
version: 1.0.0
tier: [dev, admin]
category: devhub
emoji: "🔄"
triggers:
  - "sync portal"
  - "update devhub"
  - "regen feature board"
  - "portal sync"
  - "/atlas portal sync"
  - "push to devhub"
  - "devhub out of date"
---

# Portal Sync

Push local blueprint state (FEATURES.md, plans, ADRs, docs) to the live DevHub database.

## When to Use

- After bulk edits to `.blueprint/FEATURES.md`, `.blueprint/plans/*.md`, or ADRs
- When DevHub feature board looks stale vs git HEAD
- After completing a Wave task that adds/modifies features
- Manually, when the PostToolUse auto-sync hook is disabled (`ATLAS_PORTAL_HOOK=off`)

## Command

```bash
# Full sync — all entities
atlas portal sync

# Dry-run (show what would change, no write)
atlas portal sync --dry-run

# Scoped sync — single subsystem or file
atlas portal sync --scope features
atlas portal sync --scope plans
atlas portal sync --scope docs

# Force full re-index (use after schema migration)
atlas portal sync --force

# Status only
atlas portal status
```

> ⚠️ **T10 dependency**: `atlas portal sync` is implemented in T10.
> This skill is authoritative — when T10 lands, the CLI is drop-in.

## Auth

Hook token (`ATLAS_HOOK_TOKEN`) is scoped to `portal:sync-only`.
Sourced from `~/.env`. For manual use:
```bash
source ~/.env && atlas portal sync
```

## Output

```
🔄 Portal sync starting…
  ✅ features   — 105 rows upserted  (3 new, 8 updated, 0 deleted)
  ✅ plans      — 23 plans synced    (1 new, 2 updated)
  ✅ docs       — 14 ADRs indexed    (unchanged)
Sync complete in 1.4s. DevHub up-to-date at 2026-04-26 14:22 EDT.
```

## Error Handling

| Error | Action |
|-------|--------|
| `ATLAS_HOOK_TOKEN` missing | `source ~/.env` then retry |
| DevHub API unreachable | Check `curl https://dev.axoiq.com/api/v1/health` |
| Parse error on FEATURES.md | Show offending line, ask user to fix |
| 409 Conflict | Re-run with `--force` after reviewing conflict |

## HITL Gates

- **`--force` flag**: Confirm before full re-index (destructive path)
- **Deletion of features**: Always show diff + ask before removing rows

## Related

- `feature-update` — Update a single feature row (lighter than full sync)
- `doc-regen` — Regenerate API/subsystem docs before syncing
- `feature-board` — Read-only dashboard view of synced state
- T8 hook (`~/.claude/hooks/portal-auto-sync.sh`) — auto-triggers sync on file write
