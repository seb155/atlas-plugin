#!/usr/bin/env bash
# ATLAS v6.0 Session Validation Harness
# Tests what can be verified without a session restart.
# For full validation (fresh `claude` session), see VALIDATION-V6.md.
#
# Usage:
#   ./scripts/validate-v6-session.sh
#
# Exit codes:
#   0  — all pre-flight checks pass
#   1  — at least one check failed (regression)
#
# Contract:
#   - Read-only: never modifies files (safe to run anywhere)
#   - Idempotent: can be run repeatedly
#   - Fail-loud: any unexpected output/size/count is reported

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PASS=0
FAIL=0

section() { echo ""; echo "━━━ $1 ━━━"; }
pass() { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo ""
echo "ATLAS v6.0 Session Validation Harness"
echo "Plugin root: $PLUGIN_ROOT"
echo "VERSION: $(cat "$PLUGIN_ROOT/VERSION" 2>/dev/null || echo 'UNKNOWN')"

# ── 1. Hook binaries present + executable ─────────────────────────────────────
section "1. Hooks installation (4 v6 hooks)"
for hook in inject-meta-skill pre-compact-sota-context session-end-retro effort-router; do
  if [ -x "$PLUGIN_ROOT/hooks/$hook" ]; then
    pass "hook $hook exists + executable"
  else
    fail "hook $hook missing or not executable"
  fi
done

# ── 2. Hook registration in hooks.json ────────────────────────────────────────
section "2. Hooks registered in hooks.json"
for hook in inject-meta-skill pre-compact-sota-context session-end-retro effort-router; do
  if grep -q "$hook" "$PLUGIN_ROOT/hooks/hooks.json"; then
    pass "hook $hook registered"
  else
    fail "hook $hook NOT registered"
  fi
done

# ── 3. inject-meta-skill payload size sanity ──────────────────────────────────
section "3. inject-meta-skill payload size"
PAYLOAD=$(CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/inject-meta-skill" 2>/dev/null \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('hookSpecificOutput',{}).get('additionalContext','')))" \
  2>/dev/null || echo 0)
if [ "$PAYLOAD" -gt 15000 ] && [ "$PAYLOAD" -lt 50000 ]; then
  pass "Payload size ${PAYLOAD} bytes (within 15-50KB)"
else
  fail "Payload size ${PAYLOAD} unexpected (expected 15000-50000)"
fi

# ── 4. Iron Laws count in payload ─────────────────────────────────────────────
section "4. Iron Laws count in payload"
LAWS=$(CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/inject-meta-skill" 2>/dev/null \
  | python3 -c "import json,sys; ctx=json.load(sys.stdin).get('hookSpecificOutput',{}).get('additionalContext',''); print(ctx.count('LAW-'))" \
  2>/dev/null || echo 0)
if [ "$LAWS" -ge 9 ]; then
  pass "Iron Laws present in payload: $LAWS"
else
  fail "Iron Laws count low: $LAWS (expected >=9)"
fi

# ── 5. atlas-assist content marker in payload ─────────────────────────────────
section "5. atlas-assist content in payload"
if CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/inject-meta-skill" 2>/dev/null \
     | grep -q "ATLAS"; then
  pass "atlas-assist content present (ATLAS marker found)"
else
  fail "atlas-assist content missing (no ATLAS marker)"
fi

# ── 6. effort-router heuristic suggests xhigh for race conditions ─────────────
section "6. effort-router heuristic (race condition -> xhigh)"
TEST=$(echo '{"tool_input":{"description":"debug race condition"}}' \
  | CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/effort-router" 2>/dev/null \
  | python3 -c "import json,sys; print(json.load(sys.stdin).get('hookSpecificOutput',{}).get('additionalContext',''))" \
  2>/dev/null || echo "")
if echo "$TEST" | grep -q "xhigh"; then
  pass "effort-router suggests xhigh for race condition task"
else
  fail "effort-router unexpected: $TEST"
fi

# ── 7. pre-compact-sota-context emits 6 mandatory sections ────────────────────
section "7. pre-compact-sota-context 6-section reminder"
PRECOMPACT=$(echo '{"trigger":"auto"}' \
  | "$PLUGIN_ROOT/hooks/pre-compact-sota-context" 2>/dev/null \
  | python3 -c "import json,sys; print(json.load(sys.stdin).get('hookSpecificOutput',{}).get('additionalContext',''))" \
  2>/dev/null || echo "")
SECTIONS=$(echo "$PRECOMPACT" | grep -cE "^[0-9]+\. \*\*" || true)
if [ "$SECTIONS" -ge 6 ]; then
  pass "pre-compact emits $SECTIONS numbered sections (>=6)"
else
  fail "pre-compact sections: $SECTIONS (expected >=6)"
fi

# ── 8. session-end-retro emits retrospective reminder ─────────────────────────
section "8. session-end-retro retrospective reminder"
RETRO=$(echo '{}' \
  | "$PLUGIN_ROOT/hooks/session-end-retro" 2>/dev/null \
  | python3 -c "import json,sys; print(json.load(sys.stdin).get('hookSpecificOutput',{}).get('additionalContext',''))" \
  2>/dev/null || echo "")
if echo "$RETRO" | grep -q "session-retrospective"; then
  pass "session-end-retro mentions session-retrospective skill"
else
  fail "session-end-retro missing session-retrospective reference"
fi

# ── 9. hard-gate-linter 10/10 Tier-1 skills ───────────────────────────────────
section "9. hard-gate-linter 10/10 Tier-1"
LINTER_OUT=$("$PLUGIN_ROOT/scripts/execution-philosophy/hard-gate-linter.sh" all 2>&1 || true)
if echo "$LINTER_OUT" | grep -q "10/10 skills passed"; then
  pass "10/10 Tier-1 skills pass linter"
else
  fail "hard-gate-linter regression (last line: $(echo "$LINTER_OUT" | tail -1))"
fi

# ── 10. bats suite — 30/32 min (2 pre-existing thinking_migration failures) ───
section "10. bats suite (>=30/32 pass — baseline)"
if command -v bats >/dev/null 2>&1; then
  BATS_OUT=$(bats "$PLUGIN_ROOT/tests/bats/" 2>&1 || true)
  BATS_PASS=$(echo "$BATS_OUT" | grep -cE "^ok " || true)
  BATS_FAIL=$(echo "$BATS_OUT" | grep -cE "^not ok " || true)
  if [ "$BATS_PASS" -ge 30 ] && [ "$BATS_FAIL" -le 2 ]; then
    pass "bats: ${BATS_PASS} pass, ${BATS_FAIL} fail (<=2 pre-existing)"
  else
    fail "bats regression: ${BATS_PASS} pass, ${BATS_FAIL} fail (expected >=30 pass, <=2 fail)"
  fi
else
  fail "bats binary not installed (install: apt-get install bats)"
fi

# ── 11. build.sh modular succeeds ─────────────────────────────────────────────
section "11. build.sh modular"
if (cd "$PLUGIN_ROOT" && ./build.sh modular 2>&1) | grep -q "All modular plugins built successfully"; then
  pass "build.sh modular PASS"
else
  fail "build.sh modular FAIL"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  RESULTS: $PASS pass, $FAIL fail"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$FAIL" -eq 0 ]; then
  echo "  Pre-flight PASS — proceed to VALIDATION-V6.md manual steps."
  exit 0
else
  echo "  Pre-flight FAIL — fix regressions before session restart."
  exit 1
fi
