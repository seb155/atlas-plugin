---
name: executing-plans
description: "Execute implementation plans task-by-task. Load plan → TaskCreate per step → execute sequentially → verify after each task. Uses subagents when available."
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

## Subagent Strategy

If subagents are available (Claude Code):
- Dispatch 1 Sonnet subagent per task
- Provide full task text + context in the prompt (don't make subagent read files)
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
