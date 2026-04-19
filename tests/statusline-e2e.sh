#!/usr/bin/env bash
# tests/statusline-e2e.sh — End-to-end regression test for ATLAS status line.
#
# PURPOSE
#   Verifies the full status line pipeline produces
#     "🏛️ ATLAS X.Y.Z  …"
#   in stdout, where X.Y.Z matches the current VERSION file.
#
# This is the test that would have caught the regressions in v4.44.0, v5.0.2,
# v5.5.1, v5.30.0, and v5.30.1 — none existed before v5.36.0. Every prior
# "fix" shipped green unit tests but no E2E assertion on the final rendered
# output, so dotfiles-sync overwrites and settings.json/plugin drift slipped
# through repeatedly.
#
# MODES
#   (default) ci        Hermetic: isolates HOME in a tmp dir, deploys wrapper
#                       + resolver + statusline-command.sh from plugin source,
#                       skips `claude` CLI (Tier 1) via ATLAS_NO_CLAUDE=1.
#                       Intended for Woodpecker / Forgejo CI.
#
#   --local             Invokes the user's deployed wrapper at
#                       ~/.local/share/atlas-statusline/statusline-wrapper.sh.
#                       Intended for `atlas-doctor --statusline` and local
#                       sanity checks after a fresh session.
#
# EXIT
#   0 if output contains "🏛️ ATLAS <current-version>"
#   1 on any failure (with diagnostic on stderr)
#
# ADR: docs/ADR/ADR-019-statusline-sota-v2-unification.md

set -uo pipefail

MODE="${1:-ci}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXPECTED_VERSION=$(tr -d '[:space:]' < "$PLUGIN_ROOT/VERSION" 2>/dev/null)

if [ -z "$EXPECTED_VERSION" ]; then
  echo "FAIL: cannot read VERSION file at $PLUGIN_ROOT/VERSION" >&2
  exit 1
fi

# Minimal CC status-line JSON (covers all fields consumed by statusline-command.sh)
CC_JSON='{"workspace":{"current_dir":"/tmp"},"model":{"id":"claude-opus-4-7"},"context_window":{"used_percentage":0},"rate_limits":{"5h":{"used_percentage":0}},"effort":"high"}'

case "$MODE" in
  local|--local)
    WRAPPER="$HOME/.local/share/atlas-statusline/statusline-wrapper.sh"
    if [ ! -x "$WRAPPER" ]; then
      echo "FAIL: wrapper not deployed at $WRAPPER" >&2
      echo "  Hint: restart your Claude Code session to run the session-start deploy hook" >&2
      exit 1
    fi
    OUTPUT=$(printf '%s' "$CC_JSON" | "$WRAPPER")
    ;;

  ci|*)
    # `jq` is a hard runtime dep of the plugin's statusline-command.sh.
    # python:3.13-slim (Woodpecker l1-structural base) does not ship it.
    # Install transparently so the E2E can exercise the real rendering path.
    if ! command -v jq >/dev/null 2>&1; then
      if command -v apt-get >/dev/null 2>&1; then
        apt-get update -qq >/dev/null 2>&1 && \
          apt-get install -y -qq jq >/dev/null 2>&1 || \
          { echo "SKIP: jq not available and cannot be installed" >&2; exit 77; }
      else
        echo "SKIP: jq not available (required by statusline-command.sh)" >&2
        exit 77
      fi
    fi

    # Hermetic environment: tmp HOME, no `claude` CLI, copies from plugin source
    TEST_HOME=$(mktemp -d)
    trap 'rm -rf "$TEST_HOME"' EXIT
    export HOME="$TEST_HOME"

    mkdir -p "$TEST_HOME/.atlas/runtime"
    mkdir -p "$TEST_HOME/.local/share/atlas-statusline"
    CACHE="$TEST_HOME/.claude/plugins/cache/atlas-marketplace/atlas-core/$EXPECTED_VERSION/scripts"
    mkdir -p "$CACHE"

    # Deploy artifacts from plugin source
    cp "$PLUGIN_ROOT/scripts/atlas-resolve-version.sh" \
       "$TEST_HOME/.local/share/atlas-statusline/"
    cp "$PLUGIN_ROOT/scripts/statusline-wrapper.sh" \
       "$TEST_HOME/.local/share/atlas-statusline/"
    cp "$PLUGIN_ROOT/scripts/statusline-command.sh" "$CACHE/"
    chmod +x "$TEST_HOME/.local/share/atlas-statusline/"*.sh "$CACHE/statusline-command.sh"

    # Seed capabilities.json so resolver Tier 2 resolves without needing `claude` CLI
    cat > "$TEST_HOME/.atlas/runtime/capabilities.json" <<EOF
{"version":"$EXPECTED_VERSION","source":"fs"}
EOF

    # Bypass Tier 1 (CI runners typically don't have the CC CLI)
    export ATLAS_NO_CLAUDE=1 ATLAS_RESOLVE_NO_CACHE=1

    OUTPUT=$(printf '%s' "$CC_JSON" | \
      "$TEST_HOME/.local/share/atlas-statusline/statusline-wrapper.sh")
    ;;
esac

# Assertion: strict — must contain BOTH version marker AND model token.
# Weak assertion (only the version marker) was proven to pass on fallback
# strings like "🏛️ ATLAS 5.35.0  (statusline script missing at …)", defeating
# the purpose of the test. The double check forces real plugin-script exec.
EXPECTED_MARKER="🏛️ ATLAS $EXPECTED_VERSION"
EXPECTED_MODEL_TOKEN="opus"   # derived from CC_JSON model "claude-opus-4-7"

fail() {
  {
    echo "FAIL: $1"
    echo "  Mode:           $MODE"
    echo "  Expected:       '$EXPECTED_MARKER' AND '$EXPECTED_MODEL_TOKEN'"
    echo "  Actual output:  $OUTPUT"
    echo ""
    echo "  Debugging hints:"
    echo "    - Check VERSION file matches what the resolver returns"
    echo "    - For --local mode, verify ~/.claude/settings.json L110 points to"
    echo "      \$HOME/.local/share/atlas-statusline/statusline-wrapper.sh"
    echo "    - Fallback strings (e.g. '(script missing …)') indicate wrapper"
    echo "      could not exec the plugin-shipped statusline-command.sh"
    echo "    - Run: /atlas doctor --statusline for full deployment diagnostic"
  } >&2
}

if ! printf '%s' "$OUTPUT" | grep -qF "$EXPECTED_MARKER"; then
  fail "status line output did NOT contain version marker '$EXPECTED_MARKER'"
  exit 1
fi

# Check for fallback indicators that would match version marker but prove the
# plugin-shipped statusline-command.sh was NOT exec'd.
if printf '%s' "$OUTPUT" | grep -qF "(statusline script missing"; then
  fail "wrapper emitted 'script missing' fallback — plugin script not exec'd"
  exit 1
fi

if printf '%s' "$OUTPUT" | grep -qF "(version unresolvable"; then
  fail "wrapper emitted 'unresolvable' fallback — version resolution failed"
  exit 1
fi

# The full rendering must include the model token (proves plugin script ran
# against the CC_JSON input). Fallback strings never include this token.
if ! printf '%s' "$OUTPUT" | grep -qF "$EXPECTED_MODEL_TOKEN"; then
  fail "status line output did NOT contain model token '$EXPECTED_MODEL_TOKEN' — plugin script likely not exec'd"
  exit 1
fi

echo "PASS: status line contains '$EXPECTED_MARKER' + model token (mode: $MODE)"
exit 0
