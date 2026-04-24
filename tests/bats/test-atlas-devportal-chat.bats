#!/usr/bin/env bats
# tests/bats/test-atlas-devportal-chat.bats — Unit tests for devportal chat subcommand
#
# Hermetic: temp HOME, stub curl/python3 — no real network calls.

DEVPORTAL_MOD="$BATS_TEST_DIRNAME/../../scripts/atlas-modules/devportal.sh"

setup() {
  TEST_HOME=$(mktemp -d)
  export HOME="$TEST_HOME"
  mkdir -p "$TEST_HOME/.atlas"

  STUB_BIN=$(mktemp -d)
  export PATH="$STUB_BIN:$PATH"

  # Default: authenticated
  export ATLAS_TOKEN="stub-atlas-token"
  export DEVPORTAL_URL="http://stub-devportal"
  unset ATLAS_ENV

  # Stub curl — default: simulate 200 with SSE response
  # STUB_CURL_STATUS controls HTTP status code (-w %{http_code})
  # STUB_CURL_BODY controls body written to -o file
  cat > "$STUB_BIN/curl" <<'CURLEOF'
#!/usr/bin/env bash
# Parse -o <file> and -w from args to mimic curl -o FILE -w %{http_code}
out_file=""
for i in "$@"; do
  if [ "${prev_arg:-}" = "-o" ]; then out_file="$i"; fi
  prev_arg="$i"
done
body="${STUB_CURL_BODY:-}"
status="${STUB_CURL_STATUS:-200}"
if [ -n "$out_file" ]; then
  printf "%s" "$body" > "$out_file"
fi
printf "%s" "$status"
echo "$@" >> "$HOME/.atlas/curl-calls.log"
CURLEOF
  chmod +x "$STUB_BIN/curl"

  # Minimal color vars
  export ATLAS_BOLD="" ATLAS_RESET="" ATLAS_DIM="" ATLAS_CYAN="" ATLAS_GREEN="" ATLAS_YELLOW="" ATLAS_RED=""

  # Source module under test
  # shellcheck source=/dev/null
  source "$DEVPORTAL_MOD"
}

teardown() {
  rm -rf "$TEST_HOME" "$STUB_BIN"
  unset ATLAS_TOKEN DEVPORTAL_URL ATLAS_ENV STUB_CURL_STATUS STUB_CURL_BODY
  unset ATLAS_BOLD ATLAS_RESET ATLAS_DIM ATLAS_CYAN ATLAS_GREEN ATLAS_YELLOW ATLAS_RED
}

# ─── Arg parsing ──────────────────────────────────────────────

@test "_dp_chat_cmd: missing query returns error and usage hint" {
  run _dp_chat_cmd
  [ "$status" -ne 0 ]
  [[ "$output" == *"Query required"* ]] || [[ "$output" == *"Usage"* ]]
}

@test "_dp_chat_cmd: --help prints usage" {
  run _dp_chat_cmd --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"atlas dp chat"* ]]
  [[ "$output" == *"Usage"* ]] || [[ "$output" == *"query"* ]] || [[ "$output" == *"Examples"* ]]
}

@test "_dp_chat_cmd: valid query passes query to _dp_chat_stream" {
  # Override _dp_chat_stream to capture the query without network
  _dp_chat_stream() { echo "CALLED:$*"; }
  run _dp_chat_cmd "show me all SP plans for G3"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CALLED:show me all SP plans for G3"* ]]
}

# ─── Env var resolution ───────────────────────────────────────

@test "_dp_chat_base_url: defaults to prod URL when ATLAS_ENV not set" {
  unset ATLAS_ENV DEVPORTAL_URL
  run _dp_chat_base_url
  [ "$status" -eq 0 ]
  [[ "$output" == "https://synapse.axoiq.com" ]]
}

@test "_dp_chat_base_url: returns localhost when ATLAS_ENV=dev" {
  unset DEVPORTAL_URL
  export ATLAS_ENV=dev
  run _dp_chat_base_url
  [ "$status" -eq 0 ]
  [[ "$output" == "http://localhost:8001" ]]
}

@test "_dp_chat_base_url: DEVPORTAL_URL override takes priority over ATLAS_ENV" {
  export DEVPORTAL_URL="http://my-custom-host:9999"
  export ATLAS_ENV=dev
  run _dp_chat_base_url
  [ "$status" -eq 0 ]
  [[ "$output" == "http://my-custom-host:9999" ]]
}

@test "_dp_chat_token: ATLAS_TOKEN takes priority over DEVPORTAL_TOKEN" {
  export ATLAS_TOKEN="atlas-primary-token"
  export DEVPORTAL_TOKEN="devportal-secondary-token"
  run _dp_chat_token
  [ "$status" -eq 0 ]
  [ "$output" = "atlas-primary-token" ]
}

@test "_dp_chat_token: falls back to DEVPORTAL_TOKEN when ATLAS_TOKEN unset" {
  unset ATLAS_TOKEN
  export DEVPORTAL_TOKEN="dp-fallback-token"
  run _dp_chat_token
  [ "$status" -eq 0 ]
  [ "$output" = "dp-fallback-token" ]
}

# ─── Stream parsing ───────────────────────────────────────────

@test "_dp_chat_render_sse: renders token events as concatenated text" {
  local sse_file
  sse_file=$(mktemp)
  printf "event: token\ndata: Hello\n\nevent: token\ndata:  world\n\nevent: done\ndata: \n\n" > "$sse_file"
  run _dp_chat_render_sse "$sse_file"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hello"* ]]
  [[ "$output" == *"world"* ]]
  rm -f "$sse_file"
}

@test "_dp_chat_render_sse: renders tool_call events indented" {
  local sse_file
  sse_file=$(mktemp)
  printf 'event: tool_call\ndata: {"tool":"devportal.list_plans","args":{"phase":"G3"}}\n\n' > "$sse_file"
  run _dp_chat_render_sse "$sse_file"
  [ "$status" -eq 0 ]
  [[ "$output" == *"devportal.list_plans"* ]]
  rm -f "$sse_file"
}

# ─── Fallback mode ────────────────────────────────────────────

@test "_dp_chat_stream: triggers fallback when endpoint returns 404" {
  export STUB_CURL_STATUS="404"
  export STUB_CURL_BODY=""
  # Override fallback to verify it's called
  _dp_chat_fallback_search() { echo "FALLBACK_CALLED:$1"; }
  run _dp_chat_stream "find plans for G3"
  [[ "$output" == *"FALLBACK_CALLED:find plans for G3"* ]] \
    || [[ "$output" == *"fallback"* ]] \
    || [[ "$output" == *"FALLBACK"* ]]
}

@test "_dp_chat_stream: returns error on non-200 non-404 status" {
  export STUB_CURL_STATUS="500"
  export STUB_CURL_BODY='{"detail":"internal error"}'
  run _dp_chat_stream "test query"
  [ "$status" -ne 0 ]
}

# ─── Dispatch ─────────────────────────────────────────────────

@test "_atlas_devportal_cmd: 'chat' subcommand dispatches to _dp_chat_cmd" {
  _dp_chat_cmd() { echo "CHAT_DISPATCHED:$*"; }
  run _atlas_devportal_cmd chat "my query"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CHAT_DISPATCHED:my query"* ]]
}

@test "_atlas_devportal_cmd: 'c' alias dispatches to _dp_chat_cmd" {
  _dp_chat_cmd() { echo "ALIAS_C_DISPATCHED:$*"; }
  run _atlas_devportal_cmd c "my query"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ALIAS_C_DISPATCHED:my query"* ]]
}

@test "_dp_help: includes 'chat' in help output" {
  run _dp_help
  [ "$status" -eq 0 ]
  [[ "$output" == *"chat"* ]]
}
