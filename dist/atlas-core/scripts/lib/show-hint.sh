#!/usr/bin/env bash
# ATLAS Visibility Hint (SP-AGENT-VIS Layer 3 fallback)
#
# Emits a one-time-per-session hint to stderr when Layer 3 auto-tail is
# skipped (no tmux, no WT). Uses a marker file in /tmp to throttle.
#
# Usage: show-hint.sh               (emits if not yet shown this session)
#        show-hint.sh --force       (always emit)
#        show-hint.sh --reset       (clear marker so next call shows again)
#
# Plan: .blueprint/plans/keen-nibbling-umbrella.md Layer 3 fallback.
set -euo pipefail

MARKER_DIR="/tmp"
# Use session id if set, else PPID, else static fallback
SESSION_ID="${CLAUDE_SESSION_ID:-${SESSION_ID:-${PPID:-shell}}}"
MARKER_FILE="${MARKER_DIR}/atlas-hint-shown-${SESSION_ID}"

case "${1:-}" in
  --reset)
    rm -f "$MARKER_FILE"
    echo "✓ Hint throttle reset" >&2
    exit 0
    ;;
  --force)
    show=1
    ;;
  *)
    if [ -f "$MARKER_FILE" ]; then
      exit 0  # Already shown this session
    fi
    show=1
    ;;
esac

if [ "${show:-0}" = "1" ]; then
  cat >&2 <<'EOF'
💡 ATLAS Subagent running — to see logs live:
   • Launch Claude Code inside tmux for auto-split pane visibility, OR
   • `atlas agents tail <id>` for manual tail in this terminal, OR
   • `atlas agents replay <id>` post-completion for full transcript
   • Opt-out: export ATLAS_AUTO_TAIL_AGENTS=0
EOF
  # Mark shown for this session
  touch "$MARKER_FILE" 2>/dev/null || true
fi
