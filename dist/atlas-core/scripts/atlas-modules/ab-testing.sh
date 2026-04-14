#!/usr/bin/env bash
# shellcheck shell=bash
# NOTE: Sourced by scripts/atlas-cli.sh (no set -euo pipefail at file level).
# ATLAS CLI Module: A/B Testing for Cognitive Hooks
# Sourced by atlas-cli.sh — do not execute directly
# Subcommands: atlas ab start|stop|status

AB_CONFIG="${HOME}/.atlas/cognitive-ab-config.json"
AB_GROUP_FILE="${HOME}/.claude/ab-current-group"
AB_SUMMARIES="${HOME}/.claude/ab-session-summaries.jsonl"

_atlas_ab() {
  local subcmd="${1:-status}"
  shift 2>/dev/null || true

  case "$subcmd" in
    start)  _atlas_ab_start "$@" ;;
    stop)   _atlas_ab_stop ;;
    status) _atlas_ab_status ;;
    *)
      echo "Usage: atlas ab [start|stop|status]"
      echo "  start  — Enable A/B testing (creates config, sets start_date to today)"
      echo "  stop   — Disable A/B testing (keeps data for analysis)"
      echo "  status — Show current state (group, days elapsed, session counts)"
      return 1
      ;;
  esac
}

_atlas_ab_start() {
  local today
  today=$(date +%Y-%m-%d)

  mkdir -p "$(dirname "$AB_CONFIG")" 2>/dev/null

  # Create or update config
  cat > "$AB_CONFIG" <<EOF
{
  "ab_testing_enabled": true,
  "mode": "alternating_days",
  "start_date": "$today",
  "control_days": "odd",
  "treatment_days": "even",
  "hooks_targeted": ["theory-of-mind", "tone-adaptation", "affect-signal"],
  "notes": "Cognitive hooks A/B test. Control=hooks OFF, Treatment=hooks ON."
}
EOF

  # Clear cached group so it re-resolves
  rm -f "$AB_GROUP_FILE" 2>/dev/null

  echo ""
  echo "  ${ATLAS_BOLD}A/B Testing STARTED${ATLAS_RESET}"
  echo ""
  echo "  Start date:     ${ATLAS_CYAN}${today}${ATLAS_RESET}"
  echo "  Control days:   odd day-of-year (hooks OFF)"
  echo "  Treatment days: even day-of-year (hooks ON)"
  echo "  Hooks targeted: theory-of-mind, tone-adaptation, affect-signal"
  echo ""
  echo "  Data will be logged to:"
  echo "    ${ATLAS_DIM}~/.claude/hook-log.jsonl${ATLAS_RESET} (ab_group field)"
  echo "    ${ATLAS_DIM}~/.claude/ab-session-summaries.jsonl${ATLAS_RESET} (session metrics)"
  echo ""

  _atlas_ab_show_today
}

_atlas_ab_stop() {
  if [ ! -f "$AB_CONFIG" ]; then
    echo "  No A/B config found. Nothing to stop."
    return 0
  fi

  # Set enabled=false (preserve data)
  if command -v jq &>/dev/null; then
    local tmp
    tmp=$(jq '.ab_testing_enabled = false' "$AB_CONFIG" 2>/dev/null)
    [ -n "$tmp" ] && echo "$tmp" > "$AB_CONFIG"
  else
    /usr/bin/sed -i 's/"ab_testing_enabled"[[:space:]]*:[[:space:]]*true/"ab_testing_enabled": false/' "$AB_CONFIG" 2>/dev/null
  fi

  # Clear cached group
  rm -f "$AB_GROUP_FILE" 2>/dev/null

  echo ""
  echo "  ${ATLAS_BOLD}A/B Testing STOPPED${ATLAS_RESET}"
  echo ""
  echo "  Config preserved at: ${ATLAS_DIM}${AB_CONFIG}${ATLAS_RESET}"
  echo "  All cognitive hooks will now run normally (treatment mode)."
  echo ""

  # Show summary if data exists
  if [ -f "$AB_SUMMARIES" ]; then
    local total
    total=$(wc -l < "$AB_SUMMARIES" 2>/dev/null || echo 0)
    echo "  Session data: ${ATLAS_CYAN}${total}${ATLAS_RESET} summaries collected"
    echo "  Run analysis: python3 scripts/ab-analysis.py"
  fi
  echo ""
}

_atlas_ab_status() {
  echo ""
  echo "  ${ATLAS_BOLD}A/B Testing Status${ATLAS_RESET}"
  echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Config check
  if [ ! -f "$AB_CONFIG" ]; then
    echo "  Config:  ${ATLAS_DIM}not found${ATLAS_RESET} (run 'atlas ab start')"
    echo ""
    return 0
  fi

  local enabled start_date control_days
  if command -v jq &>/dev/null; then
    enabled=$(jq -r '.ab_testing_enabled // false' "$AB_CONFIG" 2>/dev/null)
    start_date=$(jq -r '.start_date // "unknown"' "$AB_CONFIG" 2>/dev/null)
    control_days=$(jq -r '.control_days // "odd"' "$AB_CONFIG" 2>/dev/null)
  else
    enabled=$(grep -o '"ab_testing_enabled"[[:space:]]*:[[:space:]]*[a-z]*' "$AB_CONFIG" 2>/dev/null | grep -o '[a-z]*$')
    start_date=$(grep -o '"start_date"[[:space:]]*:[[:space:]]*"[^"]*"' "$AB_CONFIG" 2>/dev/null | grep -o '"[^"]*"$' | tr -d '"')
    control_days=$(grep -o '"control_days"[[:space:]]*:[[:space:]]*"[a-z]*"' "$AB_CONFIG" 2>/dev/null | grep -o '"[a-z]*"$' | tr -d '"')
    [ -z "$control_days" ] && control_days="odd"
  fi

  if [ "$enabled" = "true" ]; then
    echo "  Enabled: ${ATLAS_CYAN}YES${ATLAS_RESET}"
  else
    echo "  Enabled: ${ATLAS_DIM}NO${ATLAS_RESET} (run 'atlas ab start' to enable)"
  fi

  echo "  Started: ${start_date}"
  echo "  Rule:    control=${control_days} days, treatment=${control_days/odd/even}"

  # Days elapsed
  if [ "$start_date" != "unknown" ] && [ -n "$start_date" ]; then
    local start_epoch today_epoch days_elapsed
    start_epoch=$(date -d "$start_date" +%s 2>/dev/null || echo 0)
    today_epoch=$(date +%s)
    if [ "$start_epoch" -gt 0 ]; then
      days_elapsed=$(( (today_epoch - start_epoch) / 86400 ))
      echo "  Elapsed: ${ATLAS_CYAN}${days_elapsed}${ATLAS_RESET} days"
    fi
  fi

  echo ""
  _atlas_ab_show_today

  # Session counts from hook-log
  echo ""
  echo "  ${ATLAS_BOLD}Session Data${ATLAS_RESET}"
  echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  local log="${HOME}/.claude/hook-log.jsonl"
  if [ -f "$log" ]; then
    local control_count treatment_count skipped_count
    control_count=$(grep -c '"ab_group":"control"' "$log" 2>/dev/null || echo 0)
    treatment_count=$(grep -c '"ab_group":"treatment"' "$log" 2>/dev/null || echo 0)
    skipped_count=$(grep -c '"ab-skipped"' "$log" 2>/dev/null || echo 0)

    echo ""
    echo "  Hook events with A/B tags:"
    echo "    Control (hooks OFF):  ${ATLAS_CYAN}${control_count}${ATLAS_RESET}"
    echo "    Treatment (hooks ON): ${ATLAS_CYAN}${treatment_count}${ATLAS_RESET}"
    echo "    Skipped (ab-guard):   ${ATLAS_CYAN}${skipped_count}${ATLAS_RESET}"
  else
    echo ""
    echo "  ${ATLAS_DIM}No hook-log.jsonl found yet${ATLAS_RESET}"
  fi

  # Session summaries
  if [ -f "$AB_SUMMARIES" ]; then
    local total_summaries
    total_summaries=$(wc -l < "$AB_SUMMARIES" 2>/dev/null || echo 0)
    echo ""
    echo "  Session summaries: ${ATLAS_CYAN}${total_summaries}${ATLAS_RESET}"
  fi

  echo ""
}

_atlas_ab_show_today() {
  local day_of_year group_today
  day_of_year=$(date +%-j)

  # Determine today's group
  local control_days="odd"
  if [ -f "$AB_CONFIG" ]; then
    if command -v jq &>/dev/null; then
      control_days=$(jq -r '.control_days // "odd"' "$AB_CONFIG" 2>/dev/null)
    fi
  fi

  if [ "$control_days" = "odd" ]; then
    if (( day_of_year % 2 == 1 )); then
      group_today="CONTROL (hooks OFF)"
    else
      group_today="TREATMENT (hooks ON)"
    fi
  else
    if (( day_of_year % 2 == 0 )); then
      group_today="CONTROL (hooks OFF)"
    else
      group_today="TREATMENT (hooks ON)"
    fi
  fi

  echo "  Today:   Day ${day_of_year} → ${ATLAS_CYAN}${group_today}${ATLAS_RESET}"
}
