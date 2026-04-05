#!/usr/bin/env bash
# session-tools.sh — Session continuity tools (SP-EVOLUTION P6)
# Usage:
#   session-tools.sh import <handoff.md>  — Parse handoff → session-state.json (P6.3)
#   session-tools.sh budget               — Estimate remaining context budget (P6.5)
#   session-tools.sh replay <event.json>  — Append event to session-replay.jsonl (P6.6)
#   session-tools.sh sessions             — List active sessions (tmux-aware) (P6.4)
set -euo pipefail

STATE_FILE="${HOME}/.claude/session-state.json"
REPLAY_FILE="${HOME}/.claude/session-replay.jsonl"

# ── P6.3: Handoff Import ─────────────────────────────────────

cmd_import() {
  local handoff="$1"
  [ -f "$handoff" ] || { echo "ERROR: File not found: $handoff" >&2; exit 1; }

  python3 -c "
import json, re, os, sys
from datetime import datetime

handoff_path = '$handoff'
state_file = '$STATE_FILE'

with open(handoff_path) as f:
    content = f.read()

state = {}

# Extract date
date_match = re.search(r'\*\*Date\*\*:\s*(.+)', content)
if date_match:
    state['session_date'] = date_match.group(1).strip()

# Extract branch
branch_match = re.search(r'\*\*Branch\*\*:\s*\x60?([^\x60\n]+)', content)
if branch_match:
    state['branch'] = branch_match.group(1).strip()

# Extract focus
focus_match = re.search(r'\*\*Focus\*\*:\s*(.+)', content)
if focus_match:
    state['focus'] = focus_match.group(1).strip()

# Extract completed tasks (checkboxes)
completed = re.findall(r'- \[x\]\s*(.+)', content)
state['tasks_completed'] = [t.strip() for t in completed]

# Extract remaining tasks (unchecked)
remaining = re.findall(r'- \[ \]\s*(.+)', content)
state['tasks_remaining'] = [t.strip() for t in remaining]

# Extract active plan from 'To Resume' or content
plan_match = re.search(r'SP-\w+', content)
if plan_match:
    state['active_plan'] = plan_match.group(0)

# Extract key decisions
decisions = []
decision_section = re.search(r'## Key Decisions\n(.*?)(?=\n##|\Z)', content, re.DOTALL)
if decision_section:
    for line in decision_section.group(1).strip().split('\n'):
        line = line.strip('- ').strip()
        if line:
            decisions.append(line)
state['key_decisions'] = decisions[:10]

# Meta
state['session_id'] = datetime.now().strftime('%Y-%m-%d_%H:%M')
state['last_activity'] = datetime.now().isoformat()
state['source_handoff'] = os.path.basename(handoff_path)
state['progress'] = {
    'completed': len(completed),
    'remaining': len(remaining),
    'total': len(completed) + len(remaining),
    'pct': round(len(completed) / max(1, len(completed) + len(remaining)) * 100)
}

# Write state
os.makedirs(os.path.dirname(state_file), exist_ok=True)
with open(state_file, 'w') as f:
    json.dump(state, f, indent=2)

# Summary
print(f'✅ Imported handoff → {state_file}')
print(f'   Focus: {state.get(\"focus\", \"—\")}')
print(f'   Branch: {state.get(\"branch\", \"—\")}')
print(f'   Progress: {state[\"progress\"][\"completed\"]}/{state[\"progress\"][\"total\"]} ({state[\"progress\"][\"pct\"]}%)')
print(f'   Remaining: {len(remaining)} tasks')
" || { echo "❌ Failed to parse handoff"; exit 1; }
}

# ── P6.5: Context Budget Predictor ───────────────────────────

cmd_budget() {
  python3 -c "
import json, os, sys

state_file = '$STATE_FILE'
state = {}
if os.path.exists(state_file):
    with open(state_file) as f:
        state = json.load(f)

# Read context info from state
context_pct = state.get('context_used_pct', 0)
tasks = state.get('tasks', {})
completed = sum(1 for s in tasks.values() if s == 'completed')
total = len(tasks)
remaining = total - completed

# Estimate based on task complexity
# Heuristic: each task ~ 5-15% context depending on complexity
tasks_remaining = state.get('tasks_remaining', [])
if not tasks_remaining:
    tasks_remaining = [k for k, v in tasks.items() if v != 'completed']

estimated_per_task_pct = 8  # Average: 8% context per task
estimated_remaining_pct = len(tasks_remaining) * estimated_per_task_pct

# Current context estimate (rough — CC doesn't expose exact count)
# Use tool call count as proxy if available
tool_calls = state.get('tool_call_count', 0)
estimated_context_pct = min(95, max(context_pct, tool_calls * 0.5))  # ~0.5% per tool call

remaining_budget_pct = max(0, 100 - estimated_context_pct)

print(f'📊 Context Budget Estimate')
print(f'')
print(f'   Used:      ~{estimated_context_pct:.0f}%')
print(f'   Remaining: ~{remaining_budget_pct:.0f}%')
print(f'')
print(f'   Tasks remaining: {len(tasks_remaining)}')
print(f'   Est. per task:   ~{estimated_per_task_pct}%')
print(f'   Est. needed:     ~{estimated_remaining_pct}%')
print(f'')

if estimated_remaining_pct > remaining_budget_pct:
    deficit = estimated_remaining_pct - remaining_budget_pct
    print(f'   ⚠️  Budget TIGHT — may need handoff after ~{int(remaining_budget_pct / estimated_per_task_pct)} more tasks')
    print(f'   💡 Consider: /a-handoff then fresh session')
elif remaining_budget_pct < 30:
    print(f'   🟡 Budget LOW — {int(remaining_budget_pct / estimated_per_task_pct)} tasks comfortable')
else:
    print(f'   🟢 Budget OK — room for {int(remaining_budget_pct / estimated_per_task_pct)} more tasks')
" || echo "❌ Budget estimation failed"
}

# ── P6.6: Session Replay Log ─────────────────────────────────

cmd_replay() {
  local event_json="${1:-}"

  if [ -z "$event_json" ]; then
    # Show replay stats
    if [ ! -f "$REPLAY_FILE" ]; then
      echo "📹 No replay log found. Events are logged by hooks."
      exit 0
    fi
    python3 -c "
import json, os
from collections import Counter

replay_file = '$REPLAY_FILE'
events = []
with open(replay_file) as f:
    for line in f:
        line = line.strip()
        if line:
            try:
                events.append(json.loads(line))
            except:
                pass

print(f'📹 Session Replay — {len(events)} events')
print(f'   File: {replay_file}')
print(f'   Size: {os.path.getsize(replay_file) / 1024:.1f} KB')
print()

# Tool call distribution
tools = Counter(e.get('tool', '?') for e in events)
print('   Top tools:')
for tool, count in tools.most_common(10):
    bar = '█' * min(count, 30)
    print(f'     {tool:30s} {count:4d} {bar}')

# Time span
if events:
    first = events[0].get('ts', '?')
    last = events[-1].get('ts', '?')
    print(f'\n   Span: {first} → {last}')
"
    return
  fi

  # Append event
  local ts=$(date -Iseconds)
  echo "{\"ts\":\"${ts}\",${event_json#\{}" >> "$REPLAY_FILE"
}

# ── P6.4: Multi-session Awareness ────────────────────────────

cmd_sessions() {
  echo "🖥️  Active Sessions"
  echo ""

  # Check tmux sessions
  if command -v tmux >/dev/null 2>&1 && tmux list-sessions >/dev/null 2>&1; then
    echo "   Tmux sessions:"
    tmux list-sessions 2>/dev/null | while read -r line; do
      local name=$(echo "$line" | cut -d: -f1)
      local windows=$(echo "$line" | grep -oP '\d+ windows')
      echo "     📺 $name ($windows)"
    done
    echo ""
  else
    echo "   No tmux sessions detected."
    echo ""
  fi

  # Check for other session state files
  echo "   Session states:"
  local found=0
  for sf in "${HOME}/.claude/session-state.json" "${HOME}"/.claude/worktrees/*/session-state.json; do
    [ -f "$sf" ] || continue
    found=$((found + 1))
    python3 -c "
import json
with open('$sf') as f:
    s = json.load(f)
focus = s.get('focus', s.get('active_plan', '—'))
branch = s.get('branch', '?')
last = s.get('last_activity', '?')[:19]
pct = s.get('progress', {}).get('pct', '?')
tasks = s.get('tasks', {})
active = sum(1 for v in tasks.values() if v == 'in_progress')
print(f'     📋 {branch} — {focus}')
print(f'        Last: {last} | Active tasks: {active} | Progress: {pct}%')
" 2>/dev/null || echo "     ⚠️  $sf (parse error)"
  done
  [ "$found" -eq 0 ] && echo "     No session state files found."

  # Check for worktrees
  echo ""
  echo "   Git worktrees:"
  git worktree list 2>/dev/null | while read -r line; do
    echo "     🌿 $line"
  done 2>/dev/null || echo "     Not in a git repo."
}

# ── Main ──────────────────────────────────────────────────────

case "${1:-help}" in
  import)   shift; cmd_import "$@" ;;
  budget)   cmd_budget ;;
  replay)   shift 2>/dev/null || true; cmd_replay "$@" ;;
  sessions) cmd_sessions ;;
  *)        echo "Usage: session-tools.sh {import|budget|replay|sessions} [args]"; exit 1 ;;
esac
