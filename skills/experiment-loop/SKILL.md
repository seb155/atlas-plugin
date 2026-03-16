---
name: experiment-loop
description: "Autonomous optimization loop inspired by Karpathy's autoresearch. Loads experiment config, iterates (analyze→mutate→execute→measure→decide), HITL gates on significant changes. Uses experiment-runner agent."
---

# Experiment Loop — Autonomous Optimization

Inspired by [Karpathy's autoresearch](https://github.com/karpathy/autoresearch): give an AI agent a well-defined optimization target, let it experiment autonomously, and review improvements via HITL gates.

## Invocation

```
/atlas tune <experiment-name>        # Run a named experiment
/atlas tune --list                    # List available experiments
/atlas tune --history <experiment>    # Show experiment history
/atlas tune --baseline <experiment>   # Show/update baseline
```

## Experiment Config

Experiments are defined in `.claude/assay/experiments.yaml`:

```yaml
experiments:
  rule-engine:
    description: "Optimize synapse_rules classification accuracy"
    target:
      type: database          # database | file | api
      table: synapse_rules    # or file path for type=file
      filter: "category = 'classification' AND is_active = true"
    metric:
      name: classification_accuracy
      direction: maximize     # maximize | minimize
      command: |
        curl -s http://localhost:8001/api/v1/projects/{project_id}/rules/evaluate \
          | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['accuracy'])"
    golden_dataset:
      path: .claude/assay/baselines/rules-baseline.json
      description: "THM-012 HITL-validated instrument classifications"
    budget:
      max_iterations: 12
      time_per_iteration: 5m
      total_timeout: 60m
    hitl:
      threshold: 0.02         # HITL gate if improvement > 2%
      auto_accept_below: 0.005 # Auto-accept if improvement < 0.5%
      always_reject_below: -0.001 # Always reject if metric degrades
    mutation_strategy:
      approach: insights       # insights | random | systematic
      api: "GET /rules/insights"  # API to get suggestions
    model: sonnet              # sonnet | opus

  yolo-pid:
    description: "Optimize YOLO P&ID detection accuracy"
    target:
      type: file
      path: infrastructure/services/yolo-pid/config/training.yaml
    metric:
      name: "mAP@0.5"
      direction: maximize
      command: |
        ssh root@192.168.10.55 "cd /root/local-ai/yolo-pid && python evaluate.py --weights best.pt"
    golden_dataset:
      path: .claude/assay/baselines/yolo-baseline.json
      description: "118 pages, 7401 labels (80/20 val split)"
    budget:
      max_iterations: 6
      time_per_iteration: 30m
      total_timeout: 180m
    hitl:
      threshold: 0.01
      always_reject_below: -0.005
    mutation_strategy:
      approach: systematic
      parameters:
        - augmentation.degrees: [0, 2, 5, 10]
        - augmentation.mosaic: [0.3, 0.5, 0.7]
        - model.depth_multiple: [0.33, 0.5, 0.67]
    model: opus

  omnisearch:
    description: "Optimize ParadeDB BM25 search relevance"
    target:
      type: database
      table: search_config
    metric:
      name: "NDCG@10"
      direction: maximize
      command: "python3 scripts/eval_search.py --queries .claude/assay/baselines/search-queries.json"
    budget:
      max_iterations: 20
      time_per_iteration: 1m
    hitl:
      threshold: 0.05
    mutation_strategy:
      approach: systematic
      parameters:
        - field_weights.tag_number: [1.0, 2.0, 5.0, 10.0]
        - field_weights.description: [0.5, 1.0, 2.0]
        - boost.exact_match: [2.0, 5.0, 10.0]
```

## Execution Flow

### Step 1: LOAD

```
1. Read .claude/assay/experiments.yaml
2. Find experiment by name
3. Validate config (target exists, metric command works, golden dataset accessible)
4. Load baseline (or create if first run)
```

**HITL Gate**: AskUserQuestion to confirm experiment parameters:
```
"Starting experiment 'rule-engine':
 Target: synapse_rules (classification rules)
 Metric: classification_accuracy (maximize)
 Budget: 12 iterations × 5 min = ~60 min max
 HITL: Approve changes > 2% improvement

 Run experiment?"
```

### Step 2: BASELINE

```
1. Execute metric command against current state
2. Record as baseline: { metric: X, timestamp: T, config_snapshot: {...} }
3. Save to .claude/assay/baselines/{experiment}-baseline.json
```

### Step 3: ITERATE (loop)

For each iteration (up to budget.max_iterations):

```
┌─────────────────────────────────────────────────────┐
│  3a. ANALYZE — Read current insights/telemetry      │
│      • API: GET /rules/insights (rule-engine)       │
│      • Or: read previous iteration results          │
│      • Identify lowest-performing element            │
│                                                      │
│  3b. HYPOTHESIZE — Formulate what to change         │
│      • "Rule X has 45% success rate because..."     │
│      • "Changing condition from == to in should..."  │
│                                                      │
│  3c. MUTATE — Apply exactly ONE change              │
│      • Database: UPDATE synapse_rules SET ...        │
│      • File: Edit config parameter                   │
│      • Record: old_value, new_value, reason          │
│                                                      │
│  3d. EXECUTE — Run evaluation                       │
│      • Execute metric command                        │
│      • Wait for completion (time-boxed)              │
│                                                      │
│  3e. MEASURE — Compare vs baseline                  │
│      • delta = new_metric - baseline_metric          │
│      • improvement_pct = delta / baseline * 100      │
│                                                      │
│  3f. DECIDE                                          │
│      • If delta < always_reject_below → ROLLBACK    │
│      • If delta < auto_accept_below → ACCEPT (quiet)│
│      • If delta > threshold → HITL GATE (ask user)  │
│      • Otherwise → ACCEPT (auto)                    │
│                                                      │
│  3g. LOG — Record to history                        │
│      • .claude/assay/history/{experiment}-{date}.jsonl│
│      • { iteration, hypothesis, mutation, old, new, │
│        delta, decision, timestamp }                  │
└─────────────────────────────────────────────────────┘
```

**HITL Gate** (when delta > threshold):
```
AskUserQuestion: "Iteration 4 of rule-engine:
 Change: Rule 'classify_ZSO' condition updated (== → in)
 Metric: accuracy 87.3% → 89.5% (+2.2%)
 This exceeds the 2% HITL threshold.

 Accept this improvement?"
 Options: [Accept, Reject and rollback, Modify and re-test]
```

### Step 4: REPORT

After all iterations (or budget exhausted):

```
Generate experiment report:
- Total iterations: N
- Accepted changes: M
- Baseline: X → Final: Y (+Z%)
- Best iteration: #K (+W%)
- Rejected mutations: list with reasons
- Recommendations for next experiment run

Save to: .claude/assay/reports/{experiment}-{date}.md
```

**HITL Gate** (final):
```
AskUserQuestion: "Experiment 'rule-engine' complete:
 12 iterations | 7 accepted | 5 rejected
 Accuracy: 85.2% → 91.8% (+6.6%)

 Keep all changes or rollback to baseline?"
 Options: [Keep all, Rollback to baseline, Cherry-pick specific iterations]
```

## Experiment History Format (.jsonl)

```json
{"iteration": 1, "timestamp": "2026-03-15T20:30:00Z", "hypothesis": "Rule X low success due to narrow condition", "mutation": {"rule_id": "abc", "field": "condition", "old": {"==": "ZSO"}, "new": {"in": ["ZSO", "ZSC"]}}, "metric_before": 0.852, "metric_after": 0.865, "delta": 0.013, "decision": "auto_accept", "reason": "improvement < hitl threshold"}
```

## Integration with Existing APIs

### Rule Engine (Synapse)
- `GET /{pid}/rules/insights` — Find low-success rules
- `GET /{pid}/rules/evaluate` — Dry-run evaluation
- `PUT /{pid}/rules/{id}` — Update rule (creates version)
- `POST /{pid}/rules/{id}/revert` — Rollback

### YOLO (VM 600)
- `POST /detect` — Run detection
- SSH: `python train_yolo_pid.py` — Train model
- SSH: `python evaluate.py` — Evaluate model

## Non-Negotiable Rules

1. **ONE mutation per iteration** — isolate variables
2. **Time-boxed** — never exceed budget
3. **HITL gates** — significant changes require human approval
4. **Rollback capability** — every mutation must be reversible
5. **Structured logging** — every iteration logged to JSONL
6. **Baseline preservation** — original state always recoverable
7. **DRY_RUN first** — always validate metric command works before iterating

## Model Strategy

- **Experiment design** (analyzing insights, forming hypotheses): Opus 4.6
- **Iteration execution** (mutations, evaluation): Sonnet 4.6 (via experiment-runner agent)
- **Final report**: Opus 4.6 (synthesis + recommendations)
