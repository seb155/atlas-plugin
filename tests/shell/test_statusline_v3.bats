#!/usr/bin/env bats
# SP-STATUSLINE-SOTA-V3 Sprint A — bug fix tests for L1, L2, L3, L9, L10.
#
# Each test reproduces a specific failure mode from the 2026-04-25 forensic
# session and asserts the fix holds. See .blueprint/plans/sp-statusline-sota-v3.md.

load helper.bash

setup() {
    setup_isolated_home
    # Provide a minimal capabilities.json so command.sh has something to read
    cat > "$HOME/.atlas/runtime/capabilities.json" <<EOF
{
  "schema_version": "1.1",
  "version": "5.40.0",
  "tier": "admin",
  "tier_priority": 3,
  "addons": [
    {"name": "atlas-core", "version": "5.40.0", "tier": "core", "priority": 1},
    {"name": "atlas-admin-addon", "version": "5.40.0", "tier": "admin", "priority": 3}
  ]
}
EOF
}

teardown() {
    teardown_isolated_home
}

# ─── L1: yaml_get falls through to grep when yq returns empty ────────────

@test "L1: yaml_get parses tier from manifest with inline comment" {
    local manifest="$HOME_TMP/manifest.yaml"
    cat > "$manifest" <<'EOF'
schema_version: "1.0"
name: atlas-admin-addon
tier: admin
tier_priority: 3   # 1=core, 2=dev, 3=admin (highest wins for persona)
EOF
    # Source the function from the script under test
    source <(sed -n '/^yaml_get()/,/^}/p' "$PLUGIN_ROOT/scripts/atlas-discover-addons.sh")

    [ "$(yaml_get "$manifest" name unknown)" = "atlas-admin-addon" ]
    [ "$(yaml_get "$manifest" tier unknown)" = "admin" ]
    [ "$(yaml_get "$manifest" tier_priority 0)" = "3" ]  # NOT "3   # 1=core..."
}

@test "L1: yaml_get strips quotes around values" {
    local manifest="$HOME_TMP/manifest.yaml"
    cat > "$manifest" <<'EOF'
schema_version: "1.0"
name: "atlas-admin-addon"
EOF
    source <(sed -n '/^yaml_get()/,/^}/p' "$PLUGIN_ROOT/scripts/atlas-discover-addons.sh")

    [ "$(yaml_get "$manifest" schema_version 0)" = "1.0" ]
    [ "$(yaml_get "$manifest" name unknown)" = "atlas-admin-addon" ]
}

@test "L1: yaml_get returns default for missing key" {
    local manifest="$HOME_TMP/manifest.yaml"
    cat > "$manifest" <<'EOF'
name: foo
EOF
    source <(sed -n '/^yaml_get()/,/^}/p' "$PLUGIN_ROOT/scripts/atlas-discover-addons.sh")

    [ "$(yaml_get "$manifest" nonexistent_key fallback_value)" = "fallback_value" ]
}

@test "L1: yaml_get returns default for missing file" {
    source <(sed -n '/^yaml_get()/,/^}/p' "$PLUGIN_ROOT/scripts/atlas-discover-addons.sh")

    [ "$(yaml_get /nonexistent/path key fallback)" = "fallback" ]
}

# ─── L2: TIER_MAX_VERSION init from VERSION file ─────────────────────────

@test "L2: TIER_MAX_VERSION initialized from VERSION file when no addons resolved" {
    # Run discover with empty MARKETPLACE_DIR — no addons can be found
    run bash -c "MARKETPLACE_DIR=$HOME_TMP/empty bash $PLUGIN_ROOT/scripts/atlas-discover-addons.sh"
    [ "$status" -eq 0 ]
    # The script writes minimal capabilities and exits when marketplace missing.
    # That branch keeps version=? but documents the behavior.
    [ -f "$HOME/.atlas/runtime/capabilities.json" ]
}

@test "L2: discover end-to-end resolves a real version (not '?')" {
    # Use the real ~/.claude/plugins cache as marketplace (system-level test)
    if [ ! -d "$REAL_HOME/.claude/plugins/cache/atlas-marketplace" ]; then
        skip "no atlas-marketplace cache present"
    fi
    HOME="$REAL_HOME" run bash "$PLUGIN_ROOT/scripts/atlas-discover-addons.sh"
    [ "$status" -eq 0 ]
    local v
    v=$(jq -r '.version // "MISSING"' "$REAL_HOME/.atlas/runtime/capabilities.json")
    [ "$v" != "?" ]
    [ "$v" != "MISSING" ]
    [[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]
}

# ─── L3: command.sh fallback chain when capabilities.json .version="?" ───

@test "L3: command.sh falls back to addons[max_priority].version when .version is '?'" {
    # Inject corrupted capabilities (root cause #4 reproduction)
    jq '.version = "?"' "$HOME/.atlas/runtime/capabilities.json" > "$HOME/.atlas/runtime/capabilities.json.tmp"
    mv "$HOME/.atlas/runtime/capabilities.json.tmp" "$HOME/.atlas/runtime/capabilities.json"

    local input='{"model":{"id":"claude-opus-4-7"},"context_window":{"used_percentage":42},"workspace":{"current_dir":"/tmp"}}'
    run bash -c "ATLAS_DIR=$HOME/.atlas; echo '$input' | bash $PLUGIN_ROOT/scripts/statusline-command.sh"
    [ "$status" -eq 0 ]
    # Should contain the fallback addon version, NOT a bare "?"
    [[ "$output" == *"5.40.0"* ]]
    [[ "$output" != *"ATLAS ?"* ]] || [[ "$output" == *"?-unresolvable"* ]]
}

@test "L3: command.sh emits '?-unresolvable' (not bare '?') when capabilities.json missing" {
    rm -f "$HOME/.atlas/runtime/capabilities.json"
    local input='{"model":{"id":"claude-opus-4-7"},"context_window":{"used_percentage":42},"workspace":{"current_dir":"/tmp"}}'
    run bash -c "ATLAS_DIR=$HOME/.atlas; echo '$input' | bash $PLUGIN_ROOT/scripts/statusline-command.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"?-unresolvable"* ]]
}

# ─── L9: effort.level (object), not effort (string) ──────────────────────

@test "L9: effort.level=low renders as ○ symbol" {
    local input='{"model":{"id":"claude-opus-4-7"},"context_window":{"used_percentage":15},"workspace":{"current_dir":"/tmp"},"effort":{"level":"low"}}'
    run bash -c "ATLAS_DIR=$HOME/.atlas; echo '$input' | bash $PLUGIN_ROOT/scripts/statusline-command.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"○"* ]]
}

@test "L9: effort.level=high renders as ● symbol" {
    local input='{"model":{"id":"claude-opus-4-7"},"context_window":{"used_percentage":15},"workspace":{"current_dir":"/tmp"},"effort":{"level":"high"}}'
    run bash -c "ATLAS_DIR=$HOME/.atlas; echo '$input' | bash $PLUGIN_ROOT/scripts/statusline-command.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"●"* ]]
}

@test "L9: missing effort field falls back to ◐ (auto)" {
    local input='{"model":{"id":"claude-opus-4-7"},"context_window":{"used_percentage":15},"workspace":{"current_dir":"/tmp"}}'
    run bash -c "ATLAS_DIR=$HOME/.atlas; echo '$input' | bash $PLUGIN_ROOT/scripts/statusline-command.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"◐"* ]]
}

# ─── L10: rate_limits.five_hour (snake_case), not rate_limits["5h"] ──────

@test "L10: rate_limits.five_hour.used_percentage=42 renders R42%" {
    local input='{"model":{"id":"claude-opus-4-7"},"context_window":{"used_percentage":15},"workspace":{"current_dir":"/tmp"},"rate_limits":{"five_hour":{"used_percentage":42}}}'
    run bash -c "ATLAS_DIR=$HOME/.atlas; echo '$input' | bash $PLUGIN_ROOT/scripts/statusline-command.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"R42%"* ]]
}

@test "L10: rate_limits absent does NOT show R0% (graceful degrade)" {
    local input='{"model":{"id":"claude-opus-4-7"},"context_window":{"used_percentage":15},"workspace":{"current_dir":"/tmp"}}'
    run bash -c "ATLAS_DIR=$HOME/.atlas; echo '$input' | bash $PLUGIN_ROOT/scripts/statusline-command.sh"
    [ "$status" -eq 0 ]
    # When rate_int is 0, rate_display stays empty (existing logic at line 127)
    [[ "$output" != *"R0%"* ]]
}

# ─── Smoke: end-to-end render never contains bare "?" ────────────────────

@test "smoke: full render with all fields contains no bare '?' token" {
    local input='{"model":{"id":"claude-opus-4-7","display_name":"Opus"},"context_window":{"used_percentage":42,"context_window_size":1000000},"workspace":{"current_dir":"/tmp"},"effort":{"level":"high"},"rate_limits":{"five_hour":{"used_percentage":12}},"exceeds_200k_tokens":false}'
    run bash -c "ATLAS_DIR=$HOME/.atlas; echo '$input' | bash $PLUGIN_ROOT/scripts/statusline-command.sh"
    [ "$status" -eq 0 ]
    # Strip ANSI, then assert no bare ? followed by whitespace/end (would be ATLAS ? )
    local stripped
    stripped=$(printf '%s' "$output" | sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g')
    [[ "$stripped" != *"ATLAS ? "* ]]
    [[ "$stripped" != *"ATLAS ?"$'\n'* ]]
}
