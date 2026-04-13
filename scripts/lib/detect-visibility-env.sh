#!/usr/bin/env bash
# ATLAS Visibility Environment Detection (SP-AGENT-VIS Layer 3)
#
# Cascade detection for where to render subagent tail:
#   tmux     → 'tmux' (Linux/macOS/WSL with tmux active)
#   Win Term → 'wt'    (Windows with wt.exe available)
#   fallback → 'fallback' (no terminal multiplexer)
#   none     → 'none'   (user explicitly opted out via ATLAS_AUTO_TAIL_AGENTS=0)
#
# Exports a single string to stdout for consumption by:
#   - hooks/ts/subagent-output-capture.ts (TS code)
#   - atlas agents env CLI subcommand
#
# Usage: detect-visibility-env.sh       → prints detected env
# Plan: .blueprint/plans/keen-nibbling-umbrella.md Layer 3 cascade.
set -euo pipefail

detect_visibility_env() {
  # User opt-out check first (highest priority)
  if [ "${ATLAS_AUTO_TAIL_AGENTS:-1}" = "0" ]; then
    echo "none"
    return
  fi

  # Tmux check: both $TMUX env var + tmux session reachable
  if [ -n "${TMUX:-}" ] && tmux display-message -p '#S' &>/dev/null; then
    echo "tmux"
    return
  fi

  # Windows Terminal check: $WT_SESSION set + wt.exe available
  if [ -n "${WT_SESSION:-}" ] && command -v wt.exe &>/dev/null; then
    echo "wt"
    return
  fi

  # No interactive multiplexer — silent skip with optional hint
  echo "fallback"
}

# If run directly (not sourced), just print the result
if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
  detect_visibility_env
fi
