# Health Scoring Reference — 10 Dimensions

> Detailed scoring thresholds, formula, dashboard template, and edge cases for the
> memory health score computed in Phase 4 of the dream cycle.

## Formula

```
health = sum(dimension_score[i] * weight[i])
```

Each dimension is scored 0-10. The weighted sum produces a composite 0-10 score.

**Grade mapping**:

| Grade | Range | Meaning |
|-------|-------|---------|
| A | 9.0 - 10.0 | Excellent — minimal action needed |
| B | 7.0 - 8.9 | Good — minor issues to address |
| C | 5.0 - 6.9 | Fair — several areas need attention |
| D | 3.0 - 4.9 | Poor — significant maintenance required |
| F | 0.0 - 2.9 | Critical — immediate consolidation needed |

---

## Dimensions & Thresholds

### D1 — Index Capacity (Weight: 12%)

How close MEMORY.md is to the 200-line hard limit.

| Score | Condition |
|-------|-----------|
| 10 | <= 120 lines |
| 8 | 121-150 lines |
| 6 | 151-170 lines |
| 4 | 171-190 lines |
| 2 | 191-200 lines |
| 0 | > 200 lines |

### D2 — Orphan Rate (Weight: 12%)

Percentage of memory files not referenced in MEMORY.md.

| Score | Condition |
|-------|-----------|
| 10 | 0 orphans |
| 8 | 1-2 orphans (< 3% of files) |
| 6 | 3-5 orphans (3-5%) |
| 4 | 6-8 orphans (5-8%) |
| 2 | 9-12 orphans (8-10%) |
| 0 | > 12 orphans (> 10%) |

### D3 — Staleness (Weight: 12%)

Percentage of files not modified in the last 30 days.

| Score | Condition |
|-------|-----------|
| 10 | 0% stale (all files < 30d) |
| 8 | 1-10% stale |
| 6 | 11-20% stale |
| 4 | 21-30% stale |
| 2 | 31-50% stale |
| 0 | > 50% stale |

### D4 — Referential Integrity (Weight: 12%)

Broken links in MEMORY.md (files referenced but not existing on disk).

| Score | Condition |
|-------|-----------|
| 10 | 0 broken references |
| 8 | 1 broken |
| 6 | 2-3 broken |
| 4 | 4-5 broken |
| 2 | 6-8 broken |
| 0 | > 8 broken |

### D5 — Content Freshness (Weight: 10%)

Status claims (`COMPLETE`, `LIVE`, `DONE`, `SHIPPED`) that are stale or unverifiable.

| Score | Condition |
|-------|-----------|
| 10 | All status claims verified current |
| 8 | 1 stale claim |
| 6 | 2-3 stale claims |
| 4 | 4-5 stale claims |
| 2 | 6-8 stale claims |
| 0 | > 8 stale claims |

Requires `--validate` or `--deep` to verify claims against reality.
Without validation, this dimension defaults to 10.0 (assumed healthy).

### D6 — File Size Balance (Weight: 8%)

Files exceeding size thresholds (oversized files hurt discoverability).

| Score | Condition |
|-------|-----------|
| 10 | 0 files > 50KB |
| 8 | 1 file 50-75KB |
| 6 | 1 file > 75KB or 2 files > 50KB |
| 4 | 2+ files > 75KB |
| 2 | Any file > 100KB |
| 0 | Multiple files > 100KB |

### D7 — Type Coverage (Weight: 8%)

Percentage of memory files with proper frontmatter `type:` field.

| Score | Condition |
|-------|-----------|
| 10 | 0 untyped files |
| 8 | 1-2 untyped |
| 6 | 3-5 untyped |
| 4 | 6-8 untyped |
| 2 | 9-12 untyped |
| 0 | > 12 untyped |

### D8 — Cross-Project Coherence (Weight: 8%)

Contradictions between this project's memory and other projects' memory (same entity with different status/version).

| Score | Condition |
|-------|-----------|
| 10 | 0 contradictions |
| 8 | 1 contradiction |
| 6 | 2-3 contradictions |
| 4 | 4-5 contradictions |
| 2 | 6-8 contradictions |
| 0 | > 8 contradictions |

Requires `--deep` or `--cross-project` to scan other projects.
Without cross-project scan, this dimension defaults to 10.0 (assumed healthy until proven otherwise).

### D9 — Docs Freshness (Weight: 10%)

Staleness of the documentation ecosystem (`.blueprint/`, plans, INDEX.md).

| Score | Condition |
|-------|-----------|
| 10 | INDEX.md < 14d old, all referenced plans exist |
| 8 | INDEX.md 14-21d old, 0-1 phantom plans |
| 6 | INDEX.md 21-30d old, or 2-3 phantom plans |
| 4 | INDEX.md > 30d old, or 4+ phantom plans |
| 2 | INDEX.md > 60d old and phantom plans |
| 0 | INDEX.md > 90d old or missing |

"Phantom plan" = plan referenced in memory/INDEX but file does not exist.
Requires `--docs` or `--deep` to check docs. Without it, defaults to 10.0.

### D10 — Tech Accuracy (Weight: 8%)

Technical claims in memory (versions, ports, IPs, container counts) that are obsolete.

| Score | Condition |
|-------|-----------|
| 10 | All tech claims match reality |
| 8 | 1 obsolete claim |
| 6 | 2-3 obsolete claims |
| 4 | 4-5 obsolete claims |
| 2 | 6-8 obsolete claims |
| 0 | > 8 obsolete claims |

Requires `--tech` or `--deep` to validate tech state.
Without validation, defaults to 10.0.

---

## Edge Cases

| Situation | Behavior |
|-----------|----------|
| Dimension cannot be measured (no `--deep`, no `--tech`, etc.) | Score defaults to 10.0 (assumed healthy until proven otherwise) |
| No `dream-history.jsonl` exists yet | Trend shows "N/A — first dream", no delta |
| MEMORY.md does not exist | Score 0 on D1, skip remaining, suggest init |
| Zero memory files (only MEMORY.md) | Score 10 on D2/D3/D6/D7, other dims as measured |
| Cross-project dir found but MEMORY.md unreadable | Skip that project, note in output |
| File modified in the future (clock skew) | Treat as fresh (0 days stale) |

---

## Dashboard Output Template

```
+===================================================================+
|   MEMORY HEALTH — {project} — YYYY-MM-DD HH:MM TZ                |
|   Score: {X.X}/10  Grade: {G}  Trend: {arrow} {+/-delta}         |
+===================+=======+========+=======+=======================+
| Dimension         | Score | Weight | Wt.   | Detail                |
+===================+=======+========+=======+=======================+
| Index Capacity    | {X.X} |  12%   | {X.XX}| {N}/200 ln            |
| Orphan Rate       | {X.X} |  12%   | {X.XX}| {N} orphans           |
| Staleness         | {X.X} |  12%   | {X.XX}| {N} stale >30d        |
| Ref Integrity     | {X.X} |  12%   | {X.XX}| {N} broken            |
| Content Fresh     | {X.X} |  10%   | {X.XX}| {N} claims stale      |
| File Size Bal     | {X.X} |   8%   | {X.XX}| {N} >50KB             |
| Type Coverage     | {X.X} |   8%   | {X.XX}| {N} untyped           |
| Cross-Project     | {X.X} |   8%   | {X.XX}| {N} contradictions    |
| Docs Freshness    | {X.X} |  10%   | {X.XX}| INDEX {N}d old        |
| Tech Accuracy     | {X.X} |   8%   | {X.XX}| {N} obsolete          |
+===================+=======+========+=======+=======================+
| TOTAL             |       |        | {X.XX}| Grade: {G}            |
+===================================================================+

Ecosystem Sources Scanned
+----------------------+-------+--------+
| Source               | Items | Status |
+----------------------+-------+--------+
| memory/              | {N}   | OK     |
| .blueprint/          | {N}   | OK/WARN|
| .blueprint/plans/    | {N}   | OK/WARN|
| .blueprint/handoffs/ | {N}   | OK     |
| FEATURES.md          | {N}   | OK/WARN|
| ATLAS plugin         | v{X}  | OK/WARN|
| Tech stack           | {N}   | OK/WARN|
+----------------------+-------+--------+
```

When a dimension was not measured (e.g., cross-project without `--deep`), display `—` for score and `(need --deep)` in Detail column. Its weighted contribution is computed using the 10.0 default.

---

## Trend Tracking — dream-history.jsonl

Each dream appends exactly one JSON line to `dream-history.jsonl` in the memory directory.

### Schema

```json
{
  "timestamp": "2026-03-25T17:38:00-04:00",
  "project": "synapse",
  "score": 7.6,
  "grade": "B",
  "dimensions": {
    "index_capacity": 8.0,
    "orphan_rate": 10.0,
    "staleness": 8.0,
    "ref_integrity": 10.0,
    "content_freshness": 6.0,
    "file_size_balance": 4.0,
    "type_coverage": 10.0,
    "cross_project": null,
    "docs_freshness": 7.0,
    "tech_accuracy": 8.0
  },
  "files_total": 178,
  "memory_lines": 149,
  "orphans": 0,
  "actions_taken": 5,
  "mode": "standard",
  "duration_minutes": 8
}
```

Field notes:
- `timestamp`: ISO 8601 with timezone offset. NEVER date-only.
- `dimensions`: `null` value means dimension was not measured (used default 10.0).
- `mode`: one of `report`, `standard`, `deep`, `validate`, `health`, `journal`.
- `duration_minutes`: wall-clock time from Phase 1 start to report write.

### Trend Display (`/atlas dream trends`)

```
Health Trend — {project}
+---------------------+-------+-------+--------+
| Timestamp           | Score | Grade | Delta  |
+---------------------+-------+-------+--------+
| 2026-03-25 17:38    |  7.6  |   B   |  —     |
| 2026-03-22 14:15    |  7.4  |   B   | +0.2   |
| 2026-03-18 09:22    |  6.8  |   C   | +0.6   |
| 2026-03-12 16:45    |  6.2  |   C   | +0.6   |
+---------------------+-------+-------+--------+
Trend: improving (+1.4 over 4 dreams, 13 days)
```

Rules:
- `dream-history.jsonl` is **append-only** — never truncate or rewrite.
- Display most recent first.
- Delta is relative to the previous entry.
- If only 1 entry, delta = `—`.
