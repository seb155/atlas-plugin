---
name: executing-plans
description: "Plan executor with strategy manifests. This skill should be used when the user asks to 'execute the plan', 'run the plan', '/a-dev execute', 'start implementing', or has a written plan ready to drive TaskCreate dispatch."
effort: medium
---

# Executing Plans

## Overview

Execute an engineering plan using the **execution strategy manifest** for optimal model allocation,
parallelism, and cost efficiency. Falls back to sequential execution if no manifest exists.

## Red Flags (rationalization check)

Before starting execution or shortcutting the workflow, ask yourself — are any of these thoughts running? If yes, STOP. Plans deserve critical review BEFORE touching code.

| Thought | Reality |
|---------|---------|
| "I'll read the plan as I go" | Critical review happens upfront. Raise concerns BEFORE Step 2 (TaskCreate). |
| "Skip the manifest, I'll allocate models myself" | Manifest = deterministic cost + parallelism plan. Eyeballing = 2-4x cost. |
| "TaskCreate is ceremonial" | Task list is the visible progress. Without it, mid-session compaction erases state. |
| "These tasks are obviously parallel" | "Obvious" parallelism causes DB race conditions. Use the dependency DAG. |
| "Explore phase is overkill" | Parallel Explore agents (read-only) cut research time 2-3x. Use them. |
| "I can dispatch to Opus for everything" | Override flag `--force-opus` exists for a reason — 5x cost when Sonnet suffices. |
| "Phase gate can wait until end" | HITL gates are in the manifest for a reason. Pause; ask; don't assume approval. |
| "The plan is stale but I'll make it work" | Stale plan = re-run plan-review before executing. 86% overestimate caught 2026-04-18. |

## Process

### Step 1: Load Plan
- Read the plan file (.blueprint/plans/{subsystem}.md or .claude/plans/)
- Review critically — raise concerns BEFORE starting
- If concerns: AskUserQuestion before proceeding

### Step 1.5: Load or Generate Execution Strategy (NEW)

Check for an execution manifest:

```
IF .claude/execution-manifest.json exists AND matches current plan:
  → Load manifest, display strategy summary
ELSE:
  → Invoke execution-strategy skill to generate manifest
  → Display strategy summary (model allocation, parallel groups, cost estimate)
```

**Override flags** (passed through from user):
- `--force-opus`: Override all model allocations to Opus
- `--sequential`: Disable parallel groups
- `--no-team`: Use subagents instead of Agent Teams
- `--budget $X`: Regenerate strategy with cost cap

If user provides overrides → regenerate manifest with flags applied.

### Step 2: Create Task List
- TaskCreate for EACH task in the plan
- Set dependencies (blockedBy) from manifest dependency DAG
- Set metadata: `{ model: "sonnet", mode: "team", group: "G1" }` from manifest
- Mark overall progress visible

### Step 3: Execute Tasks (manifest-driven)

For each task (respecting dependency order from manifest):

**Mode: SOLO** (task.mode == "solo")
1. `TaskUpdate(status: "in_progress")`
2. Execute directly in current session
3. Run verification
4. `TaskUpdate(status: "completed")`

**Mode: SUBAGENT** (task.mode == "subagent")
1. `TaskUpdate(status: "in_progress")`
2. Dispatch via Agent tool with `model: task.model` from manifest
3. Provide full task text + context (don't make subagent read plan)
4. Review output, run verification
5. `TaskUpdate(status: "completed")`

**Mode: TEAM** (task.mode == "team", requires tmux)
1. For the parallel group: create all tasks as `in_progress`
2. Spawn Agent Teams with workers per task
3. Each worker gets: `model: task.model`, `name: task.id`
4. Monitor completion via TaskUpdate notifications
5. After all workers complete: run integration verification
6. Mark all group tasks as `completed`

**Mode: DET** (task.mode == "det")
1. `TaskUpdate(status: "in_progress")`
2. Execute bash command directly (no AI needed)
3. Check exit code
4. `TaskUpdate(status: "completed")`

**HITL Gates** (from manifest):
- After each HITL gate task: pause and AskUserQuestion
- Show progress so far + what's next
- Wait for user approval before continuing

**Approved-Mode Integration** (v6.0.0-alpha.7+, Phase 5 autonomy engine):

Before every `AskUserQuestion` call at a HITL gate, check session-state via `autonomy-gate.sh`:

```bash
# Extract gate info from manifest task
GATE_ID="${task.gate_id:-phase-${phase}-gate}"
TIER="${task.dod_tier:-VALIDATING}"   # CODED | VALIDATING | VALIDATED | SHIPPED
ACTION="${task.action:-}"              # e.g., deploy:production (optional)

if "$CLAUDE_PLUGIN_ROOT/hooks/autonomy-gate.sh" check "$GATE_ID" "$TIER" "$ACTION"; then
  # Gate auto-approved (strict mode or pre-approved gate + skippable tier)
  log_decision "auto-approved via approved-mode"
else
  # Fire AskUserQuestion normally
  AskUserQuestion("Proceed with ${GATE_ID}?", ...)
fi
```

**Rules**:
- If `task.action` matches an immutable always-ask action (destructive, deploy:prod, etc.) → ALWAYS fire AskUserQuestion (autonomy-gate check returns 1)
- If `task.dod_tier` is in `always_ask_tiers: [VALIDATED, SHIPPED]` → ALWAYS fire
- If `autonomy_mode: strict` (default) → ALWAYS fire (safe baseline)
- If `autonomy_mode: approved` + `gate_id` in approved_gates + `tier` in skip_tiers → SKIP

**User activation**: "fais tout", "approuve tout", "full autonomy", or explicit `autonomy-gate.sh set-mode approved` + `autonomy-gate.sh approve <gate_id>`.

**Audit trail**: Every check logged to `.claude/decisions.jsonl` with {ts, gate_id, tier, action, mode, decision}.

Schema: `.blueprint/schemas/session-state-v1.md`

### Step 4: Verify All
- Run full test suite (backend + frontend + type-check)
- Run E2E if specified in plan Section O
- If failures: systematic-debugging skill (max 2 attempts)

### Step 5: Track Costs
- After execution completes, calculate actual token usage
- Compare estimated vs actual costs
- Append to `.claude/strategy-history.jsonl`
- Display cost report

### Step 6: Finish
- Invoke `finishing-branch` skill
- Update .blueprint/plans/INDEX.md if plan was modified

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

## Mega Plan Orchestration

When executing a mega plan (M1-M16 format detected):

### Phase-Level Execution (not task-level)

1. **Load** mega plan -> parse M5 Phase Timeline
2. **For each phase** (P0, P1, ...):
   a. Identify sub-plans assigned to this phase (from M2)
   b. Verify dependencies (M3): all predecessor phases DONE?
   c. Create TaskCreate for each sub-plan in phase
   d. Execute sub-plans (parallel if independent per M3, sequential if dependent)
   e. After each sub-plan completes -> append to MEGA-STATUS.jsonl
3. **Phase gate**: All sub-plans in phase at target DoD tier -> HITL approval
4. Proceed to next phase

### MEGA-STATUS.jsonl Format

Append-only file (git-friendly, one line per status update):
```jsonl
{"date":"YYYY-MM-DD","plan":"sp{nn}","phase":"P{n}","status":"{STATUS}","effort_done_h":{n},"effort_total_h":{n},"note":"{description}"}
```

Status values: `PLANNING` | `IN_PROGRESS` | `CODED` | `VALIDATED` | `DONE`

### Progress Rollup

Programme progress = weighted sum of sub-plan progress by effort:
```
progress = sum(sub_plan_progress * sub_plan_effort) / sum(sub_plan_effort)
```

### Stop Conditions (mega-specific)

- Phase dependency violated -> STOP, show which phases must complete first
- Sub-plan quality < 12/15 -> STOP, invoke plan-review before continuing
- Integration point conflict (IP-N) -> STOP, resolve cross-plan contract
- Programme progress < expected burndown -> warn (not stop)
