---
name: feature-update
description: "DevHub feature row updater — PATCH a single feature's status/metadata via API and sync the matching FEATURES.md row. Use when the user says 'update feature X', 'mark X as done', 'feature {id} status {value}', or 'set feature X to in-progress'."
effort: low
see_also: [portal-sync, feature-board, decision-log]
thinking_mode: adaptive
version: 1.0.0
tier: [dev, admin]
category: devhub
emoji: "✏️"
triggers:
  - "update feature"
  - "mark feature"
  - "feature status"
  - "set feature"
  - "mark as done"
  - "feature complete"
  - "feature in-progress"
  - "close feature"
---

# Feature Update

Update a single feature's status or metadata — both in the DevHub API and inline in `.blueprint/FEATURES.md`.

## When to Use

- Completing a feature task: "mark SP-NAV-001 as done"
- Starting work: "set feature DEVHUB-T9 to in-progress"
- Blocking/unblocking: "feature SP-CONV-003 is blocked on auth"
- Correcting stale data without a full sync

## Commands

```bash
# Status update (most common)
atlas feature update SP-NAV-001 --status done
atlas feature update DEVHUB-T9 --status in-progress
atlas feature update SP-CONV-003 --status blocked --note "waiting on auth PR #382"

# Multi-field update
atlas feature update DEVHUB-T8 --status done --shipped-at "2026-04-26"

# Dry-run — show what would change
atlas feature update SP-NAV-001 --status done --dry-run

# List available statuses
atlas feature statuses
```

## Process

### Step 1 — Resolve feature ID

```bash
# Search FEATURES.md for the ID or name
grep -n "SP-NAV-001\|portal-sync" .blueprint/FEATURES.md | head -5
```

### Step 2 — PATCH DevHub API

```bash
source ~/.env
curl -s -X PATCH \
  "https://dev.axoiq.com/api/v1/devhub/features/${FEATURE_ID}" \
  -H "Authorization: Bearer ${FORGEJO_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"status\": \"${STATUS}\", \"note\": \"${NOTE}\"}"
```

> API endpoint: `/api/v1/devhub/features/{id}` (T10 DevHub backend)

### Step 3 — Update FEATURES.md inline

Find the row matching the feature ID and update its status column:

```python
# Pattern: | FEATURE-ID | name | ... | old-status | ...
# Replace: | FEATURE-ID | name | ... | new-status | ...
```

Use `sed` for surgical inline edit:
```bash
sed -i "s/| ${FEATURE_ID} | \([^|]*\) | \([^|]*\) | [^|]* |/| ${FEATURE_ID} | \1 | \2 | ${STATUS} |/" \
  .blueprint/FEATURES.md
```

Show the diff before writing:
```bash
git diff .blueprint/FEATURES.md
```

### Step 4 — Confirm

```
✅ Feature SP-NAV-001 updated:
   API: PATCH /devhub/features/SP-NAV-001 → 200 OK
   FEATURES.md row: status "in-progress" → "done"
   Committed: no (use portal-sync or git add/commit manually)
```

## Valid Statuses

| Status | Meaning |
|--------|---------|
| `planned` | On roadmap, not started |
| `in-progress` | Active work |
| `blocked` | Waiting on dependency |
| `done` | Shipped to prod |
| `deferred` | Intentionally paused |
| `cancelled` | Dropped from scope |

## HITL Gates

- **`done` on Tier-0/1 features**: Confirm DoD layers passed before marking
- **`cancelled`**: Always ask — this is irreversible intent change

## Error Handling

| Error | Action |
|-------|--------|
| Feature ID not found in FEATURES.md | Show fuzzy search results, ask to confirm |
| API 404 | Feature not yet indexed — run `portal-sync` first |
| API 401 | `source ~/.env`, check `FORGEJO_TOKEN` scope |
| Ambiguous match (multiple rows) | Show all matches, ask user to pick |

## Related

- `portal-sync` — Full sync after bulk updates
- `feature-board` — Read-only status view
- `decision-log` — Log architectural decisions alongside feature changes
