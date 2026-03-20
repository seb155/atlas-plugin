---
name: feature-board
description: "Feature registry dashboard. Parse 7 blueprint files for 4-level hierarchy (Program→Theme→Epic→Feature). Kanban, matrix, roadmap, swimlanes, ICE scoring. /atlas board for all modes."
effort: low
---

# Feature Board v2

Render CLI dashboard from `.blueprint/` files. 4-level hierarchy: Program → Theme → Epic → Feature. 8 swimlanes, ICE scoring, OKR tracking.

## When to Use

- User says "board", "features", "show features", "what's the status", "feature status"
- User says "roadmap", "project status", "progress", "how's the project"
- At session start (auto-injected by SessionStart hook — summary only)
- After completing a feature task (show updated board)

## Parse Order (4-Level Hierarchy)

1. `.blueprint/PROGRAM.md` → program card + KPIs
2. `.blueprint/THEMES.md` → 5 themes with epic assignments
3. `.blueprint/EPICS.md` → 8 epics with feature lists + completion %
4. `.blueprint/FEATURES.md` → 34 features with validation matrix
5. `.blueprint/SWIMLANES.md` → 8 cross-cutting checklists
6. `.blueprint/ROADMAP.md` → OKR quarterly + NOW/NEXT/LATER + rollout
7. `.blueprint/OPEX.md` → DORA targets + SLOs

## Board Modes

| Command | Mode | Description |
|---------|------|-------------|
| `/atlas board` | Kanban | Theme-grouped kanban (default) |
| `/atlas board matrix` | Matrix | Feature × validation layers |
| `/atlas board swimlanes` | Swimlanes | Feature × 8 quality dimensions |
| `/atlas board roadmap` | Roadmap | OKR quarterly + rollout phases |
| `/atlas board health` | Health | DORA + SLO + incidents |
| `/atlas board resources` | Resources | Role replacement + team capacity |
| `/atlas board ice` | ICE | Features sorted by ICE score |
| `/atlas board FEAT-NNN` | Detail | Feature detail + swimlane checklist |
| `/atlas board theme N` | Theme | Theme drill-down |
| `/atlas board epic N` | Epic | Epic drill-down |
| `/atlas board suggest` | Suggest | Suggestions only (quick check) |

## Default Board Format (`/atlas board`)

```
🏢 PROG-003 AXOIQ │ Synapse Feature Board — {date}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔧 Engineering Digitization (72%)
  📦 EPIC-01 Core Chain (84%)
    • FEAT-008 Spec Grouping    80% BE✅ FE⏳ E2E⏳ HITL🔵
    • FEAT-002 Rule Engine      70% BE✅ FE✅ E2E⏳ HITL🔵
  📦 EPIC-02 I&C Automation (52%)
    • FEAT-001 SynapseCAD       55% BE✅ FE⏳ E2E❌

📋 PM Controls (87%)
  📦 EPIC-07 PM Suite
    • FEAT-019 Risk Register    95% ✅ DONE
    • FEAT-020 Change Requests  95% ✅ DONE

🧠 AI & Intelligence (64%)
  📦 EPIC-04 Atlas AI
    • FEAT-015 Atlas AI         100% ✅ DONE

🏢 Enterprise Platform (85%)    📊 Enterprise Hub (45%)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Q2 OKR: O3 2/3 KR | O4 1/3 KR | O5 0/3 KR
🎯 NOW: FEAT-008 + FEAT-002 + Dead code cleanup
💡 FEAT-008 ready for E2E → then HITL gate
```

## ICE Scoring

| Factor | Scale | Description |
|--------|-------|-------------|
| **Impact** | 1-10 | Business value (revenue, users, risk reduction) |
| **Confidence** | 1-10 | How sure are we this delivers value? |
| **Ease** | 1-10 | Implementation effort (10=easy, 1=massive) |
| **Score** | I×C×E | Higher = prioritize first |

## Validation Summary Extraction

From each feature's Validation Matrix table:

| Layer keyword | Short |
|--------------|-------|
| BE Unit or BE Integration | BE |
| FE Unit | FE |
| E2E Workflow or E2E | E2E |
| HITL Review or HITL | HITL |

Icons: ✅ PASS, ❌ FAIL, ⏳ TODO, 🔵 PENDING HITL

## Status Mapping

| FEATURES.md Status | Column |
|-------------------|--------|
| 📋 BACKLOG | BACKLOG |
| 📐 PLANNED | PLANNED |
| 🟡 IN_PROGRESS | ACTIVE |
| 🧪 TESTING | TESTING |
| 👁️ REVIEW | REVIEW |
| ✅ DONE | DONE |

## Proactive Suggestions

| Signal | Suggestion |
|--------|-----------|
| All tests ✅ + HITL 🔵 | "FEAT-NNN ready for your review" |
| IN_PROGRESS > 5 days no commit | "FEAT-NNN stale — continue or backlog?" |
| E2E ❌ on active feature | "FEAT-NNN needs E2E tests before merge" |
| 2+ features touch same subsystem | "Merge conflict risk: FEAT-X and FEAT-Y" |
| Swimlane gaps > 3 features | "12 features missing i18n checks" |
| Rollout gate blocked | "G Mining demo requires FEAT-008 + FEAT-001" |
| ICE > 500 + status BACKLOG | "FEAT-NNN high impact, consider starting" |

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
