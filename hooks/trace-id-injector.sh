#!/usr/bin/env bash
# ATLAS trace-id-injector hook (PreToolUse + SubagentStart events)
#
# Plan: .blueprint/plans/ultrathink-regarde-ce-qui-abundant-petal.md Section H W1.1
# Part of W1 OBSERVABILITY — opens a tracing span when a tool / subagent starts.
#
# Behavior:
#   1. Exit fast (0) if ATLAS_TRACE_ENABLED != 1 (opt-in, zero overhead default)
#   2. Resolve session_id (CLAUDE_SESSION_ID > fallback "session-$PPID-$$")
#   3. Resolve trace_id (ATLAS_TRACE_ID > _active symlink > generate fresh)
#   4. Generate a span_id (uuidv4)
#   5. Determine parent_span_id from $ATLAS_TRACE_SPAN_STACK (newline-separated stack)
#   6. Build span JSON (status: "pending") and append atomically (flock)
#   7. Push span_id onto stack file ~/.atlas/traces/$SESSION_ID/_stack
#
# Fast-fail philosophy: NEVER block the tool. Target <5ms P95.
# All errors are swallowed (exit 0) — tracing is best-effort observability.
#
# Hook payload (stdin JSON) — opportunistic, optional:
#   - tool / tool_name        → operation
#   - subagent_id / agent_id  → operation when service=agent
#   - cwd / file_path / etc.  → attributes.* (non-PII metadata only)

set -u  # NB: no -e — we never want to abort on a side-effect failure

ATLAS_TRACE_ENABLED="${ATLAS_TRACE_ENABLED:-0}"
[ "$ATLAS_TRACE_ENABLED" = "1" ] || exit 0

# --- Resolve session + trace IDs --------------------------------------------

SESSION_ID="${CLAUDE_SESSION_ID:-session-$PPID-$$}"
TRACES_DIR="${ATLAS_TRACES_DIR:-$HOME/.atlas/traces}"
SESSION_DIR="$TRACES_DIR/$SESSION_ID"

# Fast mkdir (cheap if exists)
mkdir -p "$SESSION_DIR" 2>/dev/null || exit 0

# Trace ID: explicit env > _active symlink > generate now
TRACE_ID="${ATLAS_TRACE_ID:-}"
if [ -z "$TRACE_ID" ]; then
  if [ -L "$SESSION_DIR/_active" ]; then
    TRACE_ID=$(readlink "$SESSION_DIR/_active" 2>/dev/null)
  fi
fi
if [ -z "$TRACE_ID" ]; then
  TRACE_ID=$(uuidgen 2>/dev/null \
    || python3 -c 'import uuid;print(uuid.uuid4())' 2>/dev/null \
    || echo "trace-$RANDOM-$(date +%s)")
  ln -sfn "$TRACE_ID" "$SESSION_DIR/_active" 2>/dev/null || :
fi

TRACE_FILE="$SESSION_DIR/$TRACE_ID.jsonl"
STACK_FILE="$SESSION_DIR/_stack.$TRACE_ID"

# --- Generate span_id, resolve parent ---------------------------------------

SPAN_ID=$(uuidgen 2>/dev/null \
  || python3 -c 'import uuid;print(uuid.uuid4())' 2>/dev/null \
  || echo "span-$RANDOM-$(date +%s%N)")

PARENT_SPAN_ID="null"
if [ -s "$STACK_FILE" ]; then
  # Last non-empty line = current parent
  _parent=$(tail -n 1 "$STACK_FILE" 2>/dev/null)
  [ -n "$_parent" ] && PARENT_SPAN_ID="\"$_parent\""
fi

# --- Determine operation + service from event + payload ---------------------

HOOK_EVENT="${HOOK_EVENT:-PreToolUse}"
case "$HOOK_EVENT" in
  SubagentStart) SERVICE="agent" ;;
  PreToolUse)    SERVICE="tool"  ;;
  *)             SERVICE="hook"  ;;
esac

# Read stdin payload non-blockingly (timeout 0.3s — keep overhead low)
PAYLOAD=$(timeout 0.3s cat 2>/dev/null || echo "{}")
[ -z "$PAYLOAD" ] && PAYLOAD="{}"

# Extract operation + attributes via python3 (single-process, fast).
# Pass payload as argv[2] (heredoc on stdin already consumes the pipe).
PARSED=$(python3 - "$SERVICE" "$PAYLOAD" <<'PYEOF' 2>/dev/null
import json, sys
service = sys.argv[1]
raw = sys.argv[2] if len(sys.argv) > 2 else "{}"
try:
    d = json.loads(raw or "{}")
except Exception:
    d = {}
op = ""
if service == "agent":
    op = d.get("subagent_type") or d.get("agent_type") or d.get("agent_id") or d.get("subagent_id") or "subagent"
else:
    op = d.get("tool_name") or d.get("tool") or d.get("operation") or "unknown"
attrs = {}
for k in ("cwd", "file_path", "exit_code", "skill_name", "agent_id", "subagent_id", "session_id", "tool_name"):
    v = d.get(k)
    if v is not None and isinstance(v, (str, int, float, bool)):
        if isinstance(v, str) and len(v) > 200:
            v = v[:200]
        attrs[k] = v
print(json.dumps({"op": op, "attrs": attrs}))
PYEOF
)
[ -z "$PARSED" ] && PARSED='{"op":"unknown","attrs":{}}'

# --- Build span line + atomic append ----------------------------------------

# Single python invocation builds the full span JSON safely
# (avoids shell-expansion pitfalls inside JSON literals).
SPAN_JSON=$(python3 - "$TRACE_ID" "$SPAN_ID" "$PARENT_SPAN_ID" "$SERVICE" "$PARSED" <<'PYEOF' 2>/dev/null
import json, sys, datetime
trace_id, span_id, parent_raw, service, parsed_raw = sys.argv[1:6]
parent = None if parent_raw in ("null", "") else parent_raw.strip('"')
try:
    parsed = json.loads(parsed_raw or '{}')
except Exception:
    parsed = {}
op = parsed.get("op") or "unknown"
attrs = parsed.get("attrs") or {}
span = {
    "trace_id": trace_id,
    "span_id": span_id,
    "parent_span_id": parent,
    "operation": op,
    "service": service,
    "start_ts": datetime.datetime.utcnow().isoformat(timespec="milliseconds") + "Z",
    "end_ts": None,
    "duration_ms": None,
    "status": "pending",
    "attributes": attrs,
}
print(json.dumps(span))
PYEOF
)

# Fallback: if python build failed, build minimal span by hand (parent unknown → null)
if [ -z "$SPAN_JSON" ]; then
  START_TS=$(date -u '+%Y-%m-%dT%H:%M:%S.000Z')
  SPAN_JSON="{\"trace_id\":\"$TRACE_ID\",\"span_id\":\"$SPAN_ID\",\"parent_span_id\":null,\"operation\":\"unknown\",\"service\":\"$SERVICE\",\"start_ts\":\"$START_TS\",\"end_ts\":null,\"duration_ms\":null,\"status\":\"pending\",\"attributes\":{}}"
fi

# Atomic append guarded by flock (best-effort: fall back to plain append if flock missing)
if command -v flock >/dev/null 2>&1; then
  ( flock -x -w 0.5 9 || exit 0
    printf '%s\n' "$SPAN_JSON" >> "$TRACE_FILE"
  ) 9>"$TRACE_FILE.lock" 2>/dev/null
else
  printf '%s\n' "$SPAN_JSON" >> "$TRACE_FILE" 2>/dev/null
fi

# Push span_id to stack so PostToolUse / SubagentStop can resolve parent
printf '%s\n' "$SPAN_ID" >> "$STACK_FILE" 2>/dev/null

exit 0
