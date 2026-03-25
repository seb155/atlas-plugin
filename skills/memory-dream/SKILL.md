---
name: memory-dream
description: "Memory consolidation engine v2 (CC auto-dream pattern). 8-phase cycle: orient, docs audit, gather signal, validate, consolidate, session journal, prune & index, cross-project. Use when 'dream', 'consolidate memory', 'clean memory', 'memory audit', 'memory health', 'memory cleanup', 'memory check', 'dream report', 'dream health', 'dream trends', 'dream journal', 'dream status', 'tech state', 'memory hygiene'."
effort: high
---

# Memory Dream v2 — Intelligent Consolidation Engine

> Implements CC's auto-dream pattern: an 8-phase memory consolidation cycle inspired by
> sleep-time compute (UC Berkeley + Letta, 2025). v2 adds intelligence layers: health
> scoring (10 dimensions), code validation, ecosystem audit, session journaling, cross-project
> coherence, and trend tracking. Scope: memory + handoffs + docs + plans + features + plugin state.

## When to Use

- MEMORY.md growing past 150 lines
- 5+ sessions since last consolidation
- User says "dream", "clean memory", "consolidate", "memory audit", "memory health"
- End of sprint or major feature work
- Before fresh planning session (clean slate)
- After receiving handoffs from another session
- When suspecting stale status claims or outdated tech info

## Subcommands

| Command | Phases | Time | Action |
|---------|--------|------|--------|
| `/atlas dream` | 1-4 | ~10 min | Standard 4-phase cycle with HITL gates |
| `/atlas dream --deep` | 1-5 | ~20 min | Full intelligence: validate + cross-project |
| `/atlas dream --dry-run` | 1-2 | ~2 min | Report only — zero writes |
| `/atlas dream report` | 1-2 | ~2 min | Quick staleness + orphan report only |
| `/atlas dream --validate` | 1+2.5 | ~5 min | Code freshness + status claim check |
| `/atlas dream --cross-project` | 1+5 | ~5 min | Multi-repo consistency scan |
| `/atlas dream --docs` | 1+1.5 | ~3 min | .blueprint/ + plans/ + handoffs/ audit |
| `/atlas dream --handoffs` | 1+1.5-D3 | ~3 min | Ingest recent handoffs as signal |
| `/atlas dream journal` | J1 only | ~2 min | Synthesize current session into journal entry |
| `/atlas dream --tech` | 1+1.5-D6 | ~5 min | Technical state consolidation (stack, versions, ports) |
| `/atlas dream --split <file>` | 3.6 only | ~5 min | Split wizard for one oversized file |
| `/atlas dream health` | Score | ~1 min | 10D health dashboard |
| `/atlas dream trends` | History | ~1 min | Health over time from dream-history.jsonl |
| `/atlas dream status` | 2+2.5 | ~3 min | ACTIVE WORK status claim verification |
| `/atlas dream --schedule` | — | — | Schedule recurring dream via CronCreate |

### Progressive Disclosure Tiers

| Tier | Invocation | Phases Run | Writes? |
|------|------------|------------|---------|
| Report | `dream report`, `dream health`, `dream trends`, `dream status` | Read-only subset | No |
| Standard | `dream`, `dream --docs`, `dream --handoffs`, `dream journal` | 1 through 4 (subset varies) | Yes (HITL) |
| Deep | `dream --deep`, `dream --validate`, `dream --cross-project` | 1 through 5 (all phases) | Yes (HITL) |

## Phase 1 — Orient (Enhanced)

Scan memory directory and build a complete mental map.

### Steps

1. **Detect memory directory**:
   ```bash
   MEMORY_DIR=$(find ~/.claude/projects -path "*/memory/MEMORY.md" -printf "%h\n" 2>/dev/null | head -1)
   ```
   If multiple projects, use the one matching the current working directory.

2. **Read MEMORY.md**: Count lines, extract `## Section` headers, build section-to-line map.

3. **List all topic files**:
   ```bash
   ls "$MEMORY_DIR"/*.md | grep -v MEMORY.md | wc -l
   ```

4. **Detect orphans**: Files in memory dir NOT referenced in MEMORY.md.
   ```bash
   for f in "$MEMORY_DIR"/*.md; do
     base=$(basename "$f")
     [ "$base" = "MEMORY.md" ] && continue
     grep -q "$base" "$MEMORY_DIR/MEMORY.md" || echo "ORPHAN: $base"
   done
   ```

5. **File size audit** (NEW): Detect oversized files.
   ```bash
   du -k "$MEMORY_DIR"/*.md | awk '$1 > 50 {print "OVERSIZED:", $2, $1"KB"}'
   ```
   Classify: normal (<25KB) | large (25-50KB) | oversized (>50KB).

6. **Cross-project discovery** (NEW): Find all memory directories.
   ```bash
   find ~/.claude/projects -name "MEMORY.md" -printf "%h\n" 2>/dev/null
   ```

7. **Check consolidation lock**:
   ```bash
   [ -f "$MEMORY_DIR/.consolidate-lock" ] && echo "LOCKED"
   ```

8. **Output orient summary**:
   ```
   Memory Orient — YYYY-MM-DD HH:MM TZ
   ├─ MEMORY.md: {N} lines (limit: 200)
   ├─ Topic files: {N} total
   ├─ Orphans: {N} (not referenced in MEMORY.md)
   ├─ Oversized: {N} files >50KB
   ├─ Cross-project dirs: {N}
   ├─ Lock: {free|locked}
   └─ Last modified: {YYYY-MM-DD HH:MM TZ}
   ```

## Phase 1.5 — Docs & Ecosystem Audit (NEW)

> Always runs with `--deep`. Standalone with `--docs`, `--handoffs`, or `--tech`.

Scans the full documentation ecosystem beyond memory/.

For details, read `${SKILL_DIR}/references/docs-audit.md`

### Steps

- **D1 — .blueprint/ audit**: Count files, verify INDEX.md freshness, detect orphan docs and stale files (>30d).
- **D2 — Plans audit**: List `.blueprint/plans/*.md`, verify links in MEMORY.md, detect dead plan references and plans >6 months without update.
- **D3 — Handoffs ingestion**: Scan `.blueprint/handoffs/handoff-*.md`, extract decisions/gotchas/quick-start, compare with lessons.md, identify recent handoffs (<7d) with uncaptured insights. **HITL gate H1**.
- **D4 — FEATURES.md sync**: Count features by tier, compare with MEMORY.md claims, detect shipped features still in ACTIVE WORK. **HITL gate H2**.
- **D5 — ATLAS plugin state**: Compare plugin version, skill/agent/command counts against memory claims.
- **D6 — Technical state validation** (`--tech`): Compare stack versions, Docker state, ports, IPs, and infra claims against live system reality.

### Output

```
Ecosystem Audit — YYYY-MM-DD HH:MM TZ
┌──────────────────────┬───────┬────────┬────────┐
│ Source               │ Items │ Stale  │ Status │
├──────────────────────┼───────┼────────┼────────┤
│ .blueprint/          │ {N}   │ {N}    │ OK/WARN│
│ .blueprint/plans/    │ {N}   │ {N}    │ OK/WARN│
│ .blueprint/handoffs/ │ {N}   │ {N}    │ OK     │
│ FEATURES.md          │ {N}   │ {N}    │ OK/WARN│
│ ATLAS plugin         │ v{X}  │ —      │ OK/WARN│
│ Tech stack           │ —     │ {N}    │ OK/WARN│
└──────────────────────┴───────┴────────┴────────┘
```

## Phase 2 — Gather Signal (Enhanced)

Identify what needs attention without making changes.

### Steps

1. **Staleness report**: Categorize files by last modification date.
   Buckets: `<7d` (fresh) | `7-14d` (aging) | `14-30d` (stale) | `>30d` (archive candidate).

2. **Feedback audit**: Count and categorize `feedback_*.md`, detect near-duplicates (Levenshtein distance <= 3).

3. **Duplicate detection**: Jaccard similarity on word sets between non-feedback file pairs. Flag >70% overlap.

4. **Relative date detection**: Find dates that will become meaningless.
   ```bash
   grep -rn "yesterday\|last week\|today\|this morning\|ce matin\|hier" "$MEMORY_DIR"/*.md
   ```

5. **Memory type distribution**: Count by frontmatter `type:` field. Flag untyped files.

6. **Importance scoring** (NEW, 1-5 stars per file):
   - Reference count (30%): times cited in MEMORY.md + other files
   - Recency (25%): days since last modification
   - Size penalty (15%): penalize >100KB
   - Type bonus (15%): user=5, feedback=4, project=3, reference=2
   - Active Work link (15%): +2 if in ACTIVE WORK table

7. **Status claim scan** (NEW): Grep `COMPLETE|LIVE|DONE|SHIPPED` across all memory files. Build list for Phase 2.5 validation.

8. **Reference extraction** (NEW): Grep URLs, file paths, API endpoints. Prepare for Phase 2.5 validation.

9. **Output gather summary**: Dashboard table with all metrics.

If `--dry-run` or `report` subcommand: **STOP HERE**. Display report and exit.

## Phase 2.5 — Validate (NEW)

> Requires `--deep` or `--validate`. Intelligence layer that validates memory against reality.

For details, read `${SKILL_DIR}/references/validate-phase.md`

### Steps

- **V1 — Code staleness**: Extract file paths and function/hook names from memory, verify existence in codebase (`[ -f ]`, `grep`). Extract API endpoints, match against backend routes.
- **V2 — Status claim verification**: For each `COMPLETE/LIVE/DONE` claim, verify via git branch, tests, health endpoint. Check counts (test files, features) and versions (plugin, packages) against reality. **HITL gate H3** for stale claims.
- **V3 — External reference validation**: File paths (`[ -f ]`), plan references (`.blueprint/plans/` existence), URLs (with `--deep` only: `curl -sI --max-time 5`).

## Phase 3 — Consolidate (Enhanced, HITL Required)

Make changes with explicit user approval at every step.

### Steps

1. **Merge duplicates** (H4): Show both files, options: "Merge into A" / "Merge into B" / "Keep both" / "Skip".
2. **Normalize dates** (H5): Show relative dates with context, propose absolute replacement.
3. **Flag contradictions** (H6): Show opposing statements, ask which is current truth.
4. **Categorize orphans** (H7): Read first 10 lines, propose: add to MEMORY.md or archive.
5. **Type missing frontmatter** (H8): Suggest frontmatter based on content.
6. **Large file split wizard** (H9, NEW): Auto-trigger for files >50KB.
   - `lessons.md` splits by domain (backend, frontend, infra, ai, domain)
   - `session-log.md` archives entries >60 days into `session-log-archive-YYYY-Q.md`
   - Safety: create new files BEFORE modifying the original.
   For details, read `${SKILL_DIR}/references/large-file-strategy.md`
7. **Smart pruning** (H10, NEW): Files with importance <=1 AND stale >30d proposed for archival. NEVER prune feedback files or ACTIVE WORK files.
8. **Auto-categorization** (H11, NEW): Propose sub-types (plan|architecture|status|integration|vision|audit). Propose ACTIVE WORK updates (DONE items removal).

## Phase 3.5 — Session Journal & Handoff Synthesis (NEW)

Capture live session context + bidirectional handoff integration.

For details, read `${SKILL_DIR}/references/session-journal.md`

### Steps

- **J1 — Session journal entry** (H13): Synthesize current conversation into structured journal (What Went Well, What Blocked, Key Decisions, Technical Insights, Open Questions). Preview before writing.
- **J2 — Handoff signal extraction** (H12): For recent handoffs (<7d), extract decisions, gotchas, dead-ends, quick-start commands. Cross-reference with `lessons.md` and `decisions.jsonl`. Propose new memory files for uncaptured insights.
- **J3 — Handoff-to-memory sync**: For each uncaptured insight, HITL gate to create memory file.
- **J4 — Session-to-handoff feed**: Dream report v2 includes "Handoff Context" section for `/a-handoff`.

**Standalone**: `/atlas dream journal` runs J1 only, appends to `session-log.md`, no full cycle needed.
Format: `YYYY-MM-DD HH:MM TZ -- {one-line summary}`.

## Phase 4 — Prune & Index (Enhanced)

Regenerate MEMORY.md and compute health.

### Steps

1. **Generate proposed MEMORY.md**: Group by category, tables for compact representation, 200-line hard limit (180-line soft target).
2. **Show proposed structure** via AskUserQuestion (H14): "Write as-is" / "Adjust" / "Cancel".
3. **Write MEMORY.md** if approved.
4. **Health score computation** (NEW): Calculate 10 dimensions, display dashboard.
   For details, read `${SKILL_DIR}/references/health-scoring.md`
5. **Generate dream report v2** (H15): Enriched format with health score, trend, importance distribution, code staleness, ecosystem sources, tech claims table, session journal, handoff context, cross-project summary.
   For details, read `${SKILL_DIR}/references/dream-report-v2.md`
6. **Trend persistence** (H16): Append one JSON line to `dream-history.jsonl`.
7. **Release lock**: Remove `.consolidate-lock`.

## Phase 5 — Cross-Project (NEW)

> Requires `--deep` or `--cross-project`. Read-only scan across all project memory directories.

For details, read `${SKILL_DIR}/references/cross-project.md`

### Steps

1. **Discovery**: Find all `MEMORY.md` directories in `~/.claude/projects`.
2. **Entity reconciliation**: Build map of shared entities (VMs, services, repos, IPs, versions).
3. **Contradiction detection**: Same entity with different status/version between projects.
4. **Output**: Cross-project table with file count, health estimate, contradictions.
5. **HITL gate H17**: Resolve each contradiction individually. **NEVER write to other projects' memory directories.**

## Schedule Mode

When invoked with `--schedule`:
```python
# Default: weekdays at 5:57 PM (off-minute to avoid load spikes)
CronCreate(cron="57 17 * * 1-5", prompt="/atlas dream --dry-run", recurring=True)
```
Display job ID. Scheduled jobs are session-scoped (7-day max, dies on exit).

## Safety Rules (12 Rules)

1. **NEVER auto-delete** -- archive only, never permanent delete
2. **NEVER write** without HITL (AskUserQuestion before every Write/Edit)
3. **Lock protection** -- `.consolidate-lock` at start, remove at end, timeout 30 min
4. **Backup MEMORY.md** -- read content before overwrite, restore if failure
5. **Read-only `--dry-run`** -- zero writes
6. **Cross-project isolation** -- NEVER write to other projects' memory directories
7. **Feedback immutability** -- NEVER suggest deleting or modifying `feedback_*.md`
8. **Large file safety** -- create new files BEFORE modifying/deleting the original
9. **Branch awareness** -- missing file may be on another branch, note git context
10. **Trend append-only** -- `dream-history.jsonl` is never truncated
11. **Max 2 retries** -- if a step fails 2x, escalate to human via AskUserQuestion
12. **NEVER edit plugin cache** -- only write to source repo, never `~/.claude/plugins/cache/`

## HITL Gate Map (17 Gates)

| Gate | Phase | Trigger | Required? |
|------|-------|---------|-----------|
| H1 | 1.5-D3 | Handoff insight to memory sync | Yes (--docs/--deep) |
| H2 | 1.5-D4 | FEATURES.md sync corrections | Yes (--docs/--deep) |
| H3 | 2.5-V2 | Stale status claims update | Yes (--validate/--deep) |
| H4 | 3.1 | Duplicate merge | Yes |
| H5 | 3.2 | Date normalization | Yes |
| H6 | 3.3 | Contradiction resolution | Yes |
| H7 | 3.4 | Orphan categorization | Yes |
| H8 | 3.5 | Frontmatter typing | Yes |
| H9 | 3.6 | Large file split | Yes |
| H10 | 3.7 | Smart pruning batch | Yes |
| H11 | 3.8 | Auto-categorization | Yes |
| H12 | 3.5-J2 | Handoff to memory file creation | Yes |
| H13 | 3.5-J4 | Session journal entry write | Yes |
| H14 | 4.2 | MEMORY.md write | Yes |
| H15 | 4.4 | Dream report write | Yes |
| H16 | 4.5 | Trend data persist | Yes |
| H17 | 5.4 | Cross-project contradiction fixes | Yes (--deep) |

## Model Strategy

| Phase | Model | Reason |
|-------|-------|--------|
| Phase 1 (Orient) | Sonnet | Simple scan, count |
| Phase 1.5 (Docs Audit) | Sonnet | File existence, staleness, version check |
| Phase 2 (Gather) | Sonnet | Pattern matching, scoring |
| Phase 2.5 (Validate) | Opus | Code understanding, semantic verification |
| Phase 3 (Consolidate) | Opus | Merge decisions, split strategy |
| Phase 3.5 (Journal) | Opus | Session synthesis, handoff reasoning |
| Phase 4 (Prune & Index) | Opus | Index design, report synthesis |
| Phase 5 (Cross-Project) | Opus | Cross-repo reasoning |

## Health Scoring (10 Dimensions)

Health is a weighted composite score (0-10) across 10 dimensions:

| # | Dimension | Weight |
|---|-----------|--------|
| D1 | Index Capacity | 12% |
| D2 | Orphan Rate | 12% |
| D3 | Staleness | 12% |
| D4 | Referential Integrity | 12% |
| D5 | Content Freshness | 10% |
| D6 | File Size Balance | 8% |
| D7 | Type Coverage | 8% |
| D8 | Cross-Project Coherence | 8% |
| D9 | Docs Freshness | 10% |
| D10 | Tech Accuracy | 8% |

Grade: A (9-10) | B (7-8.9) | C (5-6.9) | D (3-4.9) | F (<3)

For scoring thresholds, formulas, dashboard template, and edge cases, read `${SKILL_DIR}/references/health-scoring.md`

## Timestamp Standard (NON-NEGOTIABLE)

ALL dream output uses the full timestamp with hour:minutes.

| Context | Format | Example |
|---------|--------|---------|
| Dream report header | `YYYY-MM-DD HH:MM TZ` | `2026-03-25 17:38 EDT` |
| Phase output | HH:MM in each section | `Phase 1 completed at 17:40 EDT` |
| dream-history.jsonl | ISO 8601 | `"timestamp": "2026-03-25T17:38:00-04:00"` |
| Session journal entries | `YYYY-MM-DD HH:MM TZ` | Full, never date alone |
| Memory file footers | `Updated: YYYY-MM-DD HH:MM TZ` | `Updated: 2026-03-25 17:38 EDT` |
| Trend display | `YYYY-MM-DD HH:MM` | With delta in minutes/hours |

Rule: If timestamp not available, run `date '+%Y-%m-%d %H:%M %Z'` via Bash.
Rule: NEVER just the date without the time. Minimum = `YYYY-MM-DD HH:MM`.
