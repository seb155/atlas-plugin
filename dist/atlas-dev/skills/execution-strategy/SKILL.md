---
name: execution-strategy
description: "Analyze a plan and produce an optimal execution strategy: model allocation per task, parallel vs sequential, team vs subagent, cost estimation. Auto with override. Bridge between plan-builder and executing-plans."
effort: medium
model: opus
---

# Execution Strategy

**Purpose**: Bridge the gap between plan-builder (WHAT to do) and executing-plans (HOW to do it).
Analyzes a plan and produces an **Execution Manifest** — a structured strategy that determines the
optimal model, execution mode, parallelism, and cost for each task.

**Announce**: "Analyzing plan and building execution strategy..."

## Reference Files

| File | Purpose |
|------|---------|
| `manifest-schema.yaml` | Full manifest schema with field docs, pricing reference, token heuristics |
| `model-rules.yaml` | Task classification signals, model defaults, complexity factors, downgrade chain, parallelism rules |

Load these YAML files from the skill directory to inform Steps 4-7 below.

## Invocation

```bash
# Explicit
/atlas strategy <plan-path>
/atlas strategy .blueprint/plans/sp16-test-coverage-60.md

# With overrides
/atlas strategy <plan-path> --force-opus      # All tasks use Opus
/atlas strategy <plan-path> --sequential      # No parallel groups
/atlas strategy <plan-path> --no-team         # Subagents only, no tmux teams
/atlas strategy <plan-path> --budget $10      # Cap total token cost
/atlas strategy <plan-path> --dry-run         # Show strategy, don't execute

# Auto-invocation (from executing-plans pipeline)
# When executing-plans detects no manifest, it invokes this skill first
```

## Execution Manifest Schema

The manifest is the structured output of this skill. It is saved to `.claude/execution-manifest.json`
and consumed by `executing-plans`.

```json
{
  "$schema": "atlas-execution-manifest-v1",
  "plan": {
    "path": ".blueprint/plans/sp16-test-coverage-60.md",
    "name": "SP-16 Test Coverage",
    "total_effort_h": 40,
    "total_phases": 5,
    "total_tasks": 12
  },
  "environment": {
    "hostname": "sgagnon",
    "tmux_available": true,
    "current_model": "opus-1m",
    "effort_level": "max",
    "agent_teams_enabled": true,
    "max_parallel_agents": 4
  },
  "strategy": {
    "mode": "hybrid",
    "parallel_groups": [
      {
        "group_id": "G1",
        "tasks": ["P2.1", "P2.2", "P2.3"],
        "reason": "Independent files, no shared state"
      }
    ],
    "critical_path": ["P1.1", "P2.1", "P3.1", "P4.1"],
    "critical_path_hours": 7,
    "total_hours_sequential": 11,
    "total_hours_parallel": 7,
    "speedup_pct": 36
  },
  "tasks": [
    {
      "id": "P1.1",
      "name": "DB migration",
      "phase": "P1",
      "type": "db_migration",
      "model": "opus",
      "mode": "solo",
      "files": ["backend/alembic/versions/xxxx.py"],
      "estimated_tokens": 15000,
      "estimated_cost_usd": 0.45,
      "estimated_hours": 1.5,
      "depends_on": [],
      "blocks": ["P2.1", "P2.2"]
    }
  ],
  "cost_summary": {
    "by_model": {
      "opus": { "tasks": 1, "tokens": 50000, "cost_usd": 1.50 },
      "sonnet": { "tasks": 4, "tokens": 200000, "cost_usd": 1.20 },
      "haiku": { "tasks": 1, "tokens": 20000, "cost_usd": 0.02 },
      "det": { "tasks": 1, "tokens": 0, "cost_usd": 0.00 }
    },
    "total_tokens": 270000,
    "total_cost_usd": 2.72,
    "vs_all_opus_cost_usd": 22.00,
    "savings_pct": 88
  },
  "hitl_gates": [
    { "after_task": "P1.1", "reason": "DB migration review before implementation" },
    { "after_group": "G1", "reason": "Integration check after parallel group" }
  ],
  "overrides_applied": [],
  "generated_at": "2026-03-27T15:30:00Z"
}
```

## Process (8 Steps)

### Step 1: DETECT Environment

Detect runtime capabilities before analyzing the plan.

```bash
# Check tmux availability
echo "TMUX=$TMUX SPAWN=$CLAUDE_CODE_SPAWN_BACKEND TEAMS=$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"

# Check current model
# Read from settings.json or detect from conversation context

# Check hostname (laptop vs VM affects capabilities)
hostname -s
```

Output: `environment` section of manifest.

### Step 2: PARSE Plan

Read the plan file and extract structured data from sections N (Phases) and O (Verification).

**Parsing rules**:
- Section N table: extract phase, content, files, duration, dependencies
- Each row in the phase table = one task
- Files column = list of file paths this task touches
- Dependencies column = task IDs this task depends on
- Duration column = estimated hours

**Task ID convention**: `P{phase}.{task}` (e.g., P1.1, P2.3)

**If plan has no Section N table**: STOP and inform user the plan needs phases before strategy can be built.

### Step 3: BUILD Dependency DAG

From parsed tasks, build a directed acyclic graph:

```
For each task T:
  T.depends_on = explicit deps from plan + implicit deps:
    - DB migrations before services that use new tables
    - Backend services before frontend hooks that call them
    - Type definitions before implementations that use them

For each pair (A, B):
  A and B are parallel-safe IF:
    - No dependency edge between them (direct or transitive)
    - No shared files (intersection of A.files and B.files = empty)
    - Neither is a git operation (commits are always sequential)
    - Neither is a DB migration (always sequential)
```

Output: `strategy.parallel_groups` and `strategy.critical_path`.

### Step 4: CLASSIFY Tasks

Assign a task type based on content analysis:

| Signal in task description | Task Type |
|---------------------------|-----------|
| "migration", "CREATE TABLE", "ALTER" | `db_migration` |
| "architecture", "design", "diagram" | `architecture` |
| "service", "endpoint", "API", "implement" | `implementation` |
| "hook", "component", "page", "frontend" | `implementation` |
| "test", "pytest", "vitest", "spec" | `testing` |
| "review", "audit", "check" | `review` |
| "lint", "format", "type-check" | `lint` (DET) |
| "search", "explore", "find" | `search` |
| "validate", "verify", "confirm" | `validation` |
| Default (no strong signal) | `implementation` |

### Step 5: ALLOCATE Models

For each task, assign a model using the pricing config:

```
1. Read ~/.atlas/model-pricing.json
2. For each task:
   a. Get task_type from Step 4
   b. Look up task_type_defaults[task_type] → default model
   c. If override flag (--force-opus): use opus
   d. If budget constraint: check if default model fits budget, downgrade if not
   e. Assign model to task
```

**Cost-aware downgrade rules**:
- If remaining budget < task estimated cost with default model:
  - Try next cheaper model (opus → sonnet → haiku)
  - If even haiku exceeds budget: warn user, suggest splitting task
- Never downgrade architecture/planning tasks below Sonnet
- Never assign Haiku to implementation tasks

### Step 6: DECIDE Execution Mode

For each task group (parallel group or single task):

```
Decision tree:
  IF task.type in (lint, format, type_check):
    mode = "det" (bash command, no AI)
  ELIF group has 1 task:
    mode = "solo" (current session)
  ELIF group has 2+ tasks AND tmux available AND agent_teams_enabled:
    IF parallel speedup > 20%:
      mode = "team" (tmux Agent Teams)
    ELSE:
      mode = "subagent" (in-process, parallel Agent calls)
  ELIF group has 2+ tasks AND NOT tmux:
    mode = "subagent"
  ELSE:
    mode = "solo"
```

**Tmux economics check** (when team mode considered):
```
team_overhead = 2000 tokens (coordination) + 500 * num_workers (context per worker)
solo_time = sum(task.hours for task in group)
team_time = max(task.hours for task in group) + 0.5h (coordination)
speedup = (solo_time - team_time) / solo_time

IF speedup < 0.15 (less than 15% time savings):
  downgrade to "subagent" (not worth tmux overhead)
```

### Step 7: ESTIMATE Costs

For each task:
```
estimated_input_tokens = task_complexity_factor * files_count * avg_lines_per_file * 4
  where task_complexity_factor:
    architecture = 3.0
    implementation = 2.0
    testing = 1.5
    validation = 1.0
    search = 0.5
    lint = 0 (DET, no tokens)

estimated_output_tokens = estimated_input_tokens * output_ratio
  where output_ratio:
    architecture = 0.8 (lots of reasoning)
    implementation = 1.5 (more output than input)
    testing = 1.2
    validation = 0.3
    search = 0.1

estimated_cost = (input_tokens * model.price_input / 1M) + (output_tokens * model.price_output / 1M)
```

**Comparison**: Also calculate `vs_all_opus_cost` to show savings.

### Step 8: GENERATE Manifest + PRESENT

1. Assemble all data into the manifest JSON schema
2. Save to `.claude/execution-manifest.json`
3. Present strategy summary table (see Section G format)
4. If `--dry-run`: stop here
5. If auto mode: proceed to executing-plans
6. If interactive: wait for user approval or override

## Override Flags

| Flag | Effect |
|------|--------|
| `--force-opus` | All tasks use Opus (overrides model allocation) |
| `--force-sonnet` | All implementation tasks use Sonnet (default behavior) |
| `--sequential` | Disable parallel groups, execute all tasks sequentially |
| `--no-team` | Use subagents instead of Agent Teams (no tmux) |
| `--budget $X` | Cap total estimated cost; downgrade models to fit |
| `--dry-run` | Generate and display strategy but don't execute |
| `--fast` | Aggressive model downgrade: use cheapest capable model per task |
| `--quality` | Conservative: use Opus for all non-trivial tasks |

## Integration with Pipeline

### Auto-invocation from executing-plans

When `executing-plans` starts and finds NO `.claude/execution-manifest.json`:
1. Invoke `execution-strategy` skill on the plan
2. Wait for manifest generation
3. If user overrides: regenerate with new flags
4. Proceed to execution with manifest

### Pipeline position

```
plan-builder → [HITL: approve plan]
            → execution-strategy → [AUTO: generate manifest]
            → executing-plans → [ORCHESTRATE: follow manifest]
            → verification → [VERIFY: test all]
            → finishing-branch → [SHIP: commit + PR]
```

### atlas-assist pipeline update

The `atlas-assist` skill pipeline should be updated to include STRATEGY phase:

```
1. DISCOVER  → context-discovery
2. PLAN      → plan-builder + HITL gate
3. STRATEGY  → execution-strategy (AUTO — no HITL unless budget exceeded)
4. IMPLEMENT → executing-plans (manifest-driven)
5. VERIFY    → verification
6. SHIP      → finishing-branch
```

## Strategy History (Learning)

After each execution completes, append actual results to `.claude/strategy-history.jsonl`:

```jsonl
{"ts":"2026-03-27T15:30:00Z","plan":"sp-16","strategy":"hybrid","est_cost":2.72,"actual_cost":3.10,"est_hours":7,"actual_hours":8.5,"accuracy":0.88,"notes":"P2.2 took longer than estimated (complex auth logic)"}
```

Future strategy calculations can use this history to calibrate estimates:
- If a task type consistently takes longer than estimated → adjust complexity factor
- If a model consistently underperforms on a task type → adjust capability rating
- Running average accuracy should trend toward 0.90+

## Non-Negotiable Rules

1. **NEVER skip strategy for plans > 10 tasks** — always generate manifest
2. **NEVER assign Haiku to implementation tasks** — minimum Sonnet
3. **NEVER run DB migrations in parallel** — always sequential
4. **NEVER exceed budget without user confirmation** — HITL gate on cost
5. **ALWAYS save manifest before execution** — traceable, debuggable
6. **ALWAYS compare vs all-Opus cost** — show savings to justify strategy
7. **DET over AI for deterministic tasks** — lint, format, type-check = bash
8. **Max 2 recalculations** — if overrides keep changing, ask user to decide
