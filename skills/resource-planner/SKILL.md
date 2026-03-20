---
name: resource-planner
description: Parse RESOURCE-PLAN.md to show role replacement map, dev team capacity, persona access matrix, and ROI estimates.
model: sonnet
user_invocable: false
---

# Resource Planner

Render resource planning data from `.blueprint/RESOURCE-PLAN.md`.

## When to Use

- User says "resources", "team", "roles", "capacity", "roi"
- `/atlas board resources` command
- When planning sprint allocation or pitching to stakeholders

## Process

1. **Read** `.blueprint/RESOURCE-PLAN.md` — extract all tables
2. **Render** role replacement map (5 roles, savings)
3. **Render** augmented roles (4 roles, HITL gates)
4. **Render** dev team skills matrix (current vs target)
5. **Render** persona × feature access matrix
6. **Calculate** ROI per project

## Board Format

```
🏛️ ATLAS │ Resource Plan — {date}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ROLES REPLACED (98.75%)     │ DEV TEAM
────────────────────────    │ ─────────────────
Doc Generator    -98%       │ Full-Stack  1→5
Data Classifier  -99%       │ I&C Domain  1→2
E-BOM Specifier  -98%       │ DevOps      0.5→1
Cost Estimator   -99%       │ UX Design   0→1
BOM Consolidator -100%      │ QA Eng      0→1
                            │ AI/ML       0.5→1
320h→4h per project         │ 3 FTE → 11 FTE

ROI: $119,400/project (62% savings)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
