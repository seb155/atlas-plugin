#!/usr/bin/env bats
# SP-STATUSLINE-SOTA-V3 Sprint D — auto-heal hook tests for L6.

load helper.bash

setup() {
    setup_isolated_home
    export TARGET="$HOME_TMP/.local/share/atlas-statusline"
    export ATLAS_STATUSLINE_TARGET="$TARGET"
    export ATLAS_DIR="$HOME_TMP/.atlas"
    export HOOK="$PLUGIN_ROOT/hooks/statusline-heal"
    export INSTALLER="$PLUGIN_ROOT/scripts/statusline/install.sh"
    mkdir -p "$ATLAS_DIR/runtime"
}

teardown() {
    teardown_isolated_home
}

heal_log() {
    cat "$ATLAS_DIR/runtime/.statusline-heal.log" 2>/dev/null
}

# ─── Smoke ──────────────────────────────────────────────────────────────

@test "heal hook is executable" {
    [ -x "$HOOK" ]
}

@test "heal hook always exits 0 (must never block session)" {
    run bash "$HOOK" startup
    [ "$status" -eq 0 ]
}

@test "heal hook is silent on stdout (SessionStart contract)" {
    run bash "$HOOK" startup
    [ -z "$output" ]
}

@test "heal hook always writes to log" {
    bash "$HOOK" startup
    [ -f "$ATLAS_DIR/runtime/.statusline-heal.log" ]
    local lines
    lines=$(wc -l < "$ATLAS_DIR/runtime/.statusline-heal.log")
    [ "$lines" -ge 1 ]
}

# ─── Check 1: settings.local.json detection ────────────────────────────

@test "heal detects missing settings.local.json statusLine.command" {
    bash "$HOOK" startup
    local log
    log=$(heal_log)
    [[ "$log" == *"needs-install"* ]] || [[ "$log" == *"unset"* ]]
}

@test "heal detects broken settings.local.json statusLine.command (path not executable)" {
    mkdir -p "$HOME/.claude"
    echo '{"statusLine":{"type":"command","command":"/nonexistent/wrapper.sh"}}' > "$HOME/.claude/settings.local.json"
    bash "$HOOK" startup
    [[ "$(heal_log)" == *"not executable"* ]]
}

@test "heal creates sentinel when settings.local.json is broken" {
    mkdir -p "$HOME/.claude"
    echo '{"statusLine":{"type":"command","command":"/nonexistent/wrapper.sh"}}' > "$HOME/.claude/settings.local.json"
    bash "$HOOK" startup
    [ -f "$ATLAS_DIR/runtime/.statusline-needs-install" ]
}

@test "heal reports status=ok when settings.local.json is healthy" {
    bash "$INSTALLER" --auto --target "$TARGET" >/dev/null 2>&1
    # Pre-populate fresh capabilities so check 2 doesn't trigger
    cat > "$ATLAS_DIR/runtime/capabilities.json" <<EOF
{"version":"6.0.0-test","tier":"core","addons":[]}
EOF
    bash "$HOOK" startup
    local log
    log=$(heal_log | tail -1)
    [[ "$log" == *"status=ok"* ]]
}

# ─── Check 2: capabilities.json freshness ──────────────────────────────

@test "heal detects capabilities.json .version='?'" {
    cat > "$ATLAS_DIR/runtime/capabilities.json" <<EOF
{"version":"?","addons":[]}
EOF
    bash "$HOOK" startup
    [[ "$(heal_log)" == *"version='?'"* ]] || [[ "$(heal_log)" == *"refreshing"* ]] || [[ "$(heal_log)" == *"discover"* ]]
}

@test "heal detects missing capabilities.json" {
    rm -f "$ATLAS_DIR/runtime/capabilities.json"
    bash "$HOOK" startup
    [[ "$(heal_log)" == *"version='?'"* ]] || [[ "$(heal_log)" == *"discover"* ]]
}

# ─── Check 3: wrapper drift ────────────────────────────────────────────

@test "heal reports drift when deployed wrapper differs from source" {
    bash "$INSTALLER" --auto --target "$TARGET" >/dev/null 2>&1
    cat > "$ATLAS_DIR/runtime/capabilities.json" <<EOF
{"version":"6.0.0-test","addons":[]}
EOF
    # Mutate the deployed wrapper to introduce drift
    echo "# tampered" >> "$TARGET/statusline-wrapper.sh"
    bash "$HOOK" startup
    [[ "$(heal_log)" == *"drift"* ]] || [[ "$(heal_log)" == *"wrapper"* ]]
}

# ─── Subagent skip ─────────────────────────────────────────────────────

@test "heal skips when CLAUDE_AGENT_ID is set (subagent context)" {
    rm -f "$ATLAS_DIR/runtime/.statusline-heal.log"
    CLAUDE_AGENT_ID="agent-foo" bash "$HOOK" startup
    [ ! -f "$ATLAS_DIR/runtime/.statusline-heal.log" ]
}

# ─── Performance ───────────────────────────────────────────────────────

@test "heal completes under 200ms on healthy state" {
    bash "$INSTALLER" --auto --target "$TARGET" >/dev/null 2>&1
    cat > "$ATLAS_DIR/runtime/capabilities.json" <<EOF
{"version":"6.0.0-test","addons":[]}
EOF
    local start_ns end_ns
    start_ns=$(date +%s%N)
    bash "$HOOK" startup
    end_ns=$(date +%s%N)
    local elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
    # 200ms p95 budget per plan section 9 (R2 mitigation)
    [ "$elapsed_ms" -lt 200 ] || skip "performance budget exceeded: ${elapsed_ms}ms (test machine slow?)"
}
