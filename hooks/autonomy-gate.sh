#!/usr/bin/env bash
# ATLAS Autonomy Gate Helper (v6.0 Phase 5 Approved-Mode)
# Checks session-state.json for pre-approved gates, decides whether to
# skip or fire AskUserQuestion based on autonomy_mode + tier + action.
#
# Usage:
#   autonomy-gate.sh check <gate_id> <tier> [action]
#   autonomy-gate.sh approve <gate_id> [scope]
#   autonomy-gate.sh status
#   autonomy-gate.sh set-mode <strict|approved|yolo>
#
# Exit codes:
#   0 — auto-approved (skip the question)
#   1 — needs user input (fire AskUserQuestion)
#   2 — usage error
#
# Schema: .blueprint/schemas/session-state-v1.md
# State file: .claude/session-state.json (per-project, gitignored, chmod 600)
set -euo pipefail

# ── Config ───────────────────────────────────────────────────────────

STATE_DIR="${CLAUDE_STATE_DIR:-.claude}"
STATE_FILE="${STATE_DIR}/session-state.json"
DECISIONS_LOG="${STATE_DIR}/decisions.jsonl"

# Always-ask actions (hardcoded, cannot be disabled)
IMMUTABLE_ALWAYS_ASK=(
  "destructive:rm_rf"
  "destructive:git_reset_hard"
  "destructive:git_force_push"
  "deploy:production"
  "deploy:main_branch_merge"
  "infra:change_shared_resource"
  "finance:any_cost_incurring"
  "security:modify_auth"
  "security:modify_rbac"
  "data:modify_prod_schema"
  "data:delete_persistent"
  "comm:external_notification"
  "comm:slack_post"
  "comm:email_send"
)

# ── Helpers ──────────────────────────────────────────────────────────

_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

_uuid() {
  if command -v uuidgen &>/dev/null; then
    uuidgen | tr '[:upper:]' '[:lower:]'
  else
    # Fallback: portable random UUID-like identifier
    printf '%s-%s-%s-%s-%s\n' \
      "$(head -c 4 /dev/urandom | xxd -p)" \
      "$(head -c 2 /dev/urandom | xxd -p)" \
      "$(head -c 2 /dev/urandom | xxd -p)" \
      "$(head -c 2 /dev/urandom | xxd -p)" \
      "$(head -c 6 /dev/urandom | xxd -p)"
  fi
}

_init_state() {
  mkdir -p "$STATE_DIR"
  cat >"$STATE_FILE" <<EOF
{
  "\$schema_version": "1.0",
  "session_id": "$(_uuid)",
  "started_at": "$(_timestamp)",
  "ended_at": null,
  "autonomy_mode": "strict",
  "approved_gates": [],
  "skip_tiers": ["CODED", "VALIDATING"],
  "always_ask_tiers": ["VALIDATED", "SHIPPED"],
  "always_ask_actions": $(printf '%s\n' "${IMMUTABLE_ALWAYS_ASK[@]}" | python3 -c "import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))"),
  "current_plan": null,
  "current_sprint": null,
  "task_progress": {
    "total": 0, "coded": 0, "validating": 0, "validated": 0, "shipped": 0,
    "hitl_gates_crossed": 0, "hitl_gates_skipped_via_approval": 0
  },
  "metadata": {
    "created_by": "autonomy-gate.sh",
    "last_updated": "$(_timestamp)"
  }
}
EOF
  chmod 600 "$STATE_FILE" 2>/dev/null || true
}

_ensure_state() {
  if [ ! -f "$STATE_FILE" ]; then
    _init_state
  fi
}

_log_decision() {
  local gate_id="$1"
  local tier="$2"
  local action="${3:-}"
  local mode="$4"
  local decision="$5"  # skip | ask
  local source="${6:-autonomy-gate}"

  mkdir -p "$(dirname "$DECISIONS_LOG")"
  local line
  line=$(python3 -c "
import json
print(json.dumps({
    'ts': '$(_timestamp)',
    'gate_id': '$gate_id',
    'tier': '$tier',
    'action': '$action',
    'mode': '$mode',
    'decision': '$decision',
    'source': '$source'
}))")
  echo "$line" >> "$DECISIONS_LOG"
}

# ── Commands ─────────────────────────────────────────────────────────

_cmd_check() {
  # check <gate_id> <tier> [action]
  local gate_id="${1:-}"
  local tier="${2:-}"
  local action="${3:-}"

  if [ -z "$gate_id" ] || [ -z "$tier" ]; then
    echo "Usage: autonomy-gate.sh check <gate_id> <tier> [action]" >&2
    echo "  tier: CODED | VALIDATING | VALIDATED | SHIPPED" >&2
    return 2
  fi

  _ensure_state

  # Rule 1 — Immutable always-ask actions (never skip these)
  if [ -n "$action" ]; then
    for immut in "${IMMUTABLE_ALWAYS_ASK[@]}"; do
      if [ "$action" = "$immut" ]; then
        _log_decision "$gate_id" "$tier" "$action" "immutable" "ask"
        return 1  # ALWAYS fire AskUserQuestion
      fi
    done
  fi

  # Rule 2 — Check autonomy mode + approved_gates + skip_tiers
  local skip
  skip=$(python3 <<PYEOF
import json, sys
try:
    with open("$STATE_FILE") as f:
        state = json.load(f)
except Exception:
    print("no")
    sys.exit(0)

mode = state.get("autonomy_mode", "strict")

# strict mode: always ask
if mode == "strict":
    print("no")
    sys.exit(0)

always_ask_tiers = state.get("always_ask_tiers", ["VALIDATED", "SHIPPED"])
if "$tier" in always_ask_tiers:
    print("no")
    sys.exit(0)

# yolo mode: skip everything except always_ask_tiers/actions
if mode == "yolo":
    print("yes")
    sys.exit(0)

# approved mode: check gate in approved_gates AND tier in skip_tiers
approved_gates = state.get("approved_gates", [])
approved_gate_ids = [g.get("gate_id") for g in approved_gates if isinstance(g, dict)]
skip_tiers = state.get("skip_tiers", [])

if "$gate_id" in approved_gate_ids and "$tier" in skip_tiers:
    print("yes")
else:
    print("no")
PYEOF
)

  if [ "$skip" = "yes" ]; then
    _log_decision "$gate_id" "$tier" "$action" "approved" "skip"
    # Increment skip counter
    _increment_counter "hitl_gates_skipped_via_approval"
    return 0  # auto-approved, skip
  else
    _log_decision "$gate_id" "$tier" "$action" "strict-or-unapproved" "ask"
    _increment_counter "hitl_gates_crossed"
    return 1  # fire AskUserQuestion
  fi
}

_increment_counter() {
  local counter="$1"
  _ensure_state
  python3 <<PYEOF
import json
with open("$STATE_FILE") as f:
    state = json.load(f)
state.setdefault("task_progress", {})
state["task_progress"]["$counter"] = state["task_progress"].get("$counter", 0) + 1
state.setdefault("metadata", {})
state["metadata"]["last_updated"] = "$(_timestamp)"
with open("$STATE_FILE", "w") as f:
    json.dump(state, f, indent=2)
PYEOF
}

_cmd_approve() {
  # approve <gate_id> [scope]
  local gate_id="${1:-}"
  local scope="${2:-session}"

  if [ -z "$gate_id" ]; then
    echo "Usage: autonomy-gate.sh approve <gate_id> [scope]" >&2
    return 2
  fi

  _ensure_state

  python3 <<PYEOF
import json
with open("$STATE_FILE") as f:
    state = json.load(f)

# Add to approved_gates (dedupe by gate_id)
gates = state.setdefault("approved_gates", [])
gates = [g for g in gates if not (isinstance(g, dict) and g.get("gate_id") == "$gate_id")]
gates.append({
    "gate_id": "$gate_id",
    "approved_at": "$(_timestamp)",
    "approver": "user",
    "scope": "$scope",
    "expires_at": None
})
state["approved_gates"] = gates

# Auto-promote to 'approved' mode if still 'strict'
if state.get("autonomy_mode") == "strict":
    state["autonomy_mode"] = "approved"

state.setdefault("metadata", {})
state["metadata"]["last_updated"] = "$(_timestamp)"

with open("$STATE_FILE", "w") as f:
    json.dump(state, f, indent=2)
print(f"Approved gate: $gate_id (scope=$scope)")
PYEOF
}

_cmd_status() {
  _ensure_state
  python3 <<PYEOF
import json
with open("$STATE_FILE") as f:
    state = json.load(f)

print(f"Session ID:         {state.get('session_id', '?')}")
print(f"Started:            {state.get('started_at', '?')}")
print(f"Autonomy mode:      {state.get('autonomy_mode', 'strict')}")
print(f"Approved gates:     {len(state.get('approved_gates', []))}")
for g in state.get('approved_gates', []):
    print(f"  - {g.get('gate_id')} ({g.get('scope', '?')})")
print(f"Skip tiers:         {state.get('skip_tiers', [])}")
print(f"Always-ask tiers:   {state.get('always_ask_tiers', [])}")
print(f"Always-ask actions: {len(state.get('always_ask_actions', []))} (immutable)")
progress = state.get('task_progress', {})
print(f"Task progress:")
print(f"  Total:            {progress.get('total', 0)}")
print(f"  HITL crossed:     {progress.get('hitl_gates_crossed', 0)}")
print(f"  HITL skipped:     {progress.get('hitl_gates_skipped_via_approval', 0)}")
PYEOF
}

_cmd_set_mode() {
  local mode="${1:-}"
  case "$mode" in
    strict|approved|yolo) ;;
    *)
      echo "Usage: autonomy-gate.sh set-mode <strict|approved|yolo>" >&2
      return 2
      ;;
  esac

  _ensure_state

  python3 <<PYEOF
import json
with open("$STATE_FILE") as f:
    state = json.load(f)
state["autonomy_mode"] = "$mode"
state.setdefault("metadata", {})
state["metadata"]["last_updated"] = "$(_timestamp)"
with open("$STATE_FILE", "w") as f:
    json.dump(state, f, indent=2)
print(f"Autonomy mode set: $mode")
PYEOF
}

# ── Main dispatch ────────────────────────────────────────────────────

main() {
  local cmd="${1:-}"
  shift || true

  case "$cmd" in
    check) _cmd_check "$@" ;;
    approve) _cmd_approve "$@" ;;
    status) _cmd_status "$@" ;;
    set-mode) _cmd_set_mode "$@" ;;
    init) _ensure_state; echo "State initialized: $STATE_FILE" ;;
    -h|--help|help|"")
      cat <<EOF
ATLAS Autonomy Gate Helper

Usage:
  autonomy-gate.sh check <gate_id> <tier> [action]
      Check if a gate can be auto-approved. Returns 0 (skip) or 1 (ask).

  autonomy-gate.sh approve <gate_id> [scope]
      Mark a gate as pre-approved. Promotes mode to 'approved' if strict.

  autonomy-gate.sh status
      Show current session state summary.

  autonomy-gate.sh set-mode <strict|approved|yolo>
      Change autonomy mode.

  autonomy-gate.sh init
      Initialize state file if missing.

Modes:
  strict    — All questions fire (default, safe)
  approved  — Questions on approved_gates + skip_tiers auto-approve
  yolo      — Skip everything EXCEPT always_ask_tiers/actions

Tiers:
  CODED | VALIDATING (default skip) | VALIDATED | SHIPPED (always ask)

Schema: .blueprint/schemas/session-state-v1.md
State:  .claude/session-state.json (chmod 600, gitignored)
EOF
      ;;
    *)
      echo "Unknown command: $cmd" >&2
      echo "Run 'autonomy-gate.sh help' for usage." >&2
      return 2
      ;;
  esac
}

main "$@"
