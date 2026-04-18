---
name: feature-board
description: "Feature registry dashboard with WIP audit. Parse FEATURES.md, render kanban board + validation matrix + WIP health analysis. /atlas board for status, /atlas board wip for WIP audit + reset. Proactive suggestions at session start."
effort: low
---

# Feature Board

Multi-view CLI dashboard from `.blueprint/FEATURES.md`, `.blueprint/THEMES.md`, `.blueprint/EPICS.md`.

## When to Use

- "board", "features", "show features", "status", "feature status", "roadmap", "project status", "progress"
- "wip", "work in progress", "what's active", "stale features", "wip audit", "wip reset"
- Session start (auto-injected by SessionStart hook — summary only)
- After completing a feature task (show updated board)

## Data Sources

| File | Purpose | Key fields |
|------|---------|-----------|
| `.blueprint/FEATURES.md` | All features | ID, Status, Progress, Theme, Epic, Started, AC dates, Validation Matrix, Dependencies |
| `.blueprint/THEMES.md` | 5 themes | Icon, Epics, Completion %, Impact |
| `.blueprint/EPICS.md` | 7 epics | Theme, Features, Done/Active counts, Completion %, Dependencies |

## View Modes

| Command | Mode | Default? |
|---------|------|----------|
| `/atlas board` | **Chronological** | YES — sorted by last activity, recent first |
| `/atlas board themes` | **Themed** | Progress bars + kanban grouped by Theme > Epic |
| `/atlas board kanban` | **Kanban** | Flat by status (BACKLOG → DONE) — legacy view |
| `/atlas board matrix` | **Matrix** | Validation matrix table (features × layers) |
| `/atlas board FEAT-NNN` | **Detail** | Single feature deep-dive |
| `/atlas board suggest` | **Suggest** | Sprint packs + dependency graph only |
| `/atlas board wip` | **WIP Audit** | Categorize IN_PROGRESS → KEEP/DEMOTE/DECIDE |
| `/atlas board reset` | **WIP Reset** | Apply demotions with HITL gates |
| `/atlas roadmap` | **Themed** | Alias for `/atlas board themes` |

**ALL views** append Sprint Pack Suggestions at bottom (except `matrix` and single `FEAT-NNN`).

## Process (all modes)

1. Read FEATURES.md + THEMES.md + EPICS.md
2. Parse each `## Feature: FEAT-NNN — {Name}` block
3. Extract: Status, Progress, Theme, Epic, dates, Validation Matrix (13 layers), AC done/total, Dependencies
4. Route to view by subcommand
5. Render
6. Append Sprint Pack Suggestions + Dependency Graph (board/themes/kanban/suggest)

---

## VIEW 1: Chronological (DEFAULT — `/atlas board`)

Features sorted by **last activity date** desc, grouped by time period.

### Date Extraction

Per feature, collect ALL dates from: Validation Matrix (`| **BE Unit** | ✅ PASS | Claude | 2026-03-18 |`), AC completion (`(2026-03-20)`), HITL gate approvals (`| ✅ | Seb | 2026-03-17 |`), Rollout (`| DEV | ✅ Deployed | 2026-03-18 |`), `**Started**` fallback. **Last activity** = `max(all_dates)`. None → "NO DATE".

### Time Period Buckets (relative to today)

🔥 **TODAY** | 📅 **THIS WEEK** (current Mon-Sun, not today) | 📅 **LAST WEEK** (previous Mon-Sun) | 📅 **2+ WEEKS** (before last week, has date) | ⚪ **NO DATE**

### Chrono Format

```
🏛️ ATLAS │ Feature Board — Chronological — {date}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 {N} features │ {done} ✅ DONE │ {active} 🟡 ACTIVE │ {coded} 🔨 CODED │ {backlog} 📋 BACKLOG

🔥 TODAY — {YYYY-MM-DD}
──────────────────────────────────────────────
{status_icon} FEAT-NNN {Name}    {prog}%  BE{i} FE{i} E2E{i} HITL{i}  AC:{done}/{total}
  └─ {Theme} › {Epic}  │  Last: {last_date}

(THIS WEEK / LAST WEEK / 2+ WEEKS / NO DATE sections same format)

{Sprint Pack Suggestions}
```

Within bucket: ACTIVE first (progress DESC), then DONE, then CODED.

---

## VIEW 2: Themed (`/atlas board themes` or `/atlas roadmap`)

Two-part: progress bars summary THEN grouped kanban.

### Part 1 — Theme Progress Bars

```
🏛️ ATLAS │ Feature Board — By Theme — {date}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Theme                      Done  Active  Progress
─────────────────────────────────────────────────
{icon} {Theme Name}         {d}/{t}   {a}     {bar} {pct}%
TOTAL                       {D}/{T}  {A}     {bar} {pct}%
```

**Bar**: 10 chars `█`/`░` (e.g., 72% = `████████░░`)

**Theme icon mapping** (from THEMES.md `**Icon**`): Wrench=🔧 | ClipboardList=🎯 | Brain=🤖 | Building2=🏢 | BarChart3=🏛️

### Part 2 — Grouped Kanban (Theme > Epic > Features)

Per Theme (sorted by completion % ASC — least complete first):

```
## {icon} {Theme Name} ({completion}%)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  {EPIC-NN} {Epic Name} ({epic_completion}%) — {done}/{total} done {dep_warning}
  ─────────────────────────────────────
  {status} FEAT-NNN {Name}    {prog}%  BE{i} FE{i} E2E{i} HITL{i}  AC:{d}/{t}
```

Per Epic: ACTIVE first (progress DESC), then DONE. Show `← ⚠️ depends on {EPIC-NN}` if dependencies in EPICS.md.

---

## VIEW 3: Kanban (`/atlas board kanban`)

Original flat kanban by status (legacy).

```
🏛️ ATLAS │ Feature Board — Kanban — {date}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 BACKLOG ({N})     📐 PLANNED ({N})     🟡 ACTIVE ({N})
─────────────        ──────────────        ──────────────
• {name}              • {name}              • {name} {prog}% BE{i} FE{i} E2E{i}

🔨 CODED ({N})       🧪 TESTING ({N})     ✅ DONE ({N})

{Sprint Pack Suggestions}
```

### Status Mapping

| FEATURES.md Status | Column |
|-------------------|--------|
| 📋 BACKLOG | BACKLOG |
| 📐 PLANNED | PLANNED |
| 🟡 IN_PROGRESS | ACTIVE |
| ✅ CODED | CODED |
| 🧪 TESTING | TESTING |
| 👁️ REVIEW | REVIEW |
| ✅ DONE | DONE |

---

## VIEW 4: Matrix (`/atlas board matrix`)

AG Grid-style: rows = features, columns = layers, cells = icons. No sprint packs (already dense).

```
Feature                    BE  BI  FE  FV  TC  E2E  HITL  SEC  PERF  REAL  ENT  DEMO  PROD
──────────────────────────────────────────────────────────────────────────────────────────
FEAT-001 SynapseCAD       ✅  ✅  ⏳  ⏳  ⏳   ❌    🔵    —    ✅    ⏳    ⏳    ⏳    ⏳
FEAT-002 Rule Engine       ✅  ✅  ✅  ⏳  ⏳   ⏳    🔵    ⏳    ⏳    ⏳    ⏳    ⏳    ⏳
```

---

## VIEW 5: Detail (`/atlas board FEAT-NNN`)

Render complete feature block: metadata, AC list, full 13-layer matrix, HITL gates, Dependencies, Source files, Rollout.

---

## Sprint Pack Suggestions

Appended to all views except matrix/detail.

### Algorithm

1. Collect all ACTIVE features with Epic, Theme, Progress, Dependencies
2. Group by Epic (natural sprint partners)
3. Sort within group by progress DESC (closest to done first)
4. Pair features sharing: same Epic, blocking dependency, complementary work (BE+FE)
5. Score each pack:
   - Same Epic: +3 | One blocks other: +5 (unblock first!) | Same Theme: +2 | Both >70%: +3 (quick wins) | Same work type (both need E2E): +2
6. Top 3 by score
7. Estimate: `(100% - progress%) × typical_feature_hours`

### Format

```
🎯 SPRINT PACKS — Suggested Feature Groupings
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📦 Pack 1: "{pack_name}" ({epic_or_theme})
   FEAT-NNN {Name} ({prog}%) + FEAT-NNN {Name} ({prog}%)
   Why: {dependency, same epic, quick win, etc.}
   {If blocked}: Blocked by: FEAT-NNN ({reason})
   Effort: ~{hours}h combined

📦 Pack 2: ...
```

### Dependency Graph

After sprint packs:

```
🔗 DEPENDENCY GRAPH
━━━━━━━━━━━━━━━━━━━

Feature-level:
  FEAT-NNN ──blocks──→ FEAT-NNN (reason)

Epic-level:
  EPIC-NN ──blocks──→ EPIC-NN ──→ EPIC-NN
```

Sources: feature-level from `### Dependencies` table per feature; epic-level from `**Dependencies**` in EPICS.md.

---

## Proactive Signals

After rendering, surface relevant signals (max 5, prioritized: blockers → quick wins → info):

| Signal | Condition | Suggestion |
|--------|-----------|-----------|
| Ready for HITL | All tests ✅ + HITL 🔵 | "FEAT-NNN ready for your review" |
| Stale feature | ACTIVE + no activity >7d | "FEAT-NNN stale ({N}d) — continue or backlog?" |
| E2E failing | E2E ❌ on ACTIVE | "FEAT-NNN needs E2E before merge" |
| Merge conflict | 2+ ACTIVE in same subsystem | "Conflict risk: FEAT-X and FEAT-Y" |
| Almost done | ACTIVE + ≥80% + BE✅ | "FEAT-NNN almost done — FE+E2E sprint" |
| Epic cluster | 2+ ACTIVE same Epic | "Group FEAT-X+Y — same epic, less switching" |
| Epic blocked | Epic with unmet deps | "EPIC-NN blocked by EPIC-NN: close FEAT-X/Y first" |
| Theme milestone | Theme ≥85% | "Theme {name} nearly complete — close {N} remaining" |

---

## Validation Summary Extraction

Per feature's Validation Matrix:

| Layer keyword | Short | Source |
|--------------|-------|--------|
| **BE Unit/Integration** | BE | First ✅/❌/⏳ |
| **FE Unit** | FE | First ✅/❌/⏳ |
| **E2E Workflow** | E2E | First ✅/❌/⏳ |
| **HITL Review** | HITL | ✅/🔵/⏳ |
| **Security** / **Performance** / **Real Data** / **Enterprise** / **Demo Ready** / **Deploy Prod** | SEC/PERF/REAL/ENT/DEMO/PROD | ✅/⏳/— |

Icons: ✅ PASS | ❌ FAIL | ⏳ TODO | 🔵 PENDING HITL | — N/A

---

## DoD Scoring

13 weighted layers (see `.blueprint/DEFINITION-OF-DONE.md`):

| Tier | W% | Layers |
|------|----|--------|
| CODED | 20 | BE Unit (5), BE Integration (3), FE Unit (5), FE Visual (2), Type Check (5) |
| VALIDATED | 60 | E2E Workflow (10), HITL Review (15), Security (8), Performance (7), Real Data (10), Enterprise (10) |
| SHIPPED | 20 | Demo Ready (10), Deploy Prod (10) |

**Tiers**: 0-20% 🔨 CODED | 21-80% 🧪 VALIDATING | 81-99% ✅ VALIDATED | 100% 🚀 SHIPPED

---

## Task Intelligence

Creating tasks for a feature:
1. Read FEATURES.md → AC list
2. Decompose AC into 1-3h tasks (QUOI, not COMMENT)
3. `addBlockedBy` (BE before FE hooks)
4. Mark parallel tasks for simultaneous subagent dispatch
5. HITL gates = pause-for-human tasks

When task reveals new info: update description with discovery; if blocked → prerequisite + `addBlockedBy`; scope change → update FEATURES.md + plan; architectural decision → AskUserQuestion + decision-log.

---

## VIEW 6: WIP Audit (`/atlas board wip`)

Analyze ALL `IN_PROGRESS` features. The "honest mirror" — what's really active vs parked.

### Pipeline

```
PARSE → SCORE → CLASSIFY → REPORT → RECOMMEND
```

### WIP Health Score (0-100, per feature)

| Criterion | Weight | Logic |
|-----------|--------|-------|
| **Momentum** | 30% | Days since last: 0-3=100, 4-7=70, 8-14=40, 15-30=15, >30=0 |
| **DoD Coverage** | 25% | PASS layers ÷ applicable × 100 |
| **FE Exists** | 15% | UI loads + works: 100 yes, 50 partial, 0 BE-only |
| **Progress vs Age** | 15% | progress% ÷ weeks_since_started; high ratio = good velocity |
| **Test Coverage** | 15% | Dedicated tests: 100 yes+passing, 50 exists, 0 none |

### Classification Buckets

| Bucket | Criteria | Icon | Action |
|--------|----------|------|--------|
| **KEEP** | Score ≥60 AND last <14d | 🟢 | Continue — real momentum |
| **ALMOST** | Score ≥60 AND progress ≥80% | 🔵 | Sprint to finish |
| **STALE** | Score 30-59 OR last 14-30d | 🟡 | Decide: push or park |
| **DEMOTE** | Score <30 OR last >30d OR 0 DoD PASS | 🔴 | Recommend → BACKLOG |
| **DECIDE** | Mixed signals (high progress but stale, or low score but critical) | ⚪ | AskUserQuestion |

### Output Format

```
🏛️ ATLAS │ Feature Board — WIP Audit — {date}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 {N} features IN_PROGRESS │ WIP Health: {avg_score}/100

{For each bucket — 🟢 KEEP / 🔵 ALMOST DONE / 🟡 STALE / 🔴 DEMOTE / ⚪ DECIDE}:

{icon} {bucket_name} ({N}) — {bucket_description}
──────────────────────────────────────
{icon} FEAT-NNN {Name}    {prog}%  Score:{score}  Last:{date}  DoD:{pass}/{total}
   └─ {bucket-specific context: Theme›Epic | Remaining DoD | Stale days+reason | Demote reason | Mixed signals}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📈 WIP Summary
  Target WIP: ≤15 │ Current: {N} │ {over_under} target
  Avg momentum: {avg_days} days │ Top velocity: FEAT-NNN ({ratio}) │ Biggest stall: FEAT-NNN ({days}d)

🎯 Recommendation: Demote {N} → WIP drops to {new_count}
   Use `/atlas board reset` to apply with HITL confirmation.
```

After audit, ALWAYS AskUserQuestion: "Agree with DEMOTE recommendations?" → "Accept all" / "Review one by one" / "Keep all — skip reset".

---

## VIEW 7: WIP Reset (`/atlas board reset`)

Apply WIP audit demotions to FEATURES.md. HITL-gated per change.

### Pipeline

```
AUDIT → CONFIRM → APPLY → VERIFY → REPORT
```

### Process

1. Run WIP audit (same as `/atlas board wip`)
2. AskUserQuestion: "Demote all" / "Review one by one" / "Cancel"
3. If "Review": loop with AskUserQuestion per feature: "FEAT-NNN ({prog}%, stale {N}d) — Demote?" → "Demote" / "Keep IN_PROGRESS" / "Move to CODED"
4. Apply to `.blueprint/FEATURES.md`:
   - Change `**Status**: 🟡 IN_PROGRESS` → chosen status
   - Add note: `> ℹ️ Demoted from IN_PROGRESS on {date} — WIP audit reset`
5. Verify: re-read, count new WIP, confirm target met
6. Report before/after + change list

### Output Format

```
🏛️ ATLAS │ Feature Board — WIP Reset Applied — {date}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 WIP: {before} → {after} features │ Target: ≤15 │ {status_icon}

Changes Applied:
  🔴→📋 FEAT-NNN {Name} — BACKLOG (was {prog}%, stale {N}d)
  🔴→🔨 FEAT-NNN {Name} — CODED (was {prog}%, no FE)
  🟢   FEAT-NNN {Name} — KEPT (confirmed by user)

Next: Run `/atlas board` to see updated chronological view.
```

### Safety Rules

- NEVER auto-demote without AskUserQuestion confirmation
- NEVER change DONE or SHIPPED features
- NEVER delete feature blocks — only change status field
- Always add audit trail note when changing status
- If WIP already ≤15, report "WIP healthy" and skip reset
