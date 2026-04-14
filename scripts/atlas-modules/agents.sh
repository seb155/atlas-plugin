#!/usr/bin/env bash
# shellcheck shell=bash
# NOTE: Sourced by scripts/atlas-cli.sh (no set -euo pipefail at file level).
# ATLAS CLI Module: Subagent Visibility (SP-AGENT-VIS Layer 4)
# Sourced by atlas-cli.sh — do not execute directly
#
# Provides `atlas agents [subcommand]` CLI surface for visibility into
# background subagents tracked in ~/.atlas/runtime/agents.json
# (populated by Phase 1 PostToolUse:Agent hook).
#
# Subcommands:
#   atlas agents            → list running + recent (default)
#   atlas agents list       → same as above (explicit)
#   atlas agents tail <id>  → open tail pane for an agent (or raw tail if no tmux)
#   atlas agents stop <id>  → SIGTERM the agent's process
#   atlas agents replay <id> → show full transcript paged (uses formatter when available)
#   atlas agents stats      → delegate to existing _atlas_agent_stats (historical telemetry)
#   atlas agents clean      → prune all stale entries from agents.json
#   atlas agents env        → show detected visibility environment (tmux / WT / fallback)
#
# Plan: .blueprint/plans/keen-nibbling-umbrella.md Layer 4

_ATLAS_AGENTS_FILE="${ATLAS_DIR:-$HOME/.atlas}/runtime/agents.json"
_ATLAS_JSONL_FORMAT="${ATLAS_SHELL_DIR:-$HOME/.atlas/shell}/../scripts/atlas-jsonl-format.sh"
_ATLAS_AGENT_TAIL="${ATLAS_SHELL_DIR:-$HOME/.atlas/shell}/../scripts/atlas-agent-tail.sh"

# ─── Helper: pretty-print duration ─────────────────────────────
_atlas_agents_fmt_duration() {
  local ms="$1"
  [ -z "$ms" ] || [ "$ms" = "null" ] && { echo "—"; return; }
  local s=$((ms / 1000))
  if [ "$s" -lt 60 ]; then
    echo "${s}s"
  elif [ "$s" -lt 3600 ]; then
    echo "$((s / 60))m $((s % 60))s"
  else
    echo "$((s / 3600))h $(((s % 3600) / 60))m"
  fi
}

# ─── Helper: pretty-print status icon ──────────────────────────
_atlas_agents_fmt_status() {
  case "$1" in
    running|spawning) printf '▶ running ' ;;
    completed)       printf '✓ done    ' ;;
    failed)          printf '✗ failed  ' ;;
    *)               printf '? unknown ' ;;
  esac
}

# ─── Main: list ────────────────────────────────────────────────
_atlas_agents_list() {
  if [ ! -f "$_ATLAS_AGENTS_FILE" ]; then
    echo "  No agents tracked yet. (Registry: $_ATLAS_AGENTS_FILE)"
    echo "  Dispatch a background Agent() call and it will appear here."
    return 0
  fi

  local count=$(jq -r 'length' "$_ATLAS_AGENTS_FILE" 2>/dev/null || echo 0)
  if [ "$count" = "0" ]; then
    echo "  No agents tracked. (Registry empty)"
    return 0
  fi

  echo ""
  echo "  ATLAS — Agent Visibility"
  echo ""
  printf "  %-17s  %-20s  %-11s  %-10s  %-6s  %s\n" "ID" "TYPE" "STATUS" "DURATION" "VIS" "STARTED"
  printf "  %-17s  %-20s  %-11s  %-10s  %-6s  %s\n" "$(printf '%.0s─' {1..17})" "$(printf '%.0s─' {1..20})" "$(printf '%.0s─' {1..11})" "$(printf '%.0s─' {1..10})" "$(printf '%.0s─' {1..6})" "$(printf '%.0s─' {1..8})"

  # Sort by started_at DESC, then print each row
  jq -r '
    to_entries
    | map({
        id: .value.agent_id,
        type: (.value.agent_type // "unknown"),
        status: .value.status,
        dur: (.value.duration_ms // null),
        vis: (.value.visibility_mode // "none"),
        started: (.value.started_at // "")
      })
    | sort_by(.started) | reverse
    | .[] | [.id, .type, .status, (.dur|tostring), .vis, .started] | @tsv
  ' "$_ATLAS_AGENTS_FILE" 2>/dev/null | while IFS=$'\t' read -r id type stat dur vis started; do
    local id_short="${id:0:15}"
    local type_short="${type:0:18}"
    local dur_fmt=$(_atlas_agents_fmt_duration "$dur")
    local status_icon=$(_atlas_agents_fmt_status "$stat")
    local start_short="${started:11:5}"
    printf "  %-17s  %-20s  %-11s  %-10s  %-6s  %s\n" \
      "$id_short" "$type_short" "$status_icon" "$dur_fmt" "$vis" "$start_short"
  done
  echo ""
}

# ─── Tail (manual pane spawn or raw if no tmux) ───────────────
_atlas_agents_tail() {
  local agent_id="$1"
  if [ -z "$agent_id" ]; then
    echo "Usage: atlas agents tail <agent_id>"
    return 1
  fi
  if [ ! -f "$_ATLAS_AGENTS_FILE" ]; then
    echo "No registry at $_ATLAS_AGENTS_FILE"
    return 1
  fi

  local output_file=$(jq -r --arg id "$agent_id" '.[$id].output_file // empty' "$_ATLAS_AGENTS_FILE")
  if [ -z "$output_file" ]; then
    echo "Unknown agent_id: $agent_id"
    echo "Use: atlas agents list   (to see known IDs)"
    return 1
  fi
  if [ ! -e "$output_file" ]; then
    echo "Output file not yet present: $output_file"
    echo "Agent may still be spawning. Retry in a few seconds."
    return 1
  fi

  local agent_type=$(jq -r --arg id "$agent_id" '.[$id].agent_type // "?"' "$_ATLAS_AGENTS_FILE")

  # If in tmux, spawn new pane; else raw tail in current terminal
  if [ -n "$TMUX" ] && tmux display-message -p '#S' &>/dev/null; then
    if [ -x "$_ATLAS_AGENT_TAIL" ]; then
      tmux split-window -h -p 35 -d "$_ATLAS_AGENT_TAIL $agent_id"
      echo "✓ Opened tail pane for $agent_type [$agent_id]"
    else
      echo "⚠️ atlas-agent-tail.sh not installed yet (Phase 4). Falling back to raw tail..."
      tmux split-window -h -p 35 -d "tail -f '$output_file'"
      echo "✓ Raw tail pane opened for $agent_id"
    fi
  else
    echo "═══ Tailing: $agent_type [$agent_id] ═══"
    echo "  File: $output_file"
    echo "  (Ctrl+C to stop)"
    echo ""
    if [ -x "$_ATLAS_JSONL_FORMAT" ]; then
      tail -f "$output_file" | "$_ATLAS_JSONL_FORMAT"
    else
      tail -f "$output_file"
    fi
  fi
}

# ─── Stop (SIGTERM the agent process) ─────────────────────────
_atlas_agents_stop() {
  local agent_id="$1"
  if [ -z "$agent_id" ]; then
    echo "Usage: atlas agents stop <agent_id>"
    return 1
  fi
  local output_file=$(jq -r --arg id "$agent_id" '.[$id].output_file // empty' "$_ATLAS_AGENTS_FILE" 2>/dev/null)
  if [ -z "$output_file" ]; then
    echo "Unknown agent_id: $agent_id"
    return 1
  fi
  # Find writer PID via lsof (best-effort)
  if command -v lsof &>/dev/null; then
    local pids=$(lsof -t "$output_file" 2>/dev/null | head -5)
    if [ -z "$pids" ]; then
      echo "No active writer on $output_file — agent may already be stopped."
      return 0
    fi
    echo "Stopping PIDs writing to $output_file: $pids"
    echo "$pids" | xargs -r kill -TERM 2>/dev/null
    echo "✓ SIGTERM sent to $agent_id"
  else
    echo "lsof not available — cannot find agent PID. Install lsof to use stop."
    return 1
  fi
}

# ─── Replay (cat transcript through formatter) ────────────────
_atlas_agents_replay() {
  local agent_id="$1"
  if [ -z "$agent_id" ]; then
    echo "Usage: atlas agents replay <agent_id>"
    return 1
  fi
  local output_file=$(jq -r --arg id "$agent_id" '.[$id].output_file // empty' "$_ATLAS_AGENTS_FILE" 2>/dev/null)
  if [ -z "$output_file" ] || [ ! -e "$output_file" ]; then
    echo "No output file for $agent_id (unknown or not yet created)"
    return 1
  fi
  if [ -x "$_ATLAS_JSONL_FORMAT" ]; then
    cat "$output_file" | "$_ATLAS_JSONL_FORMAT" | ${PAGER:-less -R}
  else
    # Minimal jq-only fallback: show assistant text + tool_use names
    jq -r 'if .type == "assistant" then
             (.message.content // []) | map(
               if .type == "text" then "💬 " + (.text[:200])
               elif .type == "tool_use" then "🔧 " + .name + " " + ((.input.description // .input.command // .input.file_path // "") | tostring | .[:120])
               else "" end
             ) | .[] | select(. != "")
           elif .type == "user" then
             (.message.content // []) | if type == "array" then
               map(select(.type == "tool_result")) | map("   ✓ " + (.tool_use_id // "?")) | .[]
             else empty end
           else empty end' "$output_file" 2>/dev/null | ${PAGER:-less -R}
  fi
}

# ─── Clean (prune all entries) ────────────────────────────────
_atlas_agents_clean() {
  if [ ! -f "$_ATLAS_AGENTS_FILE" ]; then
    echo "No registry to clean."
    return 0
  fi
  # Prune via the registry lib (pruneStale with 0 = immediate purge of all stale)
  local before=$(jq -r 'length' "$_ATLAS_AGENTS_FILE" 2>/dev/null || echo 0)
  # Direct purge: keep only entries with status in (running, spawning)
  jq 'with_entries(select(.value.status == "running" or .value.status == "spawning"))' \
    "$_ATLAS_AGENTS_FILE" > "${_ATLAS_AGENTS_FILE}.tmp.$$" \
    && mv "${_ATLAS_AGENTS_FILE}.tmp.$$" "$_ATLAS_AGENTS_FILE"
  local after=$(jq -r 'length' "$_ATLAS_AGENTS_FILE" 2>/dev/null || echo 0)
  echo "✓ Cleaned: $((before - after)) entries pruned, $after kept (running/spawning)."
}

# ─── Env (show detected visibility environment) ───────────────
_atlas_agents_env() {
  echo ""
  echo "  ATLAS — Visibility Environment Detection"
  echo ""
  echo "  ATLAS_AUTO_TAIL_AGENTS = ${ATLAS_AUTO_TAIL_AGENTS:-<unset> (default: on)}"
  echo "  ATLAS_MAX_TAIL_PANES   = ${ATLAS_MAX_TAIL_PANES:-2}"
  echo ""
  if [ "$ATLAS_AUTO_TAIL_AGENTS" = "0" ]; then
    echo "  Result: OPT-OUT (user disabled) — Layers 1+2+4 still active"
    return 0
  fi
  if [ -n "$TMUX" ] && tmux display-message -p '#S' &>/dev/null; then
    local panes=$(tmux list-panes 2>/dev/null | wc -l | tr -d ' ')
    echo "  Result: ✅ TMUX ACTIVE"
    echo "    Session: $(tmux display-message -p '#S')"
    echo "    Current pane count: $panes"
    echo "    Auto-tail Layer 3 will spawn side panes (cap=${ATLAS_MAX_TAIL_PANES:-2})"
    return 0
  fi
  if [ -n "$WT_SESSION" ] && command -v wt.exe &>/dev/null; then
    echo "  Result: ✅ WINDOWS TERMINAL"
    echo "    Auto-tail Layer 3 will spawn new wt.exe tab"
    return 0
  fi
  echo "  Result: ⚠️ FALLBACK (no tmux / no WT)"
  echo "    Layer 3 auto-tail skipped — hint shown once per session"
  echo "    Use: atlas agents tail <id>   (for manual tail in current terminal)"
}

# ─── Main dispatcher ───────────────────────────────────────────
_atlas_agents_cmd() {
  local sub="${1:-list}"
  case "$sub" in
    ""|list|ls)      _atlas_agents_list ;;
    tail)            shift; _atlas_agents_tail "$@" ;;
    stop|kill)       shift; _atlas_agents_stop "$@" ;;
    replay|show)     shift; _atlas_agents_replay "$@" ;;
    stats)
                     # Delegate to existing _atlas_agent_stats (historical telemetry)
                     if command -v _atlas_agent_stats &>/dev/null; then
                       shift; _atlas_agent_stats "$@"
                     else
                       echo "_atlas_agent_stats not loaded (dispatch.sh module)"
                     fi
                     ;;
    clean|prune)     _atlas_agents_clean ;;
    env)             _atlas_agents_env ;;
    help|-h|--help)
      cat <<'EOF'
ATLAS — Subagent Visibility CLI

Usage:
  atlas agents                 List running + recent agents (default)
  atlas agents list            Same as above
  atlas agents tail <id>       Tail transcript (new tmux pane or raw)
  atlas agents stop <id>       Stop an agent (SIGTERM to its PID)
  atlas agents replay <id>     Show full transcript paged
  atlas agents stats           Historical stats (delegates to existing)
  atlas agents clean           Prune completed/failed entries from registry
  atlas agents env             Show detected visibility environment

Env vars:
  ATLAS_AUTO_TAIL_AGENTS=0     Opt out of auto-tail (default: on in tmux)
  ATLAS_MAX_TAIL_PANES=N       Cap auto-spawned panes (default: 2)

See: .blueprint/plans/keen-nibbling-umbrella.md (SP-AGENT-VIS)
EOF
      ;;
    *)
      echo "Unknown subcommand: $sub"
      echo "Try: atlas agents help"
      return 1
      ;;
  esac
}
