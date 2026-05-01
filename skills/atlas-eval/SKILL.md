---
name: atlas-eval
description: "LLM-as-judge eval harness for skill regression testing. Use when the user says 'eval skill X', 'regression test skill', 'test skill quality', or when modifying mature skills."
effort: medium
version: 1.0.0
tier: [admin]
---

# atlas-eval — LLM-as-Judge Skill Regression Harness

> Treat skills like production software: golden datasets + automated judging + score thresholds.
> Pattern: input → run skill → capture output → judge against expected → score 0-100 → PASS/FAIL.
> Forward-compat with W3.1 (`regression-test`) and W3.2 (`canary`) — same JSONL schema everywhere.

## When to Use

- User says: "eval skill X", "regression test skill", "test skill quality", "score this skill"
- Before merging changes to a mature skill (e.g., `memory-dream`, `code-review`, `plan-builder`)
- After upgrading judge model (Sonnet/Opus rotation) — re-baseline scores
- Periodic CI: weekly skill-health canary on top-N skills

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ evals/skills/{skill-name}/golden.jsonl  ← test cases         │
│   id, input, expected_output_summary, expected_format,       │
│   weight, tags                                               │
└─────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────┐
│ evals/run.sh {skill-name}                                    │
│   for each entry:                                            │
│     1. invoke claude with skill prompt + input               │
│     2. capture output                                        │
│     3. invoke judge with (output, expected) → JSON score     │
│     4. append result to evals/results/{skill}/{date}.jsonl   │
│   aggregate: avg weighted score, PASS≥80 / FAIL<80           │
└─────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────┐
│ evals/results/{skill-name}/{YYYY-MM-DD}.jsonl                │
│   id, output, score, reasoning, ts, judge_model              │
└─────────────────────────────────────────────────────────────┘
```

## Judge Model Decision

**Default: Sonnet 4.6 medium-effort** (`claude-sonnet-4-6`).

Rationale:
- 97-99% of Opus on coding/reasoning at ~5x cost reduction
- Scoring is bounded reasoning (compare 2 strings against rubric) — not deep architecture
- Bulk eval = cost-sensitive (50+ judgments per skill per run)
- Rotate to Opus 4.7 for final tie-breakers or contested low-scores

**Multi-judge (Phase 2 — design only)**:
- 3 judges: Sonnet 4.6, Haiku 4.5, GPT-4o (provider diversity)
- Voting: median score; flag if std-dev > 15 (judges disagree → human review)
- Meta-rewarding pass: judge-of-judges checks scoring rubric adherence
- Status: not implemented v1; CLI flag `--multi-judge` reserved

## Storage Layout

```
evals/
├── skills/
│   ├── .template/golden.jsonl             # schema reference
│   ├── memory-dream/golden.jsonl          # bootstrap (5 entries)
│   ├── code-review/golden.jsonl           # future
│   └── plan-builder/golden.jsonl          # future
└── results/
    └── {skill-name}/
        └── {YYYY-MM-DD}.jsonl             # per-run results
```

## CLI

```bash
# Run regression for one skill
atlas eval skill-regression memory-dream

# Future: multi-judge mode (Phase 2)
atlas eval skill-regression memory-dream --multi-judge

# Direct invocation
bash evals/run.sh memory-dream

# Dry run (no claude calls — schema validation only)
DRY_RUN=1 bash evals/run.sh memory-dream
```

## Golden Dataset Schema

Each line of `golden.jsonl` is a JSON object:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Unique test case ID (e.g., `dream-happy-1`) |
| `input` | string | yes | Prompt/context fed to the skill under test |
| `expected_output_summary` | string | yes | Key facts the judge looks for (rubric anchor) |
| `expected_format` | string | yes | Format constraint (e.g., "markdown with 3 sections") |
| `weight` | number | yes | Score multiplier (1.0=normal, 1.5=critical, 0.5=nice-to-have) |
| `tags` | string[] | yes | `["happy-path", "edge-case", "regression"]` |

## Scoring Rubric (judge prompt)

The judge receives:
```
You are evaluating a skill output against expected behavior.

INPUT: {input}
ACTUAL OUTPUT: {output}
EXPECTED OUTPUT SUMMARY: {expected_output_summary}
EXPECTED FORMAT: {expected_format}

Score 0-100 based on:
- 50%: factual coverage of expected_output_summary
- 30%: format adherence to expected_format
- 20%: clarity and actionability

Return JSON only: {"score": <int 0-100>, "reasoning": "<one sentence>"}
```

## Aggregation Rules

- **PASS**: weighted average ≥ 80
- **FAIL**: weighted average < 80
- **REGRESSION ALERT**: current score drops > 10 points vs prior 7-day median
- Output: `evals/results/{skill}/{date}.jsonl` + summary line to stdout

## Forward Compatibility

- **W3.1 regression-test**: re-uses `golden.jsonl` schema; runs on PR diff against touched skills
- **W3.2 canary**: same `run.sh` invoked on cron schedule, results posted to monitoring
- **W4 multi-judge**: `--multi-judge` flag flips backend; result schema gets `votes[]` field

## Constraints

- Judge invocations cost real tokens — use sparingly in dev (DRY_RUN=1 default in tests)
- Never check in `evals/results/*.jsonl` (gitignored — runtime artifacts)
- Skill-under-test must be invocable headless via `claude --print` style (or stub)

## References

- `evals/skills/.template/golden.jsonl` — schema reference
- `evals/skills/memory-dream/golden.jsonl` — bootstrap dataset
- `evals/run.sh` — runner
- Plan SSoT: `.blueprint/plans/ultrathink-regarde-ce-qui-abundant-petal.md` Section H W1.5
