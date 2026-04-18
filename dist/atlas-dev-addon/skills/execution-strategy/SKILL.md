---
name: execution-strategy
description: "Analyze a plan and produce an optimal execution strategy: model allocation per task, parallel vs sequential, team vs subagent, cost estimation. Auto with override. Bridge between plan-builder and executing-plans."
effort: medium
model: opus
---

# Execution Strategy

**Purpose**: Bridge plan-builder (WHAT) and executing-plans (HOW). Analyzes a plan → **Execution Manifest** with optimal model, mode, parallelism, cost per task.

**Announce**: "Analyzing plan and building execution strategy..."

## Reference Files

| File | Purpose |
|------|---------|
| `manifest-schema.yaml` | Full manifest schema, pricing reference, token heuristics |
| `model-rules.yaml` | Task classification, model defaults, complexity factors, downgrade chain, parallelism rules |

Load these from skill directory to inform Steps 4-7.

## Invocation

```bash
/atlas strategy <plan-path>                    # Explicit
/atlas strategy <plan-path> --force-opus       # All tasks use Opus
/atlas strategy <plan-path> --sequential       # No parallel
/atlas strategy <plan-path> --no-team          # Subagents only, no tmux teams
/atlas strategy <plan-path> --budget $10       # Cap total token cost
/atlas strategy <plan-path> --dry-run          # Show, don't execute
# Auto: when executing-plans detects no manifest, invokes this first
```

## Execution Manifest Schema

Saved to `.claude/execution-manifest.json`, consumed by `executing-plans`.

```json
{
  "$schema": "atlas-execution-manifest-v1",
  "plan": {
    "path": ".blueprint/plans/sp16-test-coverage-60.md",
    "name": "SP-16 Test Coverage",
    "total_effort_h": 40, "total_phases": 5, "total_tasks": 12
  },
  "environment": {
    "hostname": "sgagnon", "tmux_available": true,
    "current_model": "opus-1m", "effort_level": "max",
    "agent_teams_enabled": true, "max_parallel_agents": 4
  },
  "strategy": {
    "mode": "hybrid",
    "parallel_groups": [
      { "group_id": "G1", "tasks": ["P2.1", "P2.2", "P2.3"],
        "reason": "Independent files, no shared state" }
    ],
    "critical_path": ["P1.1", "P2.1", "P3.1", "P4.1"],
    "critical_path_hours": 7,
    "total_hours_sequential": 11, "total_hours_parallel": 7, "speedup_pct": 36
  },
  "tasks": [
    {
      "id": "P1.1", "name": "DB migration", "phase": "P1", "type": "db_migration",
      "model": "sonnet", "mode": "solo",
      "files": ["backend/alembic/versions/xxxx.py"],
      "estimated_tokens": 15000, "estimated_cost_usd": 0.45, "estimated_hours": 1.5,
      "depends_on": [], "blocks": ["P2.1", "P2.2"]
    }
  ],
  "cost_summary": {
    "by_model": {
      "opus": { "tasks": 1, "tokens": 50000, "cost_usd": 1.50 },
      "sonnet": { "tasks": 4, "tokens": 200000, "cost_usd": 1.20 },
      "haiku": { "tasks": 1, "tokens": 20000, "cost_usd": 0.02 },
      "det": { "tasks": 1, "tokens": 0, "cost_usd": 0.00 }
    },
    "total_tokens": 270000, "total_cost_usd": 2.72,
    "vs_all_opus_cost_usd": 22.00, "savings_pct": 88
  },
  "hitl_gates": [
    { "after_task": "P1.1", "reason": "DB migration review before impl" },
    { "after_group": "G1", "reason": "Integration check after parallel group" }
  ],
  "overrides_applied": [],
  "generated_at": "2026-03-27T15:30:00Z"
}
```

## Process (8 Steps)

### Step 1: DETECT Environment

```bash
echo "TMUX=$TMUX SPAWN=$CLAUDE_CODE_SPAWN_BACKEND TEAMS=$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"
hostname -s  # laptop vs VM affects capabilities
# Read current model from settings.json or detect from conversation context
```

Output: `environment` section.

### Step 2: PARSE Plan

Read plan file, extract structured data from Section N (Phases) and O (Verification).

**Rules**: Section N table row = one task | files column = paths touched | dependencies column = task IDs depended on | duration column = hours.

**Task ID convention**: `P{phase}.{task}` (e.g., P1.1, P2.3)

**No Section N table**: STOP, inform user the plan needs phases first.

### Step 3: BUILD Dependency DAG

```
For each task T:
  T.depends_on = explicit deps + implicit:
    - DB migrations before services using new tables
    - Backend services before frontend hooks calling them
    - Type definitions before implementations using them

For each pair (A, B):
  A and B parallel-safe IF:
    - No dependency edge (direct or transitive)
    - No shared files (intersection A.files ∩ B.files = ∅)
    - Neither is git operation (commits always sequential)
    - Neither is DB migration (always sequential)
```

Output: `strategy.parallel_groups` and `strategy.critical_path`.

### Step 4: CLASSIFY Tasks

| Signal in description | Task Type |
|----------------------|-----------|
| "migration", "CREATE TABLE", "ALTER" | `db_migration` |
| "architecture", "design", "diagram" | `architecture` |
| "service", "endpoint", "API", "implement" | `implementation` |
| "hook", "component", "page", "frontend" | `implementation` |
| "test", "pytest", "vitest", "spec" | `testing` |
| "review", "audit", "check" | `review` |
| "lint", "format", "type-check" | `lint` (DET) |
| "search", "explore", "find" | `search` |
| "validate", "verify", "confirm" | `validation` |
| Default | `implementation` |

### Step 5: ALLOCATE Models

```
1. Read ~/.atlas/model-pricing.json
2. Per task:
   a. Get task_type from Step 4
   b. Look up task_type_defaults[task_type] → default model
   c. If --force-opus: use opus
   d. If budget: check fit, downgrade if not
   e. Assign model
```

**Downgrade rules**: Budget < cost with default → try cheaper (opus → sonnet → haiku) | even haiku exceeds → warn, suggest split | Never downgrade architecture/planning below Sonnet | Never assign Haiku to implementation.

### Step 6: DECIDE Execution Mode

Per task group (parallel or single):

```
IF task.type in (lint, format, type_check):
  mode = "det" (bash, no AI)
ELIF group has 1 task:
  mode = "solo" (current session)
ELIF group ≥2 AND tmux AND agent_teams_enabled:
  IF parallel speedup > 20%:
    mode = "team" (tmux Agent Teams)
  ELSE:
    mode = "subagent" (in-process parallel Agent calls)
ELIF group ≥2 AND NOT tmux:
  mode = "subagent"
ELSE:
  mode = "solo"
```

**Tmux economics check**:
```
team_overhead = 2000 tokens (coordination) + 500 × num_workers (context)
solo_time = sum(task.hours)
team_time = max(task.hours) + 0.5h coordination
speedup = (solo_time - team_time) / solo_time

speedup < 0.15 → downgrade to "subagent" (not worth tmux overhead)
```

### Step 7: ESTIMATE Costs

```
estimated_input_tokens = task_complexity_factor × files_count × avg_lines_per_file × 4
  factors: architecture=3.0 | implementation=2.0 | testing=1.5 | validation=1.0 | search=0.5 | lint=0 (DET)

estimated_output_tokens = input × output_ratio
  ratios: architecture=0.8 | implementation=1.5 | testing=1.2 | validation=0.3 | search=0.1

estimated_cost = (input × model.price_input / 1M) + (output × model.price_output / 1M)
```

**Comparison**: Calculate `vs_all_opus_cost` to show savings.

### Step 8: GENERATE Manifest + PRESENT

1. Assemble JSON per schema
2. Save to `.claude/execution-manifest.json`
3. Present strategy summary table (Section G format)
4. `--dry-run`: stop here
5. Auto mode: proceed to executing-plans
6. Interactive: wait for approval/override

## Override Flags

| Flag | Effect |
|------|--------|
| `--force-opus` | All tasks use Opus |
| `--force-sonnet` | All implementation use Sonnet (default) |
| `--sequential` | Disable parallel, all sequential |
| `--no-team` | Subagents only (no tmux) |
| `--budget $X` | Cap total cost; downgrade to fit |
| `--dry-run` | Generate + display, don't execute |
| `--fast` | Aggressive downgrade: cheapest capable per task |
| `--quality` | Conservative: Opus for all non-trivial |

## Integration with Pipeline

### Auto-invocation from executing-plans

When `executing-plans` starts and finds NO `.claude/execution-manifest.json`:
1. Invoke `execution-strategy` on the plan
2. Wait for manifest generation
3. User overrides → regenerate with new flags
4. Proceed to execution

### Pipeline Position

```
plan-builder → [HITL: approve plan]
            → execution-strategy → [AUTO: generate manifest]
            → executing-plans → [ORCHESTRATE: follow manifest]
            → verification → [VERIFY: test all]
            → finishing-branch → [SHIP: commit + PR]
```

### atlas-assist Pipeline Update

```
1. DISCOVER  → context-discovery
2. PLAN      → plan-builder + HITL gate
3. STRATEGY  → execution-strategy (AUTO — no HITL unless budget exceeded)
4. IMPLEMENT → executing-plans (manifest-driven)
5. VERIFY    → verification
6. SHIP      → finishing-branch
```

## Strategy History (Learning)

After execution, append actual results to `.claude/strategy-history.jsonl`:

```jsonl
{"ts":"2026-03-27T15:30:00Z","plan":"sp-16","strategy":"hybrid","est_cost":2.72,"actual_cost":3.10,"est_hours":7,"actual_hours":8.5,"accuracy":0.88,"notes":"P2.2 took longer than estimated (complex auth logic)"}
```

Future calculations calibrate from history: task type consistently slower → adjust complexity factor | model underperforms task type → adjust capability rating | running avg accuracy should trend → 0.90+.

## Non-Negotiable Rules

1. **NEVER skip strategy for plans >10 tasks** — always generate manifest
2. **NEVER assign Haiku to implementation** — minimum Sonnet
3. **NEVER run DB migrations in parallel** — always sequential
4. **NEVER exceed budget without user confirmation** — HITL gate on cost
5. **ALWAYS save manifest before execution** — traceable, debuggable
6. **ALWAYS compare vs all-Opus cost** — show savings
7. **DET over AI for deterministic tasks** — lint, format, type-check = bash
8. **Max 2 recalculations** — overrides keep changing → ask user to decide
