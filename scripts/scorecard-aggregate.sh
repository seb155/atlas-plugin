#!/bin/bash
# scorecard-aggregate.sh — Roll up per-skill scorecard JSONL files into rolling stats.
#
# Usage:
#   scripts/scorecard-aggregate.sh <skill-name> [window]
#
#   window: 1d | 7d | 30d (default 7d)
#
# Output (single-line summary, easy to parse):
#   calls=<N>, p50=<int>ms, p99=<int>ms, error_rate=<pct>%, success_rate=<pct>%, cost=$<float>
#
# Exit codes:
#   0  — aggregation produced (even if calls=0)
#   2  — bad arguments
#
# Reads:  ~/.atlas/scorecards/<skill>/*.jsonl (one JSON object per line, written by
#         hooks/scorecard-emitter.sh).
#
# Reuses the percentile-windowing pattern from skills/flow-analytics (Python is fine here:
# the script runs interactively, not in a hot path).

set -uo pipefail

SKILL="${1:-}"
WINDOW="${2:-7d}"

if [ -z "$SKILL" ]; then
  echo "usage: $0 <skill-name> [1d|7d|30d]" >&2
  exit 2
fi

case "$WINDOW" in
  1d|7d|30d) ;;
  *) echo "error: window must be 1d, 7d, or 30d (got: $WINDOW)" >&2; exit 2 ;;
esac

SCORECARD_DIR="$HOME/.atlas/scorecards/$SKILL"

if [ ! -d "$SCORECARD_DIR" ]; then
  echo "calls=0, p50=0ms, p99=0ms, error_rate=0%, success_rate=0%, cost=\$0.000"
  exit 0
fi

python3 - "$SCORECARD_DIR" "$WINDOW" <<'PYEOF'
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

scorecard_dir = Path(sys.argv[1])
window = sys.argv[2]

days = {"1d": 1, "7d": 7, "30d": 30}[window]
cutoff = datetime.now(timezone.utc) - timedelta(days=days)

durations = []
errors = 0
total = 0
cost_total = 0.0

for f in sorted(scorecard_dir.glob("*.jsonl")):
    try:
        with f.open() as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    rec = json.loads(line)
                except json.JSONDecodeError:
                    continue
                ts_raw = rec.get("ts", "")
                try:
                    ts = datetime.fromisoformat(ts_raw.replace("Z", "+00:00"))
                except (ValueError, AttributeError):
                    continue
                if ts < cutoff:
                    continue
                total += 1
                d = rec.get("duration_ms", 0)
                if isinstance(d, (int, float)) and d >= 0:
                    durations.append(int(d))
                if rec.get("status") == "error":
                    errors += 1
                c = rec.get("cost_usd", 0)
                try:
                    cost_total += float(c)
                except (TypeError, ValueError):
                    pass
    except OSError:
        continue


def percentile(values, p):
    if not values:
        return 0
    s = sorted(values)
    k = (len(s) - 1) * (p / 100.0)
    lo = int(k)
    hi = min(lo + 1, len(s) - 1)
    if lo == hi:
        return int(s[lo])
    frac = k - lo
    return int(s[lo] + (s[hi] - s[lo]) * frac)


p50 = percentile(durations, 50)
p99 = percentile(durations, 99)
error_rate = (errors / total * 100.0) if total else 0.0
success_rate = 100.0 - error_rate if total else 0.0

print(
    f"calls={total}, p50={p50}ms, p99={p99}ms, "
    f"error_rate={error_rate:.1f}%, success_rate={success_rate:.1f}%, "
    f"cost=${cost_total:.3f}"
)
PYEOF
