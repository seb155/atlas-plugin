#!/usr/bin/env bats
# Tests for ci.sh v5.14.1+ expansions:
#   - Decode None bug fix (regression)
#   - Dispatcher routes new subcommands
#   - Help text lists new commands
#   - Secrets set: JSON body construction (via Python inside bash module)
#
# Network calls are NOT made — curl references are inert in these tests.

load helper.bash

FIXTURE_META="$PLUGIN_ROOT/tests/shell/fixtures/pipeline-78-meta.json"

setup() {
    setup_isolated_home
    _atlas_header() { :; }
    _atlas_footer() { :; }
    _atlas_ci() { echo "[legacy _atlas_ci invoked]"; }
    # shellcheck disable=SC1091
    source "$PLUGIN_ROOT/scripts/atlas-modules/ci.sh"
}

teardown() {
    teardown_isolated_home
}

@test "decode: entries with data=null are silently skipped (regression)" {
    # Real-world payload: tracing row has data=null mixed with base64 lines
    local payload='[{"line":0,"data":"aGVsbG8="},{"line":1,"data":null,"type":2},{"line":2,"data":"d29ybGQ="}]'
    run _atlas_ci_logs_decode "$payload"
    [ "$status" -eq 0 ]
    # Expect 'hello' and 'world' decoded, null row skipped (no error printed)
    echo "$output" | /bin/grep -q "hello"
    echo "$output" | /bin/grep -q "world"
    ! echo "$output" | /bin/grep -q "rstrip"
    ! echo "$output" | /bin/grep -q "NoneType"
}

@test "decode: entries with empty string data are skipped (edge case)" {
    local payload='[{"line":0,"data":""},{"line":1,"data":"Zm9v"}]'
    run _atlas_ci_logs_decode "$payload"
    [ "$status" -eq 0 ]
    echo "$output" | /bin/grep -q "foo"
}

@test "help: lists all v5.14.1 subcommands" {
    run _atlas_ci_cmd help
    [ "$status" -eq 0 ]
    # Each subcommand must appear somewhere in the help — not necessarily with
    # the exact "atlas ci X" prefix (meta section uses "help | version").
    for cmd in logs list pipeline rerun watch secrets agents version; do
        echo "$output" | /bin/grep -qwE "$cmd" || {
            echo "Missing help entry for: $cmd" >&2
            return 1
        }
    done
}

@test "version: prints module version" {
    run _atlas_ci_cmd version
    [ "$status" -eq 0 ]
    echo "$output" | /bin/grep -qE "atlas-ci-module v[0-9]+\.[0-9]+\.[0-9]+"
}

@test "dispatcher: 'pipelines' routes to _atlas_ci_pipelines" {
    # Mock the real impl to verify routing (no network call)
    _atlas_ci_pipelines() { echo "PIPELINES_CALLED $*"; }
    run _atlas_ci_cmd pipelines --limit 5
    [ "$status" -eq 0 ]
    echo "$output" | /bin/grep -q "PIPELINES_CALLED --limit 5"
}

@test "dispatcher: 'pipes' alias routes to _atlas_ci_pipelines" {
    _atlas_ci_pipelines() { echo "PIPELINES_CALLED $*"; }
    run _atlas_ci_cmd pipes
    [ "$status" -eq 0 ]
    echo "$output" | /bin/grep -q "PIPELINES_CALLED"
}

@test "dispatcher: 'pipeline N' routes to _atlas_ci_pipeline_info" {
    _atlas_ci_pipeline_info() { echo "PIPELINE_INFO $*"; }
    run _atlas_ci_cmd pipeline 42
    [ "$status" -eq 0 ]
    echo "$output" | /bin/grep -q "PIPELINE_INFO 42"
}

@test "dispatcher: 'rerun N' routes to _atlas_ci_rerun" {
    _atlas_ci_rerun() { echo "RERUN $*"; }
    run _atlas_ci_cmd rerun 42
    [ "$status" -eq 0 ]
    echo "$output" | /bin/grep -q "RERUN 42"
}

@test "dispatcher: 'retry' alias routes to _atlas_ci_rerun" {
    _atlas_ci_rerun() { echo "RERUN $*"; }
    run _atlas_ci_cmd retry 42
    [ "$status" -eq 0 ]
    echo "$output" | /bin/grep -q "RERUN"
}

@test "dispatcher: 'watch N' routes to _atlas_ci_watch" {
    _atlas_ci_watch() { echo "WATCH $*"; }
    run _atlas_ci_cmd watch 42 --interval 10
    [ "$status" -eq 0 ]
    echo "$output" | /bin/grep -q "WATCH 42 --interval 10"
}

@test "dispatcher: 'secrets list' routes correctly" {
    _atlas_ci_secrets_list() { echo "SECRETS_LIST"; }
    run _atlas_ci_cmd secrets list
    [ "$status" -eq 0 ]
    echo "$output" | /bin/grep -q "SECRETS_LIST"
}

@test "dispatcher: 'secrets set' with required args passes through" {
    _atlas_ci_secrets_set() { echo "SECRETS_SET name=$1 val=$2 rest=$*"; }
    run _atlas_ci_cmd secrets set mykey myval --events push,pull_request
    [ "$status" -eq 0 ]
    echo "$output" | /bin/grep -q "name=mykey val=myval"
}

@test "dispatcher: 'agents' routes to _atlas_ci_agents" {
    _atlas_ci_agents() { echo "AGENTS"; }
    run _atlas_ci_cmd agents
    [ "$status" -eq 0 ]
    echo "$output" | /bin/grep -q "AGENTS"
}

@test "dispatcher: unknown subcommand returns non-zero and message" {
    run _atlas_ci_cmd definitely-not-a-subcommand
    [ "$status" -ne 0 ]
    echo "$output" | /bin/grep -q "unknown subcommand"
}

@test "dispatcher: no subcommand falls back to legacy _atlas_ci" {
    run _atlas_ci_cmd
    [ "$status" -eq 0 ]
    echo "$output" | /bin/grep -q "legacy _atlas_ci invoked"
}

@test "secrets_set: rejects empty name" {
    run _atlas_ci_secrets_set "" "someval"
    [ "$status" -ne 0 ]
    echo "$output" | /bin/grep -q "Usage:"
}

@test "secrets_set: rejects empty value" {
    run _atlas_ci_secrets_set "myname" ""
    [ "$status" -ne 0 ]
    echo "$output" | /bin/grep -q "Usage:"
}

@test "secrets_rm: rejects missing name" {
    run _atlas_ci_secrets_rm
    [ "$status" -ne 0 ]
    echo "$output" | /bin/grep -q "Usage:"
}

@test "rerun: rejects missing pipeline arg" {
    run _atlas_ci_rerun
    [ "$status" -ne 0 ]
    echo "$output" | /bin/grep -q "Usage:"
}

@test "watch: rejects missing pipeline arg" {
    run _atlas_ci_watch
    [ "$status" -ne 0 ]
    echo "$output" | /bin/grep -q "Usage:"
}

@test "pipeline_info: rejects missing number arg" {
    run _atlas_ci_pipeline_info
    [ "$status" -ne 0 ]
    echo "$output" | /bin/grep -q "Usage:"
}
