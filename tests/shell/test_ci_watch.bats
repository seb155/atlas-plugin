#!/usr/bin/env bats
# Tests for atlas ci watch --live: ci_watch_render.py + _atlas_ci_watch dispatch.
#
# Strategy: pure-function unit tests via python3 -c subprocess +
# bash dispatcher tests (no real curl, no WP_TOKEN required for help paths).

load helper.bash

FIXTURE_RUNNING="$PLUGIN_ROOT/tests/shell/fixtures/pipeline-running.json"
FIXTURE_LOGS="$PLUGIN_ROOT/tests/shell/fixtures/logs-running-step.json"
FIXTURE_PIPELINE_78="$PLUGIN_ROOT/tests/shell/fixtures/pipeline-78-meta.json"
RENDER_PY="$PLUGIN_ROOT/scripts/atlas-modules/ci_watch_render.py"

setup() {
    setup_isolated_home
    _atlas_header() { :; }
    _atlas_footer() { :; }
    _atlas_ci() { :; }
    # shellcheck disable=SC1091
    source "$PLUGIN_ROOT/scripts/atlas-modules/ci.sh"
    TEST_DIR="$(mktemp -d -t atlas-ci-watch-test-XXXXXX)"
}

teardown() {
    [ -n "${TEST_DIR:-}" ] && [ -d "$TEST_DIR" ] && rm -rf "$TEST_DIR"
    teardown_isolated_home
}

# ─── ci_watch_render.py via subprocess ──────────────────────────────

@test "render: pipeline-78 fixture renders header + steps" {
    run python3 "$RENDER_PY" "$FIXTURE_PIPELINE_78" --plain
    [ "$status" -eq 0 ]
    echo "$output" | /bin/grep -q "Pipeline #78"
    echo "$output" | /bin/grep -q "ci-backend"
    echo "$output" | /bin/grep -q "frontend-install"
    [ "$(echo "$output" | /usr/bin/wc -l)" -ge 30 ]
}

@test "render: --plain mode emits no ANSI escapes" {
    run python3 "$RENDER_PY" "$FIXTURE_PIPELINE_78" --plain
    [ "$status" -eq 0 ]
    ! echo "$output" | /bin/grep -q $'\033\['
}

@test "render: --tty mode emits ANSI clear + green color" {
    run python3 "$RENDER_PY" "$FIXTURE_PIPELINE_78" --tty
    [ "$status" -eq 0 ]
    echo "$output" | /bin/grep -q $'\033\[H\033\[2J'
    echo "$output" | /bin/grep -q $'\033\[32m'
}

@test "render: missing meta file errors with exit 2" {
    run python3 "$RENDER_PY" "/nonexistent-meta.json" --plain
    [ "$status" -eq 2 ]
}

@test "render: pipeline-running fixture shows running step" {
    run python3 "$RENDER_PY" "$FIXTURE_RUNNING" --plain
    [ "$status" -eq 0 ]
    echo "$output" | /bin/grep -q "Pipeline #999"
    echo "$output" | /bin/grep -q "backend-tests"
    echo "$output" | /bin/grep -q "running"
}

@test "render: with logs-dir shows progress + log tail" {
    /bin/cp "$FIXTURE_LOGS" "$TEST_DIR/9002.json"
    run python3 "$RENDER_PY" "$FIXTURE_RUNNING" --plain --logs-dir "$TEST_DIR"
    [ "$status" -eq 0 ]
    echo "$output" | /bin/grep -q "Progress: pytest"
    echo "$output" | /bin/grep -q "4521 pass"
    echo "$output" | /bin/grep -q "└─"
}

@test "render: stale state emits freeze warning" {
    local now stale
    now=$(/bin/date +%s)
    stale=$((now - 90))
    echo "{\"9002\": $stale}" > "$TEST_DIR/state.json"
    run python3 "$RENDER_PY" "$FIXTURE_RUNNING" --plain \
        --state "$TEST_DIR/state.json" --freeze-threshold 60
    [ "$status" -eq 0 ]
    echo "$output" | /bin/grep -q "frozen"
}

@test "render: fresh state silent (no freeze warning)" {
    local now
    now=$(/bin/date +%s)
    echo "{\"9002\": $now}" > "$TEST_DIR/state.json"
    run python3 "$RENDER_PY" "$FIXTURE_RUNNING" --plain \
        --state "$TEST_DIR/state.json" --freeze-threshold 60
    [ "$status" -eq 0 ]
    ! echo "$output" | /bin/grep -q "frozen"
}

# ─── pure parser unit tests via python subprocess ────────────────────

@test "parse_pytest: end summary 'N passed, M skipped, K failed'" {
    run python3 -c "
import sys; sys.path.insert(0, '$PLUGIN_ROOT/scripts/atlas-modules')
from ci_watch_render import parse_pytest
print(parse_pytest(['======= 6474 passed, 1321 skipped, 0 failed in 31s ======='])) "
    [ "$status" -eq 0 ]
    [ "$output" = "pytest 6474 pass, 1321 skip, 0 fail" ]
}

@test "parse_pytest: failed-before-passed ordering" {
    run python3 -c "
import sys; sys.path.insert(0, '$PLUGIN_ROOT/scripts/atlas-modules')
from ci_watch_render import parse_pytest
print(parse_pytest(['===== 4 failed, 6470 passed, 1321 skipped in 35s ====='])) "
    [ "$status" -eq 0 ]
    [ "$output" = "pytest 6470 pass, 1321 skip, 4 fail" ]
}

@test "parse_vitest: 'Tests N failed | M passed' format" {
    run python3 -c "
import sys; sys.path.insert(0, '$PLUGIN_ROOT/scripts/atlas-modules')
from ci_watch_render import parse_vitest
print(parse_vitest(['Tests  3 failed | 245 passed (248)'])) "
    [ "$status" -eq 0 ]
    [ "$output" = "vitest 245 pass, 3 fail" ]
}

@test "detect_freeze: stale > threshold returns warning string" {
    run python3 -c "
import sys; sys.path.insert(0, '$PLUGIN_ROOT/scripts/atlas-modules')
from ci_watch_render import detect_freeze
result = detect_freeze({'1718': 1000.0}, 1718, 60, 1100.0)
print(result if result else 'NONE') "
    [ "$status" -eq 0 ]
    echo "$output" | /bin/grep -q "frozen"
}

@test "detect_freeze: missing key returns None silently" {
    run python3 -c "
import sys; sys.path.insert(0, '$PLUGIN_ROOT/scripts/atlas-modules')
from ci_watch_render import detect_freeze
result = detect_freeze({}, 9999, 60, 1100.0)
print('NONE' if result is None else result) "
    [ "$status" -eq 0 ]
    [ "$output" = "NONE" ]
}

# ─── _atlas_ci_watch dispatcher (no real curl) ──────────────────────

@test "_atlas_ci_watch: --help shows usage and returns 0" {
    run _atlas_ci_watch --help
    [ "$status" -eq 0 ]
    echo "$output" | /bin/grep -q "Usage: atlas ci watch"
    echo "$output" | /bin/grep -q -- "--live"
}

@test "_atlas_ci_watch: no args returns 1 with usage" {
    run _atlas_ci_watch
    [ "$status" -eq 1 ]
    echo "$output" | /bin/grep -q "Usage: atlas ci watch"
}

@test "_atlas_ci_watch: -h short alias works without token" {
    run _atlas_ci_watch -h
    [ "$status" -eq 0 ]
    echo "$output" | /bin/grep -q -- "--freeze-threshold"
}

@test "module: _ATLAS_CI_RENDER_PY resolves to existing file" {
    [ -f "$_ATLAS_CI_RENDER_PY" ]
}

@test "module: version bumped to 5.18.0" {
    [ "$_ATLAS_CI_MODULE_VERSION" = "5.18.0" ]
}
