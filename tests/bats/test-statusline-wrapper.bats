#!/usr/bin/env bats
# tests/bats/test-statusline-wrapper.bats — SOTA v2 wrapper coverage
#
# Tests the thin delegation wrapper. Focus: version resolution + delegation
# contract. The wrapped plugin statusline-command.sh is NOT tested here
# (covered by statusline-e2e.sh). We stub it with a marker script and
# verify the wrapper selects + exec's the right one.
#
# ADR: docs/ADR/ADR-019-statusline-sota-v2-unification.md

SCRIPT="$BATS_TEST_DIRNAME/../../scripts/statusline-wrapper.sh"
RESOLVER="$BATS_TEST_DIRNAME/../../scripts/atlas-resolve-version.sh"

setup() {
  TEST_HOME=$(mktemp -d)
  export HOME="$TEST_HOME"
  mkdir -p "$TEST_HOME/.atlas/runtime"
  mkdir -p "$TEST_HOME/.claude/plugins/cache/atlas-marketplace/atlas-core/5.35.0/scripts"
  mkdir -p "$TEST_HOME/.local/share/atlas-statusline"

  # Install resolver so wrapper can call it
  cp "$RESOLVER" "$TEST_HOME/.local/share/atlas-statusline/atlas-resolve-version.sh"
  chmod +x "$TEST_HOME/.local/share/atlas-statusline/atlas-resolve-version.sh"

  # Stub a plugin statusline-command.sh that emits a distinctive marker
  cat > "$TEST_HOME/.claude/plugins/cache/atlas-marketplace/atlas-core/5.35.0/scripts/statusline-command.sh" <<'EOF'
#!/usr/bin/env bash
# Test stub: emits marker proving the wrapper exec'd *this* version
cat >/dev/null 2>&1 || true
printf 'STUB-5.35.0-ATLAS'
EOF
  chmod +x "$TEST_HOME/.claude/plugins/cache/atlas-marketplace/atlas-core/5.35.0/scripts/statusline-command.sh"

  # Default caps.json pointing to 5.35.0
  cat > "$TEST_HOME/.atlas/runtime/capabilities.json" <<'EOF'
{"version":"5.35.0","source":"fs"}
EOF

  # Ensure resolver does NOT call the real claude CLI
  export ATLAS_NO_CLAUDE=1
  export ATLAS_RESOLVE_NO_CACHE=1
}

teardown() {
  rm -rf "$TEST_HOME"
  unset ATLAS_NO_CLAUDE ATLAS_RESOLVE_NO_CACHE
}

@test "delegates to plugin-shipped statusline-command.sh for resolved version" {
  run bash -c "echo '{}' | bash '$SCRIPT'"
  [ "$status" -eq 0 ]
  [ "$output" = "STUB-5.35.0-ATLAS" ]
}

@test "strips update indicator when resolver emits '5.35.0 ↗ 5.36.0'" {
  # Marketplace registry advertises 5.36.0 (ahead of installed 5.35.0)
  mkdir -p "$TEST_HOME/.claude/plugins/marketplaces/atlas-marketplace/.claude-plugin"
  cat > "$TEST_HOME/.claude/plugins/marketplaces/atlas-marketplace/.claude-plugin/marketplace.json" <<'EOF'
{"plugins":[{"version":"5.36.0"}]}
EOF
  # Resolver should return "5.35.0 ↗ 5.36.0"; wrapper must strip the indicator
  # to get "5.35.0" and exec the 5.35.0 plugin (the only one on disk).
  run bash -c "echo '{}' | bash '$SCRIPT'"
  [ "$status" -eq 0 ]
  [ "$output" = "STUB-5.35.0-ATLAS" ]
}

@test "falls through to filesystem scan when resolver absent" {
  rm "$TEST_HOME/.local/share/atlas-statusline/atlas-resolve-version.sh"
  run bash -c "echo '{}' | bash '$SCRIPT'"
  [ "$status" -eq 0 ]
  [ "$output" = "STUB-5.35.0-ATLAS" ]
}

@test "emits fallback banner when no version resolvable (empty cache)" {
  rm -rf "$TEST_HOME/.claude/plugins/cache/atlas-marketplace/atlas-core/5.35.0"
  rm "$TEST_HOME/.atlas/runtime/capabilities.json"
  rm "$TEST_HOME/.local/share/atlas-statusline/atlas-resolve-version.sh"
  run bash -c "echo '{}' | bash '$SCRIPT'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"🏛️ ATLAS ?"* ]]
  [[ "$output" == *"doctor --statusline"* ]]
}

@test "emits fallback when version resolves but plugin script missing" {
  # Version resolves via caps (5.35.0) but we remove the statusline script
  rm "$TEST_HOME/.claude/plugins/cache/atlas-marketplace/atlas-core/5.35.0/scripts/statusline-command.sh"
  run bash -c "echo '{}' | bash '$SCRIPT'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"🏛️ ATLAS 5.35.0"* ]]
  [[ "$output" == *"missing"* ]]
}

@test "picks highest semver when multiple cache versions present" {
  mkdir -p "$TEST_HOME/.claude/plugins/cache/atlas-marketplace/atlas-core/5.30.0/scripts"
  mkdir -p "$TEST_HOME/.claude/plugins/cache/atlas-marketplace/atlas-core/5.34.1/scripts"
  mkdir -p "$TEST_HOME/.claude/plugins/cache/atlas-marketplace/atlas-core/5.36.0/scripts"
  # Only 5.36.0 has a script — and its output is distinctive
  cat > "$TEST_HOME/.claude/plugins/cache/atlas-marketplace/atlas-core/5.36.0/scripts/statusline-command.sh" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null 2>&1 || true
printf 'STUB-5.36.0-PICKED'
EOF
  chmod +x "$TEST_HOME/.claude/plugins/cache/atlas-marketplace/atlas-core/5.36.0/scripts/statusline-command.sh"
  # Update caps to point to 5.36.0
  echo '{"version":"5.36.0","source":"fs"}' > "$TEST_HOME/.atlas/runtime/capabilities.json"

  run bash -c "echo '{}' | bash '$SCRIPT'"
  [ "$status" -eq 0 ]
  [ "$output" = "STUB-5.36.0-PICKED" ]
}

@test "stdin passes through to plugin script" {
  # Replace stub to echo stdin back (verifies exec passes stdin)
  cat > "$TEST_HOME/.claude/plugins/cache/atlas-marketplace/atlas-core/5.35.0/scripts/statusline-command.sh" <<'EOF'
#!/usr/bin/env bash
input=$(cat)
printf 'got: %s' "$input"
EOF
  chmod +x "$TEST_HOME/.claude/plugins/cache/atlas-marketplace/atlas-core/5.35.0/scripts/statusline-command.sh"
  run bash -c "printf 'test-payload' | bash '$SCRIPT'"
  [ "$status" -eq 0 ]
  [ "$output" = "got: test-payload" ]
}

@test "exit code from plugin script passes through" {
  cat > "$TEST_HOME/.claude/plugins/cache/atlas-marketplace/atlas-core/5.35.0/scripts/statusline-command.sh" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null 2>&1 || true
printf 'will-exit-42'
exit 42
EOF
  chmod +x "$TEST_HOME/.claude/plugins/cache/atlas-marketplace/atlas-core/5.35.0/scripts/statusline-command.sh"
  run bash -c "echo '{}' | bash '$SCRIPT'"
  [ "$status" -eq 42 ]
  [ "$output" = "will-exit-42" ]
}
