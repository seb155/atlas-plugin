# Health Scoring Reference — 15 Dimensions (v4)

> Detailed scoring thresholds, formula, dashboard template, and edge cases for the
> memory health score computed in Phase 4 of the dream cycle.
> v4 adds 5 experiential dimensions (D11-D15) for whole-person memory health.

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

### D1 — Index Capacity (Weight: 10%)

How close MEMORY.md is to the 200-line hard limit.

| Score | Condition |
|-------|-----------|
| 10 | <= 120 lines |
| 8 | 121-150 lines |
| 6 | 151-170 lines |
| 4 | 171-190 lines |
| 2 | 191-200 lines |
| 0 | > 200 lines |

### D2 — Orphan Rate (Weight: 10%)

Percentage of memory files not referenced in MEMORY.md.

| Score | Condition |
|-------|-----------|
| 10 | 0 orphans |
| 8 | 1-2 orphans (< 3% of files) |
| 6 | 3-5 orphans (3-5%) |
| 4 | 6-8 orphans (5-8%) |
| 2 | 9-12 orphans (8-10%) |
| 0 | > 12 orphans (> 10%) |

### D3 — Staleness (Weight: 10%)

Percentage of files not modified in the last 30 days.

| Score | Condition |
|-------|-----------|
| 10 | 0% stale (all files < 30d) |
| 8 | 1-10% stale |
| 6 | 11-20% stale |
| 4 | 21-30% stale |
| 2 | 31-50% stale |
| 0 | > 50% stale |

### D4 — Referential Integrity (Weight: 10%)

Broken links in MEMORY.md (files referenced but not existing on disk).

| Score | Condition |
|-------|-----------|
| 10 | 0 broken references |
| 8 | 1 broken |
| 6 | 2-3 broken |
| 4 | 4-5 broken |
| 2 | 6-8 broken |
| 0 | > 8 broken |

### D5 — Content Freshness (Weight: 8%)

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

### D6 — File Size Balance (Weight: 6%)

Files exceeding size thresholds (oversized files hurt discoverability).

| Score | Condition |
|-------|-----------|
| 10 | 0 files > 50KB |
| 8 | 1 file 50-75KB |
| 6 | 1 file > 75KB or 2 files > 50KB |
| 4 | 2+ files > 75KB |
| 2 | Any file > 100KB |
| 0 | Multiple files > 100KB |

### D7 — Type Coverage (Weight: 6%)

Percentage of memory files with proper frontmatter `type:` field.

| Score | Condition |
|-------|-----------|
| 10 | 0 untyped files |
| 8 | 1-2 untyped |
| 6 | 3-5 untyped |
| 4 | 6-8 untyped |
| 2 | 9-12 untyped |
| 0 | > 12 untyped |

### D8 — Cross-Project Coherence (Weight: 6%)

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

### D9 — Docs Freshness (Weight: 8%)

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

### D10 — Tech Accuracy (Weight: 6%)

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

### D11 — Experiential Coverage (Weight: 5%)

Percentage of recent sessions (last 14 days) with corresponding episode files.

| Score | Condition |
|-------|-----------|
| 10 | 80%+ sessions have episodes |
| 8 | 60-79% coverage |
| 6 | 40-59% coverage |
| 4 | 20-39% coverage |
| 2 | 1-19% coverage |
| 0 | 0 episodes in last 14 days |

Requires `--experiential` or `--deep` to scan episode files.
Without scan, defaults to 5.0 (neutral — neither penalized nor rewarded).

### D12 — Relational Depth (Weight: 4%)

Active relationship files relative to known team size.

| Score | Condition |
|-------|-----------|
| 10 | 3+ relationship files, all updated < 30d |
| 8 | 3+ relationship files, 1 stale > 30d |
| 6 | 2 relationship files |
| 4 | 1 relationship file |
| 2 | 0 relationship files but team members in ACTIVE WORK |
| 0 | (unused — 2 is minimum when team exists) |

Defaults to 5.0 when no relationship files exist and no team is detected.

### D13 — Temporal Validity (Weight: 5%)

Facts with expired `valid_until` dates still marked as active.

| Score | Condition |
|-------|-----------|
| 10 | 0 expired temporal facts |
| 8 | 1-2 expired |
| 6 | 3-4 expired |
| 4 | 5-6 expired |
| 2 | 7-12 expired |
| 0 | > 12 expired |

Defaults to 10.0 when no temporal files exist (no violations possible).

### D14 — Intuition Quality (Weight: 3%)

Ratio of validated vs stale (> 60 days, unvalidated) intuition files.

| Score | Condition |
|-------|-----------|
| 10 | All intuitions validated or < 30d old |
| 8 | 1 stale unvalidated intuition |
| 6 | 2-3 stale |
| 4 | 4-5 stale |
| 2 | > 5 stale |
| 0 | (unused) |

Defaults to 10.0 when no intuition files exist.

### D15 — Growth Trajectory (Weight: 3%)

Positive trend in average energy, flow frequency, and decision confidence over last 30 days.

| Score | Condition |
|-------|-----------|
| 10 | All 3 metrics improving |
| 8 | 2 improving, 1 stable |
| 6 | All stable or mixed |
| 4 | 1 declining |
| 2 | 2-3 declining |
| 0 | Insufficient data (< 3 episodes in 30d) |

Defaults to 5.0 when insufficient episode data exists.

### Weight Summary (v4)

| # | Dimension | Weight | Default |
|---|-----------|--------|---------|
| D1 | Index Capacity | 10% | Measured always |
| D2 | Orphan Rate | 10% | Measured always |
| D3 | Staleness | 10% | Measured always |
| D4 | Ref Integrity | 10% | Measured always |
| D5 | Content Freshness | 8% | 10.0 if not validated |
| D6 | File Size Balance | 6% | Measured always |
| D7 | Type Coverage | 6% | Measured always |
| D8 | Cross-Project | 6% | 10.0 if not scanned |
| D9 | Docs Freshness | 8% | 10.0 if not audited |
| D10 | Tech Accuracy | 6% | 10.0 if not validated |
| D11 | Experiential Coverage | 5% | 5.0 if not scanned |
| D12 | Relational Depth | 4% | 5.0 if no data |
| D13 | Temporal Validity | 5% | 10.0 if no temporal files |
| D14 | Intuition Quality | 3% | 10.0 if no intuition files |
| D15 | Growth Trajectory | 3% | 5.0 if insufficient data |
| | **TOTAL** | **100%** | |

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
| Index Capacity    | {X.X} |  10%   | {X.XX}| {N}/200 ln            |
| Orphan Rate       | {X.X} |  10%   | {X.XX}| {N} orphans           |
| Staleness         | {X.X} |  10%   | {X.XX}| {N} stale >30d        |
| Ref Integrity     | {X.X} |  10%   | {X.XX}| {N} broken            |
| Content Fresh     | {X.X} |   8%   | {X.XX}| {N} claims stale      |
| File Size Bal     | {X.X} |   6%   | {X.XX}| {N} >50KB             |
| Type Coverage     | {X.X} |   6%   | {X.XX}| {N} untyped           |
| Cross-Project     | {X.X} |   6%   | {X.XX}| {N} contradictions    |
| Docs Freshness    | {X.X} |   8%   | {X.XX}| INDEX {N}d old        |
| Tech Accuracy     | {X.X} |   6%   | {X.XX}| {N} obsolete          |
+-------------------+-------+--------+-------+-----------------------+
| EXPERIENTIAL      |       |        |       |                       |
+-------------------+-------+--------+-------+-----------------------+
| Exp. Coverage     | {X.X} |   5%   | {X.XX}| {N}% sessions covered |
| Relational Depth  | {X.X} |   4%   | {X.XX}| {N} active relations  |
| Temporal Valid.   | {X.X} |   5%   | {X.XX}| {N} expired facts     |
| Intuition Quality | {X.X} |   3%   | {X.XX}| {N} stale intuitions  |
| Growth Trajectory | {X.X} |   3%   | {X.XX}| {trend}               |
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

---

## v3 Additions

### Relevance Coverage (Quality Indicator — not scored)

Track `relevance: HIGH|MED|LOW` distribution across topic files:
```bash
grep -rl "relevance: HIGH" "$MEMORY_DIR"/*.md | wc -l  # target: 20-30%
grep -rl "relevance: MED" "$MEMORY_DIR"/*.md | wc -l   # target: 40-60%
grep -rl "relevance: LOW" "$MEMORY_DIR"/*.md | wc -l   # target: 20-30%
```

Include distribution in dream report but not in health score (metadata, not quality).

### Knowledge Type Distribution (Quality Indicator — not scored)

Track `knowledge: propositional|prescriptive` split:
```bash
grep -rl "knowledge: propositional" "$MEMORY_DIR"/*.md | wc -l
grep -rl "knowledge: prescriptive" "$MEMORY_DIR"/*.md | wc -l
```

Healthy ratio: 60-70% propositional (facts) / 30-40% prescriptive (rules).

### Context Failure Mode Count (feeds D5)

V4 from validate-phase.md feeds into D5 (Content Freshness):
- Each POISONING or CLASH detected reduces D5 by 1 point
- Each CONFUSION detected reduces D5 by 0.5 points
- DISTRACTION detected feeds into D6 (File Size Balance) instead

### Temporal Window Coverage (feeds D5)

V5 from validate-phase.md:
- COMPLETE/DONE items WITHOUT `(since ...)` → penalty of 0.5 per missing item on D5
- Items with `(since ...)` older than 60d still in ACTIVE WORK → penalty of 1.0 per item on D5

### GRAPH.md Freshness (Quality Indicator — not scored)

Track entity-relationship index staleness:
```bash
stat -c '%Y' "$MEMORY_DIR/GRAPH.md" 2>/dev/null
```

If GRAPH.md >14d old, display `⚠️ GRAPH.md stale — regenerate with dream cycle` in report.

### Enhanced dream-history.jsonl Schema (v3)

```json
{
  "timestamp": "2026-03-26T20:36:00-04:00",
  "project": "synapse",
  "version": "v3",
  "score": 8.4,
  "grade": "B",
  "dimensions": {
    "index_capacity": 8.0,
    "orphan_rate": 10.0,
    "staleness": 9.0,
    "ref_integrity": 9.0,
    "content_freshness": 9.0,
    "file_size_balance": 7.0,
    "type_coverage": 10.0,
    "cross_project": null,
    "docs_freshness": null,
    "tech_accuracy": null
  },
  "metadata": {
    "files_total": 138,
    "memory_lines": 161,
    "orphans": 0,
    "oversized": 1,
    "feedback_files": 28,
    "relevance_distribution": {"HIGH": 35, "MED": 68, "LOW": 35},
    "knowledge_distribution": {"propositional": 96, "prescriptive": 42},
    "failure_modes": {"poisoning": 0, "distraction": 1, "confusion": 0, "clash": 0},
    "graph_md_age_days": 0
  },
  "actions_taken": ["split lessons.md", "merged 2 feedback", "resolved 7 orphans"],
  "mode": "standard",
  "duration_minutes": 12
}
```

New v3 fields:
- `version`: Schema version (`"v3"`)
- `metadata.relevance_distribution`: Count per relevance level
- `metadata.knowledge_distribution`: Count per knowledge type
- `metadata.failure_modes`: Count per V4 failure mode category
- `metadata.graph_md_age_days`: Days since GRAPH.md last modified
- `actions_taken`: Array of strings (replaces count)

### Enhanced dream-history.jsonl Schema (v4)

v4 adds experiential dimensions and metadata for the whole-person memory system.

```json
{
  "timestamp": "2026-03-28T10:15:00-04:00",
  "project": "synapse",
  "version": "v4",
  "score": 8.7,
  "grade": "B",
  "dimensions": {
    "index_capacity": 8.0,
    "orphan_rate": 10.0,
    "staleness": 9.0,
    "ref_integrity": 10.0,
    "content_freshness": 9.0,
    "file_size_balance": 9.0,
    "type_coverage": 10.0,
    "cross_project": null,
    "docs_freshness": 9.5,
    "tech_accuracy": 9.0,
    "experiential_coverage": 6.0,
    "relational_depth": 8.0,
    "temporal_validity": 10.0,
    "intuition_quality": 10.0,
    "growth_trajectory": 5.0
  },
  "metadata": {
    "files_total": 185,
    "memory_lines": 140,
    "orphans": 0,
    "oversized": 0,
    "feedback_files": 36,
    "relevance_distribution": {"HIGH": 40, "MED": 90, "LOW": 55},
    "knowledge_distribution": {"propositional": 105, "prescriptive": 36, "experiential": 8, "tacit": 2},
    "failure_modes": {"poisoning": 0, "distraction": 0, "confusion": 0, "clash": 0},
    "graph_md_age_days": 2,
    "episode_files": 5,
    "intuition_files": 2,
    "reflection_files": 1,
    "relationship_files": 3,
    "temporal_files": 0,
    "experiential_coverage_pct": 60,
    "avg_energy": 3.4,
    "flow_sessions_pct": 40,
    "avg_confidence": 0.72
  },
  "actions_taken": ["created 2 episodes", "updated 1 relationship", "archived 3 old episodes"],
  "mode": "deep",
  "duration_minutes": 15
}
```

New v4 fields:
- `dimensions.experiential_coverage`: D11 score (null if not measured)
- `dimensions.relational_depth`: D12 score (null if not measured)
- `dimensions.temporal_validity`: D13 score (null if not measured)
- `dimensions.intuition_quality`: D14 score (null if not measured)
- `dimensions.growth_trajectory`: D15 score (null if not measured)
- `metadata.episode_files`: Count of type:episode files
- `metadata.intuition_files`: Count of type:intuition files
- `metadata.reflection_files`: Count of type:reflection files
- `metadata.relationship_files`: Count of type:relationship files
- `metadata.temporal_files`: Count of type:temporal files
- `metadata.experiential_coverage_pct`: Percentage of sessions with episodes (last 14d)
- `metadata.avg_energy`: Mean energy level across recent episodes
- `metadata.flow_sessions_pct`: Percentage of sessions with flow_state:true
- `metadata.avg_confidence`: Mean decision confidence across recent episodes
