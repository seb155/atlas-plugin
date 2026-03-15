---
name: brainstorming
description: "Collaborative design exploration. 1 question at a time via AskUserQuestion. 2-3 approaches with comparison tables. ASCII mockups. HITL design approval before implementation."
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

### 2. Ask Questions (ONE at a time)
- Use AskUserQuestion for EVERY question (never free text)
- Prefer multiple choice when possible
- Open-ended only when choices can't be enumerated
- Focus on: purpose, constraints, success criteria, personas affected

### 3. Explore Approaches
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

### 4. Present Design
- Break into sections of 200-300 words max
- Ask after each section: "Does this look right?"
- Include:
  - Architecture overview (ASCII diagram)
  - Component breakdown
  - Data flow
  - Error handling approach
  - Testing strategy

### 5. Visual Companion (when helpful)
For UI/UX decisions, always include ASCII mockups:

```
┌──────────────────────────────────────┐
│  Page Title              [Actions]    │
│                                       │
│  {layout with components identified}  │
└──────────────────────────────────────┘
```

### 6. After Design Approval
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
