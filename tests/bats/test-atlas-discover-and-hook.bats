#!/usr/bin/env bats
# tests/bats/test-atlas-discover-and-hook.bats
# Covers: atlas-discover-addons.sh + capabilities-refresh hook + doctor-prune.sh

DISCOVER="$BATS_TEST_DIRNAME/../../scripts/atlas-discover-addons.sh"
HOOK="$BATS_TEST_DIRNAME/../../hooks/capabilities-refresh"
PRUNE="$BATS_TEST_DIRNAME/../../scripts/doctor-prune.sh"

setup() {
  TEST_HOME=$(mktemp -d)
  export HOME="$TEST_HOME"
  mkdir -p "$TEST_HOME/.atlas/runtime"

  # Minimal fake marketplace cache with valid addon structure
  for addon in atlas-core atlas-dev atlas-admin; do
    dir="$TEST_HOME/.claude/plugins/cache/atlas-marketplace/$addon/5.29.0"
    mkdir -p "$dir/skills/foo" "$dir/agents/bar"
    touch "$dir/skills/foo/SKILL.md" "$dir/agents/bar/AGENT.md"
    echo "5.29.0" > "$dir/VERSION"
    cat > "$dir/_addon-manifest.yaml" <<EOF
name: ${addon}-addon
tier: core
tier_priority: 1
persona_contribution: helpful assistant
banner_label: Core
pipeline_phases:
  - DISCOVER
  - ASSIST
EOF
  done

  # Stub claude CLI
  STUB_BIN=$(mktemp -d)
  export PATH="$STUB_BIN:$PATH"
  cat > "$STUB_BIN/claude" <<'EOF'
#!/usr/bin/env bash
[ "${ATLAS_TEST_CLI_FAIL:-0}" = "1" ] && exit 1
echo "${ATLAS_TEST_CLI_JSON:-[]}"
EOF
  chmod +x "$STUB_BIN/claude"
}

teardown() {
  rm -rf "$TEST_HOME" "$STUB_BIN"
  unset ATLAS_TEST_CLI_JSON ATLAS_TEST_CLI_FAIL
}

@test "discover: CLI path populates capabilities.json with source=cli" {
  export ATLAS_TEST_CLI_JSON=$(cat <<EOF
[
  {"id":"atlas-core@atlas-marketplace","version":"5.29.0","enabled":true,"installPath":"$HOME/.claude/plugins/cache/atlas-marketplace/atlas-core/5.29.0","lastUpdated":"2026-04-19T13:08:02Z"},
  {"id":"atlas-dev@atlas-marketplace","version":"5.29.0","enabled":true,"installPath":"$HOME/.claude/plugins/cache/atlas-marketplace/atlas-dev/5.29.0","lastUpdated":"2026-04-19T13:08:02Z"},
  {"id":"atlas-admin@atlas-marketplace","version":"5.29.0","enabled":true,"installPath":"$HOME/.claude/plugins/cache/atlas-marketplace/atlas-admin/5.29.0","lastUpdated":"2026-04-19T13:08:02Z"}
]
EOF
)
  run bash "$DISCOVER"
  [ "$status" -eq 0 ]
  [ -f "$HOME/.atlas/runtime/capabilities.json" ]
  run jq -r '.source' "$HOME/.atlas/runtime/capabilities.json"
  [ "$output" = "cli" ]
  run jq -r '.schema_version' "$HOME/.atlas/runtime/capabilities.json"
  [ "$output" = "1.1" ]
}

@test "discover: CLI failure → filesystem fallback, source=fs" {
  export ATLAS_TEST_CLI_FAIL=1
  run bash "$DISCOVER"
  [ "$status" -eq 0 ]
  run jq -r '.source' "$HOME/.atlas/runtime/capabilities.json"
  [ "$output" = "fs" ]
  run jq -r '.cc_cli_available' "$HOME/.atlas/runtime/capabilities.json"
  [ "$output" = "false" ]
}

@test "discover: marketplace dir missing → minimal empty capabilities" {
  rm -rf "$HOME/.claude/plugins/cache/atlas-marketplace"
  run bash "$DISCOVER"
  [ "$status" -eq 0 ]
  run jq -r '.source' "$HOME/.atlas/runtime/capabilities.json"
  [ "$output" = "empty" ]
  run jq -r '.marketplace_found' "$HOME/.atlas/runtime/capabilities.json"
  [ "$output" = "false" ]
}

@test "hook capabilities-refresh: no sentinel → exit 0 silent" {
  # Ensure no sentinel
  rm -f "$HOME/.atlas/runtime/.capabilities.stale"
  run bash "$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "hook capabilities-refresh: sentinel present → discover runs + sentinel removed" {
  touch "$HOME/.atlas/runtime/.capabilities.stale"
  # Provide a discover path via CLAUDE_PLUGIN_ROOT
  export CLAUDE_PLUGIN_ROOT="$BATS_TEST_DIRNAME/../.."
  # Stub claude to return minimal valid JSON (so discover succeeds)
  export ATLAS_TEST_CLI_JSON='[{"id":"atlas-core@atlas-marketplace","version":"5.29.0","enabled":true,"installPath":"'"$HOME"'/.claude/plugins/cache/atlas-marketplace/atlas-core/5.29.0","lastUpdated":"2026-04-19T13:08:02Z"}]'
  run bash "$HOOK"
  [ "$status" -eq 0 ]
  [ ! -f "$HOME/.atlas/runtime/.capabilities.stale" ]
  [ -f "$HOME/.atlas/runtime/capabilities.json" ]
}

@test "doctor-prune: dry-run prints but deletes nothing" {
  # Create extra orphan versions for atlas-core
  for v in 5.27.0 5.26.0 5.25.0 5.24.0; do
    mkdir -p "$HOME/.claude/plugins/cache/atlas-marketplace/atlas-core/$v"
  done
  export ATLAS_TEST_CLI_JSON='[{"id":"atlas-core@atlas-marketplace","version":"5.29.0","enabled":true,"installPath":"'"$HOME"'/.claude/plugins/cache/atlas-marketplace/atlas-core/5.29.0","lastUpdated":"2026-04-19T13:08:02Z"}]'

  before_count=$(ls -1d "$HOME/.claude/plugins/cache/atlas-marketplace/atlas-core/"*/ | wc -l)
  run bash "$PRUNE"
  [ "$status" -eq 0 ]
  after_count=$(ls -1d "$HOME/.claude/plugins/cache/atlas-marketplace/atlas-core/"*/ | wc -l)
  # No deletion in dry-run
  [ "$before_count" = "$after_count" ]
  [[ "$output" == *"[DRY-RUN] del:"* ]]
  [[ "$output" == *"Run with --confirm to apply"* ]]
}

@test "doctor-prune: --confirm deletes orphans beyond top-2" {
  for v in 5.27.0 5.26.0 5.25.0 5.24.0; do
    mkdir -p "$HOME/.claude/plugins/cache/atlas-marketplace/atlas-core/$v"
  done
  export ATLAS_TEST_CLI_JSON='[{"id":"atlas-core@atlas-marketplace","version":"5.29.0","enabled":true,"installPath":"'"$HOME"'/.claude/plugins/cache/atlas-marketplace/atlas-core/5.29.0","lastUpdated":"2026-04-19T13:08:02Z"}]'

  run bash "$PRUNE" --confirm
  [ "$status" -eq 0 ]
  # Remaining: active (5.29.0) + 2 orphans (5.27.0, 5.26.0 — most recent). Total 3.
  remaining=$(ls -1d "$HOME/.claude/plugins/cache/atlas-marketplace/atlas-core/"*/ | wc -l)
  [ "$remaining" = "3" ]
  # 5.29.0 must still exist (active)
  [ -d "$HOME/.claude/plugins/cache/atlas-marketplace/atlas-core/5.29.0" ]
  # 5.24.0 must be gone (third-oldest orphan)
  [ ! -d "$HOME/.claude/plugins/cache/atlas-marketplace/atlas-core/5.24.0" ]
}

@test "doctor-prune: refuses if CLI missing (safety)" {
  export ATLAS_TEST_CLI_FAIL=1
  run bash "$PRUNE" --confirm
  [ "$status" -eq 1 ]
  [[ "$output" == *"aborting"* ]]
}
