---
name: gms-profiler
description: "MSE profile auto-enrichment (4 layers). This skill should be used when the user asks to '/atlas gms profiler', 'profile MSE', 'expertise map', 'bus-factor', 'KC evidence', or updates a team member profile at G Mining."
effort: medium
triggers:
  - "/atlas gms profile"
  - "/atlas gms team"
  - "gms profile"
  - "mse profile"
  - "team profile"
model: sonnet
---

# GMS Profiler

Auto-enriching engineer profiles for G Mining Services POC. 4-layer schema with KC-driven evidence accumulation.

## Commands

| Command | Action |
|---------|--------|
| `/atlas gms profile {name}` | Show full profile for MSE (slug or full name) |
| `/atlas gms profile --update` | Interactive session to enrich current profile |
| `/atlas gms team` | Team dashboard — all 8 MSEs, coverage matrix |
| `/atlas gms gaps` | Skill gap analysis vs project requirements |
| `/atlas gms bus-factor` | Bus-factor risk report per skill/domain |

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

## Team Dashboard (`/atlas gms team`)

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
