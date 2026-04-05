#!/usr/bin/env bash
# mega-status-manager.sh — MEGA-STATUS.jsonl management for programme-manager
# Usage:
#   mega-status-manager.sh init <mega-plan-file>
#   mega-status-manager.sh append <sp_id> <phase> <status> <pct> [note]
#   mega-status-manager.sh rollup [mega-plan-file]
#   mega-status-manager.sh status [sp_id]
set -euo pipefail

# Default MEGA-STATUS location (project root)
STATUS_FILE="${MEGA_STATUS_FILE:-.blueprint/plans/MEGA-STATUS.jsonl}"

# ── Helpers ─────────────────────────────────────────────────────

die() { echo "ERROR: $*" >&2; exit 1; }

require_jq() {
  command -v jq &>/dev/null || die "jq is required. Install: apt install jq"
}

ensure_status_file() {
  if [ ! -f "$STATUS_FILE" ]; then
    die "MEGA-STATUS.jsonl not found at $STATUS_FILE. Run 'init' first."
  fi
}

timestamp() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

# ── init: Create MEGA-STATUS.jsonl from a mega plan file ────────

cmd_init() {
  local plan_file="${1:-}"
  [ -z "$plan_file" ] && die "Usage: mega-status-manager.sh init <mega-plan-file>"
  [ -f "$plan_file" ] || die "Plan file not found: $plan_file"

  local dir
  dir=$(dirname "$STATUS_FILE")
  mkdir -p "$dir"

  if [ -f "$STATUS_FILE" ]; then
    echo "WARNING: $STATUS_FILE already exists. Appending init entries."
  fi

  # Extract sub-plan rows from M2 table (format: | SP-NN | title | effortH | ...)
  # Look for lines matching: | SP-{digits} |
  local count=0
  while IFS= read -r line; do
    local sp_id effort title
    sp_id=$(echo "$line" | sed -n 's/.*|\s*\(SP-[0-9]\{1,3\}\)\s*|.*/\1/p')
    [ -z "$sp_id" ] && continue

    # Extract effort (NNh pattern)
    effort=$(echo "$line" | grep -oP '\d+(?=h)' | head -1)
    [ -z "$effort" ] && effort=0

    # Extract title (second column)
    title=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}')
    [ -z "$title" ] && title="$sp_id"

    # Write init entry
    printf '{"ts":"%s","plan":"%s","title":"%s","phase":"P0","status":"planned","effort_done_h":0,"effort_total_h":%d,"pct":0,"note":"Initialized from plan"}\n' \
      "$(timestamp)" "$sp_id" "$title" "$effort" >> "$STATUS_FILE"

    count=$((count + 1))
  done < "$plan_file"

  if [ "$count" -eq 0 ]; then
    echo "WARNING: No sub-plans found in $plan_file (expected M2 table with SP-NN rows)."
  else
    echo "Initialized $count sub-plans in $STATUS_FILE"
  fi
}

# ── append: Add a progress event ────────────────────────────────

cmd_append() {
  local sp_id="${1:-}" phase="${2:-}" status="${3:-}" pct="${4:-}" note="${5:-}"

  [ -z "$sp_id" ] && die "Usage: mega-status-manager.sh append <sp_id> <phase> <status> <pct> [note]"
  [ -z "$phase" ] && die "Missing: phase (e.g., P0, P1)"
  [ -z "$status" ] && die "Missing: status (planned|in_progress|completed|blocked)"
  [ -z "$pct" ] && die "Missing: pct (0-100)"

  ensure_status_file

  # Validate status
  case "$status" in
    planned|in_progress|completed|blocked) ;;
    *) die "Invalid status: $status. Must be: planned|in_progress|completed|blocked" ;;
  esac

  # Validate pct is numeric 0-100
  if ! [[ "$pct" =~ ^[0-9]+$ ]] || [ "$pct" -gt 100 ]; then
    die "pct must be 0-100, got: $pct"
  fi

  # Get effort_total from latest entry for this SP
  local effort_total=0
  if command -v jq &>/dev/null; then
    effort_total=$(grep "\"$sp_id\"" "$STATUS_FILE" | tail -1 | jq -r '.effort_total_h // 0' 2>/dev/null || echo 0)
  fi
  local effort_done=$(( effort_total * pct / 100 ))

  printf '{"ts":"%s","plan":"%s","phase":"%s","status":"%s","effort_done_h":%d,"effort_total_h":%d,"pct":%d,"note":"%s"}\n' \
    "$(timestamp)" "$sp_id" "$phase" "$status" "$effort_done" "$effort_total" "$pct" "${note:-Progress update}" >> "$STATUS_FILE"

  echo "Appended: $sp_id $phase $status ${pct}%"
}

# ── rollup: Calculate weighted programme progress ────────────────

cmd_rollup() {
  require_jq
  ensure_status_file

  # Get latest entry per sub-plan
  # Formula: sum(sub_plan_pct * sub_plan_effort) / sum(sub_plan_effort)
  jq -s '
    # Group by plan, take last entry per plan
    group_by(.plan)
    | map(last)
    | {
        sub_plans: map({
          plan: .plan,
          phase: .phase,
          status: .status,
          pct: (.pct // 0),
          effort_total_h: (.effort_total_h // 0),
          effort_done_h: (.effort_done_h // 0)
        }),
        summary: {
          total_effort: (map(.effort_total_h // 0) | add),
          total_done: (map(.effort_done_h // 0) | add),
          weighted_pct: (
            if (map(.effort_total_h // 0) | add) > 0
            then ((map((.pct // 0) * (.effort_total_h // 0)) | add) / (map(.effort_total_h // 0) | add))
            else 0
            end
          ),
          count_total: length,
          count_completed: (map(select(.status == "completed")) | length),
          count_active: (map(select(.status == "in_progress")) | length),
          count_blocked: (map(select(.status == "blocked")) | length),
          count_planned: (map(select(.status == "planned")) | length)
        }
      }
  ' "$STATUS_FILE"
}

# ── status: Show current status for one or all sub-plans ─────────

cmd_status() {
  require_jq
  ensure_status_file

  local sp_id="${1:-}"

  if [ -n "$sp_id" ]; then
    # Single sub-plan history
    grep "\"$sp_id\"" "$STATUS_FILE" | jq -s '.' 2>/dev/null || echo "[]"
  else
    # Latest status per sub-plan (compact table)
    jq -s '
      group_by(.plan)
      | map(last)
      | sort_by(.plan)
      | .[]
      | "\(.plan)\t\(.phase)\t\(.status)\t\(.pct)%\t\(.effort_done_h)/\(.effort_total_h)h"
    ' -r "$STATUS_FILE" | column -t -s $'\t' -N "PLAN,PHASE,STATUS,PCT,EFFORT"
  fi
}

# ── Main dispatch ────────────────────────────────────────────────

cmd="${1:-}"
shift || true

case "$cmd" in
  init)    cmd_init "$@" ;;
  append)  cmd_append "$@" ;;
  rollup)  cmd_rollup "$@" ;;
  status)  cmd_status "$@" ;;
  *)
    echo "mega-status-manager.sh — MEGA-STATUS.jsonl management"
    echo ""
    echo "Usage:"
    echo "  mega-status-manager.sh init <mega-plan-file>          Create MEGA-STATUS.jsonl from plan"
    echo "  mega-status-manager.sh append <sp> <phase> <status> <pct> [note]  Append progress event"
    echo "  mega-status-manager.sh rollup                         Calculate weighted programme progress"
    echo "  mega-status-manager.sh status [sp_id]                 Show current status"
    echo ""
    echo "Environment:"
    echo "  MEGA_STATUS_FILE  Override MEGA-STATUS.jsonl path (default: .blueprint/plans/MEGA-STATUS.jsonl)"
    echo ""
    echo "Statuses: planned | in_progress | completed | blocked"
    exit 1
    ;;
esac
