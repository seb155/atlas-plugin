---
name: memory-dream
description: "Memory consolidation engine v6 (CC auto-dream pattern). 16-phase cycle: orient, docs audit, gather, validate, replay analysis, experiential, workflow, learning velocity, gap detection, consolidate, session journal, experiential synthesis, propose improvements, prune (17D health), dream quality metrics, auto-schedule, reflection, cross-project. 9 memory types. Use when 'dream', 'consolidate memory', 'clean memory', 'memory audit', 'memory health', 'episode', 'intuition', 'relationship', 'reflection', 'experiential', 'dream report', 'dream health', 'dream trends', 'dream journal', 'dream status', 'tech state'."
effort: high
---

# Memory Dream v6 — Self-Improving Consolidation Engine

> CC auto-dream pattern: 16-phase memory consolidation inspired by sleep-time compute (UC Berkeley+Letta, 2025) and ACT-R/SOAR.
> v6 adds 4 cognitive phases: replay (2.9), gap detection (2.10), improvement proposals (4.7), auto-scheduling (4.8), quality metrics (4.9).
> Self-improvement loop: Dream proposes → User approves → System implements → Dream validates.
> Scope: memory + handoffs + docs + plans + features + plugin state + experiential + workflow + replay.

## When to Use

- MEMORY.md > 150 lines, 5+ sessions since last consolidation, end of sprint
- User says "dream", "clean memory", "consolidate", "memory audit", "memory health"
- After receiving handoffs, before fresh planning, suspecting stale status claims

## Subcommands

| Command | Phases | Time | Action |
|---------|--------|------|--------|
| `/atlas dream` | 1-4 | ~10m | Standard 4-phase with HITL |
| `/atlas dream --deep` | 1-5 + 4.6 | ~20m | Full intelligence + self-model + cross-project |
| `/atlas dream --dry-run` | 1-2 | ~2m | Report only, zero writes |
| `/atlas dream report` | 1-2 | ~2m | Staleness + orphan report |
| `/atlas dream --validate` | 1+2.5 | ~5m | Code freshness + status claim check |
| `/atlas dream --cross-project` | 1+5 | ~5m | Multi-repo consistency scan |
| `/atlas dream --docs` | 1+1.5 | ~3m | .blueprint/ + plans/ + handoffs/ audit |
| `/atlas dream --handoffs` | 1+1.5-D3 | ~3m | Ingest recent handoffs as signal |
| `/atlas dream journal` | J1 only | ~2m | Synthesize session into journal entry |
| `/atlas dream --tech` | 1+1.5-D6 | ~5m | Technical state consolidation |
| `/atlas dream --split <file>` | 3.6 only | ~5m | Split wizard for oversized file |
| `/atlas dream health` | Score | ~1m | 17D health dashboard |
| `/atlas dream trends` | History | ~1m | Health over time from dream-history.jsonl |
| `/atlas dream status` | 2+2.5 | ~3m | ACTIVE WORK status claim verification |
| `/atlas dream --schedule` | — | — | Schedule recurring dream via CronCreate |
| `/atlas dream --experiential` | 1+2+2.6+3.7 | ~10m | Experiential audit + synthesis |
| `/atlas dream --reflection` | 1+2+4.5 | ~5m | Monthly reflection |
| `/atlas dream --full` | ALL + 4.6 | ~25m | Complete cycle including experiential + self-model |
| `/atlas dream --topic {name}` | topic | ~3m | Consolidate topic memory into summary |
| `/atlas episode create` | standalone | ~3m | Create episode file for current session |
| `/atlas intuition log` | standalone | ~2m | Capture gut feeling or emerging pattern |
| `/atlas relationship {person}` | standalone | ~3m | Create/update relationship file |

### Progressive Disclosure Tiers

| Tier | Invocation | Writes? |
|------|------------|---------|
| Report | `dream report/health/trends/status` | No |
| Standard | `dream`, `dream --docs/handoffs/journal/topic` | Yes (HITL) |
| Experiential | `dream --experiential/reflection`, `episode/intuition/relationship` | Yes (HITL) |
| Deep | `dream --deep/full/validate/cross-project` | Yes (HITL) |

## Phase 1 — Orient

Scan memory directory, build mental map.

1. **Detect memory directory**:
   ```bash
   MEMORY_DIR=$(find ~/.claude/projects -path "*/memory/MEMORY.md" -printf "%h\n" 2>/dev/null | head -1)
   ```
2. **Read MEMORY.md**: Count lines, extract `## Section` headers.
3. **List topic files**: `ls "$MEMORY_DIR"/*.md | grep -v MEMORY.md | wc -l`
4. **Detect orphans**: Files in dir NOT referenced in MEMORY.md:
   ```bash
   for f in "$MEMORY_DIR"/*.md; do
     base=$(basename "$f"); [ "$base" = "MEMORY.md" ] && continue
     grep -q "$base" "$MEMORY_DIR/MEMORY.md" || echo "ORPHAN: $base"
   done
   ```
5. **File size audit**: `du -k "$MEMORY_DIR"/*.md | awk '$1 > 50 {print "OVERSIZED:", $2, $1"KB"}'`
6. **Cross-project discovery**: `find ~/.claude/projects -name "MEMORY.md" -printf "%h\n"`
7. **Check consolidation lock**: `[ -f "$MEMORY_DIR/.consolidate-lock" ] && echo "LOCKED"`
8. **Output orient summary**: MEMORY.md lines, topic count, orphans, oversized, cross-project dirs, lock, last modified.

## Phase 1.5 — Docs & Ecosystem Audit

> Always with `--deep`. Standalone with `--docs`/`--handoffs`/`--tech`. Details: `${SKILL_DIR}/references/docs-audit.md`

- **D1 .blueprint/ audit**: Count files, verify INDEX.md freshness, stale >30d
- **D2 Plans audit**: List `.blueprint/plans/*.md`, verify links, detect dead refs
- **D3 Handoffs ingestion**: Scan `.blueprint/handoffs/handoff-*.md`, extract decisions/gotchas, compare with lessons.md (**HITL H1**)
- **D4 FEATURES.md sync**: Count by tier, compare with MEMORY.md claims, detect shipped still in ACTIVE WORK (**HITL H2**)
- **D5 ATLAS plugin state**: Compare version, skill/agent/command counts vs memory claims
- **D6 Technical state** (`--tech`): Compare stack versions, Docker, ports, IPs vs live system

Output: Ecosystem Audit table per source (items, stale, status).

## Phase 2 — Gather Signal

Identify what needs attention without changes.

1. **Staleness buckets**: `<7d fresh | 7-14d aging | 14-30d stale | >30d archive candidate`
2. **Feedback audit**: Count `feedback_*.md`, detect near-duplicates (Levenshtein ≤3)
3. **Duplicate detection**: Jaccard similarity >70% on non-feedback pairs
4. **Relative dates**: `grep -rn "yesterday\|last week\|today\|ce matin\|hier" "$MEMORY_DIR"/*.md`
5. **Memory type distribution**: Count by frontmatter `type:`, flag untyped
6. **Importance scoring** (1-5 stars): References 30% + Recency 25% + Size penalty 15% + Type bonus 15% + Active Work link 15%
7. **Status claim scan**: Grep `COMPLETE|LIVE|DONE|SHIPPED` for Phase 2.5 validation
8. **Reference extraction**: URLs, file paths, API endpoints

If `--dry-run` or `report`: STOP HERE, display and exit.

## Phase 2.5 — Validate (HITL H3)

> `--deep`/`--validate`. Details: `${SKILL_DIR}/references/validate-phase.md`

- **V1 Code staleness**: Verify file paths, function/hook names, API endpoints exist
- **V2 Status claim verification**: For each `COMPLETE/LIVE/DONE`, verify via git branch, tests, health endpoint, counts, versions
- **V3 External refs**: File paths (`[ -f ]`), plan refs, URLs (with `--deep`: `curl -sI --max-time 5`)

## Phase 2.6 — Experiential Audit

> `--deep`/`--experiential`/`--full`. Details: `${SKILL_DIR}/references/experiential-schema.md`

1. **Episode coverage**: Count `type: episode` (last 14d) vs session-log.md entries. Target 50%.
2. **Relationship freshness**: Flag `last_interaction` >30d for active members
3. **Temporal validity expiry**: Flag `valid_until` past facts
4. **Intuition backlog**: Count `validated: false` older than 30d
5. **Experiential field coverage**: % with `energy/mood/confidence/time_quality`

Output: Dimension table (Count, Target, Status).

## Phase 2.7 — Workflow Audit

> `--deep`/`--experiential`/`--full`. Tracks skill effectiveness.

1. **Skill usage**: Scan session for invocations (count, success, errors)
2. **Timing**: Flag skills >5min (optimization targets)
3. **Error tracking**: Failures, permission denials, retries grouped by skill/hook
4. **Unused skills**: Compare installed vs invoked in 7d; flag 30+d unused

Output: Skill table (Uses, Errors, Avg ms, Status) + Unused list + Suggestions.

## Phase 2.8 — Learning Velocity Audit

> `--deep`/`--full`. Measures learning rate from feedback and bias corrections.

1. **New feedback (30d)**: Count `feedback_*.md` + `feedback-*.md` files
2. **Bias correction tracking**: Diff `self-model.md` Known Biases counts vs previous dream
3. **Confidence audit**: % feedback with `confidence:` frontmatter
4. **Regression detection**: Bias triggered 3+ times since last dream

Output: Metric table (Count, Target, Status) + D17 score.

## Phase 2.9 — Replay Analysis

> `--deep`/`--full`. Parses `~/.claude/session-replay.jsonl` (need 50+ events). SP-EVOLUTION P8.1.

1. **Load replay**: `[ -f "$REPLAY_FILE" ] || { echo "No replay data"; return; }`
2. **Tool sequences**: Bigrams/trigrams (healthy: `Read→Edit→Bash(test)`, anti: `Edit→Edit→Edit` thrashing)
3. **Skill frequency**: Unused (30+d) vs over-relied (>50%)
4. **Session flow templates**: healthy `explore→plan→implement→verify`, spiral `implement→fix→fix→fix`, paralysis `plan→plan→plan`

Output: Top sequences, skill usage bars, session shape percentages.

## Phase 2.10 — Knowledge Gap Detection

> `--deep`/`--full`. SP-EVOLUTION P8.2+P8.6.

1. **Skill outcome tracking**: Parse `agent-stats.jsonl` dispatch outcomes, `session-state.json` completion rates
2. **Unresolved topics**: Topics in 3+ handoffs with no completed plan (flag for escalation/archive)
3. **Skill gap analysis**: Unused → suggest removal; failed → suggest investigation
4. **Cross-session pattern merge**: Aggregate across worktrees/tmux; identify stalled tasks

Output: Unresolved topics, skill gaps, model success rates, cross-session stalls.

## Phase 3 — Consolidate (HITL Required)

Changes with explicit approval.

1. **Merge duplicates** (H4): Options "Merge into A/B" / "Keep both" / "Skip"
2. **Normalize dates** (H5): Relative → absolute
3. **Flag contradictions** (H6): Opposing statements → pick current truth
4. **Categorize orphans** (H7): Add to MEMORY.md or archive
5. **Type frontmatter** (H8): Suggest based on content
6. **Large file split** (H9): Auto-trigger >50KB. `lessons.md` by domain, `session-log.md` archive >60d entries. Safety: create new BEFORE modifying original. Details: `${SKILL_DIR}/references/large-file-strategy.md`
7. **Smart pruning** (H10): importance ≤1 AND stale >30d → archive. NEVER prune feedback or ACTIVE WORK files.
8. **Auto-categorization** (H11): Sub-types (plan|architecture|status|integration|vision|audit); ACTIVE WORK DONE removal.

## Phase 3.5 — Session Journal & Handoff Synthesis

> Details: `${SKILL_DIR}/references/session-journal.md`

- **J1 Journal entry** (H13): Synthesize conversation into What Went Well / Blocked / Decisions / Insights / Open Questions. Preview before write.
- **J2 Handoff signal extraction** (H12): For recent handoffs (<7d), extract decisions/gotchas/dead-ends/quick-start. Cross-ref lessons.md + decisions.jsonl. Propose new memory files for uncaptured insights.
- **J3 Handoff-to-memory sync**: HITL gate per insight → create file
- **J4 Session-to-handoff feed**: Dream report v2 includes "Handoff Context" section for `/a-handoff`

**Standalone**: `/atlas dream journal` = J1 only, appends to `session-log.md`. Format: `YYYY-MM-DD HH:MM TZ -- {one-line summary}`.

## Phase 3.7 — Experiential Synthesis

> `--deep`/`--experiential`/`--full`. Details: `${SKILL_DIR}/references/experiential-synthesis.md`

- **H19 Energy patterns**: Trends from `energy:` across recent episodes
- **H20 Productivity cycles**: Cross-ref `time_quality/flow_state` with outcomes
- **H21 Intuition generation**: Multiple episodes share pattern → propose intuition file
- **H22 Relationship depth**: Files not updated 30+d but person in recent sessions → propose update
- **H23 Growth trajectory**: Month vs previous month (energy, flow, confidence, blockers)

Output: Patterns persisted to `patterns-experiential.md`.

## Phase 3.9 — Active Forgetting: Retention Tier Scan

> Every dream cycle. Details: `${SKILL_DIR}/references/retention-tiers.md`

- **H28 Tier classification**: frontmatter `retention_tier:` → `type:` → filename pattern → default Tier 2
- **H29 Expiry scan**: T0 skip, T1 180d, T2 60d, T3 14d (warn at 75% TTL)
- **H30 Archive proposal**: AskUserQuestion per file. T3 = auto-archive.
- **H31 Archive execution**: Extract 5 lines → append `archive-expired-{year}-{month}.md` → remove → update MEMORY.md
- **H32 Retention health (D18)**: `D18 = files_within_ttl / total_tier_1_2_3_files × 10`

### Scan Command (outside Dream)

```bash
python3 -c "
import os, re, json
from datetime import datetime
from pathlib import Path
MEMORY_DIR = Path('$MEMORY_DIR')
TIER_TTL = {0: float('inf'), 1: 180, 2: 60, 3: 14}
TYPE_TIER = {'feedback': 0, 'user': 0, 'reference': 0, 'project': 1}
NAME_T0 = ['feedback_','feedback-','user_','relationship_','self-model','MEMORY','lessons']
NAME_T2 = ['handoff-','episode-','checkpoint-','session-','dream-report-','archive-']
NAME_T3 = ['debug-','temp-','scratch-','experiment-']
now = datetime.now()
results = {'fresh':0,'warning':0,'expired':0,'permanent':0}
for f in MEMORY_DIR.glob('*.md'):
    if f.name == 'MEMORY.md': continue
    content = f.read_text(); tier = 2
    fm = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
    if fm:
        if m := re.search(r'retention_tier:\s*(\d)', fm.group(1)): tier = int(m.group(1))
        elif m := re.search(r'type:\s*(\w+)', fm.group(1)): tier = TYPE_TIER.get(m.group(1), 2)
    for pat in NAME_T0:
        if f.name.startswith(pat): tier = 0; break
    if tier != 0:
        for pat in NAME_T3:
            if f.name.startswith(pat): tier = 3; break
        for pat in NAME_T2:
            if f.name.startswith(pat): tier = 2; break
    if tier == 0: results['permanent']+=1; continue
    age = (now - datetime.fromtimestamp(f.stat().st_mtime)).days
    ttl = TIER_TTL[tier]
    if age > ttl: results['expired']+=1; print(f'  EXPIRED T{tier}: {f.name} ({age}d>{ttl}d)')
    elif age > ttl*0.75: results['warning']+=1; print(f'  WARNING T{tier}: {f.name} ({age}d, TTL={ttl}d)')
    else: results['fresh']+=1
print(f'Retention: {results[\"permanent\"]}p / {results[\"fresh\"]}f / {results[\"warning\"]}w / {results[\"expired\"]}e')
"
```

## Phase 3.8 — Cross-Project Memory Reconciliation

> `--full` only. Multi-project scan for duplicates + inconsistencies.

- **H24 Multi-project scan**: Find `~/.claude/projects/*/memory/` dirs, list with file counts
- **H25 Duplicate detection**: Hash-based across projects, flag >80% similarity
- **H26 Stale cross-ref check**: File A references file B in another project → verify B exists
- **H27 Reconciliation**: Per pair: Merge/Keep both/Archive one

**Trigger**: Only if 2+ project dirs with 10+ files each.

## Phase 4 — Prune & Index

1. **Generate proposed MEMORY.md**: Group by category, tables, 200-line hard / 180-line soft limit.
2. **Show proposed structure** (H14): "Write as-is" / "Adjust" / "Cancel"
3. **Write** if approved.
3b. **Topics INDEX generation** (if `.claude/topics/` exists): Generate `INDEX.md` table per topic dir (status, created, decisions, sessions, summary).
4. **Health score** (17D): Compute + dashboard. Details: `${SKILL_DIR}/references/health-scoring.md`.
   D11-D15 (experiential) bash:
   ```bash
   # D11 Experiential Coverage: episode count (30d) / session count; Score 10@80%+, 2@<20%
   # D12 Relational Depth: rel files × freshness %; Score 10@3+rels & >50% fresh
   # D13 Temporal Validity: 10 if 0 expired, -2 per expired (min 0)
   # D14 Intuition Quality: 10 if 3+ intuitions & <30% stale
   # D15 Growth Trajectory: 10 rising, 7 stable, 4 declining from dream-history.jsonl
   ```
5. **Dream report v5.5** (H15): 17D health, trend, importance, code staleness, ecosystem, tech claims, experiential (episodes, energy, relationships, intuitions), workflow, learning velocity, session journal, handoff context, cross-project. Details: `${SKILL_DIR}/references/dream-report-v2.md`
6. **Trend persistence** (H16): Append JSON line to `dream-history.jsonl`
7. **Release lock**: Remove `.consolidate-lock`

## Phase 4.5 — Reflection Generator

> `--reflection`/`--full`. Details: `${SKILL_DIR}/references/reflection-template.md`

1. Read `type: episode` files (current month/sprint)
2. Read `type: intuition` files (validated + unvalidated)
3. Read growth trajectory from `dream-history.jsonl` (last 3-5)
4. Read recent `.claude/decisions.jsonl`
5. Synthesize: Energy Dashboard, Went Well, Difficult, Patterns, Intuitions Reviewed, Decision Review, Sustainability, Strategies Next Month
6. **H24**: Preview → approve/edit/skip
7. Write to `memory/reflection-YYYY-MM.md`

**Frequency**: Max 2/month (sprint end + month end).

## Phase 4.6 — Self-Model Auto-Update

> `--deep`/`--full`.

1. **Read self-model.md**, parse Known Biases
2. **Scan new feedback** since last dream: `find -newer "$LAST_DREAM" -name "feedback*.md"`
3. **Detect biases**: Behavior in Biases? → increment count. Else → propose new (**H25**)
4. **Update Known Biases**: Count 3+ = HIGH priority; no new 30d = consider demotion
5. **Review Ranked Values**: Feedback contradicts ranking → flag (**H26**)
6. **Update Growth Log**: Date, changes, trigger feedback files
7. **H25**: "Apply all" / "Review each" / "Skip"
8. **H26**: "Update ranking" / "Keep current" / "Discuss"
9. **Write** with `Updated:` footer timestamp

## Phase 4.7 — Improvement Proposal Engine

> `--deep`/`--full`. SP-EVOLUTION P8.3+P8.8. Self-improvement loop.

1. **Collect insights**: Aggregate Phases 2.7-2.10
2. **Generate proposals**: Unused skill → remove/onboard; debug spiral → pre-debug checklist; high Haiku fail → raise threshold; deferred topic → plan/archive
3. **Prioritize**: `Score = Impact × Urgency / Effort` (1-5 each)
4. **Track lifecycle**: `~/.claude/dream-proposals.jsonl` with `{date, proposal, type, impact, effort, status}`. Auto-mark "implemented" when commit/file matches.
5. **Feedback loop closure** (P8.8): Grep keywords in recent commits; mark "implemented" or "stale" >30d
6. **Output** (HITL per): Top 3 by score with Why + Action. Previously proposed/implemented/stale/rejected counts.

## Phase 4.8 — Auto-Schedule Next Dream

> SP-EVOLUTION P8.5.

1. **Measure activity**: Events in session-replay.jsonl since last dream
2. **Schedule**: HIGH (>200/wk)=3d | MEDIUM (50-200)=7d | LOW (<50)=14d
3. **CronCreate** if approved: `/atlas dream --deep` for `{date}`
4. **Output**: Activity level, recommendation, target date

## Phase 4.9 — Dream Quality Metrics

> SP-EVOLUTION P8.7.

1. **Pre/post metrics**: Memory file count, MEMORY.md lines, orphans, stale, proposals
2. **Track**: Append to `~/.claude/dream-history.jsonl`:
   ```json
   {"date":"2026-04-05","version":"v6","memory_before":195,"memory_after":192,"orphans_removed":3,"stale_fixed":2,"proposals":5,"duration_min":20,"health_score":78}
   ```
3. **Quality indicators**: Compression ratio, freshness lift, accuracy %
4. **Output**: Before/After table (files, lines, orphans, stale, proposals, health score) + delta summary.

## Phase 5 — Cross-Project

> `--deep`/`--cross-project`. Read-only. Details: `${SKILL_DIR}/references/cross-project.md`

1. **Discovery**: All `MEMORY.md` dirs in `~/.claude/projects`
2. **Entity reconciliation**: Shared VMs, services, repos, IPs, versions
3. **Contradiction detection**: Same entity differing across projects
4. **Output**: Cross-project table (files, health, contradictions)
5. **H17**: Resolve each. **NEVER write to other projects' memory.**

## Standalone Commands (v4)

> HITL-approved experiential memory creation. Schema: `${SKILL_DIR}/references/experiential-schema.md`

### `/atlas episode create`

Narrative episode capturing session's experiential context. Template: `${SKILL_DIR}/references/episode-template.md`

1. Read `~/.claude/atlas-experiential-signals.json`
2. Scan session for tasks/files/decisions
3. Synthesize narrative (story, not task list)
4. Auto-populate frontmatter: energy (median), mood (dominant), time_quality, confidence (avg), flow_state (2+ "deep focus"), energy_arc, duration_minutes, key_decisions (max 5), blockers_hit
5. **HITL**: "Write as-is" / "Edit" / "Skip"
6. Save `memory/episode-YYYY-MM-DD.md` (or `-2.md` if same day)
7. Cleanup signals file
8. Index: Update `## EXPERIENTIAL CONTEXT` table in MEMORY.md (or create)

### `/atlas intuition log`

Capture gut feeling as persistent intuition file. Template: `${SKILL_DIR}/references/intuition-template.md`

1. Ask feeling (free text)
2. Ask 1-3 supporting observations
3. Ask domain: Technical/Team/Strategic/Process/Product
4. Generate: confidence 0.4-0.5, confidence_trend rising, validated false, auto-plan
5. **HITL**: preview
6. Save `memory/intuition-{topic-slug}.md`
7. Link to recent `.claude/decisions.jsonl` if related

### `/atlas relationship {person}`

Template: `${SKILL_DIR}/references/relationship-template.md`

1. Check existing `memory/relationship-{person-slug}.md`
2. **If exists** (UPDATE): ask changed (interaction/trust/strength/role) → update sections + `last_interaction` + history row → **HITL** diff
3. **If new** (CREATE): ask role, org, 2-3 strengths, style, trust (Low/Med/High) → generate → **HITL** preview
4. **Reclassification**: If `team_{person_slug}.md` exists, propose migrate + archive old
5. Save `memory/relationship-{person-slug}.md`
6. Index: Update MEMORY.md EXPERIENTIAL CONTEXT table

### `/atlas dream --topic {name}`

Consolidate topic memory when branch merged or needs cleanup.

1. `[ -d ".claude/topics/${name}" ]` or error
2. Read decisions.md, lessons.md, context.md, count handoffs/
3. Generate `topic-summary.md`: Project, Duration, Sessions, Decisions, Key Decisions (top 3-5), Lessons, Technical Outcome, What Would I Do Differently
4. **HITL**: "Write as-is" / "Edit" / "Skip"
5. Save `.claude/topics/{name}/topic-summary.md`
6. Update `~/.atlas/topics.json`: status=archived, add archivedAt + summaryPath

## Schedule Mode

```python
# --schedule default: weekdays 5:57 PM (off-minute)
CronCreate(cron="57 17 * * 1-5", prompt="/atlas dream --dry-run", recurring=True)
```
Session-scoped (7-day max).

## Learning Verbosity

Setting: `ATLAS_LEARNING_VERBOSITY` in `~/.claude/settings.json` env block.

| Level | Name | Behavior |
|-------|------|----------|
| 1 | Silent | Zero injections. Dream reports only. Auto-learn background only. |
| 2 | Semi (DEFAULT) | Max 2 injections/session: energy alerts, topic context. Episode suggested at end. |
| 3 | Full | Every detection: energy, mood, confidence, patterns, skill suggestions. |

Affects: session-start (topic inject L2+), focus-guard (switch alerts L2+), experiential-capture (episode L2+), auto-learn (always), dream cycle (always).

## Safety Rules (12)

1. **NEVER auto-delete** — archive only
2. **NEVER write** without HITL
3. **Lock protection** — `.consolidate-lock` start/end, 30min timeout
4. **Backup MEMORY.md** — read before overwrite, restore on failure
5. **Read-only `--dry-run`**
6. **Cross-project isolation** — NEVER write to other projects' memory
7. **Feedback immutability** — NEVER suggest deleting/modifying `feedback_*.md`
8. **Large file safety** — create new BEFORE modifying original
9. **Branch awareness** — missing file may be on other branch
10. **Trend append-only** — `dream-history.jsonl` never truncated
11. **Max 2 retries** — escalate to human via AskUserQuestion
12. **NEVER edit plugin cache** — only source repo

## HITL Gate Map (23 Gates)

| Gate | Phase | Trigger |
|------|-------|---------|
| H1 | 1.5-D3 | Handoff insight to memory sync (--docs/deep) |
| H2 | 1.5-D4 | FEATURES.md sync corrections (--docs/deep) |
| H3 | 2.5-V2 | Stale status claims (--validate/deep) |
| H4 | 3.1 | Duplicate merge |
| H5 | 3.2 | Date normalization |
| H6 | 3.3 | Contradiction resolution |
| H7 | 3.4 | Orphan categorization |
| H8 | 3.5 | Frontmatter typing |
| H9 | 3.6 | Large file split |
| H10 | 3.7 | Smart pruning batch |
| H11 | 3.8 | Auto-categorization |
| H12 | 3.5-J2 | Handoff → memory file creation |
| H13 | 3.5-J4 | Session journal write |
| H14 | 4.2 | MEMORY.md write |
| H15 | 4.4 | Dream report write |
| H16 | 4.5 | Trend data persist |
| H17 | 5.4 | Cross-project fixes (--deep) |
| H19-23 | 3.7 | Energy/productivity/intuition/relationship/growth (--experiential/deep) |
| H24 | 4.5 | Reflection approval (--reflection/full) |
| H25 | 4.6 | New bias addition (--deep/full) |
| H26 | 4.6 | Value ranking conflict (--deep/full) |

## Model Strategy

| Phase | Model | Reason |
|-------|-------|--------|
| 1, 1.5, 2, 2.6-2.8 | Sonnet | Scan, count, pattern match |
| 2.5 (Validate) | Opus | Code understanding, semantic verification |
| 3, 3.5, 3.7 | Opus | Merge decisions, session synthesis, pattern recognition |
| 4, 4.5, 4.6 | Opus | Index design, narrative, self-model decisions |
| 5 (Cross-Project) | Opus | Cross-repo reasoning |

## Health Scoring (17 Dimensions)

Weighted composite (0-10) normalized to 100%:

| # | Dimension | W% |
|---|-----------|----|
| D1 | Index Capacity | 10 |
| D2 | Orphan Rate | 10 |
| D3 | Staleness | 8 |
| D4 | Referential Integrity | 10 |
| D5 | Content Freshness | 5 |
| D6 | File Size Balance | 6 |
| D7 | Type Coverage | 6 |
| D8 | Cross-Project Coherence | 6 |
| D9 | Docs Freshness | 8 |
| D10 | Tech Accuracy | 6 |
| D11 | Experiential Coverage | 5 |
| D12 | Relational Depth | 4 |
| D13 | Temporal Validity | 5 |
| D14 | Intuition Quality | 3 |
| D15 | Growth Trajectory | 3 |
| D16 | Workflow Efficiency | 3 |
| D17 | Learning Velocity | 5 |

Grade: A (9-10) / B (7-8.9) / C (5-6.9) / D (3-4.9) / F (<3). Details: `${SKILL_DIR}/references/health-scoring.md`

## Timestamp Standard (NON-NEGOTIABLE)

All dream output uses full timestamp with hour:minutes.

| Context | Format | Example |
|---------|--------|---------|
| Dream report header | `YYYY-MM-DD HH:MM TZ` | `2026-03-25 17:38 EDT` |
| Phase output | HH:MM per section | `Phase 1 completed at 17:40 EDT` |
| dream-history.jsonl | ISO 8601 | `"timestamp": "2026-03-25T17:38:00-04:00"` |
| Session journal | `YYYY-MM-DD HH:MM TZ` | Full, never date alone |
| Memory file footers | `Updated: YYYY-MM-DD HH:MM TZ` | `Updated: 2026-03-25 17:38 EDT` |

Rule: If missing, run `date '+%Y-%m-%d %H:%M %Z'` via Bash. NEVER date without time. Min = `YYYY-MM-DD HH:MM`.
