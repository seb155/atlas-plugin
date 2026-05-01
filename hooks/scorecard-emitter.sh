#!/bin/bash
# Hook: PostToolUse — Emit a per-skill scorecard line to ~/.atlas/scorecards/{skill}/{YYYY-MM-DD}.jsonl
#
# v7.0 W1.2 (companion to W1.1 atlas-trace). Reads Claude Code hook stdin, decides whether the
# completed tool invocation belongs to a Skill (i.e. is the body of a Skill-tool dispatch), and
# if so appends a compact metric line for downstream rolling stats / regression detection /
# cost attribution.
#
# Detection strategy (best-effort, lightweight — overhead target <2ms P95):
#   1. tool_name == "Skill" → use tool_input.skill as the skill name (direct invocation).
#   2. ATLAS_TRACE_ENABLED=1 + ATLAS_TRACE_ID set + traces dir exists → look up the parent span
#      in ~/.atlas/traces/{session}/{trace}.jsonl whose service == "skill". This handles the
#      case where a skill uses Bash/Read/etc. underneath.
#   3. Otherwise: emit nothing (avoid polluting scorecards with unrelated tool calls).
#
# Schema written (one JSON line per qualifying invocation):
#   {"ts":"<ISO-8601 UTC>","skill":"<name>","duration_ms":<int>,"status":"ok|error",
#    "tokens_used":<int>,"cost_usd":<float>,"trace_id":"<uuid|null>"}
#
# Exit 0 always (never block tool execution). Robust to missing jq / malformed input.
set -uo pipefail

# Read stdin once; tolerate empty input (e.g. when invoked manually for testing).
INPUT=""
if [ ! -t 0 ]; then
  INPUT=$(cat || true)
fi
[ -z "$INPUT" ] && exit 0

# jq is required; if absent, fail-soft.
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

# --- Resolve skill name --------------------------------------------------------------------
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
SKILL_NAME=""

if [ "$TOOL_NAME" = "Skill" ]; then
  SKILL_NAME=$(echo "$INPUT" | jq -r '.tool_input.skill // ""' 2>/dev/null)
fi

# Fallback: when the active span in the trace says we're inside a skill, attribute to that skill.
SESSION_ID="${CLAUDE_SESSION_ID:-}"
TRACE_ID="${ATLAS_TRACE_ID:-}"
if [ -z "$SKILL_NAME" ] && [ "${ATLAS_TRACE_ENABLED:-0}" = "1" ] && [ -n "$SESSION_ID" ] && [ -n "$TRACE_ID" ]; then
  TRACE_FILE="$HOME/.atlas/traces/$SESSION_ID/$TRACE_ID.jsonl"
  if [ -f "$TRACE_FILE" ]; then
    # Pick the most recent span with service=="skill" and status=="pending" — that's our parent skill.
    SKILL_NAME=$(tac "$TRACE_FILE" 2>/dev/null \
      | jq -r 'select(.service=="skill" and .status=="pending") | .operation' 2>/dev/null \
      | head -n1 || true)
  fi
fi

# No skill attribution → nothing to emit.
[ -z "$SKILL_NAME" ] && exit 0

# --- Extract metrics ----------------------------------------------------------------------
TS=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
DAY=$(date -u '+%Y-%m-%d')

DURATION_MS=$(echo "$INPUT" | jq -r '.duration_ms // 0' 2>/dev/null)
[ -z "$DURATION_MS" ] && DURATION_MS=0

EXIT_CODE=$(echo "$INPUT" | jq -r '.exit_code // 0' 2>/dev/null)
TOOL_OUTPUT=$(echo "$INPUT" | jq -r '.tool_output // ""' 2>/dev/null | head -c 200 || true)

STATUS="ok"
if [ "$EXIT_CODE" != "0" ] && [ "$EXIT_CODE" != "null" ] && [ -n "$EXIT_CODE" ]; then
  STATUS="error"
elif echo "$TOOL_OUTPUT" | grep -qiE '(^|[^a-z])(error|failed|exception|denied|traceback)' 2>/dev/null; then
  STATUS="error"
fi

# Token + cost are best-effort; populated when the harness exposes them.
TOKENS_USED=$(echo "$INPUT" | jq -r '.tokens_used // .tokens.total // 0' 2>/dev/null)
[ -z "$TOKENS_USED" ] && TOKENS_USED=0
COST_USD=$(echo "$INPUT" | jq -r '.cost_usd // .cost // 0' 2>/dev/null)
[ -z "$COST_USD" ] && COST_USD=0

# Normalize trace_id to JSON null when unknown.
TRACE_FIELD="null"
if [ -n "$TRACE_ID" ]; then
  TRACE_FIELD="\"$TRACE_ID\""
fi

# --- Append to scorecard JSONL (atomic single-line append) --------------------------------
SCORECARD_DIR="$HOME/.atlas/scorecards/$SKILL_NAME"
mkdir -p "$SCORECARD_DIR" 2>/dev/null || exit 0
SCORECARD_FILE="$SCORECARD_DIR/$DAY.jsonl"

LINE="{\"ts\":\"$TS\",\"skill\":\"$SKILL_NAME\",\"duration_ms\":$DURATION_MS,\"status\":\"$STATUS\",\"tokens_used\":$TOKENS_USED,\"cost_usd\":$COST_USD,\"trace_id\":$TRACE_FIELD}"

# Single write() — POSIX guarantees <PIPE_BUF atomic for line-sized writes.
echo "$LINE" >> "$SCORECARD_FILE" 2>/dev/null || true

exit 0
