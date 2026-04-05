#!/usr/bin/env bash
# plan-lifecycle.sh — Plan state management and dashboard
# Usage:
#   plan-lifecycle.sh scan [plans_dir]    — Scan all plans, show state dashboard
#   plan-lifecycle.sh stale [plans_dir]   — Show plans needing attention
#   plan-lifecycle.sh set <plan> <status> — Update plan status in frontmatter
#
# Valid statuses: DRAFT → APPROVED → EXECUTING → COMPLETE → ARCHIVED
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VALID_STATES="DRAFT APPROVED EXECUTING COMPLETE ARCHIVED"

# ── Helpers ───────────────────────────────────────────────────

extract_frontmatter() {
  local file="$1"
  local field="$2"
  # Extract value from > **Field**: value or field: value in frontmatter
  grep -oP "(?<=\*\*${field}\*\*:\s).*?(?=\s*\||\s*$)" "$file" 2>/dev/null | head -1 \
    || grep -oP "(?<=^${field}:\s).*" "$file" 2>/dev/null | head -1 \
    || echo ""
}

extract_status() {
  local file="$1"
  local raw=$(extract_frontmatter "$file" "Status")
  # Normalize: extract first word (e.g., "DRAFT" from "DRAFT — pending review")
  echo "$raw" | grep -oP '(DRAFT|APPROVED|EXECUTING|COMPLETE|ARCHIVED|PLANNING|SHIPPED)' | head -1 || echo "UNKNOWN"
}

extract_score() {
  local file="$1"
  extract_frontmatter "$file" "Score" | grep -oP '\d+/\d+' | head -1 || echo "—"
}

extract_effort() {
  local file="$1"
  extract_frontmatter "$file" "Total Effort" | head -1 || echo "—"
}

# ── Commands ──────────────────────────────────────────────────

cmd_scan() {
  local plans_dir="${1:-.blueprint/plans}"
  [ -d "$plans_dir" ] || { echo "ERROR: $plans_dir not found" >&2; exit 1; }

  echo "🏗️  Plan Lifecycle Dashboard"
  echo "   Directory: $plans_dir"
  echo ""

  # Count by status
  local -A STATUS_COUNT
  local -A STATUS_FILES
  for state in $VALID_STATES UNKNOWN; do
    STATUS_COUNT[$state]=0
    STATUS_FILES[$state]=""
  done

  printf "  %-40s %-12s %-8s %-12s\n" "PLAN" "STATUS" "SCORE" "EFFORT"
  printf "  %-40s %-12s %-8s %-12s\n" "────────────────────────────────────────" "────────────" "────────" "────────────"

  for f in "$plans_dir"/*.md; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .md)

    # Skip archive dirs, index files, agent plans
    [[ "$name" == "INDEX" ]] && continue
    [[ "$name" == *"-agent-"* ]] && continue

    local status=$(extract_status "$f")
    local score=$(extract_score "$f")
    local effort=$(extract_effort "$f")

    # Status emoji
    local icon="📝"
    case "$status" in
      DRAFT)     icon="📝" ;;
      APPROVED)  icon="📋" ;;
      EXECUTING) icon="⚡" ;;
      COMPLETE)  icon="✅" ;;
      ARCHIVED)  icon="🗄️" ;;
      SHIPPED)   icon="✅"; status="COMPLETE" ;;
      PLANNING)  icon="📝"; status="DRAFT" ;;
      *)         icon="❓" ;;
    esac

    STATUS_COUNT[$status]=$((${STATUS_COUNT[$status]:-0} + 1))

    # Truncate name for display
    local display_name="$name"
    [ ${#display_name} -gt 38 ] && display_name="${display_name:0:35}..."

    printf "  %s %-38s %-12s %-8s %-12s\n" "$icon" "$display_name" "$status" "$score" "$effort"
  done

  echo ""
  echo "  Summary:"
  for state in $VALID_STATES; do
    local count=${STATUS_COUNT[$state]:-0}
    [ "$count" -gt 0 ] && echo "    $state: $count"
  done
  local unknown=${STATUS_COUNT[UNKNOWN]:-0}
  [ "$unknown" -gt 0 ] && echo "    UNKNOWN: $unknown (missing status field)"
}

cmd_stale() {
  local plans_dir="${1:-.blueprint/plans}"
  [ -d "$plans_dir" ] || { echo "ERROR: $plans_dir not found" >&2; exit 1; }

  echo "⚠️  Stale Plans (needing attention)"
  echo ""

  local found=0
  for f in "$plans_dir"/*.md; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .md)
    [[ "$name" == "INDEX" ]] && continue
    [[ "$name" == *"-agent-"* ]] && continue

    local status=$(extract_status "$f")
    local score=$(extract_score "$f")

    # Stale conditions:
    # 1. EXECUTING but no recent modification (>14 days)
    # 2. DRAFT with score < 12/15
    # 3. UNKNOWN status
    local stale_reason=""

    if [ "$status" = "EXECUTING" ]; then
      local mod_epoch=$(stat -c %Y "$f" 2>/dev/null || echo 0)
      local age_days=$(( ($(date +%s) - mod_epoch) / 86400 ))
      [ "$age_days" -ge 14 ] && stale_reason="EXECUTING but not modified in ${age_days}d"
    fi

    if [ "$status" = "DRAFT" ]; then
      local num_score=$(echo "$score" | grep -oP '^\d+' || echo 0)
      [ "$num_score" -lt 12 ] && [ "$num_score" -gt 0 ] && stale_reason="DRAFT with score $score (below 12/15 gate)"
    fi

    [ "$status" = "UNKNOWN" ] && stale_reason="Missing status field in frontmatter"

    if [ -n "$stale_reason" ]; then
      found=$((found + 1))
      echo "  ⚠️  $name"
      echo "     $stale_reason"
    fi
  done

  [ "$found" -eq 0 ] && echo "  ✅ No stale plans found."
}

cmd_set() {
  local plan_file="$1"
  local new_status="$2"

  [ -f "$plan_file" ] || { echo "ERROR: File not found: $plan_file" >&2; exit 1; }

  # Validate status
  echo "$VALID_STATES" | grep -qw "$new_status" || {
    echo "ERROR: Invalid status '$new_status'. Valid: $VALID_STATES" >&2
    exit 1
  }

  # Update in frontmatter (> **Status**: ... pattern)
  if grep -q '\*\*Status\*\*:' "$plan_file"; then
    sed -i "s/\*\*Status\*\*: [A-Z]*/\*\*Status\*\*: $new_status/" "$plan_file"
    echo "✅ Updated $(basename "$plan_file"): Status → $new_status"
  else
    echo "⚠️  No Status field found in frontmatter. Add '> **Status**: $new_status' manually."
  fi
}

# ── Mermaid Roadmap ────────────────────────────────────────────

cmd_roadmap() {
  local plans_dir="${1:-.blueprint/plans}"
  [ -d "$plans_dir" ] || { echo "ERROR: $plans_dir not found" >&2; exit 1; }
  # Disable strict unbound for glob iteration
  set +u

  printf '```mermaid\n'
  printf 'gantt\n'
  printf '    title ATLAS Programme Roadmap\n'
  printf '    dateFormat YYYY-MM-DD\n'
  printf '    axisFormat %%b %%d\n'
  printf '\n'

  # Group by status
  local -A SECTIONS
  SECTIONS[EXECUTING]="section ⚡ Executing"
  SECTIONS[APPROVED]="section 📋 Approved"
  SECTIONS[DRAFT]="section 📝 Draft"

  for state in EXECUTING APPROVED DRAFT; do
    local found_in_section=false
    for f in "$plans_dir"/sp*.md; do
      [ -f "$f" ] || continue
      local name=$(basename "$f" .md)
      [[ "$name" == *"-agent-"* ]] && continue

      local status=$(extract_status "$f")
      [ "$status" != "$state" ] && continue

      if ! $found_in_section; then
        echo "    ${SECTIONS[$state]}"
        found_in_section=true
      fi

      local effort=$(extract_effort "$f" | grep -oP '\d+' | head -1 || echo "40")
      [ -z "$effort" ] && effort=40
      local weeks=$(( (effort + 24) / 25 ))  # ~25h/week
      [ "$weeks" -lt 1 ] && weeks=1

      # Status tag
      local tag=""
      case "$state" in
        EXECUTING) tag="active," ;;
        APPROVED) tag="" ;;
        DRAFT) tag="done," ;;  # Mermaid uses 'done' for completed visual, we invert for drafts
      esac

      # Display name (truncate)
      local display="$name"
      [ ${#display} -gt 30 ] && display="${display:0:27}..."

      echo "    ${display} :${tag} ${weeks}w"
    done
  done

  printf '```\n'
}

# ── Main ──────────────────────────────────────────────────────

case "${1:-scan}" in
  scan)    shift 2>/dev/null || true; cmd_scan "$@" ;;
  stale)   shift 2>/dev/null || true; cmd_stale "$@" ;;
  set)     shift; cmd_set "$@" ;;
  roadmap) shift 2>/dev/null || true; cmd_roadmap "$@" ;;
  *)       echo "Usage: plan-lifecycle.sh {scan|stale|set|roadmap} [args]"; exit 1 ;;
esac
