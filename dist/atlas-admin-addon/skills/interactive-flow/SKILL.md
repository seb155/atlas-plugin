---
name: interactive-flow
description: "Conversational development pipeline: discover → brainstorm → plan → implement → verify → ship. Full feature workflow with HITL at every phase."
effort: high
inputs:
  feature_description: string
outputs:
  commit_sha: string
  verification_report: markdown
triggers:
  - "flow"
  - "pipeline"
  - "brainstorm et implémente"
  - "full workflow"
  - "do everything"
  - "feature complète"
  - "du début à la fin"
---

# Interactive Flow — Conversational Development Pipeline

> The natural workflow codified: DISCOVER → BRAINSTORM → PLAN → IMPLEMENT → VERIFY → SHIP
> Each phase has a HITL gate. The user controls pace and direction.

## When to Use

- Building a new feature from scratch (more than a quick fix)
- User wants the full brainstorm → implement → ship experience
- User says "flow", "pipeline", "do everything", "feature complète"
- When `/atlas auto` recommends a multi-skill chain for a feature

## Pipeline

### Phase 1: DISCOVER

**Goal**: Understand the codebase context before designing.

**Actions**:
1. Invoke `context-discovery` skill (auto-scan project)
2. Read relevant files identified by the scan
3. Identify existing patterns, reusable components, API endpoints
4. Present findings summary

**HITL Gate**: AskUserQuestion — "Voici ce que j'ai trouvé dans le codebase. On continue vers le brainstorm?"

**Skip**: User can say "skip discover" if they already know the codebase.

### Phase 2: BRAINSTORM

**Goal**: Explore 2-3 approaches with the user before committing to one.

**Actions**:
1. Invoke `brainstorming` skill
2. Ask questions one at a time (AskUserQuestion)
3. Present 2-3 approaches with comparison tables
4. Show ASCII mockups for UI work
5. Save design document to `.blueprint/designs/`

**HITL Gate**: AskUserQuestion — "Quel approach? (A/B/C)"

**Skip**: User can say "skip brainstorm" → go directly to plan with approach A.

### Phase 3: PLAN

**Goal**: Write a detailed implementation plan.

**Actions**:
1. Invoke `plan-builder` skill (15-section plan, gate 12/15)
2. Optionally invoke `execution-strategy` for model allocation
3. Enter plan mode → present plan for approval

**HITL Gate**: ExitPlanMode → user approves plan

**Skip**: User can say "skip plan" for trivial changes.

### Phase 4: IMPLEMENT

**Goal**: Execute the plan, phase by phase.

**Actions**:
1. Invoke `executing-plans` skill
2. TaskCreate for each phase
3. Code each phase: write → type-check → test
4. Mark tasks complete as they finish

**HITL Gate**: Phase checkpoint reviews (after each plan phase)

**Cannot skip**: Implementation is the core work.

### Phase 5: VERIFY

**Goal**: Ensure everything works before shipping.

**Actions**:
1. Run type-check (`bun run type-check` or `tsc --noEmit`)
2. Run build (`bunx vite build` or equivalent)
3. Run tests (pytest, vitest, or project-specific)
4. Visual QA in browser (if frontend changes)
5. Present verification summary

**HITL Gate**: AskUserQuestion — "Verification passed. Commit?"

**Cannot skip**: Verification is non-negotiable.

### Phase 6: SHIP

**Goal**: Commit, push, and optionally deploy.

**Actions**:
1. Invoke `finishing-branch` skill (commit + PR/merge)
2. If multi-env deploy needed: suggest `ship-all`
3. Present final summary

**HITL Gate**: AskUserQuestion — "Push to remote? Merge to main?"

**Skip**: User can say "stop" to keep changes uncommitted.

## Flow Control

The user can control the flow at any time:

| Command | Effect |
|---------|--------|
| "skip {phase}" | Skip the current phase, move to next |
| "stop" | Pause the flow, save progress to handoff |
| "back" | Go back to previous phase |
| "restart {phase}" | Redo a specific phase |
| "status" | Show current phase and progress |

## Progress Tracking

The flow uses TaskCreate to track progress:

```
[1/6] DISCOVER    ✅ Scanned 42 files, found 3 reusable patterns
[2/6] BRAINSTORM  ✅ Approach B selected (Sheet/Drawer pattern)
[3/6] PLAN        ✅ Plan approved (score 14/15)
[4/6] IMPLEMENT   🔄 Phase 2/4 in progress...
[5/6] VERIFY      ⬜ Pending
[6/6] SHIP        ⬜ Pending
```

## Integration with Other Skills

This skill is a **composition** of existing skills — it doesn't duplicate logic:

| Flow Phase | Invokes Skill | Why Not Inline |
|------------|--------------|----------------|
| DISCOVER | context-discovery | Reuse 8-phase scan logic |
| BRAINSTORM | brainstorming | Reuse AskUserQuestion patterns |
| PLAN | plan-builder + execution-strategy | Reuse 15-section template |
| IMPLEMENT | executing-plans | Reuse TaskCreate + subagent dispatch |
| VERIFY | verification | Reuse L1-L6 test funnel |
| SHIP | finishing-branch or ship-all | Reuse commit + merge logic |

## Non-Negotiable Rules

1. **Every phase has HITL** — the user must approve before moving to next phase
2. **AskUserQuestion only** — never pose questions as free text
3. **TaskCreate visible** — progress must be trackable
4. **No phase can be silent** — always show what you did and found
5. **Handoff on stop** — if user says "stop", create handoff file for resume
