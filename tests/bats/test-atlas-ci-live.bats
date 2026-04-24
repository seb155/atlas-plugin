#!/usr/bin/env bats
# tests/bats/test-atlas-ci-live.bats — Unit tests for atlas ci live subcommand
#
# Hermetic: temp HOME, stub curl/python3/date — no real network calls.
# Coverage: arg parsing, token loading, mocked API responses, icon rendering.

CI_MOD="$BATS_TEST_DIRNAME/../../scripts/atlas-modules/ci.sh"

setup() {
  TEST_HOME=$(mktemp -d)
  export HOME="$TEST_HOME"

  STUB_BIN=$(mktemp -d)
  export PATH="$STUB_BIN:$PATH"

  # Default token in env
  export WP_TOKEN="stub-token"
  export _ATLAS_CI_URL="https://stub-ci.example.com"
  export _ATLAS_CI_REPO_ID="1"
  # Use PATH-based curl stub (overrides /usr/bin/curl absolute path)
  export _ATLAS_CI_CURL_BIN="$STUB_BIN/curl"

  # Stub sleep to no-op (prevents real waiting)
  cat > "$STUB_BIN/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$STUB_BIN/sleep"

  # Write default curl stub (success pipeline)
  _write_curl_stub '[{"number":856,"status":"running","branch":"main","commit":"50ed6179","message":"fix(prod): deploy","event":"push","started":1714000000}]'

  # Source module
  set +euo pipefail
  # shellcheck source=/dev/null
  source "$CI_MOD" 2>/dev/null || true
  set -euo pipefail
}

teardown() {
  rm -rf "$TEST_HOME" "$STUB_BIN"
}

# Helper: write a curl stub that echoes a fixed body to stdout
_write_curl_stub() {
  local body="$1"
  # Write body to a temp file the stub reads (avoids quoting issues)
  local body_file="$STUB_BIN/.curl_body"
  printf '%s' "$body" > "$body_file"
  cat > "$STUB_BIN/curl" <<EOF
#!/usr/bin/env bash
cat "$body_file"
EOF
  chmod +x "$STUB_BIN/curl"
}

# ─── Tests: help flag ────────────────────────────────────────────

@test "atlas ci live --help exits 0 and shows usage" {
  run _atlas_ci_live --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Real-time Woodpecker CI dashboard"* ]]
}

@test "atlas ci live -h shows environment variables section" {
  run _atlas_ci_live -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"WP_TOKEN"* ]]
  [[ "$output" == *"ATLAS_CI_URL"* ]]
}

# ─── Tests: token loading ────────────────────────────────────────

@test "atlas ci live fails with clear message when WP_TOKEN missing" {
  unset WP_TOKEN
  run _atlas_ci_load_token
  [ "$status" -ne 0 ]
  [[ "${output}${lines[*]}" == *"WP_TOKEN"* ]]
}

@test "atlas ci live loads WP_TOKEN from ~/.env when not in env" {
  unset WP_TOKEN
  echo 'WP_TOKEN=loaded-from-env-file' > "$HOME/.env"
  run _atlas_ci_load_token
  [ "$status" -eq 0 ]
}

# ─── Tests: unknown option ───────────────────────────────────────

@test "atlas ci live rejects unknown option with non-zero exit" {
  run _atlas_ci_live --bogus-flag
  [ "$status" -ne 0 ]
}

# ─── Tests: --once mode (snapshot) ──────────────────────────────

@test "atlas ci live --once exits 0 with valid pipeline list" {
  _write_curl_stub '[{"number":856,"status":"success","branch":"main","commit":"abc12345","message":"chore: update deps","event":"push","started":1714000000}]'
  run _atlas_ci_live --once
  [ "$status" -eq 0 ]
}

@test "atlas ci live --once output contains pipeline number" {
  _write_curl_stub '[{"number":999,"status":"success","branch":"feature/test","commit":"deadbeef","message":"test commit","event":"push","started":1714000000}]'
  run _atlas_ci_live --once
  [ "$status" -eq 0 ]
  [[ "$output" == *"999"* ]]
}

@test "atlas ci live --once output contains success icon (✅) for success pipeline" {
  _write_curl_stub '[{"number":100,"status":"success","branch":"main","commit":"aabbccdd","message":"feat: done","event":"push","started":1714000000}]'
  run _atlas_ci_live --once
  [ "$status" -eq 0 ]
  # ✅ icon is rendered for success status
  [[ "$output" == *"✅"* ]]
}

@test "atlas ci live --once output contains failure icon (❌) for failed pipeline" {
  _write_curl_stub '[{"number":101,"status":"failure","branch":"main","commit":"baddcafe","message":"broken build","event":"push","started":1714000000}]'
  run _atlas_ci_live --once
  [ "$status" -eq 0 ]
  # ❌ icon is rendered for failure status
  [[ "$output" == *"❌"* ]]
}

@test "atlas ci live --once output contains 'running' for running pipeline" {
  _write_curl_stub '[{"number":200,"status":"running","branch":"main","commit":"cafebabe","message":"ci: running now","event":"push","started":1714000000}]'
  run _atlas_ci_live --once
  [ "$status" -eq 0 ]
  [[ "$output" == *"running"* ]]
}

# ─── Tests: dispatcher integration ──────────────────────────────

@test "atlas ci live subcommand dispatched correctly from _atlas_ci_cmd" {
  run _atlas_ci_cmd live --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Real-time Woodpecker CI dashboard"* ]]
}

# ─── Tests: API error handling ───────────────────────────────────

@test "atlas ci live --once returns error when API returns HTML (SPA fallback)" {
  local html_body="<!DOCTYPE html><html><body>SPA</body></html>"
  local body_file="$STUB_BIN/.curl_body"
  printf '%s' "$html_body" > "$body_file"
  cat > "$STUB_BIN/curl" <<CURLEOF
#!/usr/bin/env bash
cat "$body_file"
CURLEOF
  chmod +x "$STUB_BIN/curl"
  export _ATLAS_CI_CURL_BIN="$STUB_BIN/curl"
  run _atlas_ci_live --once
  [ "$status" -ne 0 ]
}

@test "atlas ci live --once branch name appears in output" {
  _write_curl_stub '[{"number":777,"status":"success","branch":"feature/my-branch","commit":"f00dcafe","message":"feat: new stuff","event":"pr","started":1714000000}]'
  run _atlas_ci_live --once
  [ "$status" -eq 0 ]
  [[ "$output" == *"feature/my-branch"* ]]
}
