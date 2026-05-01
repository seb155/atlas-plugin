#!/usr/bin/env bash
# ATLAS trace-id-finalizer hook (PostToolUse + SubagentStop events)
#
# Plan: .blueprint/plans/ultrathink-regarde-ce-qui-abundant-petal.md Section H W1.1
# Part of W1 OBSERVABILITY — closes the open span opened by trace-id-injector.
#
# Behavior:
#   1. Exit fast (0) if ATLAS_TRACE_ENABLED != 1
#   2. Resolve session_id + trace_id (same logic as injector — symlink/env)
#   3. Pop the latest span_id from the stack file
#   4. Compute end_ts + duration_ms from the matching JSONL line's start_ts
#   5. Determine status: "ok" by default, "error" if payload exit_code != 0
#   6. Rewrite the JSONL line atomically (read all → patch matching line → write back via flock)
#
# Fast-fail philosophy: NEVER block tool completion. Exit 0 on any failure.
# Target overhead: <5ms P95.

set -u

ATLAS_TRACE_ENABLED="${ATLAS_TRACE_ENABLED:-0}"
[ "$ATLAS_TRACE_ENABLED" = "1" ] || exit 0

# --- Resolve IDs ------------------------------------------------------------

SESSION_ID="${CLAUDE_SESSION_ID:-session-$PPID-$$}"
TRACES_DIR="${ATLAS_TRACES_DIR:-$HOME/.atlas/traces}"
SESSION_DIR="$TRACES_DIR/$SESSION_ID"

[ -d "$SESSION_DIR" ] || exit 0

TRACE_ID="${ATLAS_TRACE_ID:-}"
if [ -z "$TRACE_ID" ] && [ -L "$SESSION_DIR/_active" ]; then
  TRACE_ID=$(readlink "$SESSION_DIR/_active" 2>/dev/null)
fi
[ -z "$TRACE_ID" ] && exit 0

TRACE_FILE="$SESSION_DIR/$TRACE_ID.jsonl"
STACK_FILE="$SESSION_DIR/_stack.$TRACE_ID"

[ -f "$TRACE_FILE" ] || exit 0
[ -f "$STACK_FILE" ] || exit 0

# --- Pop span_id from stack -------------------------------------------------

# Read last line + truncate file by 1 line (atomic via lock)
SPAN_ID=""
if command -v flock >/dev/null 2>&1; then
  ( flock -x -w 0.5 9 || exit 0
    SPAN_ID=$(tail -n 1 "$STACK_FILE" 2>/dev/null)
    if [ -n "$SPAN_ID" ]; then
      # Remove last line by writing all-but-last back
      head -n -1 "$STACK_FILE" > "$STACK_FILE.tmp" 2>/dev/null && mv -f "$STACK_FILE.tmp" "$STACK_FILE"
    fi
    printf '%s' "$SPAN_ID" > "$STACK_FILE.popped"
  ) 9>"$STACK_FILE.lock" 2>/dev/null
  SPAN_ID=$(cat "$STACK_FILE.popped" 2>/dev/null)
  rm -f "$STACK_FILE.popped" 2>/dev/null
else
  SPAN_ID=$(tail -n 1 "$STACK_FILE" 2>/dev/null)
  head -n -1 "$STACK_FILE" > "$STACK_FILE.tmp" 2>/dev/null && mv -f "$STACK_FILE.tmp" "$STACK_FILE"
fi

[ -z "$SPAN_ID" ] && exit 0

# --- Determine status from payload ------------------------------------------

PAYLOAD=$(timeout 0.3s cat 2>/dev/null || echo "{}")
[ -z "$PAYLOAD" ] && PAYLOAD="{}"

STATUS=$(python3 -c '
import json, sys
raw = sys.argv[1] if len(sys.argv) > 1 else "{}"
try:
    d = json.loads(raw or "{}")
except Exception:
    print("ok"); sys.exit(0)
ec = d.get("exit_code")
if ec is not None and ec != 0:
    print("error"); sys.exit(0)
err = d.get("error") or d.get("is_error")
if err:
    print("error"); sys.exit(0)
print("ok")
' "$PAYLOAD" 2>/dev/null)
[ -z "$STATUS" ] && STATUS="ok"

# --- Patch matching span line atomically ------------------------------------

END_TS=$(python3 -c 'import datetime;print(datetime.datetime.utcnow().isoformat(timespec="milliseconds")+"Z")' 2>/dev/null \
  || date -u '+%Y-%m-%dT%H:%M:%S.000Z')

# Patch: read all lines, find span_id, recompute duration, write back.
# Single python invocation = single fork = cheap.
_patch() {
  python3 - "$TRACE_FILE" "$SPAN_ID" "$END_TS" "$STATUS" <<'PYEOF' 2>/dev/null
import json, sys, datetime
trace_file, span_id, end_ts, status = sys.argv[1:5]
try:
    with open(trace_file, "r") as f:
        lines = f.readlines()
except Exception:
    sys.exit(0)
out = []
patched = False
for line in lines:
    s = line.strip()
    if not s:
        out.append(line); continue
    try:
        span = json.loads(s)
    except Exception:
        out.append(line); continue
    if not patched and span.get("span_id") == span_id and span.get("status") == "pending":
        span["end_ts"] = end_ts
        span["status"] = status
        try:
            t0 = datetime.datetime.fromisoformat(span["start_ts"].rstrip("Z"))
            t1 = datetime.datetime.fromisoformat(end_ts.rstrip("Z"))
            span["duration_ms"] = int((t1 - t0).total_seconds() * 1000)
        except Exception:
            span["duration_ms"] = None
        out.append(json.dumps(span) + "\n")
        patched = True
    else:
        out.append(line if line.endswith("\n") else line + "\n")
try:
    with open(trace_file, "w") as f:
        f.writelines(out)
except Exception:
    pass
PYEOF
}

if command -v flock >/dev/null 2>&1; then
  ( flock -x -w 0.5 9 || exit 0
    _patch
  ) 9>"$TRACE_FILE.lock" 2>/dev/null
else
  _patch
fi

# Cleanup empty stack files
if [ -f "$STACK_FILE" ] && [ ! -s "$STACK_FILE" ]; then
  rm -f "$STACK_FILE" 2>/dev/null
fi

exit 0
