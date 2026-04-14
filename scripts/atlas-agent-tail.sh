#!/usr/bin/env bash
# ATLAS Subagent Tail (SP-AGENT-VIS Layer 3)
#
# Runs inside a tmux pane or terminal and tails the JSONL transcript of a
# given agent_id through the formatter. Called by:
#   - Layer 3 auto-spawn (PostToolUse:Agent hook -> tmux split-window)
#   - CLI `atlas agents tail <id>` (manual invocation)
#
# Usage: atlas-agent-tail.sh <agent_id>
#
# Behavior:
#   1. Read ~/.atlas/runtime/agents.json to find output_file for agent_id
#   2. Wait up to 30s for output_file to exist (agent startup delay)
#   3. Tail -f the file through atlas-jsonl-format.sh
#
# Plan: .blueprint/plans/keen-nibbling-umbrella.md Layer 3.
set -euo pipefail

AGENT_ID="${1:-}"
if [ -z "$AGENT_ID" ]; then
  echo "Usage: atlas-agent-tail.sh <agent_id>" >&2
  exit 1
fi

AGENTS_FILE="${ATLAS_DIR:-$HOME/.atlas}/runtime/agents.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORMATTER="$SCRIPT_DIR/atlas-jsonl-format.sh"

# Wait up to 30s for output_file to exist
OUTPUT_FILE=""
for _ in $(seq 1 30); do
  if [ -f "$AGENTS_FILE" ]; then
    OUTPUT_FILE=$(jq -r --arg id "$AGENT_ID" '.[$id].output_file // empty' "$AGENTS_FILE" 2>/dev/null || echo "")
    if [ -n "$OUTPUT_FILE" ] && [ -e "$OUTPUT_FILE" ]; then
      break
    fi
  fi
  sleep 1
done

if [ -z "$OUTPUT_FILE" ]; then
  echo "❌ No output_file registered for agent $AGENT_ID (check $AGENTS_FILE)" >&2
  echo "Press any key to close..." >&2
  read -r _
  exit 1
fi

if [ ! -e "$OUTPUT_FILE" ]; then
  echo "❌ Output file not yet created: $OUTPUT_FILE" >&2
  echo "   Agent may still be spawning. Retry in a few seconds via:" >&2
  echo "   atlas agents tail $AGENT_ID" >&2
  read -r _
  exit 1
fi

# Header
AGENT_TYPE=$(jq -r --arg id "$AGENT_ID" '.[$id].agent_type // "?"' "$AGENTS_FILE" 2>/dev/null)
echo "═══════════════════════════════════════════════════════════════"
echo "  🤖 ATLAS Agent Tail — $AGENT_TYPE [$AGENT_ID]"
echo "  📄 $OUTPUT_FILE"
echo "  (Ctrl+C to stop. Pane stays visible after completion — close with prefix-x.)"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Tail + format
if [ -x "$FORMATTER" ]; then
  exec tail -f "$OUTPUT_FILE" | "$FORMATTER"
else
  echo "⚠️  Formatter not found: $FORMATTER — falling back to raw tail" >&2
  exec tail -f "$OUTPUT_FILE"
fi
