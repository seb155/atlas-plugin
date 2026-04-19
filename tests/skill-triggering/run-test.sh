#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
# ATLAS — Skill triggering eval (single skill)
# Tests whether a naive user prompt triggers the expected skill
# without mentioning the skill name.
#
# Usage:
#   ./run-test.sh <skill-name> <prompt-file> [max-turns]
#
# Example:
#   ./run-test.sh systematic-debugging ./prompts/systematic-debugging.txt
#
# Exit codes:
#   0 = PASS (skill triggered)
#   1 = FAIL (skill not triggered)
#   2 = ERROR (claude CLI failed, bad args, etc.)
#
# Source: ported from obra/superpowers tests/skill-triggering/run-test.sh
# Attribution: Jesse Vincent (Prime Radiant) — MIT
# Reference: docs/ADR/ADR-007-skill-triggering-eval-framework.md
# ─────────────────────────────────────────────────────────────────────

set -euo pipefail

SKILL_NAME="${1:-}"
PROMPT_FILE="${2:-}"
MAX_TURNS="${3:-3}"

if [[ -z "$SKILL_NAME" ]] || [[ -z "$PROMPT_FILE" ]]; then
  echo "Usage: $0 <skill-name> <prompt-file> [max-turns]" >&2
  echo "Example: $0 systematic-debugging ./prompts/systematic-debugging.txt" >&2
  exit 2
fi

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "[error] prompt file not found: $PROMPT_FILE" >&2
  exit 2
fi

# Resolve paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Output dir: /tmp/atlas-skill-eval/<timestamp>/<skill>/
TIMESTAMP=$(date +%s)
OUTPUT_DIR="/tmp/atlas-skill-eval/${TIMESTAMP}/${SKILL_NAME}"
mkdir -p "$OUTPUT_DIR"

# Copy prompt for reproducibility
cp "$PROMPT_FILE" "$OUTPUT_DIR/prompt.txt"

# Colors (respect NO_COLOR)
if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
  RED=''; GRN=''; YEL=''; BLU=''; BLD=''; RST=''
else
  RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'
  BLU=$'\033[34m'; BLD=$'\033[1m'; RST=$'\033[0m'
fi

echo "${BLU}[skill-eval]${RST} Testing: ${BLD}${SKILL_NAME}${RST}"
echo "${BLU}[skill-eval]${RST} Prompt: ${PROMPT_FILE}"
echo "${BLU}[skill-eval]${RST} Max turns: ${MAX_TURNS}"
echo "${BLU}[skill-eval]${RST} Output: ${OUTPUT_DIR}"
echo ""

# Read prompt
PROMPT=$(cat "$PROMPT_FILE")

# Log file captures stream-json output
LOG_FILE="$OUTPUT_DIR/claude-output.json"

# Run claude -p with plugin dir + stream JSON
# --dangerously-skip-permissions: needed because eval is non-interactive
# --max-turns: cap in case skill chain loops
# We capture both stdout and stderr; failures exit 0 here, we parse exit via log content
cd "$OUTPUT_DIR"

echo "${BLU}[skill-eval]${RST} Invoking claude..."
set +e
timeout 300 claude -p "$PROMPT" \
  --plugin-dir "$PLUGIN_DIR" \
  --dangerously-skip-permissions \
  --max-turns "$MAX_TURNS" \
  --output-format stream-json \
  > "$LOG_FILE" 2>&1
CLAUDE_EXIT=$?
set -e

if [[ "$CLAUDE_EXIT" -ne 0 ]]; then
  echo "${YEL}[skill-eval]${RST} claude CLI exited with $CLAUDE_EXIT (non-fatal, checking log)"
fi

# ── Parse results ──
# Pattern matches: "name":"Skill" AND "skill":"<namespace>:<skill-name>"|"<skill-name>"
SKILL_PATTERN="\"skill\":\"([^\"]*:)?${SKILL_NAME}\""

echo ""
if grep -q '"name":"Skill"' "$LOG_FILE" && grep -qE "$SKILL_PATTERN" "$LOG_FILE"; then
  echo "${GRN}✅ PASS${RST}: skill '${SKILL_NAME}' was triggered"
  VERDICT="PASS"
  EXIT=0
else
  echo "${RED}❌ FAIL${RST}: skill '${SKILL_NAME}' was NOT triggered"
  VERDICT="FAIL"
  EXIT=1
fi

# Log skills that WERE triggered (for debugging FAILs)
echo ""
echo "${BLU}Skills triggered in this run:${RST}"
grep -o '"skill":"[^"]*"' "$LOG_FILE" 2>/dev/null | sort -u || echo "  (none)"

# Show first assistant response (truncated)
echo ""
echo "${BLU}First assistant response (truncated 500 chars):${RST}"
grep '"type":"assistant"' "$LOG_FILE" 2>/dev/null | head -1 | jq -r '.message.content[0].text // .message.content' 2>/dev/null | head -c 500 || echo "  (could not extract)"

echo ""
echo "${BLU}[skill-eval]${RST} Verdict: ${VERDICT} (exit $EXIT)"
echo "${BLU}[skill-eval]${RST} Full log: ${LOG_FILE}"

exit "$EXIT"
