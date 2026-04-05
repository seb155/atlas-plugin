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

  local total_checked=0 total_unchecked=0 total_effort_h=0

  printf "  %-36s %-10s %-8s %-10s %-12s\n" "PLAN" "STATUS" "SCORE" "PROGRESS" "EFFORT"
  printf "  %-36s %-10s %-8s %-10s %-12s\n" "────────────────────────────────────" "──────────" "────────" "──────────" "────────────"

  for f in "$plans_dir"/*.md; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .md)

    # Skip archive dirs, index files, agent plans
    [[ "$name" == "INDEX" ]] && continue
    [[ "$name" == *"-agent-"* ]] && continue

    local status=$(extract_status "$f")
    local score=$(extract_score "$f")
    local effort=$(extract_effort "$f")

    # Task completion (real progress)
    local checked; checked=$(grep -cP '^\s*-\s*\[x\]' "$f" 2>/dev/null) || checked=0
    local unchecked; unchecked=$(grep -cP '^\s*-\s*\[ \]' "$f" 2>/dev/null) || unchecked=0
    local items=$((checked + unchecked))
    local pct=0
    [ "$items" -gt 0 ] && pct=$(( (checked * 100) / items ))
    total_checked=$((total_checked + checked))
    total_unchecked=$((total_unchecked + unchecked))

    # Effort accumulation
    local eff_num=$(echo "$effort" | grep -oP '^\~?\d+' | tr -d '~' || echo 0)
    [ -n "$eff_num" ] && total_effort_h=$((total_effort_h + eff_num))

    # Progress bar (10 chars)
    local bar=""
    if [ "$items" -gt 0 ]; then
      local filled=$((pct / 10))
      local empty=$((10 - filled))
      bar=$(printf '%0.s█' $(seq 1 $filled 2>/dev/null) 2>/dev/null)$(printf '%0.s░' $(seq 1 $empty 2>/dev/null) 2>/dev/null)
      bar="${bar} ${pct}%"
    else
      bar="—"
    fi

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
    [ ${#display_name} -gt 34 ] && display_name="${display_name:0:31}..."

    printf "  %s %-34s %-10s %-8s %-12s %-12s\n" "$icon" "$display_name" "$status" "$score" "$bar" "$effort"
  done

  local all_items=$((total_checked + total_unchecked))
  local all_pct=0
  [ "$all_items" -gt 0 ] && all_pct=$(( (total_checked * 100) / all_items ))

  echo ""
  echo "  Summary:"
  for state in $VALID_STATES; do
    local count=${STATUS_COUNT[$state]:-0}
    [ "$count" -gt 0 ] && echo "    $state: $count"
  done
  local unknown=${STATUS_COUNT[UNKNOWN]:-0}
  [ "$unknown" -gt 0 ] && echo "    UNKNOWN: $unknown (missing status field)"
  echo ""
  echo "  Programme: ${total_checked}/${all_items} tasks (${all_pct}%) │ ~${total_effort_h}h total"
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

cmd_archive() {
  local plans_dir="${1:-.blueprint/plans}"
  [ -d "$plans_dir" ] || { echo "ERROR: $plans_dir not found" >&2; exit 1; }

  local archive_dir="$plans_dir/archive/completed"
  mkdir -p "$archive_dir"
  local archived=0

  for f in "$plans_dir"/*.md; do
    [ -f "$f" ] || continue
    local name=$(basename "$f" .md)
    [[ "$name" == "INDEX" ]] && continue

    local status=$(extract_status "$f")
    if [ "$status" = "COMPLETE" ]; then
      mv "$f" "$archive_dir/"
      archived=$((archived + 1))
      echo "  📦 Archived: $name"
    fi
  done

  [ "$archived" -eq 0 ] && echo "  ✅ No completed plans to archive."
  [ "$archived" -gt 0 ] && echo "  📦 Archived $archived plan(s) to archive/completed/"
}

cmd_suggest() {
  local plans_dir="${1:-.blueprint/plans}"
  [ -d "$plans_dir" ] || { echo "ERROR: $plans_dir not found" >&2; exit 1; }

  echo "🎯 Sprint Suggestion"
  echo ""
  echo "  Available plans (APPROVED or EXECUTING):"
  echo ""

  local total_h=0
  local sprint_cap=25  # ~25h per sprint (5 days × 5h)
  local candidates=""

  # Collect EXECUTING plans first (highest priority)
  for f in "$plans_dir"/sp*.md; do
    [ -f "$f" ] || continue
    local name=$(basename "$f" .md)
    [[ "$name" == *"-agent-"* ]] && continue

    local status=$(extract_status "$f")
    [ "$status" != "EXECUTING" ] && [ "$status" != "APPROVED" ] && continue

    local effort=$(extract_effort "$f" | grep -oP '\d+' | head -1)
    [ -z "$effort" ] && effort=0
    local score=$(extract_score "$f")

    local priority="LOW"
    [ "$status" = "EXECUTING" ] && priority="HIGH"
    [ "$status" = "APPROVED" ] && priority="MED"

    echo "    [$priority] $name (${effort}h, $status, score: $score)"

    # Add to sprint if fits
    if [ "$total_h" -lt "$sprint_cap" ] && [ "$effort" -gt 0 ]; then
      total_h=$((total_h + effort))
      candidates="$candidates $name"
    fi
  done

  echo ""
  echo "  📋 Suggested sprint scope (~${sprint_cap}h budget):"
  if [ -n "$candidates" ]; then
    echo "    Plans:$candidates"
    echo "    Total: ${total_h}h"
    [ "$total_h" -gt "$sprint_cap" ] && echo "    ⚠️  Over budget by $((total_h - sprint_cap))h — consider splitting"
  else
    echo "    No APPROVED or EXECUTING plans found."
  fi
}

# ── Freshness Scoring (P5.2) ──────────────────────────────────

compute_freshness() {
  local file="$1"
  local now_epoch=$(date +%s)
  local mod_epoch=$(stat -c %Y "$file" 2>/dev/null || echo "$now_epoch")
  local age_days=$(( (now_epoch - mod_epoch) / 86400 ))
  local status=$(extract_status "$file")

  # Score components (0-25 each, total 0-100)
  local age_score=25 completion_score=25 activity_score=25 quality_score=25

  # 1. Age score: newer = higher. Decay: -1 per day, min 0
  age_score=$((25 - age_days))
  [ "$age_score" -lt 0 ] && age_score=0

  # 2. Completion score: count checked vs unchecked task items
  local checked; checked=$(grep -cP '^\s*-\s*\[x\]' "$file" 2>/dev/null) || checked=0
  local unchecked; unchecked=$(grep -cP '^\s*-\s*\[ \]' "$file" 2>/dev/null) || unchecked=0
  local total_items=$((checked + unchecked))
  if [ "$total_items" -gt 0 ]; then
    completion_score=$(( (checked * 25) / total_items ))
  else
    completion_score=15  # No tasks = neutral
  fi

  # 3. Activity score: based on status progression
  case "$status" in
    ARCHIVED|COMPLETE) activity_score=25 ;;  # Done = healthy
    EXECUTING) activity_score=$((20 - age_days / 2)); [ "$activity_score" -lt 0 ] && activity_score=0 ;;
    APPROVED) activity_score=$((15 - age_days / 3)); [ "$activity_score" -lt 0 ] && activity_score=0 ;;
    DRAFT) activity_score=$((10 - age_days / 5)); [ "$activity_score" -lt 0 ] && activity_score=0 ;;
    *) activity_score=5 ;;
  esac

  # 4. Quality score: based on plan score (if available)
  local plan_score=$(echo "$(extract_score "$file")" | grep -oP '^\d+' || echo 0)
  local plan_max=$(echo "$(extract_score "$file")" | grep -oP '\d+$' || echo 15)
  if [ "$plan_score" -gt 0 ] && [ "$plan_max" -gt 0 ]; then
    quality_score=$(( (plan_score * 25) / plan_max ))
  else
    quality_score=10  # No score = low quality signal
  fi

  local total=$((age_score + completion_score + activity_score + quality_score))
  echo "$total $age_score $completion_score $activity_score $quality_score $age_days $checked/$total_items"
}

cmd_freshness() {
  local plans_dir="${1:-.blueprint/plans}"
  [ -d "$plans_dir" ] || { echo "ERROR: $plans_dir not found" >&2; exit 1; }

  echo "📊 Plan Freshness Scores"
  echo "   Scoring: Age(25) + Completion(25) + Activity(25) + Quality(25) = 100"
  echo ""
  printf "  %-35s %5s  %3s %3s %3s %3s  %-6s %-8s %-10s\n" "PLAN" "TOTAL" "AGE" "CMP" "ACT" "QAL" "DAYS" "TASKS" "STATUS"
  printf "  %-35s %5s  %3s %3s %3s %3s  %-6s %-8s %-10s\n" "───────────────────────────────────" "─────" "───" "───" "───" "───" "──────" "────────" "──────────"

  local results=""
  for f in "$plans_dir"/*.md; do
    [ -f "$f" ] || continue
    local name=$(basename "$f" .md)
    [[ "$name" == "INDEX" ]] && continue
    [[ "$name" == *"-agent-"* ]] && continue

    local scores=$(compute_freshness "$f")
    local total=$(echo "$scores" | awk '{print $1}')
    local age_s=$(echo "$scores" | awk '{print $2}')
    local comp_s=$(echo "$scores" | awk '{print $3}')
    local act_s=$(echo "$scores" | awk '{print $4}')
    local qual_s=$(echo "$scores" | awk '{print $5}')
    local days=$(echo "$scores" | awk '{print $6}')
    local tasks=$(echo "$scores" | awk '{print $7}')
    local status=$(extract_status "$f")

    # Color coding via emoji
    local indicator="🟢"
    [ "$total" -lt 60 ] && indicator="🟡"
    [ "$total" -lt 40 ] && indicator="🟠"
    [ "$total" -lt 20 ] && indicator="🔴"

    # Truncate name for display
    local display="$name"
    [ ${#display} -gt 33 ] && display="${display:0:30}..."

    printf "  %s %-33s %3d    %2d  %2d  %2d  %2d  %4sd  %-8s %-10s\n" \
      "$indicator" "$display" "$total" "$age_s" "$comp_s" "$act_s" "$qual_s" "$days" "$tasks" "$status"
  done | sort -t'|' -k1 -n  # Output is already inline, sort by score

  echo ""
  echo "  Legend: 🟢 ≥60 healthy | 🟡 40-59 aging | 🟠 20-39 stale | 🔴 <20 critical"
}

# ── Plan Dependency Validator (P5.7) ──────────────────────────

cmd_validate() {
  local plans_dir="${1:-.blueprint/plans}"
  [ -d "$plans_dir" ] || { echo "ERROR: $plans_dir not found" >&2; exit 1; }

  echo "🔍 Plan Dependency Validation"
  echo ""

  local errors=0 warnings=0

  # Build list of known plans
  local -A KNOWN_PLANS
  local all_plans=()
  while IFS= read -r -d '' f; do
    all_plans+=("$f")
  done < <(find "$plans_dir" -name '*.md' -print0 2>/dev/null)
  for f in "${all_plans[@]}"; do
    local name=$(basename "$f" .md)
    [[ "$name" == "INDEX" ]] && continue
    KNOWN_PLANS[$name]=1
  done

  for f in "$plans_dir"/*.md; do
    [ -f "$f" ] || continue
    local name=$(basename "$f" .md)
    [[ "$name" == "INDEX" ]] && continue
    [[ "$name" == *"-agent-"* ]] && continue

    local status=$(extract_status "$f")

    # Extract dependencies: "Companion to:", "Blocked by:", "Depends on:" lines only
    # Then extract backtick-quoted strings that look like plan names (contain sp- or end in .md)
    local deps=$(grep -iP '^\s*(\*\*)?(?:Companion to|Blocked by|Depends on|Requires|Prerequisites)' "$f" 2>/dev/null \
      | grep -oP '`[^`]+\.md`|`sp-[^`]+`' | tr -d '`' | sed 's/\.md$//' | sort -u)

    for dep in $deps; do
      # Normalize: remove .md extension if present
      dep="${dep%.md}"

      # Check if dependency exists
      if [ -z "${KNOWN_PLANS[$dep]:-}" ]; then
        echo "  ❌ $name → references '$dep' (NOT FOUND)"
        errors=$((errors + 1))
      fi

      # Check for circular: does dep reference back to us?
      local dep_file="$plans_dir/$dep.md"
      if [ -f "$dep_file" ]; then
        if grep -q "\`$name\`" "$dep_file" 2>/dev/null; then
          # It's OK for companions to reference each other, but warn
          echo "  ⚠️  Circular reference: $name ↔ $dep"
          warnings=$((warnings + 1))
        fi
      fi
    done

    # Check for stale EXECUTING plans with no tasks
    if [ "$status" = "EXECUTING" ]; then
      local task_count=$(grep -cP '^\s*\|.*\d+h' "$f" 2>/dev/null || echo 0)
      [ "$task_count" -eq 0 ] && {
        echo "  ⚠️  $name: EXECUTING but no task table found"
        warnings=$((warnings + 1))
      }
    fi

    # Check for plans with forward references (depends on plan in earlier state)
    local our_priority=0
    case "$status" in
      EXECUTING) our_priority=3 ;;
      APPROVED) our_priority=2 ;;
      DRAFT) our_priority=1 ;;
    esac

    for dep in $deps; do
      dep="${dep%.md}"
      local dep_file="$plans_dir/$dep.md"
      if [ -f "$dep_file" ]; then
        local dep_status=$(extract_status "$dep_file")
        local dep_priority=0
        case "$dep_status" in
          EXECUTING) dep_priority=3 ;;
          APPROVED) dep_priority=2 ;;
          DRAFT) dep_priority=1 ;;
        esac
        if [ "$our_priority" -gt "$dep_priority" ] && [ "$dep_priority" -gt 0 ]; then
          echo "  ⚠️  $name ($status) depends on $dep ($dep_status) — dependency behind"
          warnings=$((warnings + 1))
        fi
      fi
    done
  done

  echo ""
  if [ "$errors" -eq 0 ] && [ "$warnings" -eq 0 ]; then
    echo "  ✅ All plan dependencies valid."
  else
    [ "$errors" -gt 0 ] && echo "  ❌ $errors error(s): missing references"
    [ "$warnings" -gt 0 ] && echo "  ⚠️  $warnings warning(s): circular or stale"
  fi
}

# ── Main ──────────────────────────────────────────────────────

case "${1:-scan}" in
  scan)      shift 2>/dev/null || true; cmd_scan "$@" ;;
  stale)     shift 2>/dev/null || true; cmd_stale "$@" ;;
  set)       shift; cmd_set "$@" ;;
  roadmap)   shift 2>/dev/null || true; cmd_roadmap "$@" ;;
  archive)   shift 2>/dev/null || true; cmd_archive "$@" ;;
  suggest)   shift 2>/dev/null || true; cmd_suggest "$@" ;;
  freshness) shift 2>/dev/null || true; cmd_freshness "$@" ;;
  validate)  shift 2>/dev/null || true; cmd_validate "$@" ;;
  *)         echo "Usage: plan-lifecycle.sh {scan|stale|set|roadmap|archive|suggest|freshness|validate} [args]"; exit 1 ;;
esac
