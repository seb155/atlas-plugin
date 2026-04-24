---
name: ci-health
description: "Woodpecker CI observability dashboard. This skill should be used when the user asks to 'ci health', 'flaky tests', 'pipeline trend', 'kill rate', '/atlas ci health', or needs 7-day p50/p95 across workflows."
triggers:
  - "/atlas ci-health"
  - "/atlas ci status"
  - "ci health report"
  - "woodpecker metrics"
  - "how is ci"
effort: low
---

# CI-Health — Woodpecker Observability Dashboard

Queries Woodpecker API, computes observability metrics, emits a daily report.
The first skill that gives AI sessions a **predictable view of CI state**
rather than "last fail caught by the human".

## Commands

```bash
/atlas ci-health                          # 7d summary to stdout (table)
/atlas ci-health --since 24h --format json
/atlas ci-health --branch "feat/*"
/atlas ci-health --post-telegram          # daily cron mode
/atlas ci-health --flaky-issues           # auto-file Forgejo issues for >20% flaky tests
/atlas ci-health --validate-p1            # HITL Gate G1 check: kill_rate < 8%?
```

## Metrics emitted

```json
{
  "window_days": 7,
  "sample_size": 100,
  "kill_rate_pct": 72.0,            // target <8% after plan P1 ships
  "status_counts": {"success": 5, "killed": 36, "failure": 3, ...},
  "workflow_p50_ms": {"ci-backend": 180000, "ci-frontend": 540000, ...},
  "workflow_p95_ms": {...},
  "flaky_top_10": [
    {"test": "tests/integration/test_foo.py::test_flaky", "fail_rate": 0.34, "runs": 12},
    ...
  ],
  "top_branches": [{"branch": "feat/...", "pipeline_count": 20}, ...]
}
```

## HITL Gate integrations

- **G1 (P1 plan)**: `--validate-p1` exits 0 if kill_rate_pct < 8% over 48h,
  else non-zero with reason. Used as deploy-gate precondition post-merge.
- **G5 (P5 plan)**: flags flaky tests >20% fail rate → auto-files
  Forgejo issue tagged `flaky` with last-10-run table + repro cmd.

## Cron mode (daily 08:00 local)

```cron
0 8 * * *   /home/seb/.claude/plugins/.../ci-health.py --post-telegram --since 24h
```

Posts a 1-line summary to Telegram:
```
[synapse/CI] 24h — 48 runs, kill 4%, ci-backend p50 3m12s, flaky: test_foo (22%)
```

## Files

- Implementation: `${CLAUDE_PLUGIN_ROOT}/skills/ci-health/ci-health.py`
- Baseline script (Synapse-local): `scripts/ci-baseline.sh`
- Pipeline config: `.woodpecker/` (6 workflows)

## References

- `.blueprint/plans/hazy-mapping-stallman.md` Phase 5 T5.1 + T5.4
- Woodpecker API: https://woodpecker-ci.org/docs/api
- `memory/ci-baseline-2026-04-16-pre-p1.json` (baseline captured pre-P1)
