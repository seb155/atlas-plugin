---
name: vision-alignment
description: "Strategic idea intake and roadmap integration. This skill should be used when the user says 'nouvelle idée', 'idea', 'feature request', 'what if', 'on devrait', 'cherry pick features', or arrives with a new task that needs alignment with the mega plan, sub-plans, digital twin vision, or product roadmap."
effort: high
---

# Vision Alignment — Strategic Idea Intake & Roadmap Integration

## Purpose

Bridge the gap between "I have an idea" and "it's in the roadmap." Every new idea or task
gets contextualized against the full strategic landscape before any implementation decision.

**Hard gate:** Do NOT implement, create features, or modify roadmap docs until the 6-step
workflow is complete and user approves at the Decision Gate (Step 5).

## Context Loading (Step 0)

Before assessment, scan these 9 sources. Use efficient grep, NOT full reads:

| Source | Path | Extract |
|--------|------|---------|
| Mega Plan | `.blueprint/plans/ticklish-tinkering-puppy.md` | M2 registry, M3 deps, M5 phases |
| Sub-Plans (12) | `.blueprint/plans/sp{00-12}-*.md` | Section A (vision) + deps + effort |
| Features | `.blueprint/FEATURES.md` | Feature names, status, sub-plan refs |
| Backlog | `.blueprint/BACKLOG.md` | BKL items, priority, acceptance criteria |
| PRD | `.blueprint/PRD-SYNAPSE-ENTERPRISE.md` | Personas, engineering chain |
| Roadmap | `.blueprint/ROADMAP-AXOIQ.md` | 19 products, timeline |
| Enterprise Vision | `memory/enterprise-vision-2029.md` | EPCM transformation goals |
| Product Vision UX | `memory/product-vision-ux.md` | Persona priorities |
| Digital Twin (SP-05) | `.blueprint/plans/sp05-digital-twin.md` | 4 phases, IoT/3D scope |

**Scan strategy**: Grep sub-plan Section A headers for keyword match. Grep FEATURES.md
and BACKLOG.md for duplicates. Read mega plan M2 (registry) + M3 (dependency) only.

## 6-Step Workflow

### Step 1: CAPTURE

Parse the user's idea into structured form:

```
Title:       {extracted or asked}
Description: {from args or AskUserQuestion}
Category:    {auto-detect: UX | Backend | Infra | Domain | AI | Integration}
Keywords:    {3-5 search terms for grep}
```

If the user's input is vague, use AskUserQuestion to get: title, one-sentence description,
and primary category. Do NOT proceed without a clear idea statement.

### Step 2: STRATEGIC SCAN

Run 4 parallel searches using the extracted keywords:

1. **Sub-plans**: Grep all `sp*.md` files for keyword matches
2. **Features**: Grep `FEATURES.md` for duplicate or related features
3. **Backlog**: Grep `BACKLOG.md` for related BKL items
4. **Mega plan**: Grep mega plan for matching integration points or phase references

Present results as a structured scan table:

```
🔍 Strategic Scan: "{idea title}"
─────────────────────────────────────────
| Source       | Match                        | Status     |
|--------------|------------------------------|------------|
| SP-{nn}      | "{matching text}" (Phase X)  | {status}   |
| FEAT-{nnn}   | "{feature name}"             | {status}   |
| BKL-{nnn}    | "{backlog item}"             | {status}   |
| Mega Plan    | IP-{n}: "{integration point}" | Phase {n}  |
─────────────────────────────────────────
```

If matches found → highlight with warning: "Related work exists in {source}."
If no matches → state: "No existing coverage found. This is genuinely new scope."

### Step 3: VISION ALIGNMENT (HITL Gate)

Use AskUserQuestion to assess alignment on 4 dimensions:

**Q1: Persona(s) served?** (multi-select)
Options: I&C Engineer, Electrical, Mechanical, Process, PM, Procurement, Admin, Client

**Q2: Engineering chain step?**
Options: IMPORT, CLASSIFY, ENGINEER, SPEC GROUP, E-BOM, PROCURE, ESTIMATE, OUTPUTS, Cross-cutting

**Q3: Best sub-plan fit?** (options derived from Step 2 scan results)
Options: {matched sub-plans from scan}, New sub-plan needed, None (standalone)

**Q4: Vision alignment score?**
Options with descriptions:
- 1 — Tangential (nice but not core)
- 2 — Nice-to-have (improves UX but not strategic)
- 3 — Supports vision (aligns with roadmap direction)
- 4 — Accelerates vision (competitive advantage)
- 5 — Core to vision (blocking other strategic work)

Display the alignment assessment:

```
🧭 Vision Alignment Assessment
─────────────────────────────────
Idea:      {title}
Personas:  {selected personas with priority}
Chain:     {engineering chain step}
Sub-plan:  {best fit or "New"}
Score:     {n}/5 — {label}

{If existing work found}: "Fits as feature within {sub-plan} Phase {n}"
{If new scope}: "Requires new sub-plan or backlog addition"
```

### Step 4: ROADMAP MAPPING

Auto-compute placement from scan + alignment:

```
📍 Roadmap Placement
─────────────────────
Phase:         P{n} ({phase name}, {quarter})
Sub-plan:      SP-{nn} ({total effort}h, this idea ~{estimate}h)
Dependencies:  {what must complete first}
Blocks:        {what this enables}
Integration:   IP-{n} ({integration point name})
Effort:        {S|M|L|XL} ({hours} estimate)
```

If the idea maps to an existing sub-plan, show where it fits in that plan's phases.
If the idea is new scope, recommend which phase and position in the dependency graph.

### Step 5: DECISION GATE (HITL Gate)

Use AskUserQuestion with 4 options:

**(A) Add to Backlog** — Append as BKL-{next} in BACKLOG.md with priority and acceptance criteria.
Good for: small ideas, nice-to-haves, future exploration.

**(B) Create Feature** — Append FEAT-{next} to FEATURES.md, invoke `brainstorming` skill,
then `plan-builder` for the detailed engineering plan.
Good for: strategic ideas scoring 3-5, with clear persona value.

**(C) Future Phase** — Note in mega plan under target phase. No immediate action.
Good for: ideas that depend on unfinished prerequisites.

**(D) Reject** — Log rationale in `decisions.jsonl`. Idea does not align with current vision.

Include your recommendation based on alignment score:
- Score 1-2 → Recommend (A) Backlog or (D) Reject
- Score 3 → Recommend (A) Backlog or (C) Future Phase
- Score 4-5 → Recommend (B) Create Feature

### Step 6: TRACKBACK

Execute the chosen action:

| Decision | Actions |
|----------|---------|
| **(A)** | Append BKL item to `BACKLOG.md`. Log to `decisions.jsonl`. |
| **(B)** | Append FEAT to `FEATURES.md`. Invoke `brainstorming` → `plan-builder`. |
| **(C)** | Note in mega plan phase section. Log to `decisions.jsonl`. |
| **(D)** | Log rejection rationale to `decisions.jsonl`. |

For ALL decisions: update memory if the idea reveals strategic information worth preserving.

## Chaining

- **After Step 5 (B)**: Invoke `brainstorming` skill with the idea context, then `plan-builder`
- **After any decision**: Invoke `decision-log` skill to persist the choice
- **If scan finds no context**: Invoke `context-discovery` skill first, then retry scan
- **Called from**: `atlas-assist` (auto-detect on trigger phrases), or `/atlas idea` command

## Anti-Patterns

| Don't | Do Instead |
|-------|-----------|
| Implement without scanning | ALWAYS run 4 greps first |
| Create new sub-plan for small ideas | Fit into existing sp00-sp12 if possible |
| Skip HITL on vision alignment | ALWAYS ask persona + chain + score |
| Assume "not found" = "not planned" | Check BKL items AND sub-plan phases |
| Modify mega plan directly | Only append to BACKLOG.md or FEATURES.md |
| Accept vague ideas | Ask clarifying questions via AskUserQuestion |
| Skip roadmap mapping for "obvious" features | Every idea gets placement analysis |

## Output Format

Use the ATLAS persona header throughout:

```
🏛️ ATLAS │ PLAN › 🧭 vision-alignment › {current-step}
─────────────────────────────────────────────────────
```

Steps map to: `capture` → `scanning` → `alignment` → `mapping` → `decision` → `trackback`

End every step with the standard ATLAS footer (Recap + Next Steps + Recommendation).
