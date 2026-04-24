#!/usr/bin/env bats
# tests/bats/test-atlas-resolve-version.bats — SSoT coverage for version resolver
#
# These tests isolate the resolver from the real `claude` CLI and real user
# $HOME by pointing every path at a per-test tmp dir. This keeps CI runs
# hermetic (no flakes from the tester's own plugin cache).

SCRIPT="$BATS_TEST_DIRNAME/../../scripts/atlas-resolve-version.sh"

setup() {
  TEST_HOME=$(mktemp -d)
  export HOME="$TEST_HOME"
  mkdir -p "$TEST_HOME/.atlas/runtime"
  mkdir -p "$TEST_HOME/.claude/plugins/cache/atlas-marketplace/atlas-core/5.29.0"
  mkdir -p "$TEST_HOME/.claude/plugins/marketplaces/atlas-marketplace/.claude-plugin"

  # Stub `claude` on PATH — each test can override STUB_JSON
  STUB_BIN=$(mktemp -d)
  export PATH="$STUB_BIN:$PATH"
  cat > "$STUB_BIN/claude" <<'EOF'
#!/usr/bin/env bash
# Test stub. Prints $ATLAS_TEST_CLI_JSON or errors out if ATLAS_TEST_CLI_FAIL=1.
[ "${ATLAS_TEST_CLI_FAIL:-0}" = "1" ] && exit 1
echo "${ATLAS_TEST_CLI_JSON:-[]}"
EOF
  chmod +x "$STUB_BIN/claude"

  # Default caps.json
  cat > "$TEST_HOME/.atlas/runtime/capabilities.json" <<'EOF'
{"version":"5.28.0","source":"fs"}
EOF
}

teardown() {
  rm -rf "$TEST_HOME" "$STUB_BIN"
  unset ATLAS_TEST_CLI_JSON ATLAS_TEST_CLI_FAIL ATLAS_NO_CLAUDE ATLAS_RESOLVE_NO_CACHE
}

_cli_json_for_version() {
  # Produce minimal valid plugin-list JSON for a given version
  cat <<EOF
[
  {"id":"atlas-core@atlas-marketplace","version":"$1","scope":"project","enabled":true,"installPath":"$HOME/.claude/plugins/cache/atlas-marketplace/atlas-core/$1","lastUpdated":"2026-04-19T13:08:02Z"}
]
EOF
}

@test "tier-1: CLI returns version → resolver uses it" {
  export ATLAS_TEST_CLI_JSON=$(_cli_json_for_version "5.29.0")
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$output" = "5.29.0" ]
}

@test "tier-2: CLI unavailable → falls through to capabilities.json" {
  export ATLAS_TEST_CLI_FAIL=1
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$output" = "5.28.0" ]
}

@test "drift sentinel: Tier-1 disagrees with caps.json → touches .capabilities.stale" {
  export ATLAS_TEST_CLI_JSON=$(_cli_json_for_version "5.29.0")
  # caps.json says 5.28.0 (drift)
  rm -f "$HOME/.atlas/runtime/.capabilities.stale"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "$HOME/.atlas/runtime/.capabilities.stale" ]
}

@test "drift sentinel: Tier-1 agrees with caps.json → NO sentinel" {
  echo '{"version":"5.29.0","source":"cli"}' > "$HOME/.atlas/runtime/capabilities.json"
  export ATLAS_TEST_CLI_JSON=$(_cli_json_for_version "5.29.0")
  rm -f "$HOME/.atlas/runtime/.capabilities.stale"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -f "$HOME/.atlas/runtime/.capabilities.stale" ]
}

@test "cache hit within 5s: returns cached without calling CLI" {
  # Write a cache that says "5.99.9" and a stub that would fail if invoked
  echo "5.99.9" > "$HOME/.atlas/runtime/.resolve-version.cache"
  export ATLAS_TEST_CLI_FAIL=1
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$output" = "5.99.9" ]
}

@test "cache bypass via ATLAS_RESOLVE_NO_CACHE=1" {
  echo "5.99.9" > "$HOME/.atlas/runtime/.resolve-version.cache"
  export ATLAS_RESOLVE_NO_CACHE=1
  export ATLAS_TEST_CLI_JSON=$(_cli_json_for_version "5.29.0")
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$output" = "5.29.0" ]
}

@test "ATLAS_NO_CLAUDE=1 skips Tier 1 → uses capabilities.json" {
  export ATLAS_NO_CLAUDE=1
  export ATLAS_RESOLVE_NO_CACHE=1
  # CLI would say 5.29.0 but must be ignored
  export ATLAS_TEST_CLI_JSON=$(_cli_json_for_version "5.29.0")
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$output" = "5.28.0" ]
}

@test "update indicator: marketplace newer than installed → appends ↗ arrow" {
  export ATLAS_TEST_CLI_JSON=$(_cli_json_for_version "5.29.0")
  cat > "$HOME/.claude/plugins/marketplaces/atlas-marketplace/.claude-plugin/marketplace.json" <<'EOF'
{"plugins":[{"name":"atlas-core","version":"5.31.0"}]}
EOF
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == "5.29.0 ↗ 5.31.0" ]]
}

@test "unresolvable: no CLI + no caps + no cache → '?'" {
  export ATLAS_TEST_CLI_FAIL=1
  rm -f "$HOME/.atlas/runtime/capabilities.json"
  # Empty cache dir (no versions)
  rm -rf "$HOME/.claude/plugins/cache/atlas-marketplace"/*
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$output" = "?" ]
}
