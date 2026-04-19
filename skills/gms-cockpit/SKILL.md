---
name: gms-cockpit
description: "GMS POC command center dashboard. This skill should be used when the user asks to '/atlas gms cockpit', 'gms dashboard', 'adoption stats', 'KC coverage', 'pilier stats', or manages the G Mining Claude Code POC."
effort: low
---

# GMS Cockpit — POC Command Center

> Dashboard for managing the GMS Claude Code POC (8 MSE, 4 disciplines, 4 Piliers).
> Data source: MCP Server REST API (mcp.axoiq.com/api/v1/) when live, local memory files otherwise.

## When to Use

- User says "gms status", "gms dashboard", "poc status", "gms cockpit"
- User asks about adoption, KC stats, magic moments, or pilier coverage
- `/atlas gms` or `/atlas gms status` or `/atlas gms kc-report` or `/atlas gms team`

## Subcommands

| Command | Action |
|---------|--------|
| `/atlas gms status` | Full dashboard (adoption, KCs, piliers, magic moments) |
| `/atlas gms kc-report` | Knowledge Card stats by type/discipline |
| `/atlas gms team` | MSE profiles summary (4 disciplines) |
| `/atlas gms skills` | Skills Matrix — competency heatmap + gap detection |
| `/atlas gms insights` | Cross-discipline insight candidates (Pilier 1) |
| `/atlas gms report` | Monthly report for Mathieu (Pilier 4) — Markdown output |
| `/atlas gms sync` | Force sync local KCs to Forgejo (git add+commit+push) |
| `/atlas gms sync --status` | Show pending/synced/failed KC counts |
| `/atlas gms sync --dry-run` | Preview sync without pushing |

## Data Sources (priority order)

1. **MCP REST API** — `https://mcp.axoiq.com/api/v1/` (live, if reachable)
2. **Local memory files** — `~/.claude/projects/*/memory/gms-*.md` (fallback)
3. **Inline estimates** — Use only if both above unavailable (label as `[estimated]`)

## Dashboard Format (`/atlas gms status`)

```
🏭 GMS │ Claude POC — {date}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 ADOPTION — Week {N}
──────────────────────────────────────────────────────────
MSE                  Discipline     Sessions  KCs  Magic?
─────────────────────────────────────────────────────────
{name}               {discipline}   {n}       {n}  {✅|—}
...
──────────────────────────────────────────────────────────
TOTAL                               {n}       {n}  {n}/8

🧩 4 PILIERS COVERAGE
──────────────────────────────────────────────────────────
Pilier 1: Automatisation            {bar} {n} KCs
Pilier 2: Analyse & Décision        {bar} {n} KCs
Pilier 3: Documentation             {bar} {n} KCs
Pilier 4: Formation & Coaching      {bar} {n} KCs

✨ MAGIC MOMENTS ({N} total)
──────────────────────────────────────────────────────────
{date} — {MSE} — {brief description}
...

📈 FLYWHEEL HEALTH
──────────────────────────────────────────────────────────
Adoption momentum : {score}/10
KC quality avg    : {score}/10
Plugin engagement : {score}/10
Email pipeline    : {pending} pending → {sent} sent
```

## KC Report Format (`/atlas gms kc-report`)

```
🗂️ GMS │ KC Report — {date}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

By Type
──────────────────────────────────────────────────────────
How-to          {n}   {bar}
Case study      {n}   {bar}
Checklist       {n}   {bar}
Reference       {n}   {bar}

By Discipline
──────────────────────────────────────────────────────────
I&C Engineering    {n}   {bar}
Electrical         {n}   {bar}
Mechanical         {n}   {bar}
Process            {n}   {bar}

By Pilier
──────────────────────────────────────────────────────────
P1 Automatisation    {n}   {bar}
P2 Analyse           {n}   {bar}
P3 Documentation     {n}   {bar}
P4 Formation         {n}   {bar}
```

## Team Format (`/atlas gms team`)

```
👥 GMS │ MSE Team — {date}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{name} ({discipline}) — {adoption_tier: 🟢 Champion | 🟡 Active | 🔴 At risk}
  Sessions: {n} | KCs created: {n} | Magic moment: {✅ Yes | ❌ No}
  Last active: {date} | Primary use case: {use_case}
...
```

## Skills Matrix Format (`/atlas gms skills`)

```
🎯 GMS │ Skills Matrix — {date}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Skill / Domain        I&C    EL     ME     PROC   Bus Factor
─────────────────────────────────────────────────────────────
Cable sizing          ░░     █████  ░░     ░░     ⚠️ 1 (EL only)
Motor selection       ░░     ██░░░  █████  ░░     ✅ 2
PLC I/O count         █████  ██░░░  ░░     ░░     ✅ 2
Calc sheet design     ███░░  ░░     ██░░░  █████  ✅ 3
Pump curve analysis   ░░     ░░     █████  ██░░░  ✅ 2
...
─────────────────────────────────────────────────────────────

🚨 ALERTS
─────────────────────────────────────────────────────────────
⚠️ Bus Factor = 1: Cable sizing (EL only), SCADA config (I&C only)
🕳️ Dead Zones: No KCs for "safety systems" across any discipline
🤝 Synergy: Cable sizing (EL) ↔ PLC I/O count (I&C) — 3 shared tags
```

### Skills Matrix Logic

**Data source**: Read MSE profile files from `gms-cowork-plugins/kit-day1/profiles/mse-*.md`
Each profile has: `skills:` list with `{name, level, kc_count}`.

**Aggregation**:
1. Parse all MSE profiles → build skill×discipline matrix
2. **Bus Factor**: Count unique disciplines per skill. ⚠️ if only 1 discipline has it.
3. **Dead Zone**: Expected skills (from ISA 5.1 standard list) with 0 KCs across all MSEs.
4. **Synergy**: Two KCs from different disciplines sharing 2+ tags → potential collaboration.

## Monthly Report Format (`/atlas gms report`)

Generate a comprehensive monthly report as Markdown. Use AskUserQuestion to confirm the reporting period.

```
# GMS POC — Monthly Report {Month Year}

## Executive Summary
- {1-2 sentences: adoption trend, highlight achievement}

## Adoption Metrics
| MSE | Discipline | Sessions | KCs | Trend |
|-----|-----------|----------|-----|-------|
{table from /atlas gms team data}

## Knowledge Card Inventory
- Total: {n} KCs ({+n} vs last month)
- By type: How-to ({n}), Case study ({n}), Checklist ({n}), Reference ({n})
- By discipline: I&C ({n}), EL ({n}), ME ({n}), Process ({n})
- Quality avg: {score}/5

## 4 Piliers Progress
| Pilier | KCs | Coverage | Status |
|--------|-----|----------|--------|
| P1 Automatisation | {n} | {bar} | {🟢🟡🔴} |
| P2 Analyse | {n} | {bar} | {🟢🟡🔴} |
| P3 Documentation | {n} | {bar} | {🟢🟡🔴} |
| P4 Formation | {n} | {bar} | {🟢🟡🔴} |

## Skills Matrix Highlights
- Bus factor alerts: {list}
- New skills identified: {list}
- Synergy opportunities: {list}

## Cross-Discipline Insights
{list from /atlas gms insights}

## Recommendations
1. {auto-generated based on gaps and trends}
2. {auto-generated}
3. {auto-generated}
```

### Report Generation Rules
- Always ask for reporting period via AskUserQuestion
- Use real data from MSE profiles, KC files, and adoption logs
- Compare with previous month if data available
- Flag [estimated] for any inferred data
- Output as Markdown — user can convert via `/atlas present --format pdf`

## Progress Bar

10-char bars: `█` for filled, `░` for empty. Scale to max KC count in category.

## Fallback Behavior

If MCP API is unreachable AND no local memory files found:
- Display skeleton dashboard with `[no data]` placeholders
- Show: "⚠️ No data available. MCP API unreachable + no local memory files found."
- Suggest: `curl -s https://mcp.axoiq.com/api/v1/health` to diagnose

## Context

- **POC scope**: 8 MSE, 4 disciplines (I&C, EL, ME, Process), 3-month pilot
- **4 Piliers**: Claude POC strategic framework — Automatisation, Analyse & Décision, Documentation, Formation & Coaching
- **Flywheel**: Usage → KCs → Shared insights → More usage
- **Memory**: `~/.claude/projects/*/memory/gms-claude-code-poc-2026-04.md`
