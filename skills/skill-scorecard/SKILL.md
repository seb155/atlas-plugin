---
name: skill-scorecard
description: "Skill quality scorecard with rolling p50/p99 latency, error rate, cost-per-invocation, success rate. Use when 'show scorecard', 'skill quality', 'which skills are slow', or 'scorecard memory-dream'."
effort: medium
version: 1.0.0
tier: [admin]
---

# Skill Scorecard — Per-Skill Quality Metrics

Per-skill quality scorecard derived from rolling JSONL telemetry emitted by the
`hooks/scorecard-emitter.sh` PostToolUse hook (v7.0 W1.2). Surfaces latency
percentiles, error rate, cost-per-invocation, and call volume so you can spot
regressions, identify hot/slow skills, and feed the auto-router (W2.2) and
regression-test gate (W3.1).

Pairs with `atlas-trace` (W1.1, span format SSoT) and `flow-analytics` (workflow
patterns) — this skill is the **per-skill quality** lens; flow-analytics is the
**ecosystem** lens.

## When to Use

- `/atlas skill-scorecard --skill <name>` — show one skill's rolling quality
- `/atlas skill-scorecard --all` — table of every skill with calls in window
- `show scorecard for memory-dream` — natural-language entry
- `which skills are slow?` / `which skills are failing?` — top-N views
- Before a skill version bump (compare current vs prior week)
- Inside `senior-review-checklist` 8th dim (perf) when assessing AI-generated changes

## Subcommands

| Command | Output |
|---------|--------|
| `atlas skill-scorecard --skill <name> [--window 1d\|7d\|30d]` | One-skill ASCII dashboard |
| `atlas skill-scorecard --all [--window 7d]` | Table of all skills with rolling stats |
| `atlas skill-scorecard --top-slow [--limit 10]` | Top N skills by p99 latency |
| `atlas skill-scorecard --top-failing [--min-rate 0.1]` | Skills with error_rate > threshold |
| `atlas skill-scorecard --since <skill> <git-ref>` | Compare skill scorecard now vs at git ref (regression check) |

## Telemetry Source

Each invocation appends a single JSON line to:

```
~/.atlas/scorecards/{skill-name}/{YYYY-MM-DD}.jsonl
```

Schema (one line per skill invocation):

```json
{"ts":"2026-04-30T21:03:00Z","skill":"memory-dream","duration_ms":543,"status":"ok","tokens_used":1234,"cost_usd":0.012,"trace_id":"a3c1f5b2-..."}
```

Fields:
- `ts` — ISO-8601 UTC second-precision
- `skill` — skill name (matches frontmatter `name:`)
- `duration_ms` — wall-clock time of the invocation (from harness `duration_ms` field)
- `status` — `ok` or `error` (derived from exit code + output heuristics)
- `tokens_used` — total tokens (best-effort, 0 when harness does not expose)
- `cost_usd` — invocation cost (best-effort)
- `trace_id` — joins back to `~/.atlas/traces/{session}/{trace}.jsonl` (W1.1)

The hook is ~80 LOC of bash + jq, target overhead **<2ms P95** per PostToolUse
event. Skill attribution falls back to the active span on the trace stack when
the invocation is a sub-tool call (Bash, Read, …) inside a Skill body.

## Aggregation

The companion script `scripts/scorecard-aggregate.sh` computes rolling stats
for a given skill + window:

```bash
$ bash scripts/scorecard-aggregate.sh memory-dream 7d
calls=42, p50=180ms, p99=2100ms, error_rate=2.4%, success_rate=97.6%, cost=$0.504
```

It is intentionally side-effect-free and used both by this skill and by
downstream consumers (W2.2 router, W3.1 regression gate, dashboards).

## Execution Steps (when invoked by user)

1. **Parse subcommand** from user message (`--skill`, `--all`, `--top-slow`, `--top-failing`, `--since`).
2. **Resolve scorecard dir**: `~/.atlas/scorecards/`. If missing → tell user
   "no telemetry yet, ensure `hooks/scorecard-emitter.sh` is wired in
   PostToolUse and run a few skills".
3. **For `--skill <name>`**:
   - Run `bash scripts/scorecard-aggregate.sh <name> <window>`.
   - Render an ASCII dashboard:
     ```
     📊 Skill Scorecard — memory-dream (7d)
     ──────────────────────────────────────
     Calls          : 42
     Latency p50    : 180ms
     Latency p99    : 2100ms
     Error rate     : 2.4% (1/42)
     Success rate   : 97.6%
     Cost (period)  : $0.504
     Cost / call    : $0.012
     Trace samples  : 5 most recent trace_ids
     ```
4. **For `--all`**: iterate every dir under `~/.atlas/scorecards/`, run the
   aggregator per skill, sort by call count desc, render a table.
5. **For `--top-slow`** / **`--top-failing`**: same iteration, sort by p99 /
   error_rate desc.
6. **For `--since <skill> <ref>`**: look up the skill's commit at `<ref>`, run
   the aggregator on data from that commit's date forward vs from now-7d
   forward, diff the two summaries, flag regressions (>2x p99, >10pp error
   rate increase).

## Reuse

- **`flow-analytics`** — borrow the Python percentile + cutoff-window block.
  The structure is parallel: per-skill rolling stats, just sourced from
  `scorecards/{skill}/*.jsonl` instead of `skill-usage.jsonl`.
- **`atlas-trace` (W1.1)** — every scorecard line carries a `trace_id` so
  drill-down (`atlas trace show <id>`) gives the full call tree.
- **`cost-analytics` (W1.4 EXTEND)** — will read from this same scorecard JSONL
  (cost_usd field) plus traces to build the call-tree flame view.

## Verification Commands

```bash
# 1. Bash sanity
bash -n hooks/scorecard-emitter.sh
bash -n scripts/scorecard-aggregate.sh

# 2. Manual emission (simulate one skill invocation)
mkdir -p ~/.atlas/scorecards/test-skill
echo '{"ts":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","skill":"test-skill","duration_ms":100,"status":"ok","tokens_used":500,"cost_usd":0.005,"trace_id":null}' \
  > ~/.atlas/scorecards/test-skill/$(date -u +%Y-%m-%d).jsonl

# 3. Aggregate
bash scripts/scorecard-aggregate.sh test-skill 1d
# Expected: calls=1, p50=100ms, p99=100ms, error_rate=0.0%, success_rate=100.0%, cost=$0.005

# 4. End-to-end: pipe a fake hook payload to the emitter
echo '{"tool_name":"Skill","tool_input":{"skill":"test-skill"},"duration_ms":250,"exit_code":0,"tool_output":"done"}' \
  | bash hooks/scorecard-emitter.sh
ls ~/.atlas/scorecards/test-skill/   # → should now contain today's date
```

## Forward-Compatibility

- **W2.2 auto-router** reads p99 + error_rate per skill to decide model tier
  per task (Haiku/Sonnet/Opus).
- **W3.1 regression gate** uses `--since <skill> <last-tagged-version>` to
  block a skill version bump if p99 doubles or error rate spikes.
- **W3.x canary mirroring** writes to `~/.atlas/scorecards/{skill}__canary/`
  (sibling dir) so the same aggregator computes baseline vs canary deltas.

## Privacy & Storage Hygiene

- Scorecard files contain no prompt content, no user data — only metric
  fields (latency, status, cost). Safe for cross-machine sync if desired.
- Garbage collection: rotate files older than 90 days via a future
  `--gc --keep-days 90` flag (out of scope for v1.0.0; tracked for W3).
- File size: ~150 bytes/line. A heavily-used skill (~100 calls/day) writes
  ~15 KB/day. 90-day retention ≈ 1.4 MB per skill.

## Constraints (W1.2 ship)

- ❌ Does NOT modify `skills/_metadata.yaml` (per Wave-1 ship rule — Seb
  consolidates metadata).
- ❌ Does NOT run `make build-modular`.
- ✅ Reuses `flow-analytics` percentile pattern (Python aggregator).
- ✅ Honors W1.1 span format (no breaking change to JSONL schema; uses
  `trace_id` as a join key only).

## See Also

- `skills/atlas-trace/SKILL.md` — W1.1 distributed tracing (span format SSoT)
- `skills/flow-analytics/SKILL.md` — workflow / ecosystem analytics
- `skills/cost-analytics/SKILL.md` — cost rollups (W1.4 will join scorecard cost_usd)
- `hooks/scorecard-emitter.sh` — the PostToolUse hook
- `scripts/scorecard-aggregate.sh` — the rolling-stats aggregator
- `.blueprint/plans/ultrathink-regarde-ce-qui-abundant-petal.md` — plan SSoT (Section H W1.2)
