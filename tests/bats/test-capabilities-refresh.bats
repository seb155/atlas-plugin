#!/usr/bin/env bats
# tests/bats/test-capabilities-refresh.bats — UserPromptSubmit drift-sentinel coverage
#
# The capabilities-refresh hook is the READ side of the drift sentinel pattern
# introduced by v5.30.0 SOTA. It reacts to ~/.atlas/runtime/.capabilities.stale
# (written by atlas-resolve-version.sh when Tier-1 CLI ≠ capabilities.json) by
# rerunning atlas-discover-addons.sh to refresh the snapshot.
#
# Until v5.36.0 this hook shipped but was effectively dormant because the other
# end (statusline bash path) never reached a resolver that could touch the
# sentinel. With the SOTA v2 wrapper in place, the pattern is live end-to-end
# and this test file exercises it.
#
# Why tests matter here: the hook's silent-on-stdout UserPromptSubmit contract
# and its "remove sentinel BEFORE discover" ordering are both easy to break on
# refactor. These tests pin the contract.
#
# ADR: docs/ADR/ADR-019-statusline-sota-v2-unification.md

HOOK="$BATS_TEST_DIRNAME/../../hooks/capabilities-refresh"

setup() {
  TEST_HOME=$(mktemp -d)
  export HOME="$TEST_HOME"
  mkdir -p "$TEST_HOME/.atlas/runtime"

  # Fake plugin root so hook can find scripts/atlas-discover-addons.sh
  PLUGIN_ROOT_TMP=$(mktemp -d)
  export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT_TMP"
  mkdir -p "$PLUGIN_ROOT_TMP/scripts"

  # Stub discover script writes to TEST_HOME to prove it ran
  cat > "$PLUGIN_ROOT_TMP/scripts/atlas-discover-addons.sh" <<EOF
#!/usr/bin/env bash
echo "DISCOVER_RAN" > "$TEST_HOME/.atlas/runtime/.discover-marker"
exit 0
EOF
  chmod +x "$PLUGIN_ROOT_TMP/scripts/atlas-discover-addons.sh"
}

teardown() {
  rm -rf "$TEST_HOME" "$PLUGIN_ROOT_TMP"
  unset CLAUDE_PLUGIN_ROOT
}

@test "no sentinel → exits 0, does nothing" {
  run bash "$HOOK"
  [ "$status" -eq 0 ]
  [ ! -f "$TEST_HOME/.atlas/runtime/.discover-marker" ]
}

@test "sentinel present → removes sentinel AND runs discover" {
  touch "$TEST_HOME/.atlas/runtime/.capabilities.stale"
  run bash "$HOOK"
  [ "$status" -eq 0 ]
  [ ! -f "$TEST_HOME/.atlas/runtime/.capabilities.stale" ]
  [ -f "$TEST_HOME/.atlas/runtime/.discover-marker" ]
}

@test "sentinel removed BEFORE discover runs (idempotence on discover failure)" {
  touch "$TEST_HOME/.atlas/runtime/.capabilities.stale"
  # Make discover fail hard
  cat > "$CLAUDE_PLUGIN_ROOT/scripts/atlas-discover-addons.sh" <<'EOF'
#!/usr/bin/env bash
# Verify sentinel is already gone by the time discover is invoked
if [ -f "${HOME}/.atlas/runtime/.capabilities.stale" ]; then
  echo "SENTINEL_STILL_PRESENT" >&2
  exit 99
fi
exit 1  # Generic failure
EOF
  chmod +x "$CLAUDE_PLUGIN_ROOT/scripts/atlas-discover-addons.sh"

  run bash "$HOOK"
  [ "$status" -eq 0 ]
  [ ! -f "$TEST_HOME/.atlas/runtime/.capabilities.stale" ]
  # Confirm our sentinel-present stderr did not fire (i.e. sentinel was removed first)
  [[ "$output" != *"SENTINEL_STILL_PRESENT"* ]]
}

@test "sentinel present but discover script missing → exits 0, sentinel still removed" {
  touch "$TEST_HOME/.atlas/runtime/.capabilities.stale"
  rm "$CLAUDE_PLUGIN_ROOT/scripts/atlas-discover-addons.sh"
  run bash "$HOOK"
  [ "$status" -eq 0 ]
  [ ! -f "$TEST_HOME/.atlas/runtime/.capabilities.stale" ]
}

@test "silent on stdout (UserPromptSubmit contract)" {
  touch "$TEST_HOME/.atlas/runtime/.capabilities.stale"
  run bash "$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "falls back to inferred plugin root when CLAUDE_PLUGIN_ROOT unset" {
  # The hook should resolve PLUGIN_ROOT via dirname/../../ when env var missing.
  # This fallback is used when the hook is invoked directly (not via CC harness).
  touch "$TEST_HOME/.atlas/runtime/.capabilities.stale"
  unset CLAUDE_PLUGIN_ROOT
  run bash "$HOOK"
  # Status is always 0 (best-effort contract). Sentinel must still be removed.
  [ "$status" -eq 0 ]
  [ ! -f "$TEST_HOME/.atlas/runtime/.capabilities.stale" ]
}
