#!/usr/bin/env bash
# ATLAS Plugin — Hook Throttle Helper
# Prevents spamming the same warning type within a cooldown period.
# Usage: source this file, then call `throttle_check "warning-key" 60` (60s cooldown)
# Returns 0 if OK to show warning, 1 if throttled (skip it)

THROTTLE_DIR="/tmp/atlas-hook-throttle"
mkdir -p "$THROTTLE_DIR" 2>/dev/null || true

# throttle_check KEY COOLDOWN_SECONDS
# Returns 0 = show warning, 1 = throttled
throttle_check() {
  local key="$1"
  local cooldown="${2:-60}"
  local lock_file="$THROTTLE_DIR/$key"

  if [ -f "$lock_file" ]; then
    local last_ts
    last_ts=$(cat "$lock_file" 2>/dev/null || echo 0)
    local now
    now=$(date +%s)
    local diff=$(( now - last_ts ))
    if [ "$diff" -lt "$cooldown" ]; then
      return 1  # throttled
    fi
  fi

  # Update timestamp
  date +%s > "$lock_file" 2>/dev/null || true
  return 0  # OK to show
}
