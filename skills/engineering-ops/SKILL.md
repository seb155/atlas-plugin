---
name: engineering-ops
description: "Engineering project maintenance + I&C estimation pipeline. 8 subcommands (status, update, links, map, checklist, recalc, plan, toolkit) plus 4-agent estimation chain with HITL gates."
effort: high
---

# Engineering Ops

Two capabilities: **Project Maintenance** (8 subcommands) + **Estimation Pipeline** (4-agent chain).

**Model**: Sonnet for all agents. Opus for synthesis + HITL decisions.
**Scope**: Any I&C project with config SSoTs in `config/` directory.

## Project Detection

Auto-detects from: CWD (`{PROJECT}-Workspace/` or `04_ESTIMATION_TOOLKIT/`) → WORK.md → explicit arg → toolkit files (`config.py` + `run_estimation.py`).

---

## Part 1: Subcommands

| Command | Description | HITL Gate |
|---------|-------------|-----------|
| `status` | Dashboard: I/O, hours, packages, sprint %, blockers | - |
| `update` | Sync metrics across PROJECT-MASTER, STATUS-DASHBOARD, INDEX | If variance > 5% |
| `links [--fix\|--strict]` | Validate/repair links, detect orphans | - |
| `map` | File structure tree with cross-references | - |
| `checklist <level>` | Interactive maintenance (daily/weekly/monthly/phase/quarterly) | - |
| `recalc` | Run Python recalc, compare documented vs calculated I/O | If variance > 5% |
| `plan [init\|sync\|gate\|risk]` | Execution plan management (milestones, triple tracking, risk register) | If milestone delayed > 3d |
| `toolkit [status\|run\|validate]` | Estimation toolkit operations, GYOW benchmark validation | If validation fails |

### Checklist Levels

| Level | Duration | Focus |
|-------|:--------:|-------|
| `daily` | 5 min | Status, blockers, sprint |
| `weekly` | 15 min | Dashboard sync, links, insights |
| `monthly` | 1 hour | Dataflow review, I/O validation |
| `phase` | 30 min | HITL gates, deliverables |
| `quarterly` | 2 hours | Template evolution, lessons learned |

---

## Part 2: Estimation Pipeline (4-Agent Chain)

```
data-extractor → estimation-analyst → qc-validator → deliverable-generator
   (sonnet)          (sonnet)           (sonnet)          (sonnet)
```

**Pre-flight**: Locate project path + config SSoTs (`config/*.json` or `00_DATA/config/*.json`). No config = stop.

| Step | Agent | Action | HITL Gate |
|------|-------|--------|-----------|
| 1 | Data Extractor | Extract instruments, I/O by type, equipment, P&ID refs | Present summary → "Proceed to estimation?" |
| 2 | Estimation Analyst | Hours per type (Asset x Labor Matrix), factors, rates, cost per package, Resource Planning table | Present total cost + hours → "Proceed to QC?" |
| 3 | QC Validator | Verify rates vs config, factors applied, I/O cross-ref, FEL accuracy, no blended rates | Report PASS/WARN/FAIL → if FAIL: fix or proceed? |
| 4 | Deliverable Gen | BOE narrative + system CSV + package README | Present final summary |

## Error Recovery

| Error | Action |
|-------|--------|
| No config files | Ask user for path or create template |
| Incomplete extraction | Ask for missing files, re-run Step 1 |
| QC FAIL (rates) | Fix estimation, re-run Steps 2-3 |
| QC FAIL (totals) | Investigate delta, present to user |
| Deliverable gen fails | Re-run Step 4 with error context |

## HITL Checkpoints (NON-NEGOTIABLE)

User confirmation required before: modifying I/O counts/hours, archiving/deleting files, cleanup operations, updating validated metrics, proceeding between estimation steps.
