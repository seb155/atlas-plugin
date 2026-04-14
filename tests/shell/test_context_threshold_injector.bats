#!/usr/bin/env bats
# Phase 6H — tests for hooks/context-threshold-injector (Phase 0 Bug B)

load helper.bash

setup() {
    setup_isolated_home
}

teardown() {
    teardown_isolated_home
}

@test "context-threshold-injector exists and is executable" {
    [ -f "$PLUGIN_ROOT/hooks/context-threshold-injector" ]
    [ -x "$PLUGIN_ROOT/hooks/context-threshold-injector" ]
}

@test "context-threshold-injector exits 0 with empty JSON on SessionStart" {
    run bash -c 'echo "{}" | "$PLUGIN_ROOT/hooks/context-threshold-injector"'
    [ "$status" -eq 0 ]
}

@test "context-threshold-injector bash syntax is valid" {
    run bash -n "$PLUGIN_ROOT/hooks/context-threshold-injector"
    [ "$status" -eq 0 ]
}

@test "context-threshold-injector creates state dir when missing" {
    # State file lives at ~/.atlas/state/context-threshold.json
    run bash -c 'echo "{}" | "$PLUGIN_ROOT/hooks/context-threshold-injector"'
    [ "$status" -eq 0 ]
    [ -d "$HOME/.atlas/state" ]
}
