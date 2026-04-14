#!/usr/bin/env bash
# Shared test helpers for ATLAS bats-core tests.
# Source this file at the top of each .bats file:
#   load helper.bash

# Resolve plugin root (repo absolute path)
PLUGIN_ROOT="${PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export PLUGIN_ROOT
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

# Isolated HOME for each test — prevents pollution of real ~/.atlas, ~/.claude
setup_isolated_home() {
    export HOME_TMP
    HOME_TMP="$(mktemp -d -t atlas-bats-home-XXXXXX)"
    export HOME="$HOME_TMP"
    mkdir -p "$HOME/.atlas/runtime" "$HOME/.atlas/state" "$HOME/.claude"
}

teardown_isolated_home() {
    [ -n "${HOME_TMP:-}" ] && [ -d "$HOME_TMP" ] && rm -rf "$HOME_TMP"
}

# Helper to invoke a hook with stdin JSON payload
invoke_hook_with_stdin() {
    local hook="$1"
    local payload="$2"
    echo "$payload" | "$PLUGIN_ROOT/hooks/$hook"
}
