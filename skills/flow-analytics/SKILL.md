---
name: flow-analytics
description: "Analyze skill invocation telemetry from ~/.atlas/skill-usage.jsonl to identify hot skills, zombie skills (0 uses), performance anomalies, and workflow patterns. Admin-tier observability for v6.0 Phase 6 Flow Optimization."
effort: medium
thinking_mode: adaptive
superpowers_pattern: [none]
see_also: [memory-dream, atlas-doctor, cost-analytics]
---

# Flow Analytics — Skill Usage Observability

Analyzes `~/.atlas/skill-usage.jsonl` (populated by `skill-usage-tracker` hook) to surface workflow patterns, identify dead code, and inform skill consolidation decisions.

## When to Use

- `/atlas flow analytics` — Show 30-day usage summary
- `/atlas flow zombies` — List skills with 0 invocations in last 60 days
- `/atlas flow hot` — Top 20 most-used skills
- `/atlas flow failures` — Skills with high failure rate
- After 7-day baseline collection post-v6.0.0 ship (Phase 8 monitoring)
- Before archival decisions (which skills to deprecate)
- Before promotion decisions (which dev skills should move to core)

## Log Schema

Each line in `~/.atlas/skill-usage.jsonl`:
```json
{
  "ts": "2026-04-23T20:45:00Z",
  "skill": "plan-builder",
  "args": "feature \"add widgets\"",
  "session": "abc123",
  "duration_ms": 125000,
  "success": true,
  "model": "claude-opus-4-7[1m]"
}
```

## Subcommands

### `/atlas flow analytics [--days 30]`

Summary report for last N days:

```
📊 Flow Analytics — Last 30 days
────────────────────────────────
Total invocations: 1,247
Unique skills:     42 / 93 (45%)
Success rate:      93.4% (1,165/1,247)
Avg duration:      18.2s
Hot skills (top 5):
  1. plan-builder      (178 uses, 95% success, 2.1m avg)
  2. code-review       (142 uses, 97% success, 45s avg)
  3. tdd               (119 uses, 91% success, 1.8m avg)
  4. systematic-debug  ( 87 uses, 89% success, 3.2m avg)
  5. memory-dream      ( 76 uses, 100% success, 15s avg)

Failure rate warnings:
  - experiment-loop    8 fails / 12 uses (67% failure rate!)
  - frontend-workflow  3 fails / 5 uses (60% failure rate)

Model usage:
  - claude-opus-4-7[1m]: 412 (33%)
  - claude-sonnet-4-6:   698 (56%)
  - claude-haiku-4-5:    137 (11%)
```

### `/atlas flow zombies [--days 60]`

Skills with 0 invocations in last N days. Archive candidates.

### `/atlas flow hot [--limit 20]`

Top N skills by invocation count. Candidates for optimization (perf, caching).

### `/atlas flow failures [--min-rate 0.2]`

Skills with failure rate > threshold. Debug candidates.

### `/atlas flow promote-candidates`

Dev-tier skills heavily used by multiple personas → consider promoting to core.
Algorithm: > 20 uses in 30d + used across > 2 session contexts.

### `/atlas flow archive-candidates`

Skills with zero uses in 60d. Archive via Phase 0 pruning-batch.yaml.

## Process

### Read telemetry
```bash
LOG="$HOME/.atlas/skill-usage.jsonl"
[ -f "$LOG" ] || { echo "No telemetry yet. Run some skills first."; exit 0; }
```

### Aggregate with jq or Python
For summary:
```bash
python3 <<'PYEOF'
import json
from collections import Counter, defaultdict
from pathlib import Path
from datetime import datetime, timedelta, timezone

log = Path.home() / ".atlas" / "skill-usage.jsonl"
cutoff = datetime.now(timezone.utc) - timedelta(days=30)

counts = Counter()
successes = defaultdict(lambda: [0, 0])  # [success, total]
durations = defaultdict(list)
models = Counter()

with log.open() as f:
    for line in f:
        try:
            rec = json.loads(line)
            ts = datetime.fromisoformat(rec["ts"].replace("Z", "+00:00"))
            if ts < cutoff:
                continue
            skill = rec.get("skill", "unknown")
            counts[skill] += 1
            successes[skill][1] += 1
            if rec.get("success", True):
                successes[skill][0] += 1
            d = rec.get("duration_ms", 0)
            if d > 0:
                durations[skill].append(d)
            models[rec.get("model", "unknown")] += 1
        except Exception:
            continue

total = sum(counts.values())
print(f"Total invocations: {total}")
print(f"Unique skills: {len(counts)}")
# ... (full formatting)
PYEOF
```

## Integration Points

- **skill-usage-tracker hook**: populates log (PostToolUse[Skill])
- **memory-dream**: triggers flow-analytics summary weekly (consolidation pass)
- **atlas-doctor**: includes zombie skill count in health dashboard
- **cost-analytics**: cross-references with cost per invocation
- **Pruning decisions**: archive-candidates feed `.blueprint/plans/*` pruning batches

## Key Metrics

| Metric | Target | Action if exceeded |
|--------|--------|-------------------|
| Zombie skills (0 uses > 60d) | < 10% of total | Archive via pruning batch |
| Skill invocation diversity | > 40% of skills used in 30d | Education (skills exist but unknown) |
| Average failure rate | < 5% | Debug via failures subcommand |
| Heavy-failing skills | 0 with > 20% fail rate | Priority debugging |
| Model allocation | 50-60% sonnet, 25-35% opus, 10-20% haiku | Adjust execution-strategy |

## Privacy

- Log contains: timestamps, skill names, args (truncated to 200 chars), success, model
- **Does NOT contain**: file contents, user queries, API responses, secrets
- Stored locally only: `~/.atlas/skill-usage.jsonl` (~/.atlas chmod 700)
- No telemetry leaves the user's machine

## Version History

- **v6.0.0-alpha.6** (2026-04-23): Initial skill shipped — consumes skill-usage-tracker hook output
- Future v6.1: add auto-report weekly via cron, dashboard UI, cost correlation
