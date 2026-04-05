---
name: experiment-loop
description: "Autonomous optimization loop inspired by Karpathy's autoresearch. Loads experiment config, iterates (analyze→mutate→execute→measure→decide), HITL gates on significant changes. Uses experiment-runner agent."
effort: high
---

# Experiment Loop — Autonomous Optimization

Karpathy autoresearch-inspired: defined target → autonomous experimentation → HITL review.

## Invocation

| Command | Action |
|---------|--------|
| `/atlas tune <name>` | Run named experiment |
| `/atlas tune --list` | List available experiments |
| `/atlas tune --history <name>` | Show experiment history |
| `/atlas tune --baseline <name>` | Show/update baseline |

## Experiment Config

Defined in `.claude/assay/experiments.yaml`. Each experiment specifies:

| Field | Purpose |
|-------|---------|
| `target` | What to optimize: `{type: database\|file\|api, table/path, filter}` |
| `metric` | Measurement: `{name, direction: maximize\|minimize, command}` |
| `golden_dataset` | HITL-validated baseline: `{path, description}` |
| `budget` | Limits: `{max_iterations, time_per_iteration, total_timeout}` |
| `hitl` | Gates: `{threshold, auto_accept_below, always_reject_below}` |
| `mutation_strategy` | Approach: `insights\|random\|systematic` + params |
| `model` | `sonnet` (iteration) or `opus` (design/report) |

See existing experiments in `.claude/assay/experiments.yaml` for examples (rule-engine, yolo-pid, omnisearch).

## Execution Flow

### Step 1: LOAD
Read config → validate target/metric/dataset → load or create baseline.
**HITL Gate**: AskUserQuestion to confirm experiment parameters before starting.

### Step 2: BASELINE
Execute metric command → record `{metric, timestamp, config_snapshot}` → save to `.claude/assay/baselines/`.

### Step 3: ITERATE (loop up to max_iterations)

| Phase | Action |
|-------|--------|
| 3a. ANALYZE | Read insights/telemetry, identify lowest-performing element |
| 3b. HYPOTHESIZE | Formulate what to change and why |
| 3c. MUTATE | Apply exactly **ONE** change. Record old/new/reason |
| 3d. EXECUTE | Run metric command (time-boxed) |
| 3e. MEASURE | `delta = new - baseline`, compute improvement % |
| 3f. DECIDE | See decision table below |
| 3g. LOG | Append to `.claude/assay/history/{experiment}-{date}.jsonl` |

**Decision table**:

| Condition | Action |
|-----------|--------|
| `delta < always_reject_below` | ROLLBACK |
| `delta < auto_accept_below` | ACCEPT (quiet) |
| `delta > threshold` | **HITL GATE** — AskUserQuestion: accept/reject/modify |
| Otherwise | ACCEPT (auto) |

### Step 4: REPORT
Generate report → save to `.claude/assay/reports/{experiment}-{date}.md`.
**HITL Gate**: Keep all / rollback to baseline / cherry-pick iterations.

## Integration APIs

| System | Endpoints |
|--------|-----------|
| Rule Engine | `GET /{pid}/rules/insights`, `GET /{pid}/rules/evaluate`, `PUT /{pid}/rules/{id}`, `POST /{pid}/rules/{id}/revert` |
| YOLO (VM 600) | `POST /detect`, SSH: `python train_yolo_pid.py`, `python evaluate.py` |

## Non-Negotiable Rules

1. **ONE mutation per iteration** — isolate variables
2. **Time-boxed** — never exceed budget
3. **HITL gates** — significant changes require human approval
4. **Rollback capability** — every mutation reversible
5. **Structured logging** — every iteration to JSONL
6. **Baseline preservation** — original state always recoverable
7. **DRY_RUN first** — validate metric command before iterating

## Model Strategy

| Phase | Model |
|-------|-------|
| Experiment design, hypotheses, final report | Opus 4.6 |
| Iteration execution (mutations, evaluation) | Sonnet 4.6 |
