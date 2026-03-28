#!/bin/bash
# TypeScript hook runner for ATLAS plugin
# Adapted from atlas/.claude/scripts/run-hook.sh
# Resolves to the ts/ directory within the plugin hooks
#
# Usage: run-hook.sh <hook-name>
# Example: run-hook.sh inject-datetime
#
# The hook name maps to hooks/ts/<hook-name>.ts

HOOK_NAME="$1"
if [ -z "$HOOK_NAME" ]; then
  echo "Usage: run-hook.sh <hook-name>" >&2
  exit 0
fi

# Resolve plugin root
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
HOOK_FILE="$PLUGIN_ROOT/hooks/ts/${HOOK_NAME}.ts"

# Graceful exit if hook doesn't exist
if [ ! -f "$HOOK_FILE" ]; then
  exit 0
fi

# ATLAS_ROOT is needed for workspace module resolution (@atlas/core/*)
# Some TS hooks import from the atlas monorepo workspace
ATLAS_ROOT="${ATLAS_ROOT:-$HOME/workspace_atlas/atlas}"

# cd to atlas root so bun resolves workspace dependencies
cd "$ATLAS_ROOT" 2>/dev/null || true

# Run the hook with timeout (10s max) to prevent hanging
# Use bun (preferred — workspace-aware) or fall back to tsx
exec timeout 10 bun run "$HOOK_FILE"
