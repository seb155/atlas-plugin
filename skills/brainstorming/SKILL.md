---
name: brainstorming
description: "Collaborative design exploration. 1 question at a time via AskUserQuestion. 2-3 approaches with comparison tables. ASCII mockups. HITL design approval before implementation."
effort: high
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [plan-builder, context-discovery]
thinking_mode: adaptive
---

# Brainstorming Ideas Into Designs

<HARD-GATE>
Do NOT invoke any implementation skill, write any code, scaffold any project, or take any implementation action until you have presented a design and the user has approved it.
This applies to EVERY project regardless of perceived simplicity.
</HARD-GATE>

<red-flags>
| Thought | Reality |
|---------|---------|
| "This feature is too simple to need a plan" | Simple projects are where unexamined assumptions cause the most wasted work. The plan can be short, but it MUST exist and be approved. "Too simple to plan" precedes 90% of scope-drift incidents. Write a 5-section micro-plan (goal, approach, files touched, tests, rollback). |
| "Let me just start coding and see where it goes" | Coding without a plan = architecting in your prefrontal cortex under tool-use latency. You will burn 10x tokens exploring paths a 15-min plan would have rejected. STOP. Invoke brainstorming skill. Present 2-3 approaches via AskUserQuestion. Wait for design approval. |
| "Plan later, let me prototype first to see if it works" | "Prototype first" = "write production code I will pretend to throw away". You will adapt the prototype, not rewrite it. Prototyping without a plan is planning-by-accretion. Timebox (30 min), named branch (spike/*), explicit "deleted after" commit. Otherwise, plan first. |
| "I know the pattern from last sprint, same plan applies" | Patterns repeat but CONTEXT does not. Tables, personas, constraints, API shape — all different. Reusing a plan verbatim skips the discovery where the gotcha lives. Run context-discovery skill FIRST. Copy template, not content. |
</red-flags>

## Overview

Turn ideas into fully formed designs through structured collaborative dialogue.
Explore the project first, then ask questions one at a time to refine the idea.
Present 2-3 approaches with comparison tables. Get approval before implementing.

## Process

### 1. Understand Context
- Run context-discovery (if not already done)
- Check existing plans for this subsystem (.blueprint/plans/)
- Read recent commits for relevant context
- Identify affected personas

### 2. UX Architecture Gate (MANDATORY for UI/frontend work)
If the task involves UI components, pages, or visual elements, ask these BEFORE any design:

**Q1: Where does this component live?**
- Shared library (`@axoiq/atlas-components`) → reusable across apps
- App-specific (e.g., `frontend/src/pages/`) → single consumer
- New standalone app → separate deployment

**Q2: What existing components can we reuse?**
- Search the codebase for similar patterns (AG Grid, modals, drawers, data providers)
- Check `atlas-components/src/` for existing shared components
- Check `frontend/src/components/` for app-specific patterns
- Present findings via AskUserQuestion: "Reuse X or build new?"

**Q3: How will data flow?**
- Data provider pattern (Context injection) → for shared components
- Direct API calls → for app-specific components
- Props drilling → for small, contained components

**Q4: Who consumes this?**
- Synapse only → app-specific page
- Multiple apps (Synapse + Enterprise Hub + standalone) → shared library
- Present consumer wiring plan with ASCII diagram

Skip this gate ONLY for non-UI work (backend, infra, data).

### 3. Ask Questions (ONE at a time)
- Use AskUserQuestion for EVERY question (never free text)
- Prefer multiple choice when possible
- Open-ended only when choices can't be enumerated
- Focus on: purpose, constraints, success criteria, personas affected

### 4. Explore Approaches
- Propose 2-3 different approaches
- For EACH approach, present:

```
📊 Approach Comparison

| Criteria | Option A: {name} | Option B: {name} | Option C: {name} |
|----------|-------------------|-------------------|-------------------|
| Complexity | {Low/Med/High} | {Low/Med/High} | {Low/Med/High} |
| Performance | {description} | {description} | {description} |
| Maintenance | {description} | {description} | {description} |
| Time | {estimate} | {estimate} | {estimate} |
| Risk | {description} | {description} | {description} |
| ⭐ | {Recommended?} | | |
```

- Lead with your recommendation and explain WHY
- Use AskUserQuestion for the choice

### 5. Present Design
- Break into sections of 200-300 words max
- Ask after each section: "Does this look right?"
- Include:
  - Architecture overview (ASCII diagram)
  - Component breakdown
  - Data flow
  - Error handling approach
  - Testing strategy

### 6. Visual Companion (when helpful)
For UI/UX decisions, always include ASCII mockups:

```
┌──────────────────────────────────────┐
│  Page Title              [Actions]    │
│                                       │
│  {layout with components identified}  │
└──────────────────────────────────────┘
```

### 7. After Design Approval — Write Design Discussion Artifact

Write a structured Design Discussion document that externalizes the shared understanding between the user and the agent. This artifact survives compaction, sessions, and worktrees — it is the source of truth for what was agreed during brainstorming.

**Output path**: `.blueprint/designs/{feature-name}.md`

**Template** (target: 100-250 lines):

```markdown
# Design Discussion: {Feature Name}
> Generated by brainstorming skill | Date: {YYYY-MM-DD}

## Current State
- {Factual description of how relevant code works today — facts only, NO opinions}
- Key files: `{paths to existing code that will be modified or extended}`
- Current patterns: {how similar features are implemented today}

## Desired End State
- {What the user described + requirements inferred during brainstorming}
- Success criteria: {measurable outcomes agreed with user}

## Patterns Found
- ✅ Reuse: `{file path}` — {existing utility/hook/component to leverage}
- ✅ Follow: `{file path}` — {how similar features are currently implemented}
- ⚠️ Anti-pattern: `{file path}` — {do NOT follow this approach, because: {reason}}

## Resolved Decisions
- [x] {Decision 1}: {choice} — rationale: {why, from brainstorm Q&A}
- [x] {Decision 2}: {choice} — rationale: {why}

## Open Questions (for plan-builder to resolve)
- [ ] {Unresolved question that needs deeper research}

## Constraints
- {Domain constraints from CLAUDE.md / engineering chain / enterprise rules}
- {Multi-tenant, security, RBAC, performance requirements}

## Phase Sketch (vertical structure)
Each phase must be an independently testable end-to-end slice.
1. {Phase 1}: {layers touched (e.g., DB+API)} → checkpoint: {what to verify}
2. {Phase 2}: {layers touched (e.g., API+FE)} → checkpoint: {what to verify}
3. {Phase N}: {layers touched} → checkpoint: {what to verify}
```

**Rules**:
- Fill ALL sections — leave none empty (use "N/A — {reason}" if not applicable)
- "Current State" and "Patterns Found" must contain only facts with file paths — zero opinions
- "Resolved Decisions" captures every choice made during brainstorming Q&A
- "Phase Sketch" enforces VERTICAL structure: each phase touches 2+ layers, each has a checkpoint
- Anti-pattern: 3+ consecutive same-layer phases (all DB → all API → all FE)

**After writing the design doc:**
- Present it to user for HITL review via AskUserQuestion: "Review the design discussion. Approve, or tell me what to change."
- Iterate if user requests changes
- After approval → Invoke `plan-builder` skill, noting: "Design doc at `.blueprint/designs/{feature-name}.md`"

## Key Principles

- **One question at a time** — don't overwhelm
- **AskUserQuestion ALWAYS** — never free text questions
- **Multiple choice preferred** — easier to answer
- **YAGNI ruthlessly** — remove unnecessary features
- **Explore alternatives** — ALWAYS 2-3 approaches before settling
- **Visual output** — ASCII diagrams and mockups for every design decision
- **Incremental validation** — present in sections, validate each
- **Emojis for scannability** — headers, status, recommendations
