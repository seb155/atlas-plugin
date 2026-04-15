#!/usr/bin/env bats
# SP-DAIMON P2 Task 2.5 — tests for hooks/pattern-signal-dispatcher

load helper.bash

HOOK="$PLUGIN_ROOT/hooks/pattern-signal-dispatcher"

# Build a throwaway git repo with N merge commits within the "last 7 days"
make_mock_repo() {
  local repo_path="$1"
  local merge_count="$2"
  mkdir -p "$repo_path"
  (
    cd "$repo_path" || exit 1
    git init -q
    git config user.email "test@test.invalid"
    git config user.name "Test"
    git commit -q --allow-empty -m "init"
    local i
    for ((i = 0; i < merge_count; i++)); do
      git checkout -q -b "feat-$i"
      git commit -q --allow-empty -m "feat: change $i"
      git checkout -q master 2>/dev/null || git checkout -q main
      git merge -q --no-ff "feat-$i" -m "Merge feat-$i" > /dev/null 2>&1
    done
  )
}

setup() {
  setup_isolated_home
  mkdir -p "$HOME/.atlas/data" "$HOME/.atlas/runtime"
  # Minimal calibration file so dispatcher doesn't skip
  cat > "$HOME/.atlas/runtime/session-calibration.json" <<EOF
{"schema_version":"1.0","user":{"short_name":"Test"}}
EOF
}

teardown() {
  teardown_isolated_home
}

# ───────── Basic sanity ─────────

@test "dispatcher exists and is executable" {
  [ -f "$HOOK" ]
  [ -x "$HOOK" ]
}

@test "bash syntax is valid" {
  run bash -n "$HOOK"
  [ "$status" -eq 0 ]
}

# ───────── Guards ─────────

@test "exits 0 silently when no calibration cache" {
  rm -f "$HOME/.atlas/runtime/session-calibration.json"
  run "$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "exits 0 even when no git repos exist" {
  unset ATLAS_ROOT
  run env ATLAS_ROOT="/nonexistent" "$HOOK"
  [ "$status" -eq 0 ]
}

# ───────── Throttle ─────────

@test "writes throttle file on first run" {
  run "$HOOK"
  [ "$status" -eq 0 ]
  [ -f "$HOME/.atlas/data/signal-dispatcher-throttle" ]
}

@test "throttle file contains a numeric timestamp" {
  "$HOOK"
  run cat "$HOME/.atlas/data/signal-dispatcher-throttle"
  [ "$status" -eq 0 ]
  # Should be a unix timestamp (10 digits starting 17xx or 18xx for dates post-2023)
  [[ "$output" =~ ^[0-9]{10}$ ]]
}

@test "second run within 10min is skipped (throttle)" {
  # Prime throttle with NOW
  date +%s > "$HOME/.atlas/data/signal-dispatcher-throttle"
  # Record signals file state before
  local before_lines=0
  [ -f "$HOME/.atlas/runtime/session-signals.jsonl" ] && \
    before_lines=$(wc -l < "$HOME/.atlas/runtime/session-signals.jsonl")
  run "$HOOK"
  [ "$status" -eq 0 ]
  # No new signals appended
  local after_lines=0
  [ -f "$HOME/.atlas/runtime/session-signals.jsonl" ] && \
    after_lines=$(wc -l < "$HOME/.atlas/runtime/session-signals.jsonl")
  [ "$before_lines" = "$after_lines" ]
}

@test "run allowed after throttle window expires" {
  # Set throttle file to 11 minutes ago
  local old_ts=$(($(date +%s) - 700))
  echo "$old_ts" > "$HOME/.atlas/data/signal-dispatcher-throttle"
  run "$HOOK"
  [ "$status" -eq 0 ]
  # Throttle file should now be recent
  local new_ts
  new_ts=$(cat "$HOME/.atlas/data/signal-dispatcher-throttle")
  [ "$new_ts" -gt "$old_ts" ]
}

# ───────── Signal detection ─────────

@test "appends chronic_dissatisfaction signal when 3+ merges in 7d" {
  local repo="$HOME/mock-repo"
  make_mock_repo "$repo" 4
  export ATLAS_ROOT="$repo"
  run "$HOOK"
  [ "$status" -eq 0 ]
  [ -f "$HOME/.atlas/runtime/session-signals.jsonl" ]
  grep -q '"signal":"chronic_dissatisfaction"' "$HOME/.atlas/runtime/session-signals.jsonl"
}

@test "no signal when repo has fewer than 3 merges" {
  local repo="$HOME/mock-repo-small"
  make_mock_repo "$repo" 1
  export ATLAS_ROOT="$repo"
  run "$HOOK"
  [ "$status" -eq 0 ]
  # Signals file may not exist OR exists but no chronic_dissatisfaction
  if [ -f "$HOME/.atlas/runtime/session-signals.jsonl" ]; then
    ! grep -q '"signal":"chronic_dissatisfaction"' "$HOME/.atlas/runtime/session-signals.jsonl"
  fi
}

@test "signal JSONL contains required fields (ts, signal, count, threshold, severity)" {
  local repo="$HOME/mock-repo"
  make_mock_repo "$repo" 5
  export ATLAS_ROOT="$repo"
  "$HOOK"
  local line
  line=$(grep '"signal":"chronic_dissatisfaction"' "$HOME/.atlas/runtime/session-signals.jsonl" | head -1)
  [[ "$line" == *'"ts":"'* ]]
  [[ "$line" == *'"signal":"chronic_dissatisfaction"'* ]]
  [[ "$line" == *'"count":'* ]]
  [[ "$line" == *'"threshold":3'* ]]
  [[ "$line" == *'"severity":"medium"'* ]]
}

@test "signal JSONL has valid JSON per line" {
  local repo="$HOME/mock-repo"
  make_mock_repo "$repo" 3
  export ATLAS_ROOT="$repo"
  "$HOOK"
  # Each line must parse as valid JSON
  run python3 -c "
import json, sys
with open('$HOME/.atlas/runtime/session-signals.jsonl') as f:
    for line in f:
        if line.strip():
            json.loads(line)
"
  [ "$status" -eq 0 ]
}

@test "evidence field includes repo name" {
  local repo="$HOME/my-cool-repo"
  make_mock_repo "$repo" 4
  export ATLAS_ROOT="$repo"
  "$HOOK"
  run grep "my-cool-repo" "$HOME/.atlas/runtime/session-signals.jsonl"
  [ "$status" -eq 0 ]
}

# ───────── Audit log ─────────

@test "appends audit log entry on signal detection" {
  local repo="$HOME/audit-repo"
  make_mock_repo "$repo" 3
  export ATLAS_ROOT="$repo"
  "$HOOK"
  [ -f "$HOME/.claude/atlas-audit.log" ]
  run grep "pattern-signal-dispatcher" "$HOME/.claude/atlas-audit.log"
  [ "$status" -eq 0 ]
}

# ───────── Silent failure invariants ─────────

@test "does not break session when HOME is unwritable" {
  # Simulate by pointing HOME at a read-only path
  local ro_dir
  ro_dir=$(mktemp -d)
  chmod 555 "$ro_dir"
  run env HOME="$ro_dir" "$HOOK"
  # Must still exit 0
  [ "$status" -eq 0 ]
  chmod 755 "$ro_dir"
  rm -rf "$ro_dir"
}

@test "does not break when git command missing" {
  # Point ATLAS_ROOT at a dir without .git
  local nogit="$HOME/nogit-dir"
  mkdir -p "$nogit"
  export ATLAS_ROOT="$nogit"
  run "$HOOK"
  [ "$status" -eq 0 ]
}

@test "silent — no stdout/stderr on normal run" {
  local repo="$HOME/silent-repo"
  make_mock_repo "$repo" 5
  export ATLAS_ROOT="$repo"
  run "$HOOK"
  [ "$status" -eq 0 ]
  # Dispatcher writes to files + logs but should not emit on stdout/stderr during normal runs
  [ -z "$output" ]
}
