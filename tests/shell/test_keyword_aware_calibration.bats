#!/usr/bin/env bats
# SP-DAIMON P2 Task 2.2 — tests for hooks/ts/keyword-aware-calibration.ts

load helper.bash

HOOK="$PLUGIN_ROOT/hooks/ts/keyword-aware-calibration.ts"

setup() {
  # Preserve real HOME so mise shim can trust its config after isolated_home
  local real_home="$HOME"
  setup_isolated_home
  export MISE_TRUSTED_CONFIG_PATHS="$real_home/.config/mise/config.toml"
  # Silence mise warnings (rate-limit noise pollutes stderr captured by `run`)
  export MISE_QUIET=1
  export MISE_DISABLE_HINTS=1
  mkdir -p "$HOME/vault/daimon" "$HOME/.atlas/data"
  # Minimal mock calibration-rules.md with 3 rules
  cat > "$HOME/vault/daimon/calibration-rules.md" <<'MD'
# Test rules

### Rule 1 — ultrathink-test
**match**: keyword
**patterns**: ultrathink, ultra-think
**interpretation**: deep mode activated
**action**:
- use max effort
- simulate futures

### Rule 2 — hitl-test
**match**: keyword
**patterns**: HITL, hitl, collapse force
**interpretation**: externalize decision
**action**:
- present options
- clarify before proceeding

### Rule 3 — visual-test
**match**: keyword
**patterns**: ASCII, wireframe, mockup
**interpretation**: visual preference
**action**:
- use ASCII art
- tables over prose
MD

  # Minimal session-calibration.json pointing to mock vault
  cat > "$HOME/.atlas/runtime/session-calibration.json" <<EOF
{
  "schema_version": "1.0",
  "vault_path": "$HOME/vault",
  "trust_level": "high",
  "user": {"short_name": "Test"}
}
EOF
}

teardown() {
  teardown_isolated_home
}

invoke_kac() {
  local payload="$1"
  echo "$payload" | bun run "$HOOK" 2>&1
}

# ───────── Basic sanity ─────────

@test "hook exists and is readable" {
  [ -f "$HOOK" ]
  [ -r "$HOOK" ]
}

@test "hook has shebang for bun" {
  run head -1 "$HOOK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"bun"* ]]
}

# ───────── Silent exit paths ─────────

@test "exits 0 silently when stdin is empty" {
  run bash -c "echo '' | bun run '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "exits 0 silently when stdin is invalid JSON" {
  run bash -c "echo 'not json' | bun run '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "exits 0 silently when prompt is under 15 chars" {
  run bash -c "echo '{\"prompt\":\"hello\"}' | bun run '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "exits 0 silently when no session-calibration.json" {
  rm -f "$HOME/.atlas/runtime/session-calibration.json"
  run bash -c "echo '{\"prompt\":\"please help me with ultrathink here\"}' | bun run '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "exits 0 silently when calibration-rules.md missing" {
  rm -f "$HOME/vault/daimon/calibration-rules.md"
  run bash -c "echo '{\"prompt\":\"please help me with ultrathink here\"}' | bun run '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "exits 0 silently when prompt has no matching keywords" {
  run bash -c "echo '{\"prompt\":\"I want to discuss banana recipes today\"}' | bun run '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "exits 0 silently when session-calibration.json is malformed" {
  echo "not valid json" > "$HOME/.atlas/runtime/session-calibration.json"
  run bash -c "echo '{\"prompt\":\"ultrathink this situation deeply\"}' | bun run '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ───────── Happy path ─────────

@test "emits system-reminder when keyword matches" {
  run bash -c "echo '{\"prompt\":\"please ultrathink this architecture decision\"}' | bun run '$HOOK'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"additionalContext"* ]]
  [[ "$output" == *"system-reminder"* ]]
  [[ "$output" == *"ultrathink-test"* ]]
  [[ "$output" == *"deep mode activated"* ]]
}

@test "output is valid JSON" {
  local tmpfile
  tmpfile=$(mktemp)
  bash -c "echo '{\"prompt\":\"please ultrathink this architecture decision\"}' | bun run '$HOOK' > $tmpfile"
  [ -s "$tmpfile" ]
  # Parse via python reading the file directly (avoids shell-escape issues)
  run python3 -c "import json; json.load(open('$tmpfile'))"
  rm -f "$tmpfile"
  [ "$status" -eq 0 ]
}

@test "keyword match is case-insensitive" {
  run bash -c "echo '{\"prompt\":\"please UltraThink this situation right now\"}' | bun run '$HOOK'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ultrathink-test"* ]]
}

@test "matches phrase with multiple words in patterns list" {
  run bash -c "echo '{\"prompt\":\"we need collapse force on this decision\"}' | bun run '$HOOK'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"hitl-test"* ]]
}

# ───────── Multi-match ─────────

@test "emits up to 3 rules on multi-match" {
  run bash -c "echo '{\"prompt\":\"need ultrathink with HITL and ASCII mockup here\"}' | bun run '$HOOK'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"3 rules"* ]]
  [[ "$output" == *"ultrathink-test"* ]]
  [[ "$output" == *"hitl-test"* ]]
  [[ "$output" == *"visual-test"* ]]
}

@test "reports singular 'rule' when 1 match" {
  run bash -c "echo '{\"prompt\":\"please ultrathink this problem fully\"}' | bun run '$HOOK'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1 rule"* ]]
  # Guard against plural form "1 rules"
  [[ "$output" != *"1 rules"* ]]
}

# ───────── Debounce ─────────

@test "debounce prevents same rule firing twice within 2h" {
  rm -f "$HOME/.atlas/data/calibration-rules-debounce.json"
  # First call
  run bash -c "echo '{\"prompt\":\"ultrathink this architecture\"}' | bun run '$HOOK'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ultrathink-test"* ]]
  # Second call same rule — should be silent
  run bash -c "echo '{\"prompt\":\"ultrathink again right now\"}' | bun run '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "debounce state file is written after match" {
  rm -f "$HOME/.atlas/data/calibration-rules-debounce.json"
  run bash -c "echo '{\"prompt\":\"ultrathink this situation\"}' | bun run '$HOOK'"
  [ "$status" -eq 0 ]
  [ -f "$HOME/.atlas/data/calibration-rules-debounce.json" ]
  run cat "$HOME/.atlas/data/calibration-rules-debounce.json"
  [[ "$output" == *"ultrathink-test"* ]]
}

@test "different rules can fire within debounce window" {
  rm -f "$HOME/.atlas/data/calibration-rules-debounce.json"
  # Match ultrathink
  run bash -c "echo '{\"prompt\":\"ultrathink situation here\"}' | bun run '$HOOK'"
  [ "$status" -eq 0 ]
  # Match HITL (different rule) — should still fire
  run bash -c "echo '{\"prompt\":\"need HITL on this decision\"}' | bun run '$HOOK'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"hitl-test"* ]]
}

# ───────── Output size ─────────

@test "output stays under reasonable injection size" {
  run bash -c "echo '{\"prompt\":\"ultrathink HITL ASCII mockup wireframe all keywords here\"}' | bun run '$HOOK'"
  [ "$status" -eq 0 ]
  size=${#output}
  # Output is JSON-wrapped but underlying text capped near 500 chars + overhead
  [ "$size" -lt 2000 ]
}

# ───────── Regression: injection-like patterns ─────────

@test "regex injection attempts in prompt do not break parser" {
  run bash -c "echo '{\"prompt\":\"ultrathink .*(?:badregex) [test attempt\"}' | bun run '$HOOK'"
  [ "$status" -eq 0 ]
  # Either matches ultrathink or silent — but never crashes
}

@test "newlines in prompt do not break parser" {
  run bash -c 'printf "%s" "{\"prompt\":\"line one\\nultrathink line two\\nline three\"}" | bun run "'"$HOOK"'"'
  [ "$status" -eq 0 ]
}
