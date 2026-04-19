---
name: gms-insights
description: "Cross-Discipline Insight Engine (Pilier 1 Coopération). This skill should be used when the user asks to '/atlas gms insights', 'cross-discipline', 'insight', 'connections', or needs tacit connections detected via shared KC tags."
effort: low
---

# GMS Cross-Discipline Insight Engine

> Pilier 1 (Coopération) — Detect tacit knowledge connections across disciplines.
> When 2 KCs from different disciplines share 2+ tags → insight candidate for Luc (Pilier lead).

## When to Use

- `/atlas gms insights` — scan all KCs for cross-discipline connections
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
