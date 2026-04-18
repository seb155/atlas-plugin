# ATLAS v6.0 Benchmark Guide — Cost/Accuracy A/B

> Measure v6.0.0-alpha.2 improvements vs v5.23.0 baseline.
> Harness is offline (no real API calls) — pairs with user-driven session runs for cost side.

## Hypothesis

Per the v6.0 plan success criteria:

| Metric       | Baseline (v5.23.0) | Target (v6.0)    | Delta          |
|--------------|--------------------|------------------|----------------|
| Accuracy     | ~0% (no heuristic) | ≥25% absolute    | ≥ +25% abs     |
| Cost/query   | X tokens           | ≤ 1.15 × X       | ≤ +15%         |
| Effort-route | N/A                | auto-classified  | new capability |

The 23KB SessionStart payload and adaptive thinking overhead in v6 are expected
to add <15% tokens per query while delivering substantially better task routing.

## Harness

`scripts/benchmark-v6.sh` runs 14 standardized prompts through
`scripts/execution-philosophy/effort-heuristic.sh` and reports:

- per-prompt resolved effort level (`low|medium|high|xhigh|max|auto`)
- match vs expected (ground truth baked into the corpus)
- per-prompt latency in ms
- aggregate accuracy and avg latency
- quality gate: exit 2 if accuracy < 70%

```bash
./scripts/benchmark-v6.sh
# Writes: tests/benchmark-results/bench-<version>-<timestamp>.json
```

### Corpus

14 prompts distributed across 5 effort buckets:

| Bucket | Count | Examples                                            |
|--------|-------|-----------------------------------------------------|
| low    | 3     | commit + push, bump version, grep for TODOs         |
| medium | 3     | review PR, explain atlas-loop, document endpoints   |
| high   | 3     | implement JWT, add dark-mode toggle, fix login bug  |
| xhigh  | 3     | debug race condition, optimize slow query, migrate  |
| max    | 2     | design event-sourcing architecture, ultrathink plan |

Counts match the distribution targets documented in `effort-heuristic.sh`
(~15% MAX, ~25% XHIGH, ~30% HIGH, ~20% MEDIUM, ~10% LOW), scaled to a
14-prompt corpus.

## A/B procedure

### Round 1 — v5.23.0 baseline

v5.23.0 shipped without `effort-heuristic.sh`, so:

- **Accuracy baseline: 0%** (no routing existed; every task defaulted to CLI heuristic)
- **Cost baseline:** run 10 standard queries on a real v5.23.0 session, capture
  `tokens_in` and `tokens_out` from CC telemetry or session JSONL files, record
  avg tokens per query.

### Round 2 — v6.0.0-alpha.2

```bash
# From this worktree (or a checkout at v6.0.0-alpha.2):
./scripts/benchmark-v6.sh
# Read accuracy and latency from the printed summary + JSON
```

Run the same 10 standard queries on a real v6 session, capture avg tokens.

### Compare

| Metric        | Formula                                              |
|---------------|------------------------------------------------------|
| Accuracy gain | v6 accuracy − 0%                                     |
| Cost delta    | (v6 avg tokens − v5 avg tokens) / v5 avg tokens × 100|

### Success criteria

- **Accuracy**: `≥25% absolute` — v6 routes correctly ≥25% of tasks in the corpus
  (current measured: 100% on the tuned corpus; real-world will be lower).
- **Cost**: `≤+15%` tokens per equivalent query — SessionStart injection plus
  adaptive thinking overhead must not exceed the budget.

## Current measured performance

On the bundled 14-prompt corpus:

- Accuracy: **14/14 (100%)**
- Avg latency: **~26ms** per routing decision
- Throughput: ~38 classifications/sec (single-threaded bash + grep)

The 100% rate is expected because the corpus is tuned against the heuristic's
keyword buckets. Real-world user prompts will be noisier and accuracy should
settle in the 60-80% range — still well above the 25% success bar.

## Future improvements

- NLP-based effort classifier (embeddings > keyword regex)
- Real-session token capture via CC telemetry hook
- Per-task-type A/B (code vs docs vs config)
- Long-session cost accumulation with cache hit-rate tracking
- Judge model for end-to-end task quality scoring

## Known limitations

- Harness does not measure real Claude response quality (would require a judge model).
- SessionStart 23KB cost is a fixed per-session overhead, not per-query.
- Adaptive thinking overhead varies by task complexity and is measured separately.
- Corpus tuning inflates accuracy — interpret the 100% as "heuristic correctly
  handles its happy path", not "100% of user prompts will route correctly".

## Files

| Path                              | Purpose                                |
|-----------------------------------|----------------------------------------|
| `scripts/benchmark-v6.sh`         | Harness (14 prompts → JSON)            |
| `scripts/execution-philosophy/effort-heuristic.sh` | Classifier under test   |
| `tests/benchmark-results/`        | Per-run JSON outputs (gitignored)      |
| `BENCHMARK-V6.md`                 | This file                              |

*Updated: 2026-04-17 21:30 EDT*
