---
name: brainstorming
description: "Collaborative design exploration. 1 question at a time via AskUserQuestion. 2-3 approaches with comparison tables. ASCII mockups. HITL design approval before implementation."
effort: high
---

# Brainstorming Ideas Into Designs

## Overview

Turn ideas into fully formed designs through structured collaborative dialogue.
Explore the project first, then ask questions one at a time to refine the idea.
Present 2-3 approaches with comparison tables. Get approval before implementing.

**Hard gate:** Do NOT write any code, invoke implementation skills, or take action until design is presented and user approves.

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

### 7. After Design Approval
- Write design doc to `docs/plans/YYYY-MM-DD-{topic}-design.md` (or project convention)
- Ask: "Ready to create the implementation plan?"
- Invoke `plan-builder` skill for the detailed engineering plan

## Key Principles

- **One question at a time** — don't overwhelm
- **AskUserQuestion ALWAYS** — never free text questions
- **Multiple choice preferred** — easier to answer
- **YAGNI ruthlessly** — remove unnecessary features
- **Explore alternatives** — ALWAYS 2-3 approaches before settling
- **Visual output** — ASCII diagrams and mockups for every design decision
- **Incremental validation** — present in sections, validate each
- **Emojis for scannability** — headers, status, recommendations
