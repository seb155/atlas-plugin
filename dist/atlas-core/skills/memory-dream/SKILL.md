---
name: memory-dream
description: "Memory consolidation engine v6 (CC auto-dream pattern). 16-phase cycle: orient, docs audit, gather, validate, replay analysis, experiential, workflow, learning velocity, gap detection, consolidate, session journal, experiential synthesis, propose improvements, prune (17D health), dream quality metrics, auto-schedule, reflection, cross-project. 9 memory types. Use when 'dream', 'consolidate memory', 'clean memory', 'memory audit', 'memory health', 'episode', 'intuition', 'relationship', 'reflection', 'experiential', 'dream report', 'dream health', 'dream trends', 'dream journal', 'dream status', 'tech state'."
effort: high
---

# Memory Dream v6 — Self-Improving Consolidation Engine

> Implements CC's auto-dream pattern: a 16-phase memory consolidation cycle inspired by
> sleep-time compute (UC Berkeley + Letta, 2025) and cognitive architectures (ACT-R/SOAR).
> v6 adds **4 cognitive phases**: replay analysis (2.9), gap detection (2.10),
> improvement proposals (4.7), auto-scheduling (4.8), and dream quality metrics (4.9).
> The self-improvement loop: Dream proposes → User approves → System implements → Dream validates.
> v5.5 added learning velocity audit (Phase 2.8).
> v5 added workflow audit (Phase 2.7).
> v4 added the experiential layer: 5 new memory types, inference-first capture, growth trajectory.
> Scope: memory + handoffs + docs + plans + features + plugin state + experiential + workflow + replay.

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
| `/atlas dream --deep` | 1-5 + 4.6 | ~20 min | Full intelligence: validate + self-model update + cross-project |
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
| `/atlas dream --full` | ALL phases + 4.6 | ~25 min | Complete cycle including experiential + self-model update |
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

## Phase 2.7 — Workflow Audit (NEW, v5)

> Runs with `--deep`, `--experiential`, or `--full`. Tracks skill effectiveness and workflow patterns.

### Steps

1. **Skill usage tracking**: Scan the current session's conversation for skill invocations.
   Count how many times each skill was triggered, which completed successfully, which errored.
   ```bash
   # Skills invoked this session (from session transcript if available)
   # Alternatively, check session-log for skill mentions
   grep -c "Skill(" "$TRANSCRIPT_FILE" 2>/dev/null || echo "0"
   ```

2. **Timing estimation**: For each skill invocation, estimate duration from surrounding timestamps.
   Flag skills that took >5 minutes (potential optimization targets).

3. **Error tracking**: Count tool call failures, permission denials, and retries.
   Group by skill/hook to identify problematic patterns.

4. **Unused skill detection**: Compare installed skills (from plugin cache) with skills actually invoked in last 7 days (from session logs). Flag skills never used in 30+ days.

5. **Output**:
   ```
   Phase 2.7 — Workflow Audit
   +-------------------+-------+--------+--------+---------+
   | Skill             | Uses  | Errors | Avg ms | Status  |
   +-------------------+-------+--------+--------+---------+
   | plan-builder      | 3     | 0      | ~120s  | OK      |
   | tdd               | 5     | 1      | ~90s   | OK      |
   | browser-automation| 0     | 0      | —      | UNUSED  |
   +-------------------+-------+--------+--------+---------+
   Unused skills (30d+): browser-automation, experiment-loop
   Suggested: consider uninstalling atlas-frontend if not needed
   ```

## Phase 2.8 — Learning Velocity Audit (NEW, v5.5)

> Runs with `--deep` or `--full`. Measures learning rate from feedback and bias corrections.

### Steps

1. **New feedback detection**: Count `feedback_*.md` files created in last 30 days.
   ```bash
   NEW_FB=$(find "$MEMORY_DIR" -name "feedback_*.md" -mtime -30 2>/dev/null | wc -l)
   NEW_CONSOL=$(find "$MEMORY_DIR" -name "feedback-*.md" -mtime -30 2>/dev/null | wc -l)
   TOTAL_NEW=$((NEW_FB + NEW_CONSOL))
   ```

2. **Bias correction tracking**: Read `self-model.md` Known Biases section. Compare correction counts with previous dream report. Count increments.
   ```bash
   # Extract current bias counts from self-model.md
   grep -A1 "corrections" "$MEMORY_DIR/self-model.md" 2>/dev/null
   ```

3. **Feedback confidence audit**: Count feedback files WITH vs WITHOUT `confidence:` frontmatter field.
   ```bash
   TOTAL_FB=$(find "$MEMORY_DIR" -name "feedback*.md" 2>/dev/null | wc -l)
   SCORED_FB=$(grep -rl "^confidence:" "$MEMORY_DIR"/feedback*.md 2>/dev/null | wc -l)
   ```

4. **Regression detection**: Check if any bias from self-model.md has been triggered 3+ times since last dream.

5. **Output**:
   ```
   Phase 2.8 — Learning Velocity Audit
   +---------------------------+-------+--------+--------+
   | Metric                    | Count | Target | Status |
   +---------------------------+-------+--------+--------+
   | New feedback (30d)        | {N}   | 2+     | OK/LOW |
   | Bias corrections          | {N}   | 1+     | OK/LOW |
   | Confidence scored (%)     | {N}%  | 50%+   | OK/GAP |
   | Regressions               | {N}   | 0      | OK/WARN|
   +---------------------------+-------+--------+--------+
   D17 Score: {N}/10
   ```

## Phase 2.9 — Replay Analysis (NEW, v6)

> Runs with `--deep` or `--full`. Parses session-replay.jsonl to detect workflow patterns.
> SP-EVOLUTION P8.1 — Foundation for workflow learning.

### Prerequisites
- `~/.claude/session-replay.jsonl` must exist (populated by session hooks or `atlas replay`)
- At least 50 events for meaningful pattern extraction

### Steps

1. **Load replay data**: Read `session-replay.jsonl`. Parse tool names, timestamps, task context.
   ```bash
   REPLAY_FILE="${HOME}/.claude/session-replay.jsonl"
   [ -f "$REPLAY_FILE" ] || { echo "No replay data. Run sessions first."; return; }
   EVENT_COUNT=$(wc -l < "$REPLAY_FILE")
   ```

2. **Extract tool sequences**: Find recurring tool call patterns (bigrams/trigrams).
   - Common sequences: `Read → Edit → Bash(test)`, `Grep → Read → Edit`
   - Detect "anti-patterns": `Edit → Edit → Edit` (thrashing without verification)

3. **Skill usage frequency**: Count which skills are invoked, measure time-between-invocations.
   - Identify unused skills (installed but never triggered in 30+ days)
   - Identify over-relied skills (>50% of invocations)

4. **Session flow templates**: Extract typical session shapes:
   - "explore → plan → implement → verify" (healthy)
   - "implement → fix → fix → fix" (debugging spiral)
   - "plan → plan → plan" (planning paralysis)

5. **Output**:
   ```
   Phase 2.9 — Replay Analysis
   Events: {N} | Sessions: {N} | Span: {days}d
   
   Top tool sequences:
     Read → Edit → Bash(test)     42 occurrences (healthy TDD)
     Grep → Read → Grep → Read    18 occurrences (exploration)
     Edit → Edit → Edit           7 occurrences (⚠️ thrashing)
   
   Skill usage (30d):
     systematic-debugging  28 invocations  ██████████
     plan-builder          14 invocations  █████
     tdd                    3 invocations  █ (underused?)
   
   Session shapes:
     Explore→Plan→Implement  45% (healthy)
     Fix→Fix→Fix             25% (⚠️ debug spiral)
     Plan→Plan               15% (consider implementing)
   ```

## Phase 2.10 — Knowledge Gap Detection (NEW, v6)

> Runs with `--deep` or `--full`. Cross-references skills used vs. outcomes achieved.
> SP-EVOLUTION P8.2 + P8.6 — Identifies blind spots and unresolved topics.

### Steps

1. **Skill outcome tracking**: For each skill invocation, check if it led to a task completion.
   - Parse `agent-stats.jsonl` for dispatch outcomes (success/fail per model).
   - Parse `session-state.json` history for task completion rates.

2. **Unresolved topic detection**: Search memory for topics that appear in 3+ handoffs but have no corresponding completed plan.
   - Pattern: topic mentioned in handoff "remaining" sections repeatedly.
   - Flag: "This topic has been deferred 3x. Escalate or archive."

3. **Skill gap analysis**: Compare skills available (from plugin manifest) vs skills actually used.
   - Unused skills → suggest removal or training
   - Failed skills → suggest investigation or alternative

4. **Cross-session pattern merge**: When multiple session-state.json files exist (from worktrees/tmux):
   - Aggregate completion rates across sessions
   - Identify tasks that stall across multiple sessions

5. **Output**:
   ```
   Phase 2.10 — Knowledge Gap Detection
   
   Unresolved topics (deferred 3+ times):
     ⚠️ "Telegram notifications" — deferred in 4 handoffs (network blocker)
     ⚠️ "SP-COGNITION P2" — mentioned 3x, never started
   
   Skill gaps:
     📊 tdd: installed but used 3x in 30d (target: every implementation)
     📊 security-audit: 0 invocations (last audit: 26d ago)
   
   Model success rates (from dispatch):
     Haiku: 91% (89 tasks) | Sonnet: 94% (147 tasks) | Opus: 96% (23 tasks)
   
   Cross-session stalls:
     ❌ "Fix Caddy→VM560" — attempted in 3 sessions, unresolved
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

## Phase 3.9 — Active Forgetting: Retention Tier Scan (NEW, P3-COG-5)

> Runs during every dream cycle. Scans memory files for retention tier compliance.
> See `${SKILL_DIR}/references/retention-tiers.md` for full tier definitions.

### Steps

- **H28 — Tier classification**: For each memory file, determine retention tier:
  1. Check explicit `retention_tier:` in frontmatter → use if present
  2. Infer from `type:` field (feedback→0, user→0, reference→0, project→1)
  3. Infer from filename pattern (handoff-*→2, episode-*→2, debug-*→3)
  4. Default: Tier 2 (medium-term, 60 days)

- **H29 — Expiry scan**: Compare file age (from modification time) against tier TTL:
  - Tier 0: skip (permanent)
  - Tier 1 (180d): warn at 150d, propose archive at 180d
  - Tier 2 (60d): warn at 45d, propose archive at 60d
  - Tier 3 (14d): warn at 10d, auto-archive at 14d

- **H30 — Archive proposal**: For each expired file, present via AskUserQuestion:
  - "Archive {filename}? (Tier {N}, {age} days old, TTL={ttl}d)"
  - Options: Archive / Keep (extend TTL) / Promote (change tier)
  - Tier 3 files: auto-archive without asking (report in summary)

- **H31 — Archive execution**: For approved archives:
  1. Extract key facts (first 5 lines after frontmatter)
  2. Append summary to `archive-expired-{year}-{month}.md`
  3. Remove original file
  4. Update MEMORY.md index (remove entry)
  5. Log to dream report

- **H32 — Retention health metric (D18)**: Compute retention health score:
  ```
  D18 = (files_within_ttl / total_tier_1_2_3_files) × 10
  ```
  Include in dream health scoring table.

### Scan Command (outside Dream)

```bash
# Quick scan without archiving
python3 -c "
import os, re, json
from datetime import datetime, timedelta
from pathlib import Path

MEMORY_DIR = Path('$MEMORY_DIR')
TIER_TTL = {0: float('inf'), 1: 180, 2: 60, 3: 14}
TYPE_TIER = {'feedback': 0, 'user': 0, 'reference': 0, 'project': 1}
NAME_TIER_0 = ['feedback_', 'feedback-', 'user_', 'relationship_', 'self-model', 'MEMORY', 'lessons']
NAME_TIER_2 = ['handoff-', 'episode-', 'checkpoint-', 'session-', 'dream-report-', 'archive-']
NAME_TIER_3 = ['debug-', 'temp-', 'scratch-', 'experiment-']

now = datetime.now()
results = {'fresh': 0, 'warning': 0, 'expired': 0, 'permanent': 0}

for f in MEMORY_DIR.glob('*.md'):
    if f.name == 'MEMORY.md': continue
    # Read frontmatter
    content = f.read_text()
    tier = 2  # default
    fm = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
    if fm:
        if m := re.search(r'retention_tier:\s*(\d)', fm.group(1)):
            tier = int(m.group(1))
        elif m := re.search(r'type:\s*(\w+)', fm.group(1)):
            tier = TYPE_TIER.get(m.group(1), 2)
    # Filename override
    for pat in NAME_TIER_0:
        if f.name.startswith(pat): tier = 0; break
    if tier != 0:
        for pat in NAME_TIER_3:
            if f.name.startswith(pat): tier = 3; break
        for pat in NAME_TIER_2:
            if f.name.startswith(pat): tier = 2; break

    if tier == 0:
        results['permanent'] += 1
        continue

    age = (now - datetime.fromtimestamp(f.stat().st_mtime)).days
    ttl = TIER_TTL[tier]
    if age > ttl:
        results['expired'] += 1
        print(f'  EXPIRED T{tier}: {f.name} ({age}d > {ttl}d)')
    elif age > ttl * 0.75:
        results['warning'] += 1
        print(f'  WARNING T{tier}: {f.name} ({age}d, TTL={ttl}d)')
    else:
        results['fresh'] += 1

total = sum(results.values())
print(f'\nRetention: {results[\"permanent\"]} permanent, {results[\"fresh\"]} fresh, {results[\"warning\"]} warning, {results[\"expired\"]} expired')
"
```

## Phase 3.8 — Cross-Project Memory Reconciliation (NEW, P2-MEM-6)

> Optional. Only runs with `--full` flag. Scans multiple project memory directories for duplicates and inconsistencies.

### Steps

- **H24 — Multi-project scan**: Find all `~/.claude/projects/*/memory/` directories. List projects with memory file counts.
- **H25 — Duplicate detection**: Hash-based comparison of memory files across projects. Flag files with >80% content similarity.
- **H26 — Stale cross-reference check**: If memory file A references file B in another project, verify B still exists and is not stale.
- **H27 — Reconciliation proposals**: For each duplicate pair, propose via AskUserQuestion:
  - Merge (combine unique content into one file, symlink the other)
  - Keep both (mark as "cross-project shared" in MEMORY.md)
  - Archive one (move to archive bundle)

**Trigger condition**: Only runs if 2+ project memory directories exist with 10+ files each.
**Output**: Reconciliation report added to dream report. Cross-project links documented.

**Example reconciliation**:
```
Cross-Project Memory Reconciliation:
  Projects scanned: synapse (197 files), atlas-core (23 files), nexus (8 files)
  Duplicates found: 3
    - feedback_zustand_selectors.md (synapse ↔ nexus) — 92% similar → MERGE
    - git-workflow.md (synapse ↔ atlas-core) — 85% similar → KEEP BOTH
    - deploy-targets.md (synapse ↔ atlas-core) — 88% similar → ARCHIVE atlas-core copy
```

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
4. **Health score computation** (v5.5): Calculate 17 dimensions (10 structural + 5 experiential + 1 workflow + 1 learning), display dashboard.
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
5. **Generate dream report v5.5** (H15): Enriched format with 17D health score, trend, importance distribution, code staleness, ecosystem sources, tech claims table, **experiential context (episodes, energy trends, relationships, intuitions)**, **workflow audit (skill usage, errors, unused)**, **learning velocity audit (new feedback, bias corrections, confidence scoring)**, session journal, handoff context, cross-project summary.
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

## Phase 4.6 — Self-Model Auto-Update (NEW, v5.5)

> Runs with `--deep` or `--full`. Updates self-model.md based on recent feedback and session data.

### Steps

1. **Read current self-model**: Load `memory/self-model.md`, parse Known Biases section.

2. **Scan recent feedback**: Find feedback files modified since last dream cycle.
   ```bash
   LAST_DREAM=$(ls -t "$MEMORY_DIR"/dream-report-*.md 2>/dev/null | head -1)
   LAST_DATE=$(stat -c %Y "$LAST_DREAM" 2>/dev/null || echo 0)
   NEW_FEEDBACK=$(find "$MEMORY_DIR" -name "feedback*.md" -newer "$LAST_DREAM" 2>/dev/null)
   ```

3. **Detect new biases**: For each new feedback file, check if the behavior is already in Known Biases.
   - If YES: increment correction count
   - If NO: propose adding as new bias (HITL gate H25)

4. **Update Known Biases**: For each bias with incremented count:
   - If count reaches 3+: ensure marked as HIGH priority
   - If count was 3+ and no new occurrence in 30d: consider for demotion

5. **Review Ranked Values**: Check if any new feedback contradicts the current value ranking.
   - Example: if "Speed > Completeness" appears in feedback but current ranking is reversed → flag for review (HITL gate H26)

6. **Update Growth Log**: Append entry with date, changes made, trigger feedback files.

7. **HITL gate H25**: Present proposed changes to Known Biases
   Options: "Apply all" / "Review each" / "Skip"

8. **HITL gate H26**: Present value ranking conflicts (if any)
   Options: "Update ranking" / "Keep current" / "Discuss"

9. **Write**: Update self-model.md with approved changes. Add `Updated: YYYY-MM-DD HH:MM TZ` to footer.

## Phase 4.7 — Improvement Proposal Engine (NEW, v6)

> Runs with `--deep` or `--full`. Aggregates insights from all phases → generates concrete proposals.
> SP-EVOLUTION P8.3 + P8.8 — The self-improvement loop.

### Steps

1. **Collect insights**: Gather findings from Phases 2.9 (replay), 2.10 (gaps), 2.8 (velocity), 2.7 (workflow).

2. **Generate proposals**: For each finding, propose a concrete action:
   - Unused skill → "Remove skill X or create onboarding example"
   - Debug spiral pattern → "Add pre-debug checklist to systematic-debugging skill"
   - High Haiku failure rate → "Increase complexity threshold for Haiku dispatch"
   - Deferred topic → "Create plan for X or explicitly archive with rationale"

3. **Prioritize**: Score proposals by:
   - **Impact** (1-5): How much does this improve workflow?
   - **Effort** (1-5): How hard to implement?
   - **Urgency** (1-5): Is this blocking other work?
   - **Score** = Impact × Urgency / Effort

4. **Track proposal lifecycle**:
   - Write proposals to `~/.claude/dream-proposals.jsonl`
   - Format: `{"date":"...","proposal":"...","type":"skill|hook|config|plan","impact":N,"effort":N,"status":"proposed|accepted|implemented|rejected"}`
   - When a proposal matches a subsequent commit or skill change → auto-mark as "implemented"

5. **Feedback loop closure** (P8.8): Compare previous proposals with current state:
   - Read `dream-proposals.jsonl`, find "accepted" proposals
   - Check if corresponding changes exist (grep for keywords in recent commits/files)
   - Mark as "implemented" if evidence found, or "stale" if >30d without progress

6. **Output** (HITL gate — user approves/rejects each):
   ```
   Phase 4.7 — Improvement Proposals
   
   🏆 Top 3 proposals (by score):
   
   1. [Score: 8.3] Add TDD guard hook
      Type: hook | Impact: 5 | Effort: 3 | Urgency: 5
      Why: Only 3 TDD invocations in 30d despite 47 implementation tasks
      Action: Create hook that warns when implementing without test file open
   
   2. [Score: 5.0] Archive SP-COGNITION P2
      Type: plan | Impact: 3 | Effort: 1 | Urgency: 5
      Why: Deferred in 3 consecutive handoffs. No progress path visible.
      Action: Move to archive/deferred/ with explicit rationale
   
   3. [Score: 4.2] Upgrade Haiku dispatch threshold
      Type: config | Impact: 3 | Effort: 2 | Urgency: 4
      Why: Haiku fails 9% of tasks. Increasing threshold from score≤2 to score≤1 reduces failures.
      Action: Edit task-complexity.sh line 78: change `<= 2` to `<= 1`
   
   Previously proposed: 5 | Implemented: 3 | Stale: 1 | Rejected: 1
   ```

## Phase 4.8 — Auto-Schedule Next Dream (NEW, v6)

> SP-EVOLUTION P8.5 — Auto-schedule next dream based on activity volume.

### Steps

1. **Measure activity since last dream**: Count events in session-replay.jsonl since last dream-report date.
   ```bash
   LAST_DREAM=$(ls -t "$MEMORY_DIR"/dream-report-*.md 2>/dev/null | head -1)
   LAST_DATE=$(stat -c %Y "$LAST_DREAM" 2>/dev/null || echo 0)
   ```

2. **Determine schedule**:
   - High activity (>200 events/week): Schedule dream in 3 days
   - Medium activity (50-200 events/week): Schedule dream in 7 days
   - Low activity (<50 events/week): Schedule dream in 14 days

3. **Schedule via CronCreate** (if in interactive session):
   ```
   Suggest: "Schedule next dream for {date}?"
   If approved: CronCreate with prompt "/atlas dream --deep"
   ```

4. **Output**:
   ```
   Phase 4.8 — Auto-Schedule
   Activity: {N} events in last {N}d (HIGH/MEDIUM/LOW)
   Recommendation: Next dream in {N} days ({date})
   ```

## Phase 4.9 — Dream Quality Metrics (NEW, v6)

> SP-EVOLUTION P8.7 — Quantify dream effectiveness.

### Steps

1. **Pre/post metrics**: Compare state before and after consolidation:
   - Memory file count (before → after)
   - Total MEMORY.md lines (before → after)
   - Orphan files removed
   - Stale entries corrected
   - Proposals generated

2. **Track in history**: Append to `~/.claude/dream-history.jsonl`:
   ```json
   {"date":"2026-04-05","version":"v6","memory_before":195,"memory_after":192,"orphans_removed":3,"stale_fixed":2,"proposals":5,"duration_min":20,"health_score":78}
   ```

3. **Quality indicators**:
   - **Compression ratio**: bytes saved / total bytes before
   - **Freshness lift**: avg age_days reduction
   - **Accuracy**: % of status claims verified as correct (from Phase 2.5)

4. **Output**:
   ```
   Phase 4.9 — Dream Quality Metrics
   ┌─────────────────────┬────────┬────────┐
   │ Metric              │ Before │ After  │
   ├─────────────────────┼────────┼────────┤
   │ Memory files        │ 197    │ 194    │
   │ MEMORY.md lines     │ 198    │ 185    │
   │ Orphan files        │ 5      │ 0      │
   │ Stale entries       │ 3      │ 0      │
   │ Proposals generated │ —      │ 5      │
   │ Health score        │ 72/100 │ 85/100 │
   └─────────────────────┴────────┴────────┘
   Dream effectiveness: +13 health points, 3 files archived
   ```

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

## Learning Verbosity Configuration

Configure how actively the system communicates its learning:

| Level | Name | Behavior |
|-------|------|----------|
| 1 | Silent | Zero injections. Dream reports only. Auto-learn still captures in background. |
| 2 | Semi (DEFAULT) | Max 2 injections per session: energy alerts, topic context. Episode suggested at end. |
| 3 | Full | Every detection injected: energy, mood, confidence, patterns, skill suggestions. |

**Setting**: `atlas_learning_verbosity` in `~/.claude/settings.json` env block:
```json
{
  "env": {
    "ATLAS_LEARNING_VERBOSITY": "2"
  }
}
```

**Affects**:
- session-start: topic context injection (level 2+)
- focus-guard: context-switch alerts (level 2+)
- experiential-capture: episode suggestion (level 2+)
- auto-learn: signal capture always runs (all levels)
- dream cycle: always runs fully (all levels)

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
| **H25** | **4.6** | **New bias addition to Known Biases** | **Yes (--deep/--full)** |
| **H26** | **4.6** | **Value ranking conflict resolution** | **Yes (--deep/--full)** |

## Model Strategy

| Phase | Model | Reason |
|-------|-------|--------|
| Phase 1 (Orient) | Sonnet | Simple scan, count |
| Phase 1.5 (Docs Audit) | Sonnet | File existence, staleness, version check |
| Phase 2 (Gather) | Sonnet | Pattern matching, scoring |
| Phase 2.5 (Validate) | Opus | Code understanding, semantic verification |
| Phase 2.6 (Experiential Audit) | Sonnet | File counting, date comparison |
| Phase 2.7 (Workflow Audit) | Sonnet | Skill counting, log scanning |
| Phase 2.8 (Learning Velocity Audit) | Sonnet | Feedback counting, bias diff |
| Phase 3 (Consolidate) | Opus | Merge decisions, split strategy |
| Phase 3.5 (Journal) | Opus | Session synthesis, handoff reasoning |
| Phase 3.7 (Experiential Synthesis) | Opus | Pattern recognition, growth analysis |
| Phase 4 (Prune & Index) | Opus | Index design, report synthesis, 16D scoring |
| Phase 4.5 (Reflection Generator) | Opus | Narrative synthesis, trend analysis |
| Phase 4.6 (Self-Model Auto-Update) | Opus | Self-model decisions need deep reasoning |
| Phase 5 (Cross-Project) | Opus | Cross-repo reasoning |

## Health Scoring (17 Dimensions)

Health is a weighted composite score (0-10) across 17 dimensions (normalized to 100%):

| # | Dimension | Weight |
|---|-----------|--------|
| D1 | Index Capacity | 10% |
| D2 | Orphan Rate | 10% |
| D3 | Staleness | 8% |
| D4 | Referential Integrity | 10% |
| D5 | Content Freshness | 5% |
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
| **D16** | **Workflow Efficiency** | **3%** |
| **D17** | **Learning Velocity** | **5%** |

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
