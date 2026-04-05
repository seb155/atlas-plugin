#!/usr/bin/env zsh
# ATLAS CLI Module: Agent Dispatch (lightweight fire-and-forget)
# Sourced by atlas-cli.sh — do not execute directly
# SP-EVOLUTION P7.4 — atlas dispatch "task" [--model sonnet]

_atlas_dispatch() {
  local desc=""
  local model=""
  local mode="auto"

  # Parse args
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --model) model="$2"; shift 2 ;;
      --mode) mode="$2"; shift 2 ;;
      *) desc="$desc $1"; shift ;;
    esac
  done
  desc="${desc## }"  # trim leading space

  if [ -z "$desc" ]; then
    echo "Usage: atlas dispatch \"task description\" [--model sonnet|opus|haiku]"
    return 1
  fi

  # Auto-detect model if not specified
  if [ -z "$model" ]; then
    local complexity_script="${ATLAS_SHELL_DIR}/../scripts/task-complexity.sh"
    [ -f "$complexity_script" ] || complexity_script="$(dirname "$(dirname "$ATLAS_SHELL_DIR")")/scripts/task-complexity.sh"
    if [ -f "$complexity_script" ]; then
      local result=$(bash "$complexity_script" "$desc")
      model=$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin)['model'])" 2>/dev/null || echo "sonnet")
      local level=$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin)['level'])" 2>/dev/null || echo "moderate")
      echo "🎯 Complexity: ${level} → model: ${model}"
    else
      model="sonnet"
    fi
  fi

  # Map model name to full model ID
  local model_id=""
  case "$model" in
    opus)   model_id="claude-opus-4-6" ;;
    sonnet) model_id="claude-sonnet-4-6" ;;
    haiku)  model_id="claude-haiku-4-5-20251001" ;;
    *)      model_id="$model" ;;
  esac

  echo "🚀 Dispatching: \"${desc}\""
  echo "   Model: ${model} (${model_id})"
  echo ""

  # Log dispatch
  local log_file="${HOME}/.claude/agent-stats.jsonl"
  printf '{"ts":"%s","task":"%s","model":"%s","status":"dispatched"}\n' \
    "$(date -Iseconds)" "$desc" "$model" >> "$log_file" 2>/dev/null

  # Find claude binary
  local claude_bin=$(command -v claude 2>/dev/null || echo "/usr/local/bin/claude")
  if [ ! -x "$claude_bin" ]; then
    echo "❌ claude binary not found"
    return 1
  fi

  # Dispatch as background agent via claude --print (non-interactive)
  echo "   Running..."
  local start_ts=$(date +%s)
  local output=$($claude_bin --print --model "$model_id" "$desc" 2>&1)
  local end_ts=$(date +%s)
  local duration=$((end_ts - start_ts))

  echo ""
  echo "─── Result (${duration}s) ───"
  echo "$output" | head -50
  [ $(echo "$output" | wc -l) -gt 50 ] && echo "... (truncated, $(echo "$output" | wc -l) lines total)"

  # Log completion
  printf '{"ts":"%s","task":"%s","model":"%s","status":"completed","duration_s":%d}\n' \
    "$(date -Iseconds)" "$desc" "$model" "$duration" >> "$log_file" 2>/dev/null

  echo ""
  echo "✅ Done in ${duration}s (model: ${model})"
}

# atlas agents stats — Show agent performance metrics
_atlas_agent_stats() {
  local log_file="${HOME}/.claude/agent-stats.jsonl"
  if [ ! -f "$log_file" ]; then
    echo "No agent stats yet. Run 'atlas dispatch' first."
    return 0
  fi

  _atlas_header
  printf "  ${ATLAS_BOLD}Agent Performance Stats${ATLAS_RESET}\n\n"

  python3 -c "
import json, sys
from collections import defaultdict

stats = defaultdict(lambda: {'count': 0, 'total_s': 0, 'success': 0, 'fail': 0})

with open('${log_file}') as f:
    for line in f:
        try:
            e = json.loads(line)
            model = e.get('model', '?')
            if e.get('status') == 'completed':
                stats[model]['count'] += 1
                stats[model]['total_s'] += e.get('duration_s', 0)
                stats[model]['success'] += 1
            elif e.get('status') == 'failed':
                stats[model]['fail'] += 1
        except:
            pass

if not stats:
    print('  No completed dispatches yet.')
    sys.exit(0)

print(f'  {\"Model\":<10} {\"Tasks\":<8} {\"Avg\":<8} {\"Success\":<10}')
print(f'  {\"─\"*10} {\"─\"*8} {\"─\"*8} {\"─\"*10}')
for model, s in sorted(stats.items()):
    avg = f'{s[\"total_s\"]/s[\"count\"]:.0f}s' if s['count'] > 0 else '—'
    rate = f'{s[\"success\"]/(s[\"success\"]+s[\"fail\"])*100:.0f}%' if (s['success']+s['fail']) > 0 else '—'
    print(f'  {model:<10} {s[\"count\"]:<8} {avg:<8} {rate:<10}')
" 2>/dev/null

  _atlas_footer
}
