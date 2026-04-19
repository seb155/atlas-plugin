---
name: feature-board
description: "Feature registry dashboard and WIP audit. This skill should be used when the user asks to '/atlas board', 'feature board', 'kanban', 'WIP audit', 'feature status', or at session start when FEATURES.md drift needs surfacing."
effort: low
---

# Feature Board

Multi-view CLI dashboard from `.blueprint/FEATURES.md`, `.blueprint/THEMES.md`, `.blueprint/EPICS.md`.

## When to Use

- User says "board", "features", "show features", "what's the status", "feature status"
- User says "roadmap", "project status", "progress", "how's the project"
- User says "wip", "work in progress", "what's active", "stale features", "wip audit", "wip reset"
- At session start (auto-injected by SessionStart hook — summary only)
- After completing a feature task (show updated board)

## Data Sources

Read these 3 files from project root:

| File | Purpose | Key fields |
|------|---------|-----------|
| `.blueprint/FEATURES.md` | All features | ID, Status, Progress, Theme, Epic, Started, AC dates, Validation Matrix, Dependencies |
| `.blueprint/THEMES.md` | 5 themes | Icon, Epics list, Completion %, Impact |
| `.blueprint/EPICS.md` | 7 epics | Theme, Features list, Done/Active counts, Completion %, Dependencies |

## View Modes

| Command | Mode | Default? |
|---------|------|----------|
| `/atlas board` | **Chronological** | YES — features sorted by last activity date, most recent first |
| `/atlas board themes` | **Themed** | Progress bars summary + kanban grouped by Theme > Epic |
| `/atlas board kanban` | **Kanban** | Flat kanban by status (BACKLOG → DONE) — original view |
| `/atlas board matrix` | **Matrix** | Validation matrix table (all features × all layers) |
| `/atlas board FEAT-NNN` | **Detail** | Single feature deep-dive |
| `/atlas board suggest` | **Suggest** | Sprint packs + dependency graph only |
| `/atlas board wip` | **WIP Audit** | Categorize IN_PROGRESS → KEEP / DEMOTE / DECIDE |
| `/atlas board reset` | **WIP Reset** | Apply demotions from WIP audit with HITL gates |
| `/atlas roadmap` | **Themed** | Alias for `/atlas board themes` |

**ALL views** append Sprint Pack Suggestions at the bottom (except `matrix` and single `FEAT-NNN`).

## Process (all modes)

1. **Read** `.blueprint/FEATURES.md` + `.blueprint/THEMES.md` + `.blueprint/EPICS.md`
2. **Parse** each `## Feature: FEAT-NNN — {Name}` block
3. **Extract** per feature: Status, Progress, Theme, Epic, all dates, Validation Matrix (13 layers), AC done/total, Dependencies
4. **Route** to view mode based on subcommand argument
5. **Render** the selected view
6. **Append** Sprint Pack Suggestions + Dependency Graph (for board/themes/kanban/suggest modes)

---

## VIEW 1: Chronological (DEFAULT — `/atlas board`)

Features sorted by **last activity date** descending. Grouped by time period.

### Date Extraction Logic

For each feature, collect ALL dates found in its block:
1. Validation Matrix dates (e.g., `| **BE Unit** | ✅ PASS | Claude | 2026-03-18 |`)
2. AC completion dates in parentheses (e.g., `- [x] AC-1: ... (2026-03-20)`)
3. HITL gate approval dates (e.g., `| ✅ | Seb | 2026-03-17 |`)
4. Rollout dates (e.g., `| DEV | ✅ Deployed | 2026-03-18 |`)
5. `**Started**` field as fallback

**Last activity** = `max(all_dates)`. If no dates found → group under "NO DATE".

### Time Period Buckets

Relative to today's date:
- **🔥 TODAY** — last activity = today
- **📅 THIS WEEK** — last activity within current Mon-Sun week (not today)
- **📅 LAST WEEK** — last activity within previous Mon-Sun week
- **📅 2+ WEEKS** — last activity before last week but has a date
- **⚪ NO DATE** — no dates found in feature block

### Chrono Format

```
🏛️ ATLAS │ Feature Board — Chronological — {date}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 {N} features │ {done} ✅ DONE │ {active} 🟡 ACTIVE │ {coded} 🔨 CODED │ {backlog} 📋 BACKLOG

🔥 TODAY — {YYYY-MM-DD}
──────────────────────────────────────────────────────────
{status_icon} FEAT-NNN {Name}          {prog}%  BE{i} FE{i} E2E{i} HITL{i}  AC:{done}/{total}
  └─ {Theme} › {Epic}  │  Last: {last_date}

📅 THIS WEEK — {Mon} → {Sun}
──────────────────────────────────────────────────────────
...

📅 LAST WEEK — {Mon} → {Sun}
──────────────────────────────────────────────────────────
...

📅 2+ WEEKS — Before {date}
──────────────────────────────────────────────────────────
...

⚪ NO DATE
──────────────────────────────────────────────────────────
...

{Sprint Pack Suggestions — see section below}
```

Within each time bucket, sort ACTIVE features first (by progress DESC), then DONE, then CODED.

---

## VIEW 2: Themed (`/atlas board themes` or `/atlas roadmap`)

Two-part output: progress bars summary THEN grouped kanban.

### Part 1 — Theme Progress Bars

```
🏛️ ATLAS │ Feature Board — By Theme — {date}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Theme                      Done  Active  Progress
─────────────────────────────────────────────────────────
{icon} {Theme Name}         {d}/{t}   {a}     {bar} {pct}%
...
─────────────────────────────────────────────────────────
TOTAL                      {D}/{T}  {A}     {bar} {pct}%
```

**Progress bar**: 10 chars, `█` for filled, `░` for empty. E.g., 72% = `████████░░`

**Theme icon mapping** (from `THEMES.md` `**Icon**` field):
| THEMES.md Icon | Emoji |
|---------------|-------|
| `Wrench` | 🔧 |
| `ClipboardList` | 🎯 |
| `Brain` | 🤖 |
| `Building2` | 🏢 |
| `BarChart3` | 🏛️ |

### Part 2 — Grouped Kanban (Theme > Epic > Features)

For each Theme (sorted by completion % ASC — least complete first):

```
## {icon} {Theme Name} ({completion}%)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  {EPIC-NN} {Epic Name} ({epic_completion}%) — {done}/{total} done {dep_warning}
  ─────────────────────────────────────
  {status} FEAT-NNN {Name}        {prog}%  BE{i} FE{i} E2E{i} HITL{i}  AC:{d}/{t}
  {status} FEAT-NNN {Name}        {prog}%  BE{i} FE{i} E2E{i} HITL{i}  AC:{d}/{t}
  ...
```

Within each Epic:
- Sort ACTIVE features first (by progress DESC), then DONE
- Show `← ⚠️ depends on {EPIC-NN}` if epic has dependencies (from EPICS.md)

### Dependency Warning

If an Epic has `**Dependencies**` in EPICS.md, show inline warning:
```
  EPIC-02 I&C Automation (52%) — 0/3 done  ← ⚠️ depends on EPIC-01
```

---

## VIEW 3: Kanban (`/atlas board kanban`)

Original flat kanban grouped by status. This is the legacy view.

```
🏛️ ATLAS │ Feature Board — Kanban — {date}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 BACKLOG ({N})     📐 PLANNED ({N})     🟡 ACTIVE ({N})
─────────────        ──────────────        ──────────────────
• {name}              • {name}              • {name} {prog}% BE{i} FE{i} E2E{i}

🔨 CODED ({N})       🧪 TESTING ({N})     ✅ DONE ({N})
──────────────       ──────────────        ────────────
• {name}              • {name}              • {name}

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

AG Grid-style table: rows = features, columns = validation layers, cells = status icons.

```
Feature                    BE  BI  FE  FV  TC  E2E  HITL  SEC  PERF  REAL  ENT  DEMO  PROD
─────────────────────────────────────────────────────────────────────────────────────────────
FEAT-001 SynapseCAD       ✅  ✅  ⏳  ⏳  ⏳   ❌    🔵    —    ✅    ⏳    ⏳    ⏳    ⏳
FEAT-002 Rule Engine       ✅  ✅  ✅  ⏳  ⏳   ⏳    🔵    ⏳    ⏳    ⏳    ⏳    ⏳    ⏳
...
```

No sprint packs appended for matrix view (too dense already).

---

## VIEW 5: Detail (`/atlas board FEAT-NNN`)

Render complete feature block from FEATURES.md:
- All metadata fields
- Full AC list with status
- Full 13-layer validation matrix
- HITL gates
- Dependencies
- Source files
- Rollout status

---

## Sprint Pack Suggestions

Appended to **all views except matrix and detail**. Analyze ACTIVE features and suggest groupings.

### Sprint Pack Algorithm

1. **Collect** all ACTIVE features with their Epic, Theme, Progress, Dependencies
2. **Group** by Epic → features in the same epic are natural sprint partners
3. **Sort** within each group by progress DESC (closest to done = highest priority)
4. **Pair** features that share: same Epic, blocking dependency, or complementary work (BE+FE)
5. **Score** each potential pack:
   - Same Epic: +3 points
   - One blocks the other: +5 points (unblock first!)
   - Same Theme: +2 points
   - Both > 70% progress: +3 points (quick wins)
   - Both need same type of work (both need E2E): +2 points
6. **Select** top 3 packs by score
7. **Estimate** remaining effort: `(100% - progress%) × typical_feature_hours`

### Sprint Pack Format

```
🎯 SPRINT PACKS — Suggested Feature Groupings
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📦 Pack 1: "{pack_name}" ({epic_or_theme})
   FEAT-NNN {Name} ({prog}%) + FEAT-NNN {Name} ({prog}%)
   Why: {rationale — dependency, same epic, quick win, etc.}
   {If blocked}: Blocked by: FEAT-NNN ({dependency description})
   Effort: ~{hours}h combined

📦 Pack 2: ...

📦 Pack 3: ...
```

### Dependency Graph

After sprint packs, render the ACTIVE dependency graph:

```
🔗 DEPENDENCY GRAPH
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Feature-level:
  FEAT-NNN ──blocks──→ FEAT-NNN (reason)
  FEAT-NNN ──blocks──→ FEAT-NNN (reason)

Epic-level:
  EPIC-NN ──blocks──→ EPIC-NN
  EPIC-NN ──blocks──→ EPIC-NN ──→ EPIC-NN
```

Sources for dependencies:
- **Feature-level**: Parse `### Dependencies` table in each feature block
- **Epic-level**: Parse `**Dependencies**` field in EPICS.md

---

## Proactive Signals

After rendering any view, analyze and surface relevant signals:

| Signal | Condition | Suggestion |
|--------|-----------|-----------|
| Ready for HITL | All tests ✅ + HITL 🔵 | "FEAT-NNN ready for your review" |
| Stale feature | ACTIVE + no date activity > 7 days | "FEAT-NNN stale ({N}d) — continue or backlog?" |
| E2E failing | E2E ❌ on ACTIVE feature | "FEAT-NNN needs E2E tests before merge" |
| Merge conflict risk | 2+ ACTIVE features in same subsystem | "Merge conflict risk: FEAT-X and FEAT-Y" |
| Almost done | ACTIVE + progress >= 80% + BE✅ | "FEAT-NNN almost done — FE + E2E sprint to close" |
| Epic cluster | 2+ ACTIVE in same Epic | "Group FEAT-X + FEAT-Y — same epic, reduce context switching" |
| Epic blocked | Epic with unmet dependencies | "EPIC-NN blocked by EPIC-NN: close FEAT-X/Y first" |
| Theme milestone | Theme at 85%+ completion | "Theme {name} nearly complete — close {N} remaining features" |

Show max 5 signals, prioritized by impact (blockers first, then quick wins, then info).

---

## Validation Summary Extraction

From each feature's Validation Matrix table, extract status icon per layer:

| Layer keyword | Short | Icon extraction |
|--------------|-------|----------------|
| **BE Unit** or **BE Integration** | BE | First ✅/❌/⏳ found |
| **FE Unit** | FE | First ✅/❌/⏳ found |
| **E2E Workflow** | E2E | First ✅/❌/⏳ found |
| **HITL Review** | HITL | ✅/🔵/⏳ |
| **Security** | SEC | ✅/⏳/— |
| **Performance** | PERF | ✅/⏳/— |
| **Real Data** | REAL | ✅/⏳/— |
| **Enterprise** | ENT | ✅/⏳/— |
| **Demo Ready** | DEMO | ✅/⏳/— |
| **Deploy Prod** | PROD | ✅/⏳/— |

Icons: ✅ PASS, ❌ FAIL, ⏳ TODO, 🔵 PENDING HITL, — N/A

---

## DoD Scoring

Each feature scored using 13 weighted validation layers (see `.blueprint/DEFINITION-OF-DONE.md`):

| Tier | Weight | Layers |
|------|--------|--------|
| CODED | 20% | BE Unit (5), BE Integration (3), FE Unit (5), FE Visual (2), Type Check (5) |
| VALIDATED | 60% | E2E Workflow (10), HITL Review (15), Security (8), Performance (7), Real Data (10), Enterprise (10) |
| SHIPPED | 20% | Demo Ready (10), Deploy Prod (10) |

**Tiers**: 0-20% = 🔨 CODED, 21-80% = 🧪 VALIDATING, 81-99% = ✅ VALIDATED, 100% = 🚀 SHIPPED

---

## Task Intelligence

When creating tasks for a feature implementation:
1. **Read FEATURES.md** → get AC list
2. **Decompose** each AC into 1-3h tasks (QUOI, not COMMENT)
3. **Set dependencies** via `addBlockedBy` (BE before FE hooks)
4. **Mark parallel** tasks for simultaneous subagent dispatch
5. **HITL gates** = tasks that pause for human input

When a task reveals new info:
1. Update task description with discovery
2. If blocked → create prerequisite task + `addBlockedBy`
3. If scope change → update FEATURES.md + plan file
4. If architectural decision → AskUserQuestion + decision-log

---

## VIEW 6: WIP Audit (`/atlas board wip`)

Analyze ALL `IN_PROGRESS` features and categorize each into actionable buckets.
This is the "honest mirror" — it tells you what's really active vs. parked.

### WIP Audit Pipeline

```
PARSE → SCORE → CLASSIFY → REPORT → RECOMMEND
```

### WIP Health Criteria (per feature)

For each IN_PROGRESS feature, compute a **WIP Health Score** (0-100):

| Criterion | Weight | Score Logic |
|-----------|--------|-------------|
| **Momentum** | 30% | Days since last activity: 0-3d=100, 4-7d=70, 8-14d=40, 15-30d=15, >30d=0 |
| **DoD Coverage** | 25% | Count of PASS layers ÷ applicable layers × 100 |
| **FE Exists** | 15% | Has UI that loads and works: 100=yes, 50=partial, 0=BE-only |
| **Progress vs Age** | 15% | progress% ÷ weeks_since_started. High ratio=good velocity |
| **Test Coverage** | 15% | Has dedicated tests: 100=yes+passing, 50=exists, 0=none |

### Classification Buckets

| Bucket | Criteria | Icon | Action |
|--------|----------|------|--------|
| **KEEP** | WIP Score ≥ 60 AND last activity < 14 days | 🟢 | Continue — has real momentum |
| **ALMOST** | WIP Score ≥ 60 AND progress ≥ 80% | 🔵 | Sprint to finish — almost done |
| **STALE** | WIP Score 30-59 OR last activity 14-30 days | 🟡 | Decide: push to finish or park |
| **DEMOTE** | WIP Score < 30 OR last activity > 30 days OR 0 DoD PASS | 🔴 | Recommend → BACKLOG |
| **DECIDE** | Ambiguous: mixed signals (high progress but stale, or low score but critical) | ⚪ | Needs human decision via AskUserQuestion |

### WIP Audit Output Format

```
🏛️ ATLAS │ Feature Board — WIP Audit — {date}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 {N} features IN_PROGRESS │ WIP Health: {avg_score}/100

🟢 KEEP ({N}) — Real momentum, continue
──────────────────────────────────────────────────────────
🟢 FEAT-NNN {Name}        {prog}%  Score:{score}  Last:{date}  DoD:{pass}/{total}
   └─ {Theme} › {Epic}

🔵 ALMOST DONE ({N}) — Sprint to finish
──────────────────────────────────────────────────────────
🔵 FEAT-NNN {Name}        {prog}%  Score:{score}  Last:{date}  DoD:{pass}/{total}
   └─ Remaining: {list of TODO DoD layers}

🟡 STALE ({N}) — Decide: push or park
──────────────────────────────────────────────────────────
🟡 FEAT-NNN {Name}        {prog}%  Score:{score}  Last:{date}  DoD:{pass}/{total}
   └─ Stale {N} days │ {reason for low score}

🔴 DEMOTE ({N}) — Recommend → BACKLOG
──────────────────────────────────────────────────────────
🔴 FEAT-NNN {Name}        {prog}%  Score:{score}  Last:{date}  DoD:{pass}/{total}
   └─ Reason: {no momentum | no tests | no FE | 0 DoD PASS}

⚪ DECIDE ({N}) — Needs your input
──────────────────────────────────────────────────────────
⚪ FEAT-NNN {Name}        {prog}%  Score:{score}  Last:{date}  DoD:{pass}/{total}
   └─ Mixed signals: {description of ambiguity}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📈 WIP Summary
  Target WIP: ≤15 features │ Current: {N} │ {over_under} target
  Avg momentum: {avg_days_since_activity} days since last touch
  Top velocity: FEAT-NNN ({velocity_ratio})
  Biggest stall: FEAT-NNN ({days_stale} days)

🎯 Recommendation: Demote {N} features → WIP drops to {new_count}
   Use `/atlas board reset` to apply with HITL confirmation.
```

After rendering the audit, ALWAYS use AskUserQuestion to ask:
- "Do you agree with the DEMOTE recommendations?"
- Options: "Accept all", "Review one by one", "Keep all — skip reset"

---

## VIEW 7: WIP Reset (`/atlas board reset`)

Apply WIP audit demotions to FEATURES.md. HITL-gated — every change requires confirmation.

### Reset Pipeline

```
AUDIT → CONFIRM → APPLY → VERIFY → REPORT
```

### Process

1. **Run WIP audit** (same as `/atlas board wip`) to get classifications
2. **Present DEMOTE list** via AskUserQuestion:
   - Show each feature to demote with reason
   - Options: "Demote all", "Review one by one", "Cancel"
3. **If "Review one by one"**: Loop through each DEMOTE feature with AskUserQuestion:
   - "FEAT-NNN {Name} ({prog}%, stale {N}d) — Demote to BACKLOG?"
   - Options: "Demote", "Keep IN_PROGRESS", "Move to CODED"
4. **Apply changes** to `.blueprint/FEATURES.md`:
   - Change `**Status**: 🟡 IN_PROGRESS` → `**Status**: 📋 BACKLOG` (or chosen status)
   - Add note: `> ℹ️ Demoted from IN_PROGRESS on {date} — WIP audit reset`
5. **Verify**: Re-read FEATURES.md, count new WIP, confirm target met
6. **Report**: Show before/after WIP count + list of changes made

### Reset Output Format

```
🏛️ ATLAS │ Feature Board — WIP Reset Applied — {date}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 WIP: {before} → {after} features │ Target: ≤15 │ {status_icon}

Changes Applied:
  🔴→📋 FEAT-NNN {Name} — BACKLOG (was {prog}%, stale {N}d)
  🔴→🔨 FEAT-NNN {Name} — CODED (was {prog}%, no FE)
  🟢   FEAT-NNN {Name} — KEPT (confirmed by user)
  ...

Next: Run `/atlas board` to see updated chronological view.
```

### Safety Rules

- NEVER auto-demote without AskUserQuestion confirmation
- NEVER change DONE or SHIPPED features
- NEVER delete feature blocks — only change status field
- Always add audit trail note when changing status
- If WIP is already ≤ 15, report "WIP healthy" and skip reset
