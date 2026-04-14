#!/usr/bin/env bats
# Phase 6H — tests for hooks/worktree-exit-safe (Phase 3 safety net)

load helper.bash

setup() {
    setup_isolated_home
}

teardown() {
    teardown_isolated_home
}

@test "worktree-exit-safe exists and is executable" {
    [ -f "$PLUGIN_ROOT/hooks/worktree-exit-safe" ]
    [ -x "$PLUGIN_ROOT/hooks/worktree-exit-safe" ]
}

@test "worktree-exit-safe bash syntax is valid" {
    run bash -n "$PLUGIN_ROOT/hooks/worktree-exit-safe"
    [ "$status" -eq 0 ]
}

@test "worktree-exit-safe exits 0 with minimal ExitWorktree payload" {
    # Minimal payload: action=keep should never block (no dirty check needed)
    local payload='{"hook_event_name":"ExitWorktree","action":"keep","worktree_path":"/tmp/nonexistent"}'
    run bash -c "echo '$payload' | \"$PLUGIN_ROOT/hooks/worktree-exit-safe\""
    [ "$status" -eq 0 ]
}
