# /board — 📊 Feature Board Dashboard

Show all features with 4-level hierarchy (Program → Theme → Epic → Feature).
Parse 7 `.blueprint/` files for kanban, matrix, swimlanes, roadmap, and more.

**Usage**: `/atlas board [mode]`

Invoke the appropriate Skill based on mode:
- Default/matrix/ice/detail/theme/epic/suggest → Skill 'feature-board'
- swimlanes → Skill 'swimlane-tracker'
- health → Skill 'opex-dashboard'
- resources → Skill 'resource-planner'
- roadmap → Skill 'rollout-tracker'

ARGUMENTS: $ARGUMENTS

Modes:
- `/atlas board` — 📊 Theme-grouped kanban (default)
- `/atlas board matrix` — 📋 Validation matrix (features × layers)
- `/atlas board swimlanes` — 🏊 8 cross-cutting quality dimensions
- `/atlas board roadmap` — 🗺️ OKR quarterly + rollout phases
- `/atlas board health` — 🏥 DORA + SLO + incidents
- `/atlas board resources` — 👥 Role replacement + team capacity
- `/atlas board ice` — 🧊 Features sorted by ICE score
- `/atlas board FEAT-NNN` — 🔍 Feature detail + swimlane checklist
- `/atlas board theme N` — 🎨 Theme drill-down
- `/atlas board epic N` — 📦 Epic drill-down
- `/atlas board suggest` — 💡 Suggestions only (quick check)
