---
name: engineering-ops
description: "Engineering project maintenance + I&C estimation pipeline. 8 subcommands (status, update, links, map, checklist, recalc, plan, toolkit) plus 4-agent estimation chain with HITL gates."
---

# Engineering Ops

## Overview

Two integrated capabilities:
1. **Project Maintenance** — 8 subcommands for I&C/engineering project docs
2. **Estimation Pipeline** — 4-agent sequential chain for I&C cost estimation

**Model strategy:** Sonnet for all agents (data extraction, estimation, QC, deliverables). Opus for synthesis and HITL gate decisions.

Works with any I&C project that has config SSoTs in a `config/` directory. Reusable across projects (THM-012, BRTZ, any mining capital project).

---

## Part 1: Project Maintenance

### Project Detection

Auto-detects active project from:
1. Current working directory (`{PROJECT}-Workspace/` or `04_ESTIMATION_TOOLKIT/`)
2. WORK.md active project section
3. Explicit argument (e.g., `thm-012 status`)
4. Estimation Toolkit detection (`config.py` + `run_estimation.py` present)

### Subcommands

| Command | Description | Time |
|---------|-------------|:----:|
| `status` | Dashboard with metrics (I/O, hours, packages, sprint %) | 5s |
| `update` | Sync documentation metrics across project files | 30s |
| `links [--fix]` | Validate/repair internal links, detect orphan files | 10s |
| `map` | Visualize file structure with cross-references | 5s |
| `checklist [level]` | Interactive maintenance checklist | 5-60m |
| `recalc` | Recalculate I/O via Python script, compare to documented | 30s |
| `plan [init\|sync\|gate\|risk]` | Execution plan management | 5s-5m |
| `toolkit [status\|run\|validate]` | Estimation toolkit operations | 5s-60s |

### status

Read PROJECT-MASTER.md, STATUS-DASHBOARD.md, ESTIMATION-ROADMAP.md. Display:
- I/O count, hours, packages, budget
- Sprint progress bar
- Current phase, next HITL gate
- Blockers, last updated date

### update

1. Read I/O count from source (CSV or recalc)
2. Update PROJECT-MASTER.md Section 1
3. Update STATUS-DASHBOARD.md metrics
4. Update INDEX.md if structure changed
5. Present diff before/after

**HITL Gate:** Confirm via AskUserQuestion if variance > 5%.

### links

Detect broken links and orphan files. Report: valid links, broken links (with location), orphan files.
- `--fix` — auto-remove broken links
- `--strict` — fail if any issues found

### map

Show file structure tree with cross-references between documents.

### checklist

| Level | Duration | Focus |
|-------|:--------:|-------|
| `daily` | 5 min | Status, blockers, sprint progress |
| `weekly` | 15 min | Dashboard sync, links, insights, plan sync |
| `monthly` | 1 hour | Dataflow review, I/O validation |
| `phase` | 30 min | HITL gates, deliverables |
| `quarterly` | 2 hours | Template evolution, lessons learned |

### recalc

Execute Python recalculation script. Compare documented vs calculated I/O by type (AI, AO, DI, DO). Show variance.

**HITL Gate:** Prompt via AskUserQuestion if variance > 5%.

### plan

| Subcommand | Action |
|------------|--------|
| `plan` | Show execution plan status (milestones, risks, next gate) |
| `plan init` | Generate execution plan from project data (hybrid: auto + input) |
| `plan sync` | Synchronize plan with actual progress (triple tracking) |
| `plan gate <id>` | Validate a HITL gate (prerequisites check, decision record) |
| `plan risk` | Interactive risk register (ADD / UPDATE / CLOSE) |

**HITL Gate (plan sync):** If milestone delayed > 3 days, AskUserQuestion for replan.

### toolkit

| Subcommand | Action |
|------------|--------|
| `toolkit status` | Dashboard: instruments, I/O, hours, packages, budget, script version |
| `toolkit run` | Execute full estimation pipeline with validation |
| `toolkit validate` | Check output Excel against GYOW benchmark (I/O ratios, $/IO, hours) |

**HITL Gate (toolkit run):** If validation fails (I/O ratios out of range).

---

## Part 2: Estimation Pipeline (4-Agent Chain)

Sequential pipeline with HITL gates between each step. Works with any I&C project that has config SSoTs.

```
data-extractor → estimation-analyst → qc-validator → deliverable-generator
   (sonnet)          (sonnet)           (sonnet)          (sonnet)
```

### Pre-flight

1. Determine project path (argument, cwd, or ask user)
2. Locate config SSoTs: `config/*.json` or `00_DATA/config/*.json`
3. If no config files found, inform user and stop

### Step 1: Data Extraction (Sonnet)

Extract from project directory:
- Instrument list (tags, types, package assignments)
- I/O counts by type (AI, AO, DI, DO)
- Equipment list with quantities
- P&ID tag references

**HITL Gate:** Present summary (total instruments, I/O breakdown, data quality issues). AskUserQuestion: "Data extraction complete. Proceed to estimation?"

### Step 2: Estimation Calculation (Sonnet)

Using extracted data + config SSoTs:
1. Read labor rates, factors, instrument hours from config
2. Calculate hours per instrument type (Asset x Labor Matrix)
3. Hours per discipline (ENG/INST/PROG) per package
4. Apply factors (productivity, spare I/O, contingency)
5. Apply labor rates, calculate total cost per package
6. Produce Resource Planning table

**HITL Gate:** Present cost summary + Resource Planning table. AskUserQuestion: "Estimation complete. Total: ${total}, {hours} hours. Proceed to QC?"

### Step 3: QC Validation (Sonnet)

Validate against config SSoTs:
1. Verify labor rates match config values
2. Verify factors correctly applied
3. Cross-reference I/O totals (extraction vs calculation)
4. Check for weighted/blended rates (flag as violation)
5. Verify accuracy range for project's FEL stage
6. Compare instrument counts across documents

**HITL Gate:** Present QC report (PASS / WARN / FAIL). If FAIL: AskUserQuestion to decide fix + re-run Step 2 or proceed.

### Step 4: Deliverable Generation (Sonnet)

Generate:
1. **BOE Narrative** — methodology, assumptions, results, annexes
2. **System export CSV** — packages, hours, costs
3. **Package README** with delivery checklist

Use Resource Planning table format (full rates, not weighted).

### Completion

Present final summary: total cost, total hours by discipline, deliverables (file paths), QC status, HITL gates passed.

### Error Recovery

| Error | Action |
|:------|:-------|
| No config files | Ask user for config path or create template |
| Data extraction incomplete | Ask user for missing files, re-run Step 1 |
| QC FAIL on rates | Fix estimation, re-run Steps 2-3 |
| QC FAIL on totals | Investigate delta, present to user |
| Deliverable gen fails | Re-run Step 4 with error context |

## HITL Checkpoints Summary

User confirmation required before:
- Modifying I/O counts or hours
- Archiving or deleting files
- Executing cleanup operations
- Updating validated metrics
- Proceeding between estimation pipeline steps
