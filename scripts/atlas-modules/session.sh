#!/usr/bin/env bash
# ATLAS session lifecycle CLI module (v6.1.0)
#
# Subcommands:
#   atlas session start [--intent <text>]         — pickup + lock + dashboard snapshot
#   atlas session pause                           — release lock, save state, stay in session
#   atlas session handoff [--end-session]         — smart handoff/close detect
#   atlas session end-session                     — alias of handoff with --end-session
#   atlas session status                          — current workflow step + pending gates
#   atlas session overview                        — multi-repo CLI dashboard
#   atlas session who                             — cross-repo active locks
#   atlas session roadmap                         — mega-plan + sprint view
#   atlas session audit                           — progress per repo
#   atlas session dream                           — inspect last dream cycle
#
# Plan ref: .blueprint/plans/le-plugin-atlas-core-devrais-adaptive-treasure.md Section O
# Tasks: v6.1-tasks.md 7.1-7.5

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CLAUDE_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}/.claude"

session_start() {
  local intent="${1:-}"
  echo "🏛️  ATLAS session start — $(date +%H:%M:%S)"

  # Read session-state.json if exists
  local state_file="${CLAUDE_DIR}/session-state.json"
  if [[ -f "$state_file" ]]; then
    local active_wf
    active_wf=$(python3 -c "import json; d=json.load(open('$state_file')); aw=d.get('active_workflow') or {}; print(aw.get('name','') if aw else '')" 2>/dev/null)
    if [[ -n "$active_wf" ]]; then
      echo "   Active workflow detected: $active_wf"
      echo "   (auto-resume via session-pickup hook)"
    fi
  fi

  # Acquire lock via atlas-lock-acquire hook (if present)
  "${PLUGIN_ROOT}/hooks/atlas-lock-acquire" 2>/dev/null || true

  # Intent match if provided
  if [[ -n "$intent" ]]; then
    echo "   Intent: $intent"
    # Future: dispatch to workflow-intent-detect hook
  fi

  # Quick dashboard snapshot
  session_overview --brief
}

session_pause() {
  echo "⏸️  ATLAS session pause — $(date +%H:%M:%S)"
  # Release lock + persist state (keep session alive)
  "${PLUGIN_ROOT}/hooks/atlas-lock-release" 2>/dev/null || true
  echo "   Lock released. Session state persisted."
  echo "   Resume with: atlas session start"
}

session_handoff() {
  local end_session=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --end-session) end_session=true; shift ;;
      *) shift ;;
    esac
  done

  echo "👋  ATLAS session handoff — $(date +%H:%M:%S)"

  # Smart state detection (O.2)
  local tests_green="unknown"
  local git_clean="unknown"
  local pending_hitl="0"

  # Tests: check last pytest run in session hook-log
  if [[ -f ~/.claude/hook-log.jsonl ]]; then
    local last_test
    last_test=$(grep -E 'pytest|bun test' ~/.claude/hook-log.jsonl 2>/dev/null | tail -1)
    if [[ -n "$last_test" ]] && echo "$last_test" | grep -q '"result":"pass"'; then
      tests_green="yes"
    elif [[ -n "$last_test" ]]; then
      tests_green="no"
    fi
  fi

  # Git status
  if git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null; then
    git_clean="yes"
  else
    git_clean="no"
  fi

  echo "   State detector:"
  echo "     Tests green:   $tests_green"
  echo "     Git clean:     $git_clean"
  echo "     Pending HITL:  $pending_hitl"

  # Route
  if [[ "$end_session" == "true" ]] || { [[ "$tests_green" == "yes" ]] && [[ "$git_clean" == "yes" ]]; }; then
    echo "   → Route: CLOSE SESSION path"
    echo "     • retro + dream + memory-index-update"
    echo "     • finishing-branch (CHANGELOG + commit)"
    echo "     • push + CI feedback loop"
    echo "     • PR create if branch = feat/*"
    echo "     • release lock"
    echo "   (invoke workflow-handoff + workflow-audit-ship)"
  else
    echo "   → Route: HANDOFF path (resumable)"
    echo "     • retro + dream + memory-index-update"
    echo "     • write memory/handoff-YYYY-MM-DD-*.md"
    echo "     • leave lock ACTIVE (TTL 24h)"
    echo "     • update .claude/session-state.json"
    echo "   (invoke workflow-handoff only)"
  fi
}

session_status() {
  echo "🏛️  ATLAS session status — $(date +%H:%M:%S)"
  local state_file="${CLAUDE_DIR}/session-state.json"
  if [[ -f "$state_file" ]]; then
    python3 <<PYEOF
import json
d = json.load(open("$state_file"))
print(f"   Mode: {d.get('mode', 'strict')}")
aw = d.get('active_workflow') or {}
if aw:
    print(f"   Active workflow: {aw.get('name', '?')}")
    print(f"   Completed steps: {aw.get('completed_steps', [])}")
    print(f"   Pending HITL: {len(aw.get('pending_hitl', []))}")
else:
    print("   No active workflow")
PYEOF
  else
    echo "   No session state (strict mode default)"
  fi
}

session_overview() {
  local brief=false
  [[ "${1:-}" == "--brief" ]] && brief=true

  echo "📊  ATLAS Ecosystem Overview"
  echo "─────────────────────────────────────────────────────────"

  local workspace="${ATLAS_WORKSPACE_ROOT:-$HOME/workspace_atlas}"
  local count=0

  for repo in "$workspace"/projects/*/; do
    [[ -d "$repo/.git" ]] || continue
    local name
    name=$(basename "$repo")
    local branch
    branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
    local status
    if git -C "$repo" diff --quiet 2>/dev/null && git -C "$repo" diff --cached --quiet 2>/dev/null; then
      status="clean"
    else
      status="dirty"
    fi
    printf "   %-25s %-30s %s\n" "$name" "$branch" "$status"
    count=$((count + 1))
    [[ "$brief" == "true" ]] && [[ "$count" -ge 5 ]] && break
  done

  echo "─────────────────────────────────────────────────────────"
  [[ "$brief" != "true" ]] && echo "   $count repos scanned."
}

session_who() {
  echo "👥  ATLAS active work (who's doing what)"
  echo "─────────────────────────────────────────────────────────"

  local workspace="${ATLAS_WORKSPACE_ROOT:-$HOME/workspace_atlas}"
  local found=0

  # Scan .claude/locks/ in each worktree
  find "$workspace" -path "*/.claude/locks/*.lock.json" -mmin -30 2>/dev/null | while read -r lock; do
    python3 <<PYEOF
import json, os
try:
    with open("$lock") as f:
        d = json.load(f)
    print(f"   {d.get('agent_id', 'human')} → {d.get('branch', '?')} (task: {d.get('task_id', 'N/A')})")
except Exception:
    pass
PYEOF
    found=$((found + 1))
  done

  if [[ "$found" -eq 0 ]]; then
    echo "   (no active locks in last 30 min)"
  fi
}

session_roadmap() {
  echo "🗺️  ATLAS Roadmap View"
  echo "─────────────────────────────────────────────────────────"
  # Scan .blueprint/plans/ in current project
  local plans_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}/.blueprint/plans"
  if [[ -d "$plans_dir" ]]; then
    ls -1 "$plans_dir"/*.md 2>/dev/null | head -10 | while read -r plan; do
      local name
      name=$(basename "$plan" .md)
      echo "   - $name"
    done
  else
    echo "   (no .blueprint/plans/ in current project)"
  fi
}

session_audit() {
  echo "🔍  ATLAS Progress Audit"
  echo "─────────────────────────────────────────────────────────"
  echo "   (stub — use /atlas workflow meta/audit-ship or workflow-audit for full audit)"
}

session_dream() {
  echo "💭  ATLAS Dream Cycle Inspect"
  echo "─────────────────────────────────────────────────────────"
  local memory_dir="${HOME}/.claude/projects"
  if [[ -d "$memory_dir" ]]; then
    find "$memory_dir" -name "dream-*.md" -mmin -$((60*24)) 2>/dev/null | head -3
  fi
  echo "   (stub — full dream inspection via memory-dream skill)"
}

# Entry point
case "${1:-status}" in
  start) shift; session_start "$@" ;;
  pause) shift; session_pause ;;
  handoff) shift; session_handoff "$@" ;;
  end-session) shift; session_handoff --end-session "$@" ;;
  status) shift; session_status ;;
  overview) shift; session_overview "$@" ;;
  who) shift; session_who ;;
  roadmap) shift; session_roadmap ;;
  audit) shift; session_audit ;;
  dream) shift; session_dream ;;
  --help|-h|help)
    cat <<'EOF'
atlas session — lifecycle commands

Usage:
  atlas session start [--intent "..."]   — pickup + lock + dashboard
  atlas session pause                    — release lock, keep session open
  atlas session handoff [--end-session]  — smart route handoff vs close
  atlas session end-session              — alias of handoff --end-session
  atlas session status                   — current workflow + pending gates
  atlas session overview [--brief]       — multi-repo dashboard
  atlas session who                      — cross-repo active locks (<30 min)
  atlas session roadmap                  — plans in current project
  atlas session audit                    — progress report (stub)
  atlas session dream                    — last dream cycles (stub)
EOF
    ;;
  *) echo "Unknown subcommand: $1. Try 'atlas session help'." >&2; exit 1 ;;
esac
