#!/usr/bin/env bats
# tests/bats/test-atlas-devportal.bats — Unit tests for the devportal module
#
# Tests are hermetic: each test uses a temp HOME, stub curl, and stub python3
# so no real network calls are made.

DEVPORTAL_MOD="$BATS_TEST_DIRNAME/../../scripts/atlas-modules/devportal.sh"
UI_MOD="$BATS_TEST_DIRNAME/../../scripts/atlas-modules/ui.sh"

# Minimal stubs for modules that devportal.sh depends on (ATLAS_BOLD etc.)
setup() {
  TEST_HOME=$(mktemp -d)
  export HOME="$TEST_HOME"
  mkdir -p "$TEST_HOME/.atlas"

  STUB_BIN=$(mktemp -d)
  export PATH="$STUB_BIN:$PATH"
  export DEVPORTAL_TOKEN="test-token-stub"
  export DEVPORTAL_URL="http://stub-devportal"

  # Stub curl — prints $STUB_CURL_OUTPUT or exits non-zero if STUB_CURL_FAIL=1
  cat > "$STUB_BIN/curl" <<'EOF'
#!/usr/bin/env bash
[ "${STUB_CURL_FAIL:-0}" = "1" ] && exit 1
default='{}'
echo "${STUB_CURL_OUTPUT:-$default}"
EOF
  chmod +x "$STUB_BIN/curl"

  # Minimal color vars so module sources without error
  export ATLAS_BOLD="" ATLAS_RESET="" ATLAS_DIM="" ATLAS_CYAN="" ATLAS_GREEN="" ATLAS_YELLOW="" ATLAS_RED=""

  # Source the module under test
  # shellcheck source=/dev/null
  source "$DEVPORTAL_MOD"
}

teardown() {
  rm -rf "$TEST_HOME" "$STUB_BIN"
  unset DEVPORTAL_TOKEN DEVPORTAL_URL STUB_CURL_OUTPUT STUB_CURL_FAIL
  unset ATLAS_BOLD ATLAS_RESET ATLAS_DIM ATLAS_CYAN ATLAS_GREEN ATLAS_YELLOW ATLAS_RED
}

# ─── _dp_token ────────────────────────────────────────────────

@test "_dp_token: returns env var when DEVPORTAL_TOKEN set" {
  export DEVPORTAL_TOKEN="my-secret"
  run _dp_token
  [ "$status" -eq 0 ]
  [ "$output" = "my-secret" ]
}

@test "_dp_token: reads from credentials.json when env unset" {
  unset DEVPORTAL_TOKEN
  mkdir -p "$TEST_HOME/.atlas"
  printf '{"token":"creds-token"}' > "$TEST_HOME/.atlas/credentials.json"
  run _dp_token
  [ "$status" -eq 0 ]
  [ "$output" = "creds-token" ]
}

@test "_dp_token: returns empty when no env and no credentials file" {
  unset DEVPORTAL_TOKEN
  run _dp_token
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

# ─── _dp_plan_list ────────────────────────────────────────────

@test "_dp_plan_list: renders table header on success" {
  export STUB_CURL_OUTPUT='{"items":[{"id":"SP-17","title":"DevPortal V1","status":"active","effort":"30h","phase":"G0","sprint":""}]}'
  run _dp_plan_list
  [ "$status" -eq 0 ]
  [[ "$output" == *"PLANS"* ]]
  [[ "$output" == *"SP-17"* ]]
  [[ "$output" == *"DevPortal V1"* ]]
}

@test "_dp_plan_list: --json flag outputs raw JSON" {
  export STUB_CURL_OUTPUT='{"items":[]}'
  run _dp_plan_list --json
  [ "$status" -eq 0 ]
  # JSON mode → output should look like JSON
  [[ "$output" == *"items"* ]]
}

@test "_dp_plan_list: fails gracefully when not authenticated" {
  unset DEVPORTAL_TOKEN
  run _dp_plan_list
  # Non-zero exit: curl fails (no token → error message to stderr, status 1)
  [ "$status" -ne 0 ]
  # Verify the stderr message appears via $stderr (bats 1.5+ with --separate-stderr)
  # or just verify status is non-zero (sufficient for CLI contract)
}

@test "_dp_plan_list: filters --phase and --sprint via query string" {
  export STUB_CURL_OUTPUT='{"items":[]}'
  # Capture the curl call to verify qs params are passed
  cat > "$STUB_BIN/curl" <<'EOF'
#!/usr/bin/env bash
# Record args for inspection
echo "$@" >> "$HOME/.atlas/curl-calls.log"
echo '{"items":[]}'
EOF
  chmod +x "$STUB_BIN/curl"
  run _dp_plan_list --phase G3 --sprint SP-17
  [ "$status" -eq 0 ]
  grep -q "phase=G3" "$TEST_HOME/.atlas/curl-calls.log"
  grep -q "sprint=SP-17" "$TEST_HOME/.atlas/curl-calls.log"
}

# ─── _dp_plan_show ────────────────────────────────────────────

@test "_dp_plan_show: prints JSON for valid plan-id" {
  export STUB_CURL_OUTPUT='{"id":"SP-17","title":"DevPortal V1","status":"active"}'
  run _dp_plan_show "SP-17"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SP-17"* ]]
}

@test "_dp_plan_show: fails with usage when no plan-id given" {
  run _dp_plan_show
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}

# ─── _dp_plan_claim ───────────────────────────────────────────

@test "_dp_plan_claim: accepts plan-id/task-id format" {
  export STUB_CURL_OUTPUT='{"status":"claimed"}'
  run _dp_plan_claim "SP-17/T-001"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Claimed"* ]]
}

@test "_dp_plan_claim: fails with usage when no argument given" {
  run _dp_plan_claim
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "_dp_plan_claim: fails when no slash separator in argument" {
  run _dp_plan_claim "SP-17"
  # When plan-id and task-id are same (no slash), function returns non-zero
  [ "$status" -ne 0 ]
  # Error text goes to stderr; just verify non-zero exit is sufficient
}

# ─── _dp_adr_list ─────────────────────────────────────────────

@test "_dp_adr_list: renders table with entries" {
  export STUB_CURL_OUTPUT='{"items":[{"id":"ADR-007","status":"accepted","title":"Skill Triggering Eval","date":"2026-04-19"}]}'
  run _dp_adr_list
  [ "$status" -eq 0 ]
  [[ "$output" == *"ADRs"* ]]
  [[ "$output" == *"ADR-007"* ]]
}

@test "_dp_adr_list: --status filter passed to API" {
  export STUB_CURL_OUTPUT='{"items":[]}'
  cat > "$STUB_BIN/curl" <<'EOF'
#!/usr/bin/env bash
echo "$@" >> "$HOME/.atlas/curl-calls.log"
echo '{"items":[]}'
EOF
  chmod +x "$STUB_BIN/curl"
  run _dp_adr_list --status accepted
  [ "$status" -eq 0 ]
  grep -q "status=accepted" "$TEST_HOME/.atlas/curl-calls.log"
}

# ─── _atlas_devportal_cmd dispatch ────────────────────────────

@test "_atlas_devportal_cmd: help flag prints usage" {
  run _atlas_devportal_cmd --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"atlas devportal"* ]]
}

@test "_atlas_devportal_cmd: unknown subcommand returns error" {
  run _atlas_devportal_cmd unknowncmd
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown devportal subcommand"* ]]
}

@test "_atlas_devportal_cmd: 'plan' dispatches to plan list" {
  export STUB_CURL_OUTPUT='{"items":[]}'
  run _atlas_devportal_cmd plan list
  [ "$status" -eq 0 ]
  [[ "$output" == *"PLANS"* ]]
}

@test "_atlas_devportal_cmd: 'roadmap' dispatches to roadmap" {
  export STUB_CURL_OUTPUT='{"phases":[]}'
  run _atlas_devportal_cmd roadmap
  [ "$status" -eq 0 ]
  [[ "$output" == *"ROADMAP"* ]]
}

# ─── _dp_catalog_cmd ──────────────────────────────────────────

@test "_dp_catalog_list: renders catalog table" {
  export STUB_CURL_OUTPUT='{"items":[{"name":"PT-101","kind":"instrument","description":"Pressure transmitter"}]}'
  run _dp_catalog_list
  [ "$status" -eq 0 ]
  [[ "$output" == *"CATALOG"* ]]
  [[ "$output" == *"PT-101"* ]]
}

@test "_dp_catalog_search: fails with usage when no query" {
  run _dp_catalog_search
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "_dp_catalog_show: fails with usage when no arg" {
  run _dp_catalog_show
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}
