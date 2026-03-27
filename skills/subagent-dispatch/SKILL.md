---
name: subagent-dispatch
description: "Dispatch subagents per task with manifest-driven model allocation. 2-stage review: spec compliance then code quality. Supports parallel dispatch for independent tasks. Cost-aware."
effort: medium
---

# Subagent Dispatch

## Overview

Execute plan tasks by dispatching specialized subagents. Each task gets a subagent with the
**model specified by the execution manifest** (default: Sonnet), followed by 2-stage review.

## Model Strategy (Manifest-Driven)

When an execution manifest is available (from `execution-strategy` skill):
- **Read task.model from manifest** → use that model for the subagent
- **Opus**: Architecture, DB migration, cross-system design tasks
- **Sonnet**: Implementation, bug fixes, tests, code review (default)
- **Haiku**: Validation, search, spec checklists (read-only tasks)
- **DET**: Lint, format, type-check (bash command, no subagent needed)

When NO manifest is available (legacy fallback):
- **Implementation subagents**: Sonnet 4.6 (efficient, high quality)
- **Review subagents**: Sonnet 4.6 (spec + quality review)
- **Never**: Haiku for implementation (too shallow)

### Cost Awareness

Before dispatching a subagent, estimate the cost:
```
estimated_tokens = task_files_count * avg_lines * 4 (input) + output_ratio * input
estimated_cost = tokens * model.price_per_token (from ~/.atlas/model-pricing.json)
```

If estimated_cost > $2 (configurable threshold):
- Log warning: "Task {id} estimated at ${cost} with {model}"
- If --budget flag active and would exceed budget: downgrade model or ask user

After subagent completes:
- Log actual token usage (from Agent tool result)
- Append to cost tracking for strategy-history.jsonl

## Per-Task Workflow

### 1. Dispatch Implementer
```
Agent tool:
  subagent_type: general-purpose
  model: task.model  # FROM MANIFEST (was hardcoded "sonnet")
  prompt: "{full task text from plan + context + constraints}"
```

Provide the subagent with:
- Full task text (don't make it read the plan file)
- Relevant file paths and current content
- Test commands to run
- Commit message format

### 2. Handle Subagent Questions
If subagent returns NEEDS_CONTEXT:
- Provide the missing context
- Re-dispatch with additional info

### 3. Spec Compliance Review
Dispatch a review subagent:
```
Agent tool:
  subagent_type: feature-dev:code-reviewer
  model: sonnet
  prompt: "Review this implementation against the spec: {spec text}"
```

Check: Does the code match what the plan specified?
- If issues → implementer fixes → re-review
- Loop until spec compliance ✅

### 4. Code Quality Review
Dispatch quality review:
```
Agent tool:
  subagent_type: feature-dev:code-reviewer
  model: sonnet
  prompt: "Review code quality: {file paths changed}"
```

Check: Is the code well-built?
- If issues → implementer fixes → re-review
- Loop until quality ✅

### 5. Mark Complete
- TaskUpdate(status: "completed")
- Move to next task

## Parallel Independent Tasks

When a plan contains tasks that touch **different files with no shared state**,
those tasks are safe to run in parallel. Multiple Agent tool calls issued in the
**same message** execute concurrently.

### Dependency graph analysis (before dispatching)

Build a simple dependency map from the plan:

```
Task A: backend/services/spec_grouping_service.py    ← no deps
Task B: frontend/src/hooks/use-spec-groups.ts        ← no deps
Task C: frontend/src/pages/SpecGroupPage.tsx         ← depends on B
Task D: tests/test_spec_grouping.py                  ← depends on A

Parallel-safe pairs: (A, B), (A, C if B done), (B if A done, D)
NOT parallel: (A, D) — D reads output of A. (B, C) — C imports B.
```

Tasks A and B share no files → launch in parallel.
Task C depends on B → launch only after B completes.

### Parallel dispatch pattern

```
# PARALLEL — both Agent calls in the same message
Agent 1 (Task A):
  subagent_type: general-purpose
  model: sonnet
  prompt: "Implement the backend service in backend/services/spec_grouping_service.py.
           Full spec: {task_A_text}. Run: pytest tests/services/ -x -q --tb=short"

Agent 2 (Task B):
  subagent_type: general-purpose
  model: sonnet
  prompt: "Implement the TanStack Query hook in frontend/src/hooks/use-spec-groups.ts.
           Full spec: {task_B_text}. Run: bun run type-check"
```

### Safety rules for parallel dispatch

| Safe to parallelize | NOT safe to parallelize |
|---------------------|------------------------|
| Tasks touching different files | Tasks sharing any file |
| Read-only explore agents | Git operations (commit, push, merge) |
| Backend + frontend tasks | DB migrations (run these first, sequential) |
| Independent test suites | Deployment steps |
| Research/search queries | Tasks with explicit `blockedBy` dependency |

### Worktree isolation for file-writing tasks

For tasks that might accidentally conflict, use worktree isolation:

```
Agent tool:
  isolation: "worktree"   # Each agent gets its own git worktree
  subagent_type: general-purpose
  model: sonnet
  prompt: "{task text}"
```

After parallel agents complete: review outputs, resolve any conflicts manually,
then merge into main working branch.

### After parallel completion

1. Collect all agent outputs
2. Run full verification (L1-L4) — see verification skill
3. Proceed with dependent tasks (sequential from this point)

## Rules

- **Dependency-aware**: Build task graph before dispatching. Never assume independence.
- **Sequential for git**: All git ops (commit, push, tag) are always sequential.
- **Sequential for DB**: Migrations always run before any parallel test dispatch.
- **Never skip reviews**: Both spec compliance AND code quality are mandatory.
- **Max 2 review loops**: If still failing after 2 fix rounds → escalate to user.
- **Full context in prompt**: Don't make subagents read plan files — provide full text.
