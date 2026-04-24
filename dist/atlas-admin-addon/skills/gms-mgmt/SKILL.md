---
name: gms-mgmt
description: "G Mining Services unified management (cockpit + profiler + onboard + insights merged 2026-04-17). Subcommands: status/kc-report/team[--deep]/skills/insights[--quick]/report/sync/profile/gaps/bus-factor/onboard. Triggers on: gms status, gms dashboard, poc status, gms cockpit, gms profile, gms team, mse profile, team profile, gms onboard, onboard new, new team member, playbook, gms insights, cross-discipline, insight, connections, gms gaps, bus-factor, kc-report, gms sync, gms skills, gms report, magic moments, pilier coverage, adoption tracking."
effort: medium
thinking_mode: adaptive
superpowers_pattern: [none]
see_also: [atlas-team, knowledge]
tier: admin
version: 6.0.0-alpha.3
---

# gms-mgmt — G Mining Services Unified Management

> **Note (2026-04-17)** : Consolidated from 4 gms-* skills (Sprint 4 dedup HITL approved Seb 21:40 EDT).
> 16 subcommands preserved. 2 collisions resolved via flag-based routing.

## Collision routing table

| Command | Default behavior | Flag override |
|---|---|---|
| `/atlas gms team` | cockpit table rapide | `--deep` → profiler matrix |
| `/atlas gms insights` | insights scan complet (4 types classified) | `--quick` → cockpit mini list candidates |

All other subcommands route to their unique source skill.

---

## Subcommand: cockpit (formerly gms-cockpit)

Subcommands routed: status, kc-report, team (default), skills, insights (--quick), report, sync

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

## Team Format (`/atlas gms team` — DEFAULT, cockpit table rapide)

```
👥 GMS │ MSE Team — {date}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{name} ({discipline}) — {adoption_tier: 🟢 Champion | 🟡 Active | 🔴 At risk}
  Sessions: {n} | KCs created: {n} | Magic moment: {✅ Yes | ❌ No}
  Last active: {date} | Primary use case: {use_case}
...
```

> Use `--deep` flag to switch to profiler matrix (cross-discipline coverage view, see profiler subcommand below).

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

---

## Subcommand: profiler (formerly gms-profiler)

Subcommands routed: profile, team (--deep flag), gaps, bus-factor

Auto-enriching engineer profiles for G Mining Services POC. 4-layer schema with KC-driven evidence accumulation.

## Commands

| Command | Action |
|---------|--------|
| `/atlas gms profile {name}` | Show full profile for MSE (slug or full name) |
| `/atlas gms profile --update` | Interactive session to enrich current profile |
| `/atlas gms team --deep` | Team dashboard — all 8 MSEs, coverage matrix (profiler view) |
| `/atlas gms gaps` | Skill gap analysis vs project requirements |
| `/atlas gms bus-factor` | Bus-factor risk report per skill/domain |

> Note: `/atlas gms team` (no flag) routes to cockpit table by default. Use `--deep` for this profiler matrix view.

## Profile Schema (4 Layers)

Each MSE profile is a markdown file with YAML frontmatter:

```yaml
---
type: mse-profile
slug: {firstname-lastname}            # kebab-case
name: {Full Name}
discipline: DIR|EL|ME|IT|PROG|AUTO
layer_maturity: 1                     # 1-4 (layers populated)

# LAYER 1 — DISCIPLINE (what they know technically)
skills:
  - name: {skill-name}
    level: 0                          # 0=unknown 1=aware 2=proficient 3=expert
    evidence_count: 0                 # KCs creating evidence for this skill
    last_observed: null               # ISO date of last KC evidence

# LAYER 2 — PERSONAL (how they work)
preferences:
  language: fr|en|bilingual
  response_style: concise|detailed|visual
  review_preference: inline|summary|checklist
  work_rhythm: morning|afternoon|flexible

# LAYER 3 — ENTERPRISE (impact + org value)
contribution:
  kc_total: 0                         # Total Knowledge Captures
  kc_shared: 0                        # KCs flagged as team-visible
  docs_created: 0                     # Reference docs authored
  reviews_completed: 0               # Peer reviews done

# LAYER 4 — TEAM COLLABORATION
team:
  collaboration_score: 0             # 0-100 (cross-discipline interactions)
  pair_sessions: 0                   # Sessions with other MSEs
  mentoring_given: 0                 # KCs that helped others (reaction evidence)
  bus_factor_risk: unknown           # low|medium|high (computed from skill coverage)
---
```

## Auto-Enrichment Rules

| Trigger | Effect |
|---------|--------|
| MSE creates KC with `skill` tag | `skills[*].evidence_count++` + `level` recalculated |
| MSE opens Cowork with another MSE present | `team.pair_sessions++` |
| KC flagged `visibility: team` | `contribution.kc_shared++` |
| MSE creates reference doc | `contribution.docs_created++` |
| KC created by another MSE referencing this profile | `team.mentoring_given++` |
| 3+ KCs in same skill area | `level` upgrades from aware→proficient |
| 8+ KCs in skill + shared | `level` upgrades to expert |

Layer maturity auto-advances:
- Layer 1 complete: ≥3 skills with `level ≥ 1`
- Layer 2 complete: all 4 `preferences` fields set
- Layer 3 complete: `kc_total ≥ 5`
- Layer 4 complete: `collaboration_score ≥ 30`

## Display — ASCII Dashboard

```
╔══════════════════════════════════════════════════════╗
║  👤 MSE Profile: {Name} ({Discipline})               ║
║  Layer Maturity: ████░░░░ L{N}/4                     ║
╠══════════════════════════════════════════════════════╣
║  LAYER 1 — DISCIPLINE EXPERTISE                       ║
║  {Skill 1}     ████████░░ Expert  (12 KCs)           ║
║  {Skill 2}     ████░░░░░░ Proficient (5 KCs)         ║
║  {Skill 3}     ██░░░░░░░░ Aware   (2 KCs)            ║
╠══════════════════════════════════════════════════════╣
║  LAYER 2 — PERSONAL PREFERENCES                       ║
║  Language: FR  Style: Concise  Rhythm: Morning       ║
╠══════════════════════════════════════════════════════╣
║  LAYER 3 — ENTERPRISE CONTRIBUTION                    ║
║  KCs: {N} total / {N} shared   Docs: {N}             ║
╠══════════════════════════════════════════════════════╣
║  LAYER 4 — TEAM COLLABORATION                         ║
║  Score: {N}/100   Bus-Factor Risk: {LOW|MED|HIGH}    ║
╚══════════════════════════════════════════════════════╝
```

## Team Dashboard (`/atlas gms team --deep`)

Cross-matrix view — rows=MSEs, cols=skill domains, cells=coverage level:

```
MSE             | ISA 5.1 | Cable | Arc Flash | Pump | PLC | Server | Code
----------------|---------|-------|-----------|------|-----|--------|-----
[REDACTED-PM] (DIR)   |    —    |   —   |     —     |  —   |  —  |   —    |  —
Lanthier (EL)   |    —    |  ██   |    ███    |  —   |  —  |   —    |  —
Blouin (EL)     |    —    |  ██   |    ██     |  —   |  —  |   —    |  —
...
```

Colour coding: `░` unknown, `▒` aware, `█` proficient, `█` expert.

## Gap Analysis (`/atlas gms gaps`)

Compare team coverage vs THM-012 required skills. Output:
1. **Covered** (≥2 experts): green
2. **Thin** (1 proficient): yellow — single point of failure
3. **Gap** (none or aware only): red — requires training or external hire

## Bus-Factor Report (`/atlas gms bus-factor`)

For each skill in THM-012 scope:
- Count engineers at `level ≥ 2` (proficient+expert)
- `bus_factor = 1` → HIGH risk
- `bus_factor = 2` → MEDIUM risk
- `bus_factor ≥ 3` → LOW risk

Output: ranked risk table + recommended cross-training pairs.

## Profile Location

Profiles stored at:
`{project}/gms-cowork-plugins/kit-day1/profiles/mse-profile-{slug}.md`

Read via filesystem; enrichment updates YAML frontmatter in-place.

---

## Subcommand: onboard (formerly gms-onboard)

Subcommands routed: onboard

> Pilier 1 (RH) — Generate a personalized 4-week onboarding playbook for new MSEs.
> Input: name + discipline. Output: structured playbook with core KCs, shadow schedule, first KC goal.

## When to Use

- `/atlas gms onboard "Name" --discipline EL` — generate playbook for specific person
- User asks about "onboarding", "new team member", "playbook for new engineer"
- User mentions "nouvel employé", "intégration", "formation initiale"

## Process

### Step 1: Gather Input

Use AskUserQuestion to collect:
1. **Name** of new MSE
2. **Discipline** (I&C, EL, ME, Process)
3. **Experience level** (Junior / Mid / Senior)
4. **Start date** (for scheduling)

### Step 2: Read Existing Data

1. **Skills Matrix**: Read MSE profiles to identify discipline champion (highest KC count)
2. **KC Inventory**: Read all KCs for the target discipline, sorted by `confidence` desc
3. **Gap Analysis**: Identify skills with bus factor = 1 in the discipline

### Step 3: Generate Playbook

```markdown
# Onboarding Playbook — {Name} ({Discipline})

> Auto-generated {date} | 4-week structured integration
> Discipline Champion: {champion_name} (shadow partner)

## Week 1: Foundation — Core Knowledge Cards

Goal: Read and understand the top 10 foundational KCs for {discipline}.

| # | KC Title | Type | Author | Priority |
|---|----------|------|--------|----------|
| 1 | {kc_title} | {type} | {author} | 🔴 Critical |
| 2 | {kc_title} | {type} | {author} | 🔴 Critical |
...
| 10| {kc_title} | {type} | {author} | 🟡 Important |

Daily routine:
- [ ] Read 2 KCs per day
- [ ] Note questions for champion
- [ ] Explore Claude Code basics (session, /help, skills)

## Week 2: Shadow — Learn from Champion

Goal: Shadow {champion_name} for 3+ working sessions.

- [ ] Attend {champion_name}'s next Claude Code session (observe workflow)
- [ ] Review {champion_name}'s recent KCs (understand quality bar)
- [ ] Practice: reproduce one KC analysis independently
- [ ] Debrief with champion: gaps identified, questions answered

Shadow focus areas (based on skills matrix gaps):
{list of skills where bus_factor = 1 in this discipline}

## Week 3: First KC — Independent Creation

Goal: Create first independent Knowledge Card.

Suggested KC topics (based on gap analysis):
1. {gap_topic_1} — no KC exists yet, high demand
2. {gap_topic_2} — only 1 KC, needs depth
3. {gap_topic_3} — cross-discipline opportunity

Requirements for first KC:
- [ ] Type: How-to (easiest for first KC)
- [ ] Minimum 3 tags
- [ ] Reviewed by champion before publishing
- [ ] Synced to Forgejo via `/atlas gms sync`

## Week 4: Cross-Discipline Exposure

Goal: Understand how {discipline} connects to other disciplines.

- [ ] Read 3 KCs from adjacent disciplines:
  - {adjacent_discipline_1}: "{kc_title}" — relates to {connection}
  - {adjacent_discipline_2}: "{kc_title}" — relates to {connection}
  - {adjacent_discipline_3}: "{kc_title}" — relates to {connection}
- [ ] Identify 1 cross-discipline insight (shared tags with your work)
- [ ] Attend 1 session from a different discipline MSE

## Checklist — Week 4 Completion

- [ ] Claude Code account active
- [ ] Profile created in gms-cowork-plugins
- [ ] 10+ KCs read (Week 1)
- [ ] 3+ shadow sessions attended (Week 2)
- [ ] 1+ KC created and published (Week 3)
- [ ] 3+ cross-discipline KCs reviewed (Week 4)
- [ ] 1 cross-discipline insight identified (Week 4)
- [ ] Champion sign-off obtained
```

### Step 4: HITL Review

Present the generated playbook to the user via output. Ask:
- "Ce playbook est-il adapté pour {name}? Ajustements?"
- AskUserQuestion with options: Approve / Adjust / Regenerate

### Step 5: Save & Share

On approval:
1. Save as `gms-cowork-plugins/playbooks/onboard-{slug}-{date}.md`
2. If Forgejo accessible: commit + push
3. Suggest: "Partager avec {champion_name} et {name}"

## Adjacent Discipline Mapping

| Discipline | Adjacent 1 | Adjacent 2 | Connection Topic |
|-----------|-----------|-----------|-----------------|
| I&C | EL | Process | Field instrumentation, control loops |
| EL | I&C | ME | Motor control, power distribution |
| ME | EL | Process | Rotating equipment, piping |
| Process | I&C | ME | Process control, equipment sizing |

## Context

- **POC scope**: 8 MSE, 4 disciplines, 3-month pilot
- **Champion**: MSE with highest KC count in the discipline
- **Experience adaptation**: Senior → skip Week 1, focus on KCs; Junior → full 4 weeks
- **Memory**: Save playbook reference in `~/.claude/projects/*/memory/gms-*.md`

---

## Subcommand: insights (formerly gms-insights)

Subcommands routed: insights (default — scan complet)

> Pilier 1 (Coopération) — Detect tacit knowledge connections across disciplines.
> When 2 KCs from different disciplines share 2+ tags → insight candidate for Luc (Pilier lead).

## When to Use

- `/atlas gms insights` — scan all KCs for cross-discipline connections (DEFAULT — full scan)
- `/atlas gms insights --quick` — fast mini list candidates (cockpit-style summary)
- User asks about "cross-discipline", "connections between teams", "shared knowledge"
- User asks about Pilier 1 or inter-discipline collaboration

## Process

### Step 1: Scan KC Files

Read all KC files from the knowledge base:
- Primary: `gms-cowork-plugins/*/knowledge-cards/*.md` (Forgejo repo)
- Fallback: `~/.claude/projects/*/memory/gms-*.md` (local memory)

Each KC has frontmatter with `tags: [tag1, tag2, ...]` and `discipline: I&C|EL|ME|Process`.

### Step 2: Build Tag Graph

For each pair of KCs from DIFFERENT disciplines:
1. Compute tag intersection
2. If intersection >= 2 tags → candidate insight
3. Score by: tag overlap count, KC quality, recency

### Step 3: Classify Insights

| Type | Pattern | Example |
|------|---------|---------|
| **Workflow Integration** | Same process, different disciplines | EL "cable sizing MCC" + ME "motor selection 50HP" |
| **Interface Loop** | Input/output boundary | AUTO "PLC I/O count" + EL "field wiring spec" |
| **Tool Synergy** | Complementary tools/methods | ME "pump curve" + PROC "calc sheet" |
| **Standard Overlap** | Same standard, different application | I&C "ISA 5.1 tagging" + EL "ANSI labeling" |

### Step 4: Present Results

```
🔗 GMS │ Cross-Discipline Insights — {date}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Found {N} insight candidates:

1. 🔗 Workflow Integration (3 shared tags)
   I&C: "PLC I/O count for MCC starters" (Seb)
   EL:  "Field wiring spec for MCC" (Jonathan)
   Tags: [MCC, wiring, I/O-count]
   → Suggest: Joint review of MCC wiring + I/O specs

2. 🔗 Tool Synergy (2 shared tags)
   ME:   "Pump curve analysis" (Charles)
   PROC: "Hydraulic calc sheet v3" (Marie)
   Tags: [pump, hydraulic]
   → Suggest: Shared pump selection workflow

...

📊 Summary:
   Workflow Integration: {n}
   Interface Loop: {n}
   Tool Synergy: {n}
   Standard Overlap: {n}
```

### Step 5: HITL Gate

Present insights via AskUserQuestion:
- "Valider et envoyer à Luc (Pilier 1)?"
- Options: Approve all, Select specific, Dismiss

Only validated insights are logged and forwarded.

## Data Schema

KC frontmatter required fields:
```yaml
---
title: Cable Sizing for MCC
discipline: EL
author: Jonathan Mercier
tags: [cable-sizing, MCC, motor-control, NEC]
type: how-to
confidence: 0.8
---
```

## Context

- **8 MSE, 4 disciplines**: I&C (2), EL (2), ME (2), Process (2)
- **Pilier 1 Lead**: Luc (Coopération Inter-Discipline)
- **Insight threshold**: 2+ shared tags (configurable)
- **Frequency**: Run weekly or on-demand via `/atlas gms insights`

---

## Migration Notes for Existing Users

Old commands continue to work transparently :
- `/atlas gms cockpit` → cockpit subcommand (unchanged)
- `/atlas gms profile` → profiler subcommand
- `/atlas gms onboard` → onboard subcommand
- `/atlas gms insights` → insights subcommand (full scan, was profile-only before)
- `/atlas gms team` → cockpit table by default (use `--deep` for profiler matrix)
