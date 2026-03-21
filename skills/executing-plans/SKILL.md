---
name: executing-plans
description: "Execute implementation plans task-by-task. Load plan → TaskCreate per step → execute sequentially → verify after each task. Uses subagents when available."
effort: medium
---

# Executing Plans

## Overview

Execute an engineering plan by working through tasks sequentially.
Each task is tracked with TaskCreate/TaskUpdate. Verification after each task.

## Process

### Step 1: Load Plan
- Read the plan file (.blueprint/plans/{subsystem}.md or .claude/plans/)
- Review critically — raise concerns BEFORE starting
- If concerns: AskUserQuestion before proceeding

### Step 2: Create Task List
- TaskCreate for EACH task in the plan
- Set dependencies (blockedBy) where applicable
- Mark overall progress visible

### Step 3: Execute Tasks (sequentially)
For each task:
1. `TaskUpdate(status: "in_progress")` — BEFORE starting
2. Follow the plan's steps exactly
3. Run verification as specified in the plan
4. `TaskUpdate(status: "completed")` — AFTER verified
5. If blocked: create new task for the blocker, keep current in_progress

### Step 4: Verify All
- Run full test suite (backend + frontend + type-check)
- Run E2E if specified in plan Section O
- If failures: systematic-debugging skill (max 2 attempts)

### Step 5: Finish
- Invoke `finishing-branch` skill
- Update .blueprint/plans/INDEX.md if plan was modified

## Parallel Explore Phase

When a plan requires understanding multiple independent areas of the codebase, launch
2-3 Explore agents **in parallel** before implementation begins. Multiple Agent tool
calls issued in the **same message** execute concurrently.

### When to use
- Plan touches 2+ subsystems (e.g. backend service + frontend hook + DB schema)
- Unclear which existing patterns/hooks can be reused
- Need to map file locations across unrelated directories

### Pattern

```
# PARALLEL — all 3 Agent calls in the same message
Agent 1: "Search backend/services/ for any existing spec_grouping patterns.
          List file paths, class names, and key method signatures."

Agent 2: "Search frontend/src/hooks/ for TanStack Query hooks related to
          instruments or tags. List hook names and their query keys."

Agent 3: "Read .blueprint/PATTERNS.md and summarize the data-fetching and
          form-submission patterns relevant to a new CRUD page."
```

### Consolidation (after all 3 complete)
1. Merge findings into a shared context block
2. Identify reusable hooks/utils — prefer extend over duplicate
3. Resolve conflicts (e.g. two agents found the same pattern via different paths)
4. **Then** begin implementation (sequential from this point)

### Safety rules
- Explore agents are **read-only** — no writes, no git ops
- If 2 agents might read the same file, that is fine (reads are safe in parallel)
- Never launch parallel agents that write to overlapping files

## Subagent Strategy

If subagents are available (Claude Code):
- **Phase 1 — Explore** (parallel): 2-3 Explore agents per subsystem area
- **Phase 2 — Implement** (sequential per task): 1 Sonnet subagent per task
- Provide full task text + consolidated explore results in the prompt
- After each subagent completes: review output, run verification

If no subagents:
- Execute tasks directly in current session
- Commit after each task

## Stop Conditions

STOP and AskUserQuestion if:
- Hit a blocker (missing dependency, unclear instruction)
- Test fails after 2 fix attempts
- Plan has critical gaps
- Working on main/master without explicit consent
- Scope seems larger than planned

## Task Tracking

```
📋 Execution Progress

| # | Task | Status | Notes |
|---|------|--------|-------|
| 1 | DB migration | ✅ | alembic upgrade head |
| 2 | Backend service | ⏳ | in progress |
| 3 | API endpoints | ⬜ | blocked by #2 |
| 4 | Frontend page | ⬜ | |
| 5 | Tests | ⬜ | |
```

Update this table as you progress.
