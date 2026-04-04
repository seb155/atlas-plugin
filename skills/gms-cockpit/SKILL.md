---
name: gms-cockpit
description: "GMS POC command center — adoption tracking, KC stats, pilier coverage, magic moments. Dashboard for managing the Claude Code POC at G Mining Services (8 MSE, 4 disciplines, 4 Piliers)."
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
