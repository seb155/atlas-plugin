#!/usr/bin/env bats
# Phase 6H — tests for hooks/pre-compact-context

load helper.bash

setup() {
    setup_isolated_home
}

teardown() {
    teardown_isolated_home
}

@test "pre-compact-context exists and is executable" {
    [ -f "$PLUGIN_ROOT/hooks/pre-compact-context" ]
    [ -x "$PLUGIN_ROOT/hooks/pre-compact-context" ]
}

@test "pre-compact-context exits 0 with empty JSON" {
    run bash -c 'echo "{}" | "$PLUGIN_ROOT/hooks/pre-compact-context"'
    [ "$status" -eq 0 ]
}

@test "pre-compact-context bash syntax is valid" {
    run bash -n "$PLUGIN_ROOT/hooks/pre-compact-context"
    [ "$status" -eq 0 ]
}
