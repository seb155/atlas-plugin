#!/usr/bin/env bats
# Phase 6H — tests for scripts/atlas-cli.sh core functions

load helper.bash

setup() {
    setup_isolated_home
    # Copy modules to isolated HOME (simulate user install)
    mkdir -p "$HOME/.atlas/shell/modules"
    cp "$PLUGIN_ROOT"/scripts/atlas-cli.sh "$HOME/.atlas/shell/atlas.sh"
    cp "$PLUGIN_ROOT"/scripts/atlas-modules/*.sh "$HOME/.atlas/shell/modules/"
}

teardown() {
    teardown_isolated_home
}

@test "atlas-cli.sh has valid bash syntax" {
    run bash -n "$PLUGIN_ROOT/scripts/atlas-cli.sh"
    [ "$status" -eq 0 ]
}

@test "atlas-cli.sh can be sourced in bash" {
    run bash -c "source \"$PLUGIN_ROOT/scripts/atlas-cli.sh\" 2>&1"
    # Should not error on source (may print warning about modules)
    [ "$status" -eq 0 ]
}

@test "all atlas-modules have valid bash syntax" {
    for m in "$PLUGIN_ROOT"/scripts/atlas-modules/*.sh; do
        run bash -n "$m"
        [ "$status" -eq 0 ] || {
            echo "syntax error in $m:"
            bash -n "$m" 2>&1
            return 1
        }
    done
}

@test "subcommands module has zero zsh-specific syntax" {
    # Regression guard for Phase 6A-2 conversion
    run grep -cE '\{[^}]*:[ht]\}|\*\(N[/)]' "$PLUGIN_ROOT/scripts/atlas-modules/subcommands.sh"
    [ "$output" = "0" ] || [ -z "$output" ]
}
