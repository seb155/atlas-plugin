---
name: feature-board
description: "Feature registry dashboard. Parse FEATURES.md, render kanban board + validation matrix. /atlas board for status, /atlas roadmap for drill-down. Proactive suggestions at session start."
effort: low
---

# Feature Board

Render CLI dashboard from `.blueprint/FEATURES.md`. Show all features grouped by status with validation matrix summary.

## When to Use

- User says "board", "features", "show features", "what's the status", "feature status"
- User says "roadmap", "project status", "progress", "how's the project"
- At session start (auto-injected by SessionStart hook — summary only)
- After completing a feature task (show updated board)

## Process

1. **Read** `.blueprint/FEATURES.md` (project root)
2. **Parse** each `## Feature: FEAT-NNN — {Name}` block
3. **Extract** per feature: Status, Progress, Branch, Validation Matrix (BE/FE/E2E/HITL)
4. **Group** by status column (BACKLOG → PLANNED → ACTIVE → TESTING → REVIEW → DONE)
5. **Render** ASCII kanban board
6. **Analyze** and suggest next actions (proactive)

## Board Format (`/atlas board`)

```
🏛️ ATLAS │ Feature Board — {date}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 BACKLOG ({N})     📐 PLANNED ({N})     🟡 ACTIVE ({N})
─────────────        ──────────────        ──────────────────
• {name}              • {name}              • {name} BE{icon} FE{icon} E2E{icon}

🧪 TESTING ({N})     👁️ REVIEW ({N})      ✅ DONE ({N})
──────────────       ──────────────        ────────────
• {name}                                    • {name}

🎯 SUGGESTED: {proactive recommendation}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Roadmap Format (`/atlas roadmap`)

Group features by Epic (from `**Epic**` field). Show progress bars per epic + per objective.

## Matrix Format (`/atlas board matrix`)

AG Grid-style table: rows = features, columns = validation layers, cells = status icons.

## DoD Scoring

Each feature is scored using 13 weighted validation layers (see `.blueprint/DEFINITION-OF-DONE.md`):

| Tier | Weight | Layers |
|------|--------|--------|
| CODED | 20% | BE Unit (5), BE Integration (3), FE Unit (5), FE Visual (2), Type Check (5) |
| VALIDATED | 60% | E2E Workflow (10), HITL Review (15), Security (8), Performance (7), Real Data (10), Enterprise (10) |
| SHIPPED | 20% | Demo Ready (10), Deploy Prod (10) |

**Board display**: Each feature card shows DoD score + tier badge:
```
• FEAT-001 SynapseCAD  13% 🔨 CODED  [BE✅ FE⏳ E2E❌]
• FEAT-002 Rule Engine  28% 🧪 VALIDATING  [BE✅ FE✅ E2E⏳]
```

**Tiers**: 0-20% = 🔨 CODED, 21-80% = 🧪 VALIDATING, 81-99% = ✅ VALIDATED, 100% = 🚀 SHIPPED

## Validation Summary Extraction

From each feature's Validation Matrix table, extract first icon per layer:

| Layer keyword | Short |
|--------------|-------|
| BE Unit or BE Integration | BE |
| FE Unit | FE |
| E2E Workflow | E2E |
| HITL Review | HITL |

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

After rendering, analyze and surface:

| Signal | Suggestion |
|--------|-----------|
| All tests ✅ + HITL 🔵 | "FEAT-NNN ready for your review" |
| IN_PROGRESS > 5 days no commit | "FEAT-NNN stale — continue or backlog?" |
| E2E ❌ on active feature | "FEAT-NNN needs E2E tests before merge" |
| 2+ features touch same subsystem | "Merge conflict risk: FEAT-X and FEAT-Y" |

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
