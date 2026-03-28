---
name: memory-dream
description: "Memory consolidation engine v4 (CC auto-dream pattern). 11-phase cycle with experiential layer: orient, docs audit, gather signal, validate, experiential audit, consolidate, session journal, experiential synthesis, prune & index (15D health), reflection generator, cross-project. 9 memory types (user, feedback, project, reference + episode, intuition, reflection, relationship, temporal). Use when 'dream', 'consolidate memory', 'clean memory', 'memory audit', 'memory health', 'episode', 'intuition', 'relationship', 'reflection', 'experiential', 'dream report', 'dream health', 'dream trends', 'dream journal', 'dream status', 'tech state'."
effort: high
---

# Memory Dream v4 — Whole-Person Consolidation Engine

> Implements CC's auto-dream pattern: an 11-phase memory consolidation cycle inspired by
> sleep-time compute (UC Berkeley + Letta, 2025) and cognitive architectures (ACT-R/SOAR).
> v4 adds the **experiential layer**: 5 new memory types (episode, intuition, reflection,
> relationship, temporal), 15-dimension health scoring, inference-first capture, and
> growth trajectory tracking. From technical vault to whole-person memory.
> Scope: memory + handoffs + docs + plans + features + plugin state + experiential context.

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
| `/atlas dream --experiential` | 1+2+2.6+3.7 | ~10 min | Experiential audit + synthesis |
| `/atlas dream --reflection` | 1+2+4.5 | ~5 min | Generate monthly reflection |
| `/atlas dream --full` | ALL 11 phases | ~25 min | Complete cycle including experiential |
| `/atlas dream --topic {name}` | topic consolidation | ~3 min | Consolidate topic memory into summary |
| `/atlas episode create` | standalone | ~3 min | Create episode file for current session |
| `/atlas intuition log` | standalone | ~2 min | Capture a gut feeling or emerging pattern |
| `/atlas relationship {person}` | standalone | ~3 min | Create/update relationship file |

### Progressive Disclosure Tiers

| Tier | Invocation | Phases Run | Writes? |
|------|------------|------------|---------|
| Report | `dream report`, `dream health`, `dream trends`, `dream status` | Read-only subset | No |
| Standard | `dream`, `dream --docs`, `dream --handoffs`, `dream journal`, `dream --topic` | 1 through 4 (subset varies) | Yes (HITL) |
| Experiential | `dream --experiential`, `dream --reflection`, `episode create`, `intuition log`, `relationship` | 1+2.6+3.7 or standalone | Yes (HITL) |
| Deep | `dream --deep`, `dream --full`, `dream --validate`, `dream --cross-project` | 1 through 5 (all phases) | Yes (HITL) |

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

## Phase 2.6 — Experiential Audit (NEW, v4)

> Requires `--deep`, `--experiential`, or `--full`. Assesses experiential coverage gaps.

For details, read `${SKILL_DIR}/references/experiential-schema.md`

### Steps

1. **Episode coverage check**: Count `type: episode` files created in last 14 days. Compare with session-log.md entries. Gap = sessions without episode files. Target: 50% coverage.
   ```bash
   MEMORY_DIR=...
   SESSION_COUNT=$(grep -c "^📅" "$MEMORY_DIR/session-log.md" 2>/dev/null || echo "0")
   EPISODE_COUNT=$(find "$MEMORY_DIR" -name "episode-*.md" -mtime -14 2>/dev/null | wc -l)
   COVERAGE=$((EPISODE_COUNT * 100 / (SESSION_COUNT > 0 ? SESSION_COUNT : 1)))
   ```

2. **Relationship freshness**: For each `type: relationship` file, check `last_interaction` field. Flag if >30 days for active team members.
   ```bash
   for f in "$MEMORY_DIR"/relationship-*.md; do
     last=$(grep "^last_interaction:" "$f" 2>/dev/null | awk '{print $2}')
     days_old=$(( ($(date +%s) - $(date -d "$last" +%s 2>/dev/null || echo 0)) / 86400 ))
     [ $days_old -gt 30 ] && echo "STALE: $(basename $f) — $days_old days"
   done
   ```

3. **Temporal validity expiry**: Scan `valid_until` fields across all memory files. Flag facts past their validity window.
   ```bash
   grep -rl "^valid_until:" "$MEMORY_DIR"/*.md 2>/dev/null | while read f; do
     until_date=$(grep "^valid_until:" "$f" | awk '{print $2}')
     [ "$(date -d "$until_date" +%s 2>/dev/null)" -lt "$(date +%s)" ] && echo "EXPIRED: $(basename $f)"
   done
   ```

4. **Intuition validation backlog**: Count `type: intuition` files where `validated: false` and older than 30 days.
5. **Experiential field coverage**: Across ALL files, count how many have `energy:`, `mood:`, `confidence:`, `time_quality:` fields. Report percentage.

### Output

```
Phase 2.6 — Experiential Audit
+---------------------------+-------+--------+--------+
| Dimension                 | Count | Target | Status |
+---------------------------+-------+--------+--------+
| Episodes (last 14d)       | {N}   | 50%+   | OK/GAP |
| Relationships (active)    | {N}   | 3+     | OK/GAP |
| Temporal facts (expired)  | {N}   | 0      | OK/STALE|
| Intuitions (unvalidated)  | {N}   | N/A    | OK     |
| Energy coverage (%)       | {N}%  | 30%+   | OK/LOW |
+---------------------------+-------+--------+--------+
```

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

## Phase 3.7 — Experiential Synthesis (NEW, v4)

> Requires `--deep`, `--experiential`, or `--full`. Synthesizes patterns from experiential data.

For details, read `${SKILL_DIR}/references/experiential-synthesis.md`

### Steps

- **H19 — Energy pattern detection**: Analyze `energy:` fields across recent episodes. Detect trends ("Energy consistently low on Fridays", "Peak energy during infrastructure work"). Present patterns for confirmation.
- **H20 — Productivity cycle mapping**: Cross-reference `time_quality:` and `flow_state:` with session outcomes. Surface patterns ("Deep work sessions = 3x more decisions").
- **H21 — Intuition log generation**: When multiple episodes share similar observations not yet captured as intuition files, propose creating one.
- **H22 — Relationship depth check**: For relationship files not updated in 30+ days but where the person appears in recent sessions, propose update.
- **H23 — Growth trajectory snapshot**: Compare this month's experiential data with previous month. Track average energy, flow frequency, decision confidence trend, blocker frequency.

**Output**: Patterns persisted to `patterns-experiential.md` (HITL on each pattern).

## Phase 4 — Prune & Index (Enhanced)

Regenerate MEMORY.md and compute health.

### Steps

1. **Generate proposed MEMORY.md**: Group by category, tables for compact representation, 200-line hard limit (180-line soft target).
2. **Show proposed structure** via AskUserQuestion (H14): "Write as-is" / "Adjust" / "Cancel".
3. **Write MEMORY.md** if approved.
3b. **Topics INDEX generation** (if `.claude/topics/` exists):
   ```bash
   TOPICS_DIR=".claude/topics"
   if [ -d "$TOPICS_DIR" ]; then
     # Generate INDEX.md
     echo "# Topic Memory Index" > "$TOPICS_DIR/INDEX.md"
     echo "" >> "$TOPICS_DIR/INDEX.md"
     echo "| Topic | Status | Created | Decisions | Sessions | Summary |" >> "$TOPICS_DIR/INDEX.md"
     echo "|-------|--------|---------|-----------|----------|---------|" >> "$TOPICS_DIR/INDEX.md"

     for topic_dir in "$TOPICS_DIR"/*/; do
       [ -d "$topic_dir" ] || continue
       topic_name=$(basename "$topic_dir")
       decisions=$(grep -c "^## Decision:" "$topic_dir/decisions.md" 2>/dev/null || echo "0")
       sessions=$(ls "$topic_dir/handoffs/" 2>/dev/null | wc -l)
       has_summary=$([ -f "$topic_dir/topic-summary.md" ] && echo "yes" || echo "—")
       # Get status from topics.json
       status=$(python3 -c "import json,os; t=json.load(open(os.path.expanduser('~/.atlas/topics.json'))); print(t.get('$topic_name',{}).get('status','?'))" 2>/dev/null || echo "?")
       created=$(python3 -c "import json,os; t=json.load(open(os.path.expanduser('~/.atlas/topics.json'))); print(t.get('$topic_name',{}).get('created','?')[:10])" 2>/dev/null || echo "?")
       echo "| $topic_name | $status | $created | $decisions | $sessions | $has_summary |" >> "$TOPICS_DIR/INDEX.md"
     done
   fi
   ```
4. **Health score computation** (v4): Calculate 15 dimensions (10 structural + 5 experiential), display dashboard.
   For details, read `${SKILL_DIR}/references/health-scoring.md`

   D1-D10 computed per existing health-scoring.md. D11-D15 (experiential):
   ```bash
   # D11: Experiential Coverage (5%)
   SESSION_COUNT=$(grep -c "^📅" "$MEMORY_DIR/session-log.md" 2>/dev/null || echo "0")
   EPISODE_COUNT=$(find "$MEMORY_DIR" -name "episode-*.md" -mtime -30 | wc -l)
   # Score: 10 if 80%+, 8 if 60-79%, 6 if 40-59%, 4 if 20-39%, 2 if <20%

   # D12: Relational Depth (4%)
   REL_COUNT=$(find "$MEMORY_DIR" -name "relationship-*.md" | wc -l)
   REL_FRESH=$(find "$MEMORY_DIR" -name "relationship-*.md" -exec grep -l "last_interaction: $(date +%Y)" {} \; | wc -l)
   # Score: 10 if 3+ relationships AND >50% fresh, scale down proportionally

   # D13: Temporal Validity (5%)
   TOTAL_TEMPORAL=$(grep -rl "valid_until:" "$MEMORY_DIR"/*.md 2>/dev/null | wc -l)
   EXPIRED=$(grep -rl "valid_until:" "$MEMORY_DIR"/*.md 2>/dev/null | while read f; do
     d=$(grep "^valid_until:" "$f" | awk '{print $2}')
     [ "$(date -d "$d" +%s 2>/dev/null)" -lt "$(date +%s)" ] && echo "$f"
   done | wc -l)
   # Score: 10 if 0 expired, -2 per expired fact (min 0)

   # D14: Intuition Quality (3%)
   INTUITION_COUNT=$(find "$MEMORY_DIR" -name "intuition-*.md" | wc -l)
   STALE_INTUITIONS=$(find "$MEMORY_DIR" -name "intuition-*.md" -mtime +60 | wc -l)
   # Score: 10 if 3+ intuitions AND <30% stale, scale down proportionally

   # D15: Growth Trajectory (3%)
   # Read last 3 dream-history.jsonl entries, compute energy/flow/confidence trends
   # Score: 10 if all rising, 7 if stable, 4 if declining, 2 if no data
   ```
5. **Generate dream report v4** (H15): Enriched format with 15D health score, trend, importance distribution, code staleness, ecosystem sources, tech claims table, **experiential context (episodes, energy trends, relationships, intuitions)**, session journal, handoff context, cross-project summary.
   For details, read `${SKILL_DIR}/references/dream-report-v2.md`
6. **Trend persistence** (H16): Append one JSON line to `dream-history.jsonl`.
7. **Release lock**: Remove `.consolidate-lock`.

## Phase 4.5 — Reflection Generator (NEW, v4)

> Requires `--reflection` or `--full`. Generates monthly/sprint reflection from experiential data.

For details, read `${SKILL_DIR}/references/reflection-template.md`

### Steps

1. Read all `type: episode` files from current month/sprint period
2. Read all `type: intuition` files (validated and unvalidated)
3. Read growth trajectory from `dream-history.jsonl` (last 3-5 entries)
4. Read recent decisions from `.claude/decisions.jsonl`
5. Synthesize into reflection using `${SKILL_DIR}/references/reflection-template.md`:
   - **Energy Dashboard**: Avg energy, peak/low days, day-of-week heatmap
   - **What Went Well**: Top 3 accomplishments with supporting episode refs
   - **What Was Difficult**: Top 3 blockers/challenges, resolution status
   - **Patterns Observed**: Recurring themes from episodes + intuition files
   - **Intuitions Reviewed**: Validated vs. unvalidated, confidence changes
   - **Decision Confidence Review**: Decisions from `.claude/decisions.jsonl` with hindsight assessment
   - **Sustainability Check**: Work hours trend, energy sustainability, recovery patterns
   - **Strategies for Next Month**: Actionable recommendations based on patterns
6. **HITL gate H24**: Preview reflection, approve/edit/skip
7. Write to `memory/reflection-YYYY-MM.md`

**Frequency**: Max 2 per month. One at sprint end, one at month end.

## Phase 5 — Cross-Project (NEW)

> Requires `--deep` or `--cross-project`. Read-only scan across all project memory directories.

For details, read `${SKILL_DIR}/references/cross-project.md`

### Steps

1. **Discovery**: Find all `MEMORY.md` directories in `~/.claude/projects`.
2. **Entity reconciliation**: Build map of shared entities (VMs, services, repos, IPs, versions).
3. **Contradiction detection**: Same entity with different status/version between projects.
4. **Output**: Cross-project table with file count, health estimate, contradictions.
5. **HITL gate H17**: Resolve each contradiction individually. **NEVER write to other projects' memory directories.**

## Standalone Commands (v4)

> These commands run independently of the dream cycle. They create experiential
> memory files with HITL approval. Schema: `${SKILL_DIR}/references/experiential-schema.md`

### `/atlas episode create`

Create a narrative episode file capturing the current session's experiential context.

For template details, read `${SKILL_DIR}/references/episode-template.md`

#### Steps

1. **Read signals**: Load `~/.claude/atlas-experiential-signals.json` if exists
2. **Read session context**: Scan conversation for tasks completed, files modified, decisions made
3. **Synthesize narrative**: Generate episode using template format (story, NOT task list)
4. **Auto-populate frontmatter**:
   - `energy`: Median of accumulated energy signals (or ask if none)
   - `mood`: Dominant mood signal (or ask if none)
   - `time_quality`: "deep" if flow detected, else infer from signal pattern
   - `confidence`: Average of decision-related confidence signals
   - `flow_state`: true if 2+ "deep focus" signals detected
   - `energy_arc`: Infer from chronological energy signal timestamps
   - `duration_minutes`: Session end - start (from signals timestamps, or estimate)
   - `key_decisions`: Extract from conversation (max 5)
   - `blockers_hit`: Extract from conversation (tool call failures, pivots)
5. **HITL gate**: Present complete episode via AskUserQuestion for review
   Options: "Write as-is" / "Edit" / "Skip"
6. **Write**: Save to `memory/episode-YYYY-MM-DD.md` (or `-2.md` if same day exists)
7. **Cleanup**: Clear `~/.claude/atlas-experiential-signals.json` after successful write
8. **Index**: If MEMORY.md has `## EXPERIENTIAL CONTEXT` section, update episode count. If not, add the section:
   ```markdown
   ## EXPERIENTIAL CONTEXT

   | Type | Count | Latest | Coverage |
   |------|-------|--------|----------|
   | Episodes | {N} | {date} | {%} of sessions |
   | Relationships | {N} | {date} | — |
   | Intuitions | {N} | — | — |
   | Reflections | {N} | {date} | — |
   ```

### `/atlas intuition log`

Capture a gut feeling or emerging pattern as a persistent intuition file.

For template details, read `${SKILL_DIR}/references/intuition-template.md`

#### Steps

1. **Ask the feeling** via AskUserQuestion: "What's the gut feeling or pattern you're noticing?"
   - Free text input (no predefined options for creativity)
2. **Ask supporting observations** via AskUserQuestion: "What observations support this?"
   - Options: user provides 1-3 observations
3. **Ask domain** via AskUserQuestion: "What domain does this relate to?"
   - Options: "Technical" / "Team" / "Strategic" / "Process" / "Product"
4. **Generate file**: Use intuition template with:
   - `confidence`: 0.4-0.5 (initial hunch)
   - `confidence_trend`: "rising" (just created)
   - `validated`: false
   - Auto-generate validation plan based on domain
5. **HITL gate**: Present complete file for review
6. **Write**: Save to `memory/intuition-{topic-slug}.md`
7. **Link**: If related to a recent decision in `.claude/decisions.jsonl`, add cross-reference

### `/atlas relationship {person}`

Create or update a relationship file for a team member or collaborator.

For template details, read `${SKILL_DIR}/references/relationship-template.md`

#### Steps

1. **Check existing**: Look for `memory/relationship-{person-slug}.md`
2. **If exists** (UPDATE mode):
   a. Read current file
   b. Ask what to update via AskUserQuestion: "What's changed?"
      Options: "New interaction" / "Trust level changed" / "New strength observed" / "Update role"
   c. Update relevant sections
   d. Update `last_interaction` date
   e. Add entry to Interaction History table
   f. HITL gate: show diff before writing
3. **If new** (CREATE mode):
   a. Ask role via AskUserQuestion
   b. Ask organization
   c. Ask 2-3 strengths
   d. Ask interaction style
   e. Ask trust level: "Low" / "Medium" / "High"
   f. Generate file from template
   g. HITL gate: preview before write
4. **Reclassification check**: If `memory/team_{person_slug}.md` exists (old format):
   a. Read the old file
   b. Propose via AskUserQuestion: "Found existing team_{person}.md. Migrate to relationship format?"
      Options: "Yes, migrate + archive old" / "Keep both" / "Skip"
   c. If migrate: create relationship file, rename old to `_archived-team_{person}.md`
5. **Write**: Save to `memory/relationship-{person-slug}.md`
6. **Index**: Update MEMORY.md EXPERIENTIAL CONTEXT table

### `/atlas dream --topic {name}`

Consolidate a topic's accumulated memory into a summary. Use when a topic is completed (branch merged) or when topic memory needs cleanup.

#### Steps

1. **Read topic directory**: Check `.claude/topics/{name}/` exists
   ```bash
   TOPIC_DIR=".claude/topics/${name}"
   [ -d "$TOPIC_DIR" ] || { echo "Topic not found: ${name}"; exit 1; }
   ```

2. **Read topic files**:
   - `decisions.md` — all decisions made during this topic
   - `lessons.md` — lessons learned (if exists)
   - `context.md` — last known technical context
   - `handoffs/` — count handoff files (number of sessions)

3. **Generate topic summary**: Synthesize into `topic-summary.md`:
   ```markdown
   # Topic Summary: {name}

   **Project**: {from topics.json}
   **Duration**: {created} to {completed/now}
   **Sessions**: {handoff count}
   **Decisions**: {decision count}

   ## Key Decisions
   {Summarize top 3-5 decisions with rationale}

   ## Lessons Learned
   {Extract from lessons.md or synthesize from decisions}

   ## Technical Outcome
   {From context.md: what was built, which files, which patterns}

   ## What Would I Do Differently
   {Retrospective insight based on decision confidence and outcomes}
   ```

4. **HITL gate**: Present topic-summary.md via AskUserQuestion
   - Options: "Write as-is" / "Edit" / "Skip"

5. **Write**: Save to `.claude/topics/{name}/topic-summary.md`

6. **Update topics.json**: Set status to "archived", add summaryPath
   ```bash
   python3 -c "
   import json, os
   from datetime import datetime
   topics_file = os.path.expanduser('~/.atlas/topics.json')
   with open(topics_file) as f:
       topics = json.load(f)
   if '${name}' in topics:
       topics['${name}']['status'] = 'archived'
       topics['${name}']['archivedAt'] = datetime.now().isoformat()
       topics['${name}']['summaryPath'] = '.claude/topics/${name}/topic-summary.md'
       with open(topics_file, 'w') as f:
           json.dump(topics, f, indent=2)
   "
   ```

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

## HITL Gate Map (23 Gates)

| Gate | Phase | Trigger | Required? |
|------|-------|---------|-----------|
| H1 | 1.5-D3 | Handoff insight to memory sync | Yes (--docs/--deep) |
| H2 | 1.5-D4 | FEATURES.md sync corrections | Yes (--docs/--deep) |
| H3 | 2.5-V2 | Stale status claims update | Yes (--validate/--deep) |
| H4 | 3.1 | Duplicate merge | Yes |
| H5 | 3.2 | Date normalization | Yes |
| H6 | 3.3 | Contradiction resolution | Yes |
| H7 | 3.4 | Orphan categorization | Yes |
| H8 | 3.5 | Frontmatter typing (includes new v4 types) | Yes |
| H9 | 3.6 | Large file split | Yes |
| H10 | 3.7 | Smart pruning batch | Yes |
| H11 | 3.8 | Auto-categorization | Yes |
| H12 | 3.5-J2 | Handoff to memory file creation | Yes |
| H13 | 3.5-J4 | Session journal entry write (v4: +Energy/Mood sections) | Yes |
| H14 | 4.2 | MEMORY.md write | Yes |
| H15 | 4.4 | Dream report write | Yes |
| H16 | 4.5 | Trend data persist | Yes |
| H17 | 5.4 | Cross-project contradiction fixes | Yes (--deep) |
| **H19** | **3.7** | **Energy pattern confirmation** | **Yes (--experiential/--deep)** |
| **H20** | **3.7** | **Productivity cycle confirmation** | **Yes (--experiential/--deep)** |
| **H21** | **3.7** | **Intuition log creation from patterns** | **Yes (--experiential/--deep)** |
| **H22** | **3.7** | **Relationship update proposal** | **Yes (--experiential/--deep)** |
| **H23** | **3.7** | **Growth trajectory snapshot approval** | **Yes (--experiential/--deep)** |
| **H24** | **4.5** | **Reflection file approval** | **Yes (--reflection/--full)** |

## Model Strategy

| Phase | Model | Reason |
|-------|-------|--------|
| Phase 1 (Orient) | Sonnet | Simple scan, count |
| Phase 1.5 (Docs Audit) | Sonnet | File existence, staleness, version check |
| Phase 2 (Gather) | Sonnet | Pattern matching, scoring |
| Phase 2.5 (Validate) | Opus | Code understanding, semantic verification |
| Phase 2.6 (Experiential Audit) | Sonnet | File counting, date comparison |
| Phase 3 (Consolidate) | Opus | Merge decisions, split strategy |
| Phase 3.5 (Journal) | Opus | Session synthesis, handoff reasoning |
| Phase 3.7 (Experiential Synthesis) | Opus | Pattern recognition, growth analysis |
| Phase 4 (Prune & Index) | Opus | Index design, report synthesis, 15D scoring |
| Phase 4.5 (Reflection Generator) | Opus | Narrative synthesis, trend analysis |
| Phase 5 (Cross-Project) | Opus | Cross-repo reasoning |

## Health Scoring (15 Dimensions)

Health is a weighted composite score (0-10) across 10 dimensions:

| # | Dimension | Weight |
|---|-----------|--------|
| D1 | Index Capacity | 10% |
| D2 | Orphan Rate | 10% |
| D3 | Staleness | 10% |
| D4 | Referential Integrity | 10% |
| D5 | Content Freshness | 8% |
| D6 | File Size Balance | 6% |
| D7 | Type Coverage | 6% |
| D8 | Cross-Project Coherence | 6% |
| D9 | Docs Freshness | 8% |
| D10 | Tech Accuracy | 6% |
| **D11** | **Experiential Coverage** | **5%** |
| **D12** | **Relational Depth** | **4%** |
| **D13** | **Temporal Validity** | **5%** |
| **D14** | **Intuition Quality** | **3%** |
| **D15** | **Growth Trajectory** | **3%** |

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
