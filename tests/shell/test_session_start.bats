#!/usr/bin/env bats
# Phase 6H — tests for hooks/session-start

load helper.bash

setup() {
    setup_isolated_home
}

teardown() {
    teardown_isolated_home
}

@test "session-start exits 0 with empty JSON input" {
    run bash -c 'echo "{}" | "$PLUGIN_ROOT/hooks/session-start"'
    [ "$status" -eq 0 ]
}

@test "session-start produces JSON output" {
    run bash -c 'echo "{}" | "$PLUGIN_ROOT/hooks/session-start"'
    [ "$status" -eq 0 ]
    # Output should contain "continue" key (Claude Code hook protocol)
    [[ "$output" == *'"continue"'* ]] || [[ "$output" == *'continue'* ]]
}

@test "session-start handles missing ~/.atlas/config.json gracefully" {
    # isolated HOME has no config — hook must not crash
    run bash -c 'echo "{}" | "$PLUGIN_ROOT/hooks/session-start"'
    [ "$status" -eq 0 ]
}
