#!/usr/bin/env bash
# shellcheck shell=bash
# NOTE: Sourced by scripts/atlas-cli.sh (no set -euo pipefail at file level).
# ATLAS CLI Module: Backward Compatibility, Zsh Completion, First-run
# Sourced by atlas-cli.sh — do not execute directly

# ─── Backward Compatibility (deprecated, remove after 2026-04-27) ──
atlas-synapse()       { echo "⚠️  Deprecated: use 'atlas synapse'" >&2; atlas synapse "$@"; }
atlas-synapse-w()     { echo "⚠️  Deprecated: use 'atlas synapse'" >&2; atlas synapse "$@"; }
atlas-synapse-split() { echo "⚠️  Deprecated: use 'atlas synapse'" >&2; atlas synapse "$@"; }
atlas-w()             { echo "⚠️  Deprecated: use 'atlas <project>'" >&2; atlas "$@"; }
atlas-split()         { echo "⚠️  Deprecated: use 'atlas <project>'" >&2; atlas "$@"; }

# ─── Zsh Completion ───────────────────────────────────────────
if [ -n "$ZSH_VERSION" ]; then
  _atlas_completions() {
    local -a subcommands projects flags

    subcommands=(
      'list:Show projects (--all for workspace scan)'
      'resume:Resume most recent session'
      'status:Active tmux sessions'
      'dashboard:Session & topic overview'
      'dash:Session & topic overview (alias)'
      'topics:List topic registry (active & completed)'
      'setup:Run onboarding wizard'
      'doctor:Health check'
      'hooks:Hook health dashboard'
      'help:Show documentation'
    )

    projects=($(_atlas_known_projects))

    flags=(
      '-i:Inline mode (no worktree, no split)'
      '--inline:Inline mode (no worktree, no split)'
      '-y:Yolo mode (bypass permissions)'
      '--yolo:Yolo mode (bypass permissions)'
      '-a:Auto mode (Sonnet classifier)'
      '--auto:Auto mode (Sonnet classifier)'
      '-p:Plan mode (read-only)'
      '--plan:Plan mode (read-only)'
      '-b:Bare mode (fast, no plugins)'
      '--bare:Bare mode (fast, no plugins)'
      '-e:Set effort level (low/medium/high/max)'
      '--effort:Set effort level'
      '-c:Continue last session'
      '--continue:Continue last session'
      '-r:Resume session by name'
      '--resume:Resume session by name'
      '-n:Override session name'
      '--name:Override session name'
      '--no-split:Disable tmux split'
      '--no-worktree:Disable worktree'
      '-h:Show help'
    )

    if (( CURRENT == 2 )); then
      _describe 'subcommand' subcommands
      compadd -a projects
    else
      _describe 'flag' flags
    fi
  }
  compdef _atlas_completions atlas 2>/dev/null
fi

# ─── First-run Detection ─────────────────────────────────────
if [ ! -f "$ATLAS_CONFIG" ] || ! python3 -c "import json; json.load(open('$ATLAS_CONFIG')).get('launcher')" 2>/dev/null; then
  if [ -t 0 ] && [ -t 1 ]; then
    # Only show in interactive shells, not during script execution
    printf "\n  ${ATLAS_GOLD}🏛️ ATLAS${ATLAS_RESET} detected but not configured.\n"
    printf "  Run ${ATLAS_BOLD}atlas setup${ATLAS_RESET} to configure your environment.\n\n"
  fi
fi
