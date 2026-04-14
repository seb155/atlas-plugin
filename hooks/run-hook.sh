#!/usr/bin/env bash
# TypeScript hook runner for ATLAS plugin
# Resolves to the ts/ directory within the plugin hooks
#
# Usage: run-hook.sh <hook-name>
# Example: run-hook.sh inject-datetime

set -euo pipefail
IFS=$'\n\t'

HOOK_NAME="${1:-}"
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

# Workspace root for module resolution (falls back to plugin root)
ATLAS_ROOT="${ATLAS_ROOT:-$PLUGIN_ROOT}"
cd "$ATLAS_ROOT" 2>/dev/null || cd "$PLUGIN_ROOT" 2>/dev/null || true

# Detect JS runtime: bun (preferred) → npx tsx → skip
# Use array to avoid word-splitting issues with multi-word commands.
if command -v bun &>/dev/null; then
  JS_CMD=(bun run)
elif command -v npx &>/dev/null; then
  JS_CMD=(npx --yes tsx)
else
  # No JS runtime — skip TS hooks gracefully
  exit 0
fi

# Run with timeout if available (GNU coreutils), otherwise run directly.
# CC enforces its own hook timeout via hooks.json, so this is a safety net.
if command -v timeout &>/dev/null; then
  exec timeout 10 "${JS_CMD[@]}" "$HOOK_FILE"
else
  exec "${JS_CMD[@]}" "$HOOK_FILE"
fi
