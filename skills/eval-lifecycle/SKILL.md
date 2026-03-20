---
name: eval-lifecycle
description: "Full evaluation lifecycle for plugins and codebases. Use when asked to 'evaluate skills', 'run evals', 'benchmark a skill', 'score this codebase', 'check quality', 'regression test', or 'A/B test a skill variant'."
model: opus
effort: high
---

# Eval Lifecycle — SOTA Enterprise Evaluation Platform

## Overview

ATLAS Eval is a dual-mode evaluation engine that scores plugin skills (self-eval) and any codebase (universal eval) using automated structural analysis and LLM-as-Judge behavioral scoring.

**Dual modes**:
- **Plugin mode**: Evaluate SKILL.md quality, agent configs, hook coverage, golden set behavioral scoring
- **Codebase mode**: Auto-discover stack, run configurable dimension rubrics, score any repo

## Evaluation Pipeline

```
DISCOVER → CONFIGURE → EVALUATE → SCORE → REPORT → GATE
```

### Phase 1: DISCOVER (DET)
Detect evaluation target:
- If in atlas-plugin repo → default to plugin mode
- If `.atlas/eval.yaml` exists → load codebase config
- Otherwise → auto-discover stack and apply defaults

### Phase 2: CONFIGURE (HITL)
Present eval configuration to user via AskUserQuestion:
- Mode (plugin / codebase)
- Level (structural / behavioral / full)
- Suite (full / core / custom)
- Skills filter (all or specific)

### Phase 3: EVALUATE (AGENT)
Execute the evaluation:

**Plugin structural** (automated, no API cost):
```bash
python -m evals.runner --mode plugin --level structural --output /tmp/eval.json
```

**Plugin behavioral** (LLM-as-Judge, requires ANTHROPIC_API_KEY):
```bash
python -m evals.runner --mode plugin --level behavioral --suite core --output /tmp/eval.json
```

**Codebase** (hybrid auto-discovery + LLM):
```bash
python -m evals.runner --mode codebase --output /tmp/eval.json
```

### Phase 4: SCORE (DET)
Scoring uses the enterprise-audit rubric pattern:
- Base score: 100 per dimension
- Weighted average → composite (0-100)
- Grade: A (90+), B (80-89), C (70-79), D (60-69), F (<60)
- Regression: flag any score drop > 3 points vs baseline

### Phase 5: REPORT (HITL)
Present results to user:
- Console report with colored grades
- Per-skill/dimension breakdown with deltas
- Regression alerts highlighted
- Ask: "Submit to Synapse DB?" / "Save as baseline?" / "Export report?"

### Phase 6: GATE (DET)
CI/release gate check:
```bash
python -m evals.gate --min-structural 70 --max-regressions 0 /tmp/eval.json
```

## Scoring Dimensions

### Plugin Structural (9 dimensions)

| Dimension | Weight | Description |
|-----------|--------|-------------|
| Body quality | 15% | Line count, sections, code blocks |
| Coherence | 10% | Logical heading order, no orphan refs |
| Completeness | 15% | Required sections present |
| Progressive disclosure | 10% | 3-level structure |
| Cross-references | 10% | All skill/agent refs resolve |
| Token budget | 10% | Context cost within limits |
| HITL coverage | 10% | High-effort skills have gates |
| Tool patterns | 10% | Appropriate tools for skill type |
| Enterprise compliance | 10% | Security, multi-tenant keywords |

### Plugin Behavioral (per skill type)

**Code generation**: correctness (30%), adherence (25%), completeness (20%), style (15%), safety (10%)
**Planning**: structure (25%), coverage (25%), feasibility (20%), actionability (20%), traceability (10%)
**Review**: thoroughness (30%), accuracy (25%), actionability (20%), severity_calibration (15%), evidence (10%)
**Ops**: completeness (25%), safety (25%), correctness (20%), idempotency (15%), observability (15%)

### Codebase (9 default dimensions)

Security (20%), Testing (15%), Code quality (15%), Architecture (12%), Documentation (10%), Dependencies (8%), API surface (8%), Observability (7%), Performance (5%)

## Experiments (A/B Testing)

Run A/B tests on skill variants:
```bash
python -m evals.runner --experiment evals/experiments/tdd-format-test.yaml
```

Experiment config defines variants, golden cases, judge model, and significance threshold.

## Integration Points

- **Synapse API**: POST results to `/api/v1/admin/eval/runs` for dashboard
- **CI**: `.forgejo/workflows/eval-on-pr.yaml` gates PRs on eval scores
- **Baselines**: Version-tracked in `evals/baselines/` for regression detection
- **Dashboard**: Synapse admin → AtlasDev → Eval view
