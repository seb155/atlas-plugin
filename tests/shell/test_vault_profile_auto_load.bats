#!/usr/bin/env bats
# SP-DAIMON P1 Task 1.7 — tests for hooks/vault-profile-auto-load
# Related plan: synapse .blueprint/plans/sp-daimon-calibration.md

load helper.bash

setup() {
  setup_isolated_home
  # shellcheck source=fixtures/mock-vault-setup.sh
  source "$PLUGIN_ROOT/tests/shell/fixtures/mock-vault-setup.sh"
  VAULT_DIR="$HOME/vault"
}

teardown() {
  teardown_isolated_home
}

# ───────── Basic sanity ─────────

@test "vault-profile-auto-load exists and is executable" {
  [ -f "$PLUGIN_ROOT/hooks/vault-profile-auto-load" ]
  [ -x "$PLUGIN_ROOT/hooks/vault-profile-auto-load" ]
}

@test "vault-profile-auto-load bash syntax is valid" {
  run bash -n "$PLUGIN_ROOT/hooks/vault-profile-auto-load"
  [ "$status" -eq 0 ]
}

# ───────── Silent exit paths ─────────

@test "exits 0 silently when no vault found" {
  export ATLAS_ROOT="$HOME/nonexistent"
  run "$PLUGIN_ROOT/hooks/vault-profile-auto-load"
  [ "$status" -eq 0 ]
  [ ! -f "$HOME/.atlas/runtime/session-calibration.json" ]
}

@test "exits 0 silently when vault exists but no kernel/config.json" {
  setup_mock_vault "$VAULT_DIR"
  rm -f "$VAULT_DIR/kernel/config.json"
  setup_atlas_profile_for_vault "$VAULT_DIR"
  run "$PLUGIN_ROOT/hooks/vault-profile-auto-load"
  [ "$status" -eq 0 ]
  [ ! -f "$HOME/.atlas/runtime/session-calibration.json" ]
}

@test "exits 0 silently when daimon_auto_load is false (opt-out)" {
  setup_mock_vault "$VAULT_DIR" false
  setup_atlas_profile_for_vault "$VAULT_DIR"
  run "$PLUGIN_ROOT/hooks/vault-profile-auto-load"
  [ "$status" -eq 0 ]
  [ ! -f "$HOME/.atlas/runtime/session-calibration.json" ]
}

# ───────── Happy path ─────────

@test "creates calibration cache when opt-in and vault valid" {
  setup_mock_vault "$VAULT_DIR"
  setup_atlas_profile_for_vault "$VAULT_DIR"
  run "$PLUGIN_ROOT/hooks/vault-profile-auto-load"
  [ "$status" -eq 0 ]
  [ -f "$HOME/.atlas/runtime/session-calibration.json" ]
}

@test "calibration cache has valid JSON" {
  setup_mock_vault "$VAULT_DIR"
  setup_atlas_profile_for_vault "$VAULT_DIR"
  run "$PLUGIN_ROOT/hooks/vault-profile-auto-load"
  run python3 -m json.tool "$HOME/.atlas/runtime/session-calibration.json"
  [ "$status" -eq 0 ]
}

@test "cache contains schema_version 1.0" {
  setup_mock_vault "$VAULT_DIR"
  setup_atlas_profile_for_vault "$VAULT_DIR"
  "$PLUGIN_ROOT/hooks/vault-profile-auto-load"
  sv=$(python3 -c "import json; print(json.load(open('$HOME/.atlas/runtime/session-calibration.json'))['schema_version'])")
  [ "$sv" = "1.0" ]
}

@test "cache contains parsed big_five scores" {
  setup_mock_vault "$VAULT_DIR"
  setup_atlas_profile_for_vault "$VAULT_DIR"
  "$PLUGIN_ROOT/hooks/vault-profile-auto-load"
  c=$(python3 -c "import json; d=json.load(open('$HOME/.atlas/runtime/session-calibration.json')); print(d['user']['big_five']['C'])")
  [ "$c" = "4.0" ]
}

@test "cache contains parsed enneagram (type + wing)" {
  setup_mock_vault "$VAULT_DIR"
  setup_atlas_profile_for_vault "$VAULT_DIR"
  "$PLUGIN_ROOT/hooks/vault-profile-auto-load"
  enn=$(python3 -c "import json; d=json.load(open('$HOME/.atlas/runtime/session-calibration.json')); print(d['user']['enneagram']['wing'])")
  [ "$enn" = "5w4" ]
}

@test "cache contains parsed cognitive_pattern (HID_N_layers)" {
  setup_mock_vault "$VAULT_DIR"
  setup_atlas_profile_for_vault "$VAULT_DIR"
  "$PLUGIN_ROOT/hooks/vault-profile-auto-load"
  pat=$(python3 -c "import json; d=json.load(open('$HOME/.atlas/runtime/session-calibration.json')); print(d['user'].get('cognitive_pattern',''))")
  [ "$pat" = "HID_7_layers" ]
}

@test "cache contains parsed deep_telos" {
  setup_mock_vault "$VAULT_DIR"
  setup_atlas_profile_for_vault "$VAULT_DIR"
  "$PLUGIN_ROOT/hooks/vault-profile-auto-load"
  tel=$(python3 -c "import json; d=json.load(open('$HOME/.atlas/runtime/session-calibration.json')); print(d['user'].get('deep_telos',''))")
  [[ "$tel" == *"frameworks de test"* ]]
}

@test "cache contains core_values from values section" {
  setup_mock_vault "$VAULT_DIR"
  setup_atlas_profile_for_vault "$VAULT_DIR"
  "$PLUGIN_ROOT/hooks/vault-profile-auto-load"
  vals=$(python3 -c "import json; d=json.load(open('$HOME/.atlas/runtime/session-calibration.json')); print(','.join(d['user'].get('core_values',[])))")
  [[ "$vals" == *"Curiosity"* ]]
}

@test "cache file has user-only permissions (0600)" {
  setup_mock_vault "$VAULT_DIR"
  setup_atlas_profile_for_vault "$VAULT_DIR"
  "$PLUGIN_ROOT/hooks/vault-profile-auto-load"
  perms=$(stat -c '%a' "$HOME/.atlas/runtime/session-calibration.json")
  [ "$perms" = "600" ]
}

# ───────── Fingerprint cache ─────────

@test "second run within 1h uses cache (no re-parse)" {
  setup_mock_vault "$VAULT_DIR"
  setup_atlas_profile_for_vault "$VAULT_DIR"
  "$PLUGIN_ROOT/hooks/vault-profile-auto-load"
  # Record mtime of cache file
  mtime1=$(stat -c '%Y' "$HOME/.atlas/runtime/session-calibration.json")
  sleep 1
  "$PLUGIN_ROOT/hooks/vault-profile-auto-load"
  mtime2=$(stat -c '%Y' "$HOME/.atlas/runtime/session-calibration.json")
  # Cache should NOT be rewritten (same mtime)
  [ "$mtime1" = "$mtime2" ]
}

@test "cache refreshes when vault file is modified" {
  setup_mock_vault "$VAULT_DIR"
  setup_atlas_profile_for_vault "$VAULT_DIR"
  "$PLUGIN_ROOT/hooks/vault-profile-auto-load"
  sleep 1
  # Modify a vault file
  touch "$VAULT_DIR/daimon/test.daimon.md"
  "$PLUGIN_ROOT/hooks/vault-profile-auto-load"
  # Cache was rewritten (new fingerprint)
  mtime=$(stat -c '%Y' "$HOME/.atlas/runtime/session-calibration.json")
  now=$(date +%s)
  # Cache mtime should be within last 5 seconds
  [ "$((now - mtime))" -lt 5 ]
}

# ───────── Privacy / ACL ─────────

@test "respects sharing.json: no auto_load entry = no auto-load" {
  setup_mock_vault "$VAULT_DIR"
  # Overwrite sharing.json to disallow everything
  cat > "$VAULT_DIR/sharing.json" <<'EOF'
{}
EOF
  setup_atlas_profile_for_vault "$VAULT_DIR"
  "$PLUGIN_ROOT/hooks/vault-profile-auto-load"
  # Cache should exist but with no user data
  [ -f "$HOME/.atlas/runtime/session-calibration.json" ]
  bf=$(python3 -c "import json; d=json.load(open('$HOME/.atlas/runtime/session-calibration.json')); print(len(d['user'].get('big_five', {})))")
  [ "$bf" = "0" ]
}

@test "audit log contains entry after run" {
  setup_mock_vault "$VAULT_DIR"
  setup_atlas_profile_for_vault "$VAULT_DIR"
  "$PLUGIN_ROOT/hooks/vault-profile-auto-load"
  [ -f "$HOME/.claude/atlas-audit.log" ]
  grep -q "vault-profile-auto-load" "$HOME/.claude/atlas-audit.log"
}
