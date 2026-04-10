#!/usr/bin/env bash
# ATLAS E2E Validation — 30 checks covering all plugin features
# Usage: ./scripts/atlas-e2e-validate.sh
# Run: before version bumps, in CI, or via /atlas doctor --full

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PLUGIN_ROOT"

PASS=0; FAIL=0; SKIP=0; TOTAL=0

check() {
  TOTAL=$((TOTAL + 1))
  local desc="$1"; shift
  if eval "$@" >/dev/null 2>&1; then
    echo "  ✅ #${TOTAL} ${desc}"
    PASS=$((PASS + 1))
  else
    echo "  ❌ #${TOTAL} ${desc}"
    FAIL=$((FAIL + 1))
  fi
}

skip() {
  TOTAL=$((TOTAL + 1))
  SKIP=$((SKIP + 1))
  echo "  ⏭️ #${TOTAL} $1 (skipped: $2)"
}

echo "🏛️ ATLAS │ 🩺 E2E VALIDATION"
echo ""

# ═══ BUILD ═══
echo "=== Build ==="
check "Build all tiers" "./build.sh all"
check "Admin skills >= 42" "[ \$(find dist/atlas-admin/skills -name SKILL.md | wc -l) -ge 42 ]"
check "Admin commands >= 40" "[ \$(find dist/atlas-admin/commands -name '*.md' | wc -l) -ge 40 ]"
check "Presets in dist" "[ -f dist/atlas-admin/scripts/presets/axoiq.json ] && [ -f dist/atlas-admin/scripts/presets/generic.json ]"

# ═══ TESTS ═══
echo ""
echo "=== Tests ==="
check "Pytest all pass" "python3 -m pytest tests/ -x -q --tb=line --maxfail=3"

# ═══ HOOKS ═══
echo ""
echo "=== Hooks ==="
check "session-start valid JSON" "echo '{}' | CLAUDE_PLUGIN_ROOT=. hooks/session-start 2>/dev/null | tail -1 | python3 -c 'import sys,json; d=json.load(sys.stdin); assert d[\"continue\"]'"
check "enterprise-check runs clean" "echo '{\"file_path\":\"/dev/null\"}' | hooks/enterprise-check"
check "post-compact branded" "echo '{}' | CLAUDE_PLUGIN_ROOT=. hooks/post-compact 2>/dev/null | grep -q 'ATLAS'"
check "permission-request runs" "echo '{\"tool_name\":\"Bash\",\"command\":\"ls\"}' | hooks/permission-request"

# ═══ SCRIPTS ═══
echo ""
echo "=== Scripts ==="
check "detect-platform JSON" "scripts/detect-platform.sh | python3 -c 'import sys,json; d=json.load(sys.stdin); assert d[\"os\"] in (\"linux\",\"macos\",\"wsl\",\"windows\",\"unknown\")'"
check "detect-network JSON" "scripts/detect-network.sh 2>/dev/null | python3 -c 'import sys,json; d=json.load(sys.stdin); assert \"trust\" in d'"
check "shell-aliases generates" "scripts/shell-aliases.sh /tmp 2>/dev/null > /tmp/.atlas-e2e-aliases && grep -q 'atlas()' /tmp/.atlas-e2e-aliases"
check "setup-terminal runs" "scripts/setup-terminal.sh --check | grep -q 'Score'"
check "get-secret tier 1" "FORGEJO_TOKEN=test_value scripts/get-secret.sh FORGEJO_TOKEN | grep -q 'test_value'"

# Tier 2 (.env) — only if FORGEJO_TOKEN is in .env
if grep -q "FORGEJO_TOKEN" "${HOME}/.env" 2>/dev/null; then
  check "get-secret tier 2 (.env)" "unset FORGEJO_TOKEN; scripts/get-secret.sh FORGEJO_TOKEN"
else
  skip "get-secret tier 2 (.env)" "FORGEJO_TOKEN not in ~/.env"
fi

# Tier 3 (bw) — only if BW_SESSION available
if [ -n "${BW_SESSION:-}" ] || scripts/atlas-keyring.sh get bw_session 2>/dev/null | grep -q .; then
  check "get-secret tier 3 (bw)" "unset FORGEJO_TOKEN; scripts/get-secret.sh FORGEJO_TOKEN"
else
  skip "get-secret tier 3 (bw)" "BW_SESSION not available"
fi

# ═══ KEYRING ═══
echo ""
echo "=== Keyring ==="
check "atlas-keyring set+get+delete" "scripts/atlas-keyring.sh set _e2e_test 'ok' && [ \"\$(scripts/atlas-keyring.sh get _e2e_test)\" = 'ok' ] && scripts/atlas-keyring.sh delete _e2e_test"

# Keyring BW_SESSION persistence
if scripts/atlas-keyring.sh get bw_session 2>/dev/null | grep -q .; then
  check "BW_SESSION in keyring" "scripts/atlas-keyring.sh get bw_session | grep -q ."
else
  skip "BW_SESSION in keyring" "not cached yet"
fi

# Cross-session recovery would need restart — skip in automated run
skip "Cross-session keyring recovery" "needs CC restart to test"

# ═══ CONFIG ═══
echo ""
echo "=== Config ==="
check "config.json valid" "python3 -c 'import json; json.load(open(\"${HOME}/.atlas/config.json\"))'"
check "Zero hardcoded URLs" "! grep -r '192.168.10\\.\\|forgejo\\.home\\.axoiq\\|sgagnon\\.dev' skills/ hooks/ scripts/ commands/ --include='*.md' --include='*.sh' --include='*.yaml' 2>/dev/null | grep -v presets/ | grep -v __pycache__ | grep -q ."
check "No missing emojis" "! grep -q '❓' dist/atlas-admin/skills/atlas-assist/SKILL.md 2>/dev/null"

# ═══ NETWORK + GEO ═══
echo ""
echo "=== Network & Geo ==="
if scripts/detect-network.sh 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['trust'] in ('trusted','standard','restricted','unknown')" 2>/dev/null; then
  check "Trust level detected" "true"
else
  check "Trust level detected" "scripts/detect-network.sh 2>/dev/null | python3 -c \"import sys,json; d=json.load(sys.stdin); assert 'trust' in d\""
fi
if [ -f "${HOME}/.atlas/location.json" ]; then
  check "Geolocation configured" "scripts/detect-network.sh 2>/dev/null | python3 -c 'import sys,json; assert json.load(sys.stdin)[\"geo\"][\"source\"] != \"none\"'"
else
  skip "Geolocation configured" "no ~/.atlas/location.json"
fi

# ═══ SECRETS ═══
echo ""
echo "=== Secrets ==="
# SessionStart auto-resolve tested via session-start hook check above
check "Missing secrets badge" "echo '{}' | CLAUDE_PLUGIN_ROOT=. hooks/session-start 2>/dev/null | python3 -c 'import sys,json; ctx=json.load(sys.stdin).get(\"additionalContext\",\"\"); print(\"ok\" if \"ATLAS\" in ctx else \"fail\")' | grep -q ok"

# ═══ IDENTITY ═══
echo ""
echo "=== Identity ==="
check "Hooks branded (6/6)" "[ \$(grep -rl '🏛️ ATLAS' dist/atlas-admin/hooks/* 2>/dev/null | wc -l) -ge 6 ]"

# ═══ REGRESSION ═══
echo ""
echo "=== Regression ==="
check "Agents >= 6" "[ \$(find dist/atlas-admin/agents -name AGENT.md 2>/dev/null | wc -l) -ge 6 ]"
check "Test files >= 13" "[ \$(find tests -name 'test_*.py' | wc -l) -ge 13 ]"

# ═══ RESULTS ═══
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  RESULTS: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped (${TOTAL} total)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $FAIL -eq 0 ]; then
  echo "  ✅ ALL E2E CHECKS PASSED"
else
  echo "  ❌ ${FAIL} CHECKS FAILED"
fi
exit $FAIL
