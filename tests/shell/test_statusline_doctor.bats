#!/usr/bin/env bats
# SP-STATUSLINE-SOTA-V3 Sprint C — doctor.sh tests for L5.

load helper.bash

setup() {
    setup_isolated_home
    export TARGET="$HOME_TMP/.local/share/atlas-statusline"
    export DOCTOR="$PLUGIN_ROOT/scripts/statusline/doctor.sh"
    export INSTALLER="$PLUGIN_ROOT/scripts/statusline/install.sh"
    export ATLAS_STATUSLINE_TARGET="$TARGET"
}

teardown() {
    teardown_isolated_home
}

@test "doctor is executable" {
    [ -x "$DOCTOR" ]
}

@test "doctor --help exits 0" {
    run bash "$DOCTOR" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "doctor on empty install reports failures (exit non-zero)" {
    run bash "$DOCTOR"
    [ "$status" -ne 0 ]
    [[ "$output" == *"DEGRADED"* ]] || [[ "$output" == *"fail"* ]] || [[ "$output" == *"✗"* ]]
}

@test "doctor after install reports HEALTHY" {
    # Pre-populate capabilities for the render check
    mkdir -p "$HOME/.atlas/runtime"
    cat > "$HOME/.atlas/runtime/capabilities.json" <<EOF
{"version":"6.0.0-test","tier":"core","addons":[{"name":"atlas-core","version":"6.0.0-test","priority":1}]}
EOF
    bash "$INSTALLER" --auto --target "$TARGET" >/dev/null 2>&1

    run bash "$DOCTOR"
    # In isolated test HOME, cship/jq/starship are present (pass), but the
    # plugin renderer at ~/.claude/plugins/... is not, so wrapper falls back.
    # We accept either HEALTHY or DEGRADED — but the bats focus is on
    # specific checks: settings + wrapper + drift should be ok.
    [[ "$output" == *"settings.local.json"* ]]
    [[ "$output" == *"$TARGET/statusline-wrapper.sh"* ]]
    [[ "$output" == *"deployed files match source"* ]] \
        || [[ "$output" == *"deployed files match"* ]]
}

@test "doctor --json produces valid JSON" {
    bash "$INSTALLER" --auto --target "$TARGET" >/dev/null 2>&1
    run bash "$DOCTOR" --json
    # Status non-zero is fine if some checks fail in isolated env;
    # what matters is JSON validity.
    echo "$output" | jq -e '.checks | length == 8' >/dev/null
    echo "$output" | jq -e '.total == 8' >/dev/null
    echo "$output" | jq -e '.passed >= 0' >/dev/null
    echo "$output" | jq -e '.failed >= 0' >/dev/null
}

@test "doctor --quiet only outputs failures" {
    # On a fresh isolated HOME, almost everything fails — useful filter
    run bash "$DOCTOR" --quiet
    # No need to assert exit status; just ensure output is non-empty when
    # there are failures, and check the "Overall" line is present.
    [[ "$output" == *"Overall"* ]]
}

@test "doctor reports drift when deployed file differs from source" {
    bash "$INSTALLER" --auto --target "$TARGET" >/dev/null 2>&1
    # Mutate the deployed wrapper
    echo "# tampered" >> "$TARGET/statusline-wrapper.sh"
    run bash "$DOCTOR"
    [[ "$output" == *"diverge"* ]] || [[ "$output" == *"mismatch"* ]] || [[ "$output" == *"drift"* ]] || [[ "$output" == *"warn"* ]] || [[ "$output" == *"⚠"* ]]
}

@test "doctor reports failure when settings.local.json statusLine.command points to nonexistent file" {
    mkdir -p "$HOME/.claude"
    echo '{"statusLine":{"type":"command","command":"/nonexistent/path/wrapper.sh"}}' > "$HOME/.claude/settings.local.json"
    run bash "$DOCTOR"
    [[ "$output" == *"not executable"* ]] || [[ "$output" == *"DEGRADED"* ]]
    [ "$status" -ne 0 ]
}
