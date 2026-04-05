---
name: programme-manager
description: "Programme dashboard for mega plans. Cross-plan rollup, dependency graph, phase gates, sprint suggestions. Use when 'programme', 'program status', 'mega status', 'phase gate', 'cross-plan', or managing multi-plan programmes."
effort: medium
---

# Programme Manager

Manage multi-plan programmes (mega plans). Dashboard, rollup, dependency graph, phase gates.

## When to Use

- User says "programme", "program", "programme status", "mega status"
- User says "phase gate", "cross-plan", "which sub-plan next"
- After completing a sub-plan phase
- At session start if a mega plan exists (summary only)

## Data Sources

| File | Purpose |
|------|---------|
| `.blueprint/plans/{mega-plan}.md` | Programme definition (M1-M16) |
| `.blueprint/plans/sp*.md` | Sub-plans (Section A: vision, deps, effort) |
| `.blueprint/plans/INDEX.md` | Plan registry |
| `.blueprint/plans/MEGA-STATUS.jsonl` | Historical progress (append-only) |
| `.blueprint/FEATURES.md` | Feature ↔ sub-plan mapping |

## Subcommands

| Command | Mode |
|---------|------|
| `/atlas programme` | Dashboard (default) — progress bars per phase |
| `/atlas programme status` | Detailed status with MEGA-STATUS.jsonl rollup |
| `/atlas programme deps` | Dependency graph (ASCII + Mermaid) |
| `/atlas programme gate P{N}` | Phase gate check — all sub-plans in phase at target? |
| `/atlas programme next` | Suggest next sub-plan based on deps + progress |

## Dashboard Format (`/atlas programme`)

```
🏛️ ATLAS │ Programme Dashboard — {programme name}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Phase    Sub-Plans                   Status    Progress
───────  ─────────────────────────  ────────  ──────────
P0       SP-00 + SP-11 + SP-12     🟡 ACTIVE  ██████░░░░ {pct}%
P1       SP-06 + SP-08             📐 PLANNED  ░░░░░░░░░░ 0%
P2       SP-01                     📐 PLANNED  ░░░░░░░░░░ 0%
...
───────  ─────────────────────────  ────────  ──────────
TOTAL    {N} sub-plans              {phase}    {bar} {pct}%
         {total}h                   {n}/{N} phases
```

### Phase Status Detection

For each phase, check sub-plans:
- ALL sub-plans DONE → phase = ✅ DONE
- ANY sub-plan IN_PROGRESS → phase = 🟡 ACTIVE
- ALL sub-plans PLANNING and deps met → phase = 📐 READY
- Dependencies not met → phase = 🔒 BLOCKED
- No work started → phase = 📐 PLANNED

## Status Format (`/atlas programme status`)

Detailed per-sub-plan breakdown:

```
🏛️ ATLAS │ Programme Status — {name}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Sub-Plan                     Phase  Effort     Status    Features
──────────────────────────  ─────  ─────────  ────────  ─────────
SP-00 Stack Remediation      P0    0/70h      📐 PLAN   —
SP-11 ATLAS Plugin           P0    35/50h     🟡 70%    —
SP-12 IaC Platform           P0    38/72h     🟡 53%    FEAT-005
SP-06 Enterprise Platform    P1    0/200h     🔒 BLOCK  FEAT-005,014
...

Programme: {done}h / {total}h ({pct}%) │ Phase {current} active
Last update: {date from MEGA-STATUS.jsonl}
```

## Dependency Graph (`/atlas programme deps`)

```
🏛️ ATLAS │ Dependency Graph
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Critical Path (longest): SP-11 → SP-12 → SP-06 → SP-01 → SP-02 → SP-03
Duration: {weeks}w │ Effort: {hours}h

SP-11 Plugin ─────→ SP-12 IaC ─────→ SP-06 Platform
                                        ├──→ SP-01 SOTA AI ──→ SP-02 Knowledge ──→ SP-03 Unified
                                        └──→ SP-08 Hub
SP-00 Stack ──────→ SP-06 Platform
SP-04 Multi-Disc ─→ SP-07 CAD
SP-09 Process Sim → SP-05 Digital Twin → SP-10 Construction

Legend: ──→ = blocks │ ✅ = done │ 🟡 = active │ 📐 = planned │ 🔒 = blocked
```

## Phase Gate Check (`/atlas programme gate P{N}`)

```
🏛️ ATLAS │ Phase Gate Check — P{N}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Sub-Plan         Quality  Progress  DoD Tier      Pass?
───────────────  ───────  ────────  ────────────  ─────
SP-{NN} {name}   {n}/15   {pct}%   {tier}        ✅/❌
...

Gate: {pass_count}/{total} sub-plans pass │ {PASS/FAIL}
Required: ALL sub-plans ≥ 12/15 quality + target DoD tier

{If FAIL}: "Sub-plan SP-{NN} blocks gate: {reason}. Run /atlas review-plan sp-{nn} to improve."
{If PASS}: "Phase P{N} gate PASSED. Proceed to P{N+1}? (HITL confirmation required)"
```

## Next Suggestion (`/atlas programme next`)

Algorithm:
1. Find current active phase
2. Within that phase, find sub-plans not yet started or lowest progress
3. Check dependencies: which sub-plans are unblocked?
4. Sort by: blocking impact (how many others does it unblock?) DESC, then effort ASC
5. Suggest top 1-2

```
🏛️ ATLAS │ Suggested Next
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📦 Next: SP-{NN} {name} ({effort}h)
   Phase: P{N} │ Dependencies: ✅ all met
   Why: Unblocks {N} other sub-plans. {reason}.
   Start: /atlas plan sp-{nn} (or /atlas execute sp-{nn})
```

## MEGA-STATUS.jsonl Management

### Reading
Parse each line as JSON. Group by `plan` field. Latest entry per plan = current status.

### Writing
After executing a sub-plan phase or receiving HITL update:
```bash
echo '{"date":"'$(date +%Y-%m-%d)'","plan":"sp{nn}","phase":"P{n}","status":"{STATUS}","effort_done_h":{n},"effort_total_h":{n},"note":"{description}"}' >> .blueprint/plans/MEGA-STATUS.jsonl
```

### Rollup Calculation
```
programme_progress = Σ(sp_effort_done) / Σ(sp_effort_total) × 100
phase_progress = Σ(sp_in_phase_effort_done) / Σ(sp_in_phase_effort_total) × 100
```
