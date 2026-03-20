---
name: rollout-tracker
description: Parse ROADMAP.md rollout phases (Pilot→Expand→GA) to show gate status, client readiness, and OKR progress.
model: sonnet
user_invocable: false
---

# Rollout Tracker

Track business rollout progress from `.blueprint/ROADMAP.md`.

## When to Use

- User says "rollout", "pilot", "ga", "client readiness"
- `/atlas board rollout` command
- Before G Mining demos or stakeholder meetings

## Process

1. **Read** `.blueprint/ROADMAP.md` — extract rollout phases + OKR
2. **Assess** current phase gate criteria
3. **Render** phase timeline with gate status
4. **Show** OKR progress for current quarter
5. **Suggest** blockers for next gate

## Board Format

```
🏛️ ATLAS │ Rollout Tracker — {date}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PILOT (Q1-Q2) ◄── CURRENT    EXPAND (Q3)         GA (Q4)
THM-012 Perama Hill           +BRTZ +CAJB          5+ projects
1 proj, 1 disc, 1 user       3 proj, 3+ users     SaaS active
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PILOT Gate Criteria:
  ✅ Import pipeline functional (FEAT-009)
  ✅ ISA classification (FEAT-012)
  🟡 Spec Grouping (FEAT-008, 80%)
  🟡 SynapseCAD drawings (FEAT-001, 55%)
  ❌ G Mining demo with real data

Q2 OKR Progress:
  O3: Eng Automation   ██████████████░░░░░ 2/3 KR
  O4: AI Workspace     ████████░░░░░░░░░░ 1/3 KR
  O5: Code Excellence  ████░░░░░░░░░░░░░░ 0/3 KR

🎯 Next gate: G Mining demo → requires FEAT-008 + FEAT-001 complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
