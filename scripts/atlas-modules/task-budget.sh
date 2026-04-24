#!/usr/bin/env bash
# shellcheck shell=bash
# ATLAS Task Budget Module — exposes CLAUDE_TOKEN_BUDGET env from AGENT.md
# Plan v6.0 Sprint 5.5
#
# Sourced by atlas-cli.sh (no set -euo pipefail at file level when sourced).
# Self-test mode: ./task-budget.sh --test (runs as standalone executable).

# Only enable strict mode when invoked directly, not when sourced
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  set -euo pipefail
fi

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Read task_budget integer from AGENT.md YAML frontmatter.
# Usage: _atlas_get_task_budget <agent_name>
# Returns: budget integer (>=0); 0 means unset/missing.
_atlas_get_task_budget() {
  local agent_name="$1"
  local agent_md="${PLUGIN_ROOT}/agents/${agent_name}/AGENT.md"
  [ -f "$agent_md" ] || { echo "0"; return 0; }

  # Parse YAML frontmatter for task_budget
  python3 -c "
import yaml, sys
try:
    with open('$agent_md') as f:
        content = f.read()
    parts = content.split('---')
    if len(parts) >= 3:
        fm = yaml.safe_load(parts[1]) or {}
        budget = fm.get('task_budget', 0)
        try:
            print(int(budget) if isinstance(budget, (int, str)) else 0)
        except (ValueError, TypeError):
            print(0)
    else:
        print(0)
except Exception:
    print(0)
" 2>/dev/null || echo "0"
}

# Export CLAUDE_TOKEN_BUDGET=<budget> if AGENT.md declares one (>0).
# Usage: _atlas_apply_task_budget <agent_name>
_atlas_apply_task_budget() {
  local agent_name="$1"
  local budget
  budget=$(_atlas_get_task_budget "$agent_name")
  if [ "$budget" -gt 0 ] 2>/dev/null; then
    export CLAUDE_TOKEN_BUDGET="$budget"
    echo "📊 Task budget: $budget tokens (advisory)" >&2
  fi
}

# Self-test if invoked directly
if [[ "${1:-}" == "--test" ]]; then
  for agent in plan-architect code-reviewer team-engineer team-researcher; do
    echo "$agent: $(_atlas_get_task_budget "$agent")"
  done
fi
