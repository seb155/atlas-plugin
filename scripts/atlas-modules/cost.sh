#!/usr/bin/env bash
# atlas cost — Claude Code usage cost analytics
#
# Reads session JSONL files from ~/.claude/projects/ to calculate actual API costs.
# Uses ccusage (bunx) for accurate pricing, with a pure-bash fallback.
#
# Usage:
#   atlas cost                    # Today's cost summary
#   atlas cost daily              # Last 7 days daily breakdown
#   atlas cost weekly             # Weekly summary
#   atlas cost monthly            # Monthly summary
#   atlas cost session            # Per-session breakdown
#   atlas cost --since 20260401   # Custom date range
#   atlas cost --json             # JSON output for automation
#   atlas cost sprint             # Current sprint (last 5 days)
#   atlas cost status             # Quick statusline output
#
# Dependencies: bun (for ccusage), jq (for JSON parsing)
# Author: ATLAS Plugin v4.30.0+

set -euo pipefail

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# --- Arguments ---
SUBCMD="${1:-today}"
shift 2>/dev/null || true

EXTRA_ARGS=("$@")
JSON_FLAG=""
SINCE_FLAG=""
UNTIL_FLAG=""
WITH_EVALS=""

# v4.42: parse --with-evals flag (includes eval harness runs in cost summary)
for arg in "${EXTRA_ARGS[@]}"; do
  if [[ "$arg" == "--with-evals" ]]; then
    WITH_EVALS="true"
  fi
done
BREAKDOWN_FLAG="--breakdown"

# Parse extra args
for ((i = 0; i < ${#EXTRA_ARGS[@]}; i++)); do
  case "${EXTRA_ARGS[$i]}" in
    --json) JSON_FLAG="--json" ;;
    --since) SINCE_FLAG="${EXTRA_ARGS[$((i+1))]:-}"; ((i++)) ;;
    --until) UNTIL_FLAG="${EXTRA_ARGS[$((i+1))]:-}"; ((i++)) ;;
    --no-breakdown) BREAKDOWN_FLAG="" ;;
  esac
done

# --- Helpers ---
check_bun() {
  command -v bun &>/dev/null
}

check_ccusage() {
  check_bun
}

format_cost() {
  local cost="$1"
  if (( $(echo "$cost > 100" | bc -l 2>/dev/null || echo 0) )); then
    echo -e "${RED}\$${cost}${NC}"
  elif (( $(echo "$cost > 50" | bc -l 2>/dev/null || echo 0) )); then
    echo -e "${YELLOW}\$${cost}${NC}"
  else
    echo -e "${GREEN}\$${cost}${NC}"
  fi
}

run_ccusage() {
  local mode="$1"
  shift
  local args=("$mode")

  [[ -n "$BREAKDOWN_FLAG" ]] && args+=("$BREAKDOWN_FLAG")
  [[ -n "$SINCE_FLAG" ]] && args+=("--since" "$SINCE_FLAG")
  [[ -n "$UNTIL_FLAG" ]] && args+=("--until" "$UNTIL_FLAG")
  [[ -n "$JSON_FLAG" ]] && args+=("$JSON_FLAG")

  args+=("$@")

  bun x ccusage@latest "${args[@]}" 2>/dev/null
}

# --- Count session files ---
count_sessions() {
  find "$HOME/.claude/projects/" -name "*.jsonl" 2>/dev/null | wc -l
}

# --- Fallback: Pure bash cost calculator ---
# Uses the session JSONL files directly when ccusage is not available
fallback_cost() {
  local since="${1:-$(date -d '-7 days' '+%Y%m%d' 2>/dev/null || date -v-7d '+%Y%m%d')}"

  echo -e "${BOLD}ATLAS Cost Analytics (fallback mode)${NC}"
  echo -e "${DIM}Using direct JSONL parsing — install bun for full ccusage support${NC}"
  echo ""

  python3 -c "
import json, os, glob, sys
from datetime import datetime, timedelta
from collections import defaultdict

# Pricing per million tokens (2026-04)
PRICING = {
    'claude-opus-4-7': {'input': 5.0, 'output': 25.0, 'cache_write': 6.25, 'cache_read': 0.50},
    'claude-opus-4-6': {'input': 15.0, 'output': 75.0, 'cache_write': 18.75, 'cache_read': 1.50},
    'claude-sonnet-4-6': {'input': 3.0, 'output': 15.0, 'cache_write': 3.75, 'cache_read': 0.30},
    'claude-haiku-4-5-20251001': {'input': 0.25, 'output': 1.25, 'cache_write': 0.3125, 'cache_read': 0.025},
    'claude-haiku-4-5': {'input': 0.25, 'output': 1.25, 'cache_write': 0.3125, 'cache_read': 0.025},
}

def get_pricing(model):
    for key in PRICING:
        if key in model:
            return PRICING[key]
    if 'opus' in model:
        return PRICING['claude-opus-4-7']
    elif 'sonnet' in model:
        return PRICING['claude-sonnet-4-6']
    elif 'haiku' in model:
        return PRICING['claude-haiku-4-5']
    return PRICING['claude-sonnet-4-6']  # default

# Find all session JSONL files
files = glob.glob(os.path.expanduser('~/.claude/projects/*/*.jsonl'))
since_date = '${since}'

daily = defaultdict(lambda: {'input': 0, 'output': 0, 'cache_write': 0, 'cache_read': 0, 'cost': 0.0, 'models': set(), 'sessions': set()})

for fpath in files:
    mtime = os.path.getmtime(fpath)
    fdate = datetime.fromtimestamp(mtime).strftime('%Y%m%d')
    if fdate < since_date:
        continue

    session_id = os.path.basename(fpath).replace('.jsonl', '')
    try:
        with open(fpath) as f:
            for line in f:
                try:
                    entry = json.loads(line.strip())
                    if 'message' not in entry or not isinstance(entry['message'], dict):
                        continue
                    msg = entry['message']
                    if 'usage' not in msg:
                        continue

                    model = msg.get('model', 'unknown')
                    usage = msg['usage']
                    ts = entry.get('timestamp', '')
                    if isinstance(ts, (int, float)):
                        day = datetime.fromtimestamp(ts / 1000 if ts > 1e12 else ts).strftime('%Y-%m-%d')
                    elif isinstance(ts, str) and len(ts) >= 10:
                        day = ts[:10]
                    else:
                        day = datetime.fromtimestamp(mtime).strftime('%Y-%m-%d')

                    pricing = get_pricing(model)
                    inp = usage.get('input_tokens', 0)
                    out = usage.get('output_tokens', 0)
                    cw = usage.get('cache_creation_input_tokens', 0)
                    cr = usage.get('cache_read_input_tokens', 0)

                    cost = (inp * pricing['input'] + out * pricing['output'] +
                            cw * pricing['cache_write'] + cr * pricing['cache_read']) / 1_000_000

                    daily[day]['input'] += inp
                    daily[day]['output'] += out
                    daily[day]['cache_write'] += cw
                    daily[day]['cache_read'] += cr
                    daily[day]['cost'] += cost
                    daily[day]['models'].add(model)
                    daily[day]['sessions'].add(session_id)
                except (json.JSONDecodeError, KeyError):
                    continue
    except Exception:
        continue

if not daily:
    print('No usage data found.')
    sys.exit(0)

total_cost = 0
print(f'  {\"Date\":<12} {\"Sessions\":>8} {\"Models\":<30} {\"Cost (USD)\":>12}')
print(f'  {\"-\"*12} {\"-\"*8} {\"-\"*30} {\"-\"*12}')
for day in sorted(daily.keys()):
    d = daily[day]
    models = ', '.join(sorted(m.replace('claude-','') for m in d['models']))
    cost = d['cost']
    total_cost += cost
    print(f'  {day:<12} {len(d[\"sessions\"]):>8} {models:<30} \${cost:>10.2f}')

print(f'  {\"-\"*12} {\"-\"*8} {\"-\"*30} {\"-\"*12}')
print(f'  {\"TOTAL\":<12} {\"\":>8} {\"\":30} \${total_cost:>10.2f}')
print()
print(f'  Session files scanned: {len(files)}')
"
}

# --- Subcommands ---
case "$SUBCMD" in
  today)
    TODAY=$(date '+%Y%m%d')
    if check_ccusage; then
      echo -e "${BOLD}${CYAN}ATLAS${NC} ${BOLD}Cost Analytics — Today${NC}"
      echo ""
      run_ccusage daily --since "$TODAY"
    else
      fallback_cost "$TODAY"
    fi
    ;;

  daily)
    SINCE="${SINCE_FLAG:-$(date -d '-7 days' '+%Y%m%d' 2>/dev/null || date -v-7d '+%Y%m%d')}"
    if check_ccusage; then
      echo -e "${BOLD}${CYAN}ATLAS${NC} ${BOLD}Cost Analytics — Daily${NC}"
      echo ""
      SINCE_FLAG="$SINCE" run_ccusage daily
    else
      fallback_cost "$SINCE"
    fi
    ;;

  weekly)
    SINCE="${SINCE_FLAG:-$(date -d '-30 days' '+%Y%m%d' 2>/dev/null || date -v-30d '+%Y%m%d')}"
    if check_ccusage; then
      echo -e "${BOLD}${CYAN}ATLAS${NC} ${BOLD}Cost Analytics — Weekly${NC}"
      echo ""
      SINCE_FLAG="$SINCE" run_ccusage weekly
    else
      fallback_cost "$SINCE"
    fi
    ;;

  monthly)
    if check_ccusage; then
      echo -e "${BOLD}${CYAN}ATLAS${NC} ${BOLD}Cost Analytics — Monthly${NC}"
      echo ""
      run_ccusage monthly
    else
      fallback_cost "20260101"
    fi
    ;;

  session|sessions)
    SINCE="${SINCE_FLAG:-$(date -d '-3 days' '+%Y%m%d' 2>/dev/null || date -v-3d '+%Y%m%d')}"
    if check_ccusage; then
      echo -e "${BOLD}${CYAN}ATLAS${NC} ${BOLD}Cost Analytics — Per Session${NC}"
      echo ""
      SINCE_FLAG="$SINCE" run_ccusage session
    else
      echo "Per-session breakdown requires ccusage (bun x ccusage@latest)"
      echo "Install bun: curl -fsSL https://bun.sh/install | bash"
    fi
    ;;

  sprint)
    # Last 5 working days
    SINCE="${SINCE_FLAG:-$(date -d '-5 days' '+%Y%m%d' 2>/dev/null || date -v-5d '+%Y%m%d')}"
    if check_ccusage; then
      echo -e "${BOLD}${CYAN}ATLAS${NC} ${BOLD}Cost Analytics — Sprint (5-day)${NC}"
      echo ""
      SINCE_FLAG="$SINCE" run_ccusage daily
    else
      fallback_cost "$SINCE"
    fi
    ;;

  status)
    # Compact one-line output for statusline/hooks — pure python for speed (<1s)
    python3 -c "
import json, os, glob
from datetime import datetime
from collections import defaultdict

PRICING = {
    'opus': {'input': 15.0, 'output': 75.0, 'cache_write': 18.75, 'cache_read': 1.50},
    'sonnet': {'input': 3.0, 'output': 15.0, 'cache_write': 3.75, 'cache_read': 0.30},
    'haiku': {'input': 0.25, 'output': 1.25, 'cache_write': 0.3125, 'cache_read': 0.025},
}

def get_pricing(model):
    for key in ['opus', 'sonnet', 'haiku']:
        if key in model:
            return PRICING[key]
    return PRICING['sonnet']

today = datetime.now().strftime('%Y-%m-%d')
today_ymd = datetime.now().strftime('%Y%m%d')
total_cost = 0.0

# Only scan files modified today for speed
for fpath in glob.glob(os.path.expanduser('~/.claude/projects/*/*.jsonl')):
    mtime = os.path.getmtime(fpath)
    fdate = datetime.fromtimestamp(mtime).strftime('%Y%m%d')
    if fdate < today_ymd:
        continue
    try:
        with open(fpath) as f:
            for line in f:
                try:
                    entry = json.loads(line.strip())
                    msg = entry.get('message', {})
                    if not isinstance(msg, dict) or 'usage' not in msg:
                        continue
                    usage = msg['usage']
                    model = msg.get('model', 'sonnet')
                    pricing = get_pricing(model)
                    total_cost += (
                        usage.get('input_tokens', 0) * pricing['input'] +
                        usage.get('output_tokens', 0) * pricing['output'] +
                        usage.get('cache_creation_input_tokens', 0) * pricing['cache_write'] +
                        usage.get('cache_read_input_tokens', 0) * pricing['cache_read']
                    ) / 1_000_000
                except (json.JSONDecodeError, KeyError):
                    pass
    except Exception:
        pass

print(f'\${total_cost:.2f} today')
" 2>/dev/null || echo "\$? today"
    ;;

  help|--help|-h)
    echo "atlas cost — Claude Code usage cost analytics"
    echo ""
    echo "Subcommands:"
    echo "  today      Today's costs (default)"
    echo "  daily      Last 7 days, daily breakdown"
    echo "  weekly     Last 30 days, weekly summary"
    echo "  monthly    All-time monthly summary"
    echo "  session    Per-session breakdown (last 3 days)"
    echo "  sprint     Current sprint (last 5 days)"
    echo "  status     One-line for statusline"
    echo ""
    echo "Options:"
    echo "  --since YYYYMMDD   Start date filter"
    echo "  --until YYYYMMDD   End date filter"
    echo "  --json             JSON output"
    echo "  --no-breakdown     Hide per-model breakdown"
    echo ""
    echo "Examples:"
    echo "  atlas cost daily --since 20260401"
    echo "  atlas cost monthly --json"
    echo "  atlas cost sprint"
    echo ""
    echo "Data source: ~/.claude/projects/*/*.jsonl ($(count_sessions) session files)"
    echo "Engine: ccusage (bunx ccusage@latest) with fallback to direct JSONL parsing"
    ;;

  *)
    echo "Unknown subcommand: $SUBCMD"
    echo "Run 'atlas cost help' for usage"
    exit 1
    ;;
esac

# v4.42: --with-evals adds summary of eval harness costs from .blueprint/eval-runs/
if [ "$WITH_EVALS" = "true" ]; then
  echo ""
  echo -e "${BOLD}Eval Harness Activity${NC}"
  EVAL_DIR=""
  for candidate in "$(pwd)/.blueprint/eval-runs" "$HOME/workspace_atlas/projects/atlas/synapse/.blueprint/eval-runs"; do
    if [ -d "$candidate" ]; then
      EVAL_DIR="$candidate"
      break
    fi
  done
  if [ -n "$EVAL_DIR" ]; then
    RUN_COUNT=$(ls "$EVAL_DIR"/eval-*.json 2>/dev/null | wc -l)
    echo "  Eval runs: ${RUN_COUNT} in $EVAL_DIR"
    if [ "$RUN_COUNT" -gt 0 ]; then
      LATEST=$(ls -t "$EVAL_DIR"/eval-*.json 2>/dev/null | head -1)
      LATEST_NAME=$(basename "$LATEST" .json)
      echo "  Latest:    $LATEST_NAME"
      python3 -c "
import json
try:
    with open('$LATEST') as f:
        d = json.load(f)
    s = d.get('summary', {})
    print(f\"  Pass rate: {s.get('pass_rate', 0)*100:.1f}% ({s.get('passed', 0)}/{s.get('total', 0)})\")
    print(f\"  Tokens:    {s.get('total_tokens', 0):,}\")
    print(f\"  Cost:      \${s.get('total_cost_usd', 0):.4f}\")
except Exception as e:
    print(f\"  (could not parse: {e})\")
"
    fi
  else
    echo "  ${DIM}(no eval harness data found; run 'python3 -m toolkit.evals run' first)${NC}"
  fi
fi
