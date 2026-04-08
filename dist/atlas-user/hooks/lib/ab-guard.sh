#!/usr/bin/env bash
# ATLAS Hook Library: A/B Testing Guard for Cognitive Hooks
# Returns 0 (continue) if hooks should run, 1 (skip) if control day
# Sets AB_GROUP=treatment|control for downstream logging
#
# Performance target: <5ms (pure bash + jq fallback)
# Config: ~/.atlas/cognitive-ab-config.json
#
# Usage:
#   source "$(dirname "$0")/lib/ab-guard.sh"
#   ab_should_run || { echo '{"result":"skip","reason":"ab-control-day"}'; exit 0; }

AB_CONFIG="${HOME}/.atlas/cognitive-ab-config.json"
AB_GROUP_FILE="${HOME}/.claude/ab-current-group"

# Resolve current group and cache it for the day
_ab_resolve_group() {
  # Fast path: group file already set today
  if [ -f "$AB_GROUP_FILE" ]; then
    local file_date
    file_date=$(date -r "$AB_GROUP_FILE" +%Y-%m-%d 2>/dev/null || stat -c %Y "$AB_GROUP_FILE" 2>/dev/null | xargs -I{} date -d @{} +%Y-%m-%d 2>/dev/null || echo "")
    local today
    today=$(date +%Y-%m-%d)
    if [ "$file_date" = "$today" ]; then
      AB_GROUP=$(cat "$AB_GROUP_FILE" 2>/dev/null)
      [ -n "$AB_GROUP" ] && return 0
    fi
  fi

  # No config = always treatment (hooks ON)
  if [ ! -f "$AB_CONFIG" ]; then
    AB_GROUP="treatment"
    echo "$AB_GROUP" > "$AB_GROUP_FILE" 2>/dev/null || true
    return 0
  fi

  # Read config — try jq first, fallback to grep+sed
  local enabled control_days
  if command -v jq &>/dev/null; then
    enabled=$(jq -r '.ab_testing_enabled // false' "$AB_CONFIG" 2>/dev/null)
    control_days=$(jq -r '.control_days // "odd"' "$AB_CONFIG" 2>/dev/null)
  else
    # Fallback: bash string parsing (no jq dependency)
    enabled=$(grep -o '"ab_testing_enabled"[[:space:]]*:[[:space:]]*[a-z]*' "$AB_CONFIG" 2>/dev/null | grep -o '[a-z]*$')
    control_days=$(grep -o '"control_days"[[:space:]]*:[[:space:]]*"[a-z]*"' "$AB_CONFIG" 2>/dev/null | grep -o '"[a-z]*"$' | tr -d '"')
    [ -z "$control_days" ] && control_days="odd"
  fi

  # Not testing = always treatment
  if [ "$enabled" != "true" ]; then
    AB_GROUP="treatment"
    echo "$AB_GROUP" > "$AB_GROUP_FILE" 2>/dev/null || true
    return 0
  fi

  # Day-of-year parity check
  local day_of_year
  day_of_year=$(date +%-j)  # 1-366, no zero-padding

  if [ "$control_days" = "odd" ]; then
    if (( day_of_year % 2 == 1 )); then
      AB_GROUP="control"
    else
      AB_GROUP="treatment"
    fi
  else
    if (( day_of_year % 2 == 0 )); then
      AB_GROUP="control"
    else
      AB_GROUP="treatment"
    fi
  fi

  # Cache for the day
  echo "$AB_GROUP" > "$AB_GROUP_FILE" 2>/dev/null || true
  return 0
}

# Main guard function: returns 0 = run hooks, 1 = skip (control day)
ab_should_run() {
  _ab_resolve_group

  if [ "$AB_GROUP" = "control" ]; then
    return 1  # Control day = skip cognitive hooks
  fi
  return 0  # Treatment day = run hooks
}

# Export group for downstream _hook_log usage
ab_get_group() {
  if [ -z "$AB_GROUP" ]; then
    _ab_resolve_group
  fi
  echo "$AB_GROUP"
}
