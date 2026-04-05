# Dream Report v4 — Template & Schema

> Enriched report format generated in Phase 4 of the dream cycle. Includes health score
> (17D with experiential + workflow + learning velocity dimensions), trends, importance
> distribution, ecosystem audit, tech validation, experiential context, workflow audit,
> learning velocity audit, session journal, handoff context, and cross-project summary.

## Report Filename

```
dream-report-YYYY-MM-DD-HHMM.md
```

Always include time in the filename to allow multiple dreams per day.

---

## Report Template

```markdown
# Dream Report — {project} — YYYY-MM-DD HH:MM TZ

> Health: {X.X}/10 ({Grade}) | Trend: {arrow} {+/-delta} vs last dream
> Mode: {standard|deep|validate} | Duration: {N} min | Phases: {list}

---

## Health Score (17 Dimensions)

| # | Dimension | Score | Weight | Weighted | Detail |
|---|-----------|-------|--------|----------|--------|
| D1 | Index Capacity | {X.X} | 10% | {X.XX} | {N}/200 lines |
| D2 | Orphan Rate | {X.X} | 10% | {X.XX} | {N} orphans |
| D3 | Staleness | {X.X} | 8% | {X.XX} | {N}% files >30d |
| D4 | Ref Integrity | {X.X} | 10% | {X.XX} | {N} broken refs |
| D5 | Content Freshness | {X.X} | 5% | {X.XX} | {N} stale claims |
| D6 | File Size Balance | {X.X} | 6% | {X.XX} | {N} files >50KB |
| D7 | Type Coverage | {X.X} | 6% | {X.XX} | {N} untyped |
| D8 | Cross-Project | {X.X} | 6% | {X.XX} | {N} contradictions |
| D9 | Docs Freshness | {X.X} | 8% | {X.XX} | INDEX {N}d old |
| D10 | Tech Accuracy | {X.X} | 6% | {X.XX} | {N} obsolete claims |
| | **EXPERIENTIAL** | | | | |
| D11 | Experiential Coverage | {X.X} | 5% | {X.XX} | {N}% sessions covered |
| D12 | Relational Depth | {X.X} | 4% | {X.XX} | {N} active relations |
| D13 | Temporal Validity | {X.X} | 5% | {X.XX} | {N} expired facts |
| D14 | Intuition Quality | {X.X} | 3% | {X.XX} | {N} stale intuitions |
| D15 | Growth Trajectory | {X.X} | 3% | {X.XX} | {trend} |
| | **WORKFLOW & LEARNING** | | | | |
| D16 | Workflow Efficiency | {X.X} | 3% | {X.XX} | {N}% success rate |
| D17 | Learning Velocity | {X.X} | 5% | {X.XX} | {N} new FB/30d |
| **Total** | | | | **{X.XX}** | **Grade: {G}** |

---

## Before / After Metrics

| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| MEMORY.md lines | {N} | {N} | {+/-N} |
| Total memory files | {N} | {N} | {+/-N} |
| Orphan files | {N} | {N} | {+/-N} |
| Oversized files (>50KB) | {N} | {N} | {+/-N} |
| Untyped files | {N} | {N} | {+/-N} |
| Stale files (>30d) | {N} | {N} | {+/-N} |
| Broken references | {N} | {N} | {+/-N} |
| Duplicates resolved | — | {N} | — |
| Dates normalized | — | {N} | — |
| Contradictions resolved | — | {N} | — |

---

## Actions Taken

1. {Action description} — {file(s) affected}
2. {Action description} — {file(s) affected}
3. ...

Total actions: {N} | HITL gates passed: {N}/{N}

---

## Code Staleness (if --validate ran)

| Memory Claim | Path / Entity | Exists? | Status |
|-------------|---------------|---------|--------|
| Hook `useWorkspaceNavigation` | `frontend/src/hooks/` | YES | Current |
| Endpoint `/api/v1/instruments` | `backend/routers/` | YES | Current |
| File `coverage-engine.md` | `memory/` | NO | STALE |
| Plugin version v3.23.0 | `plugin.json` | — | Outdated (v3.23.3) |

Stale claims requiring update: {N}
(Gate H3 triggered for each stale claim)

---

## Importance Distribution

| Stars | Count | Examples |
|-------|-------|---------|
| 5 (critical) | {N} | user_profile.md, stack-2026.md |
| 4 (high) | {N} | feedback_*.md, active project files |
| 3 (medium) | {N} | reference files, completed plans |
| 2 (low) | {N} | historical context, old audits |
| 1 (archive candidate) | {N} | stale + unreferenced files |

---

## Ecosystem Sources Scanned

| Source | Items | Stale | Status | Notes |
|--------|-------|-------|--------|-------|
| memory/ | {N} | {N} | OK/WARN | {detail} |
| .blueprint/ | {N} | {N} | OK/WARN | {detail} |
| .blueprint/plans/ | {N} | {N} | OK/WARN | {detail} |
| .blueprint/handoffs/ | {N} | {N} | OK/WARN | {N} unsynced |
| FEATURES.md | {N} features | {N} | OK/WARN | {N} tier mismatches |
| ATLAS plugin | v{X.Y.Z} | — | OK/WARN | memory says v{A.B.C} |
| Tech stack | {N} claims | {N} | OK/WARN | {N}/{N} match |

---

## Tech Claims vs Reality (if --tech ran)

| Claim | Memory Value | Actual Value | Match |
|-------|-------------|-------------|-------|
| Python version | {mem} | {actual} | YES/NO |
| bun version | {mem} | {actual} | YES/NO |
| PostgreSQL version | {mem} | {actual} | YES/NO |
| Plugin version | {mem} | {actual} | YES/NO |
| Docker containers | {mem} | {actual} | YES/NO |
| Backend port | {mem} | {actual} | YES/NO |
| Forgejo IP | {mem} | {actual} | YES/NO |

Mismatches: {N} — memory files to update: {list}

---

## Experiential Context (if --experiential or --deep ran)

### Episode Coverage (last 14 days)

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Sessions total | {N} | — | — |
| Episodes created | {N} | {50%+ of sessions} | OK/GAP |
| Average energy | {X.X}/5 | 3.0+ | OK/LOW |
| Flow sessions | {N} ({%}) | 30%+ | OK/LOW |
| Avg confidence | {X.X} | 0.6+ | OK/LOW |

### Energy Trend

```
{ASCII sparkline or simple trend: 4 → 3 → 2 → 3 → 4}
```

### Relationship Freshness

| Person | Last Interaction | Status |
|--------|-----------------|--------|
| {name} | {date} | OK/STALE (>{30d}) |

### Intuition Status

| Intuition | Age | Confidence | Status |
|-----------|-----|------------|--------|
| {topic} | {N}d | {trend} | pending/validated/stale |

### Growth Signals

- Energy: {rising/stable/declining}
- Flow frequency: {rising/stable/declining}
- Decision confidence: {rising/stable/declining}

---

## Session Journal (if journal captured)

### What Went Well
- {decisions made, problems solved, insights}

### What Blocked / Pivots
- {errors, dead-ends, direction changes}

### Key Decisions

| # | Decision | Why | Alternative Rejected |
|---|----------|-----|---------------------|
| 1 | {decision} | {rationale} | {alternative} |

### Technical Insights
- {patterns discovered, gotchas, performance observations}

### Open Questions
- {unresolved questions for future sessions}

---

## Handoff Context

> This section is designed to feed directly into `/a-handoff` for seamless session transitions.

### Current Health
- Score: {X.X}/10 ({Grade})
- Top issues: {list of lowest-scoring dimensions}

### Files Modified During Dream
- {file1.md} — {action taken}
- {file2.md} — {action taken}

### Recommendations for Next Session
1. {recommendation}
2. {recommendation}
3. {recommendation}

### Tech State Snapshot
- Stack: {versions summary}
- Docker: {container count, health}
- Infra: {any notable changes}
- Plugin: v{X.Y.Z}

---

## Cross-Project Summary (if --deep ran)

| Project | Files | Health Est. | Contradictions |
|---------|-------|-------------|----------------|
| synapse | {N} | {X.X} ({G}) | {N} |
| atlas-core | {N} | {X.X} ({G}) | {N} |
| infrastructure | {N} | {X.X} ({G}) | {N} |

### Contradictions Found

| Entity | This Project | Other Project | Resolution |
|--------|-------------|--------------|------------|
| {entity} | {value here} | {value there} ({project}) | {pending/resolved} |

---

## Recommendations for Next Dream

1. {recommendation with priority}
2. {recommendation with priority}
3. {recommendation with priority}

Suggested next dream mode: {standard|deep|validate}
Suggested timing: {when, based on current health and work pace}
```

---

## dream-history.jsonl Append Format

After writing the report, append exactly one line to `dream-history.jsonl` in the memory directory.

### JSON Line Schema

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

### Rules

- **Timestamp**: ISO 8601 with timezone offset. NEVER date-only. Example: `2026-03-25T17:38:00-04:00`.
- **Dimensions**: Use `null` for dimensions that were not measured (default 10.0 was used in scoring).
- **Mode**: One of `report`, `standard`, `deep`, `validate`, `health`, `journal`.
- **Append-only**: NEVER truncate, rewrite, or delete lines from this file.
- **One line per dream**: Each dream cycle produces exactly one JSON line, regardless of how many phases ran.
- **HITL gate H16**: User must approve before the line is appended.

### How to Append

```bash
echo '{"timestamp":"2026-03-25T17:38:00-04:00","project":"synapse","score":7.6,...}' >> "$MEMORY_DIR/dream-history.jsonl"
```

Use `>>` (append), never `>` (overwrite).
