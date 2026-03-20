---
name: opex-dashboard
description: Operational excellence dashboard — DORA metrics from Forgejo API, SLOs from health endpoints, incident tracking, runbook status.
model: sonnet
user_invocable: false
---

# OpEx Dashboard

Render operational excellence metrics from `.blueprint/OPEX.md` + live Forgejo API + health endpoints.

## When to Use

- User says "opex", "dora", "slo", "incidents", "operational health"
- `/atlas board opex` or `/atlas board health` command
- After deploying to prod (show DORA impact)

## Process

1. **Read** `.blueprint/OPEX.md` — extract targets + incident levels
2. **Query Forgejo API** — GET recent merges, PRs, deploy frequency
3. **Check health** — curl backend /health endpoint for uptime
4. **Calculate DORA** — deploy freq, lead time, MTTR from git history
5. **Render** dashboard with gauges + SLO table + incident list

## Board Format

```
🏛️ ATLAS │ OpEx Health — {date}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DORA Metrics              │ SLOs
┌────────┬──────┬────┐   │ ┌──────────┬────────┬──────┐
│ Deploy │ 3/wk │ 🟡 │   │ │ API p95  │ 145ms  │ ✅   │
│ Lead   │ 18h  │ 🟡 │   │ │ Avail    │ 99.7%  │ ✅   │
│ Fail % │ 3%   │ 🟡 │   │ │ Errors   │ 0.02%  │ ✅   │
│ MTTR   │ 25m  │ 🟡 │   │ │ Import   │ 22s    │ ✅   │
└────────┴──────┴────┘   │ └──────────┴────────┴──────┘

Recent Incidents          │ Runbook Status
• SEV3 2026-03-18 4h res  │ • deploy-rollback ✅
• SEV4 2026-03-17 1d res  │ • db-backup ✅
                          │ • import-failure ⏳
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## DORA Calculation

```bash
# Deploy Frequency: count merges to main in last 7 days
git log --oneline --since="7 days ago" main | wc -l

# Lead Time: avg time from PR open to merge
# (requires Forgejo API: list merged PRs, calc open→merge delta)

# Change Failure Rate: reverts / total merges
git log --oneline --since="30 days ago" main --grep="revert" | wc -l

# MTTR: from incident reports in OPEX.md
```
