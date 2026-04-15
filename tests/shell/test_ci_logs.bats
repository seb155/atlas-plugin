#!/usr/bin/env bats
# Tests for scripts/atlas-modules/ci.sh — atlas ci logs subcommand
#
# Strategy: source the module, call internal resolver/decode/print
# functions with fixture JSON (captured from real Woodpecker 3.14 API).
# No network calls — curl is not invoked in these tests.

load helper.bash

FIXTURE_META="$PLUGIN_ROOT/tests/shell/fixtures/pipeline-78-meta.json"
FIXTURE_LOGS="$PLUGIN_ROOT/tests/shell/fixtures/logs-78-1718.json"

setup() {
    setup_isolated_home
    # Stub the UI functions the module doesn't need for these tests
    _atlas_header() { :; }
    _atlas_footer() { :; }
    _atlas_ci() { :; }
    # shellcheck disable=SC1091
    source "$PLUGIN_ROOT/scripts/atlas-modules/ci.sh"
}

teardown() {
    teardown_isolated_home
}

@test "fixtures exist and are non-empty" {
    [ -s "$FIXTURE_META" ]
    [ -s "$FIXTURE_LOGS" ]
}

@test "resolve: step_id '1718' → 1718" {
    local meta
    meta=$(cat "$FIXTURE_META")
    run _atlas_ci_logs_resolve "$meta" "1718"
    [ "$status" -eq 0 ]
    [ "$output" = "1718" ]
}

@test "resolve: pid '12' → step_id 1718 (frontend-install)" {
    local meta
    meta=$(cat "$FIXTURE_META")
    run _atlas_ci_logs_resolve "$meta" "12"
    [ "$status" -eq 0 ]
    [ "$output" = "1718" ]
}

@test "resolve: step name 'frontend-install' → step_id 1718" {
    local meta
    meta=$(cat "$FIXTURE_META")
    run _atlas_ci_logs_resolve "$meta" "frontend-install"
    [ "$status" -eq 0 ]
    [ "$output" = "1718" ]
}

@test "resolve: prefix 'frontend-insta' → step_id 1718" {
    local meta
    meta=$(cat "$FIXTURE_META")
    run _atlas_ci_logs_resolve "$meta" "frontend-insta"
    [ "$status" -eq 0 ]
    [ "$output" = "1718" ]
}

@test "resolve: bogus token → empty output" {
    local meta
    meta=$(cat "$FIXTURE_META")
    run _atlas_ci_logs_resolve "$meta" "absolutely-not-a-step"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "resolve_all: returns 31 step ids for pipeline 78" {
    local meta
    meta=$(cat "$FIXTURE_META")
    run _atlas_ci_logs_resolve_all "$meta"
    [ "$status" -eq 0 ]
    local count
    count=$(echo "$output" | /usr/bin/wc -l)
    [ "$count" = "31" ]
    # Spot-check: 1712 (clone) and 1742 (last step) are present
    echo "$output" | /bin/grep -q "^1712$"
    echo "$output" | /bin/grep -q "^1742$"
}

@test "print_steps: table includes frontend-install and failure" {
    local meta
    meta=$(cat "$FIXTURE_META")
    run _atlas_ci_logs_print_steps "$meta" "78"
    [ "$status" -eq 0 ]
    echo "$output" | /bin/grep -q "frontend-install"
    echo "$output" | /bin/grep -q "failure"
    echo "$output" | /bin/grep -q "CI Pipeline #78"
}

@test "decode: base64 logs from fixture contain 'bun install --frozen-lockfile'" {
    local log_json
    log_json=$(cat "$FIXTURE_LOGS")
    run _atlas_ci_logs_decode "$log_json"
    [ "$status" -eq 0 ]
    echo "$output" | /bin/grep -q "bun install --frozen-lockfile"
}

@test "decode: empty array → '(empty log)' message" {
    run _atlas_ci_logs_decode "[]"
    [ "$status" -eq 0 ]
    echo "$output" | /bin/grep -q "(empty log)"
}

@test "help subcommand prints usage without error" {
    run _atlas_ci_cmd help
    [ "$status" -eq 0 ]
    echo "$output" | /bin/grep -q "atlas ci — Woodpecker CI helpers"
    echo "$output" | /bin/grep -q "atlas ci logs <N>"
}

@test "unknown subcommand returns non-zero" {
    run _atlas_ci_cmd definitely-not-a-subcommand
    [ "$status" -ne 0 ]
    echo "$output" | /bin/grep -q "unknown subcommand"
}

@test "logs without pipeline arg returns usage error" {
    run _atlas_ci_logs
    [ "$status" -ne 0 ]
    echo "$output" | /bin/grep -q "Usage: atlas ci logs"
}

@test "logs with --step but no value returns error" {
    run _atlas_ci_logs 78 --step
    [ "$status" -ne 0 ]
    echo "$output" | /bin/grep -q "requires an argument"
}

@test "_atlas_ci_load_token fails fast when env and ~/.env missing" {
    unset WP_TOKEN
    # HOME is isolated via setup_isolated_home, so ~/.env doesn't exist
    run _atlas_ci_load_token
    [ "$status" -ne 0 ]
    echo "$output" | /bin/grep -q "WP_TOKEN not set"
}
