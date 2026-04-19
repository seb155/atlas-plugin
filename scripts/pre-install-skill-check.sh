#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
# ATLAS — Pre-install skill security check (REC-015, ADR-013)
# Runs LichAmnesia/skill-lint against a skill URL or local path before
# allowing install. Exits with skill-lint's verdict codes.
#
# Usage:
#   ./pre-install-skill-check.sh <url-or-path> [--force-warn]
#
# Examples:
#   ./pre-install-skill-check.sh https://github.com/user/some-skill
#   ./pre-install-skill-check.sh ./local/skill-dir
#   ./pre-install-skill-check.sh https://github.com/user/some-skill --force-warn
#
# Exit codes:
#   0 = SAFE (install allowed)
#   1 = WARN (install requires --force-warn OR interactive approval)
#   2 = TOXIC (install blocked, never allowed)
#   3 = LINTER ERROR (network, missing deps, etc.)
#   4 = USAGE ERROR (bad arguments)
#
# Requirements:
#   - Node.js ≥20 (skill-lint engines requirement)
#   - npx (shipped with npm)
#   - jq OR python3 (for JSON parsing)
#
# Source: LichAmnesia/skill-lint v0.1.0+
# Reference: ADR-013-skill-lint-security-baseline.md
# ─────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Colors (no color if NO_COLOR or not TTY) ──
if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
  RED=''; YEL=''; GRN=''; BLU=''; BLD=''; RST=''
else
  RED=$'\033[31m'; YEL=$'\033[33m'; GRN=$'\033[32m'
  BLU=$'\033[34m'; BLD=$'\033[1m'; RST=$'\033[0m'
fi

# ── Usage ──
usage() {
  cat <<EOF
${BLD}pre-install-skill-check.sh${RST} — ATLAS skill security gate

Usage:
  $0 <url-or-path> [--force-warn] [--verbose]

Arguments:
  <url-or-path>    GitHub/Forgejo URL or local directory containing SKILL.md
  --force-warn     Accept WARN verdict (default: interactive prompt)
  --verbose, -v    Show full skill-lint JSON findings

Exit codes:
  0=SAFE  1=WARN  2=TOXIC  3=LINTER_ERROR  4=USAGE_ERROR

Reference: ADR-013-skill-lint-security-baseline.md
EOF
}

# ── Parse arguments ──
if [[ $# -lt 1 ]]; then
  usage
  exit 4
fi

TARGET="$1"
shift
FORCE_WARN=0
VERBOSE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force-warn) FORCE_WARN=1 ;;
    --verbose|-v) VERBOSE=1 ;;
    --help|-h) usage; exit 0 ;;
    *)
      echo "${RED}[error]${RST} unknown flag: $1" >&2
      usage
      exit 4
      ;;
  esac
  shift
done

# ── Preflight: tools ──
if ! command -v npx >/dev/null 2>&1; then
  echo "${RED}[error]${RST} npx not found. Install Node.js ≥20." >&2
  exit 3
fi

# Check Node version (skill-lint requires ≥20)
NODE_VER=$(node --version 2>/dev/null | sed 's/^v//' | cut -d. -f1)
if [[ -z "$NODE_VER" ]] || [[ "$NODE_VER" -lt 20 ]]; then
  echo "${RED}[error]${RST} Node.js ≥20 required (found: v${NODE_VER:-unknown})" >&2
  exit 3
fi

# JSON parser: prefer jq, fallback to python3
if command -v jq >/dev/null 2>&1; then
  JSON_PARSER="jq"
elif command -v python3 >/dev/null 2>&1; then
  JSON_PARSER="python3"
else
  echo "${RED}[error]${RST} neither jq nor python3 available for JSON parsing" >&2
  exit 3
fi

# ── Run skill-lint ──
echo "${BLU}[skill-lint]${RST} Scanning: ${BLD}${TARGET}${RST}"
echo "${BLU}[skill-lint]${RST} Tool: npx --yes skill-lint (LichAmnesia/skill-lint)"

TMP_OUT=$(mktemp)
trap 'rm -f "$TMP_OUT"' EXIT

# Run skill-lint. Default: vendored ATLAS fork at third_party/atlas-skill-lint
# (v0.2.0-atlas.1, see ADR-019b). This is the canonical scanner for ATLAS
# internal skills — tuned to recognize reasoning-agent SKILL.md as documentation
# and not to flag CLI placeholders + fenced shell examples as executable intent.
# To use the unmodified upstream or a different pinned version, set
#   SKILL_LINT_PACKAGE=github:LichAmnesia/skill-lint@v0.2.0
# or a tarball/git URL.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENDORED_PKG="${SCRIPT_DIR}/../third_party/atlas-skill-lint"
SKILL_LINT_PACKAGE="${SKILL_LINT_PACKAGE:-}"

set +e
if [[ -z "$SKILL_LINT_PACKAGE" ]] && [[ -d "$VENDORED_PKG" ]] && [[ -f "$VENDORED_PKG/bin/skill-lint.js" ]]; then
  # Fast path: run the vendored fork directly via node (no npx fork overhead,
  # no network, no npm-cache stale-tarball surprise).
  # Lazy-install the fork's 2 runtime deps (chalk, yaml) on first run so the
  # vendored dir can be committed without node_modules. Idempotent.
  if [[ ! -d "$VENDORED_PKG/node_modules" ]]; then
    (cd "$VENDORED_PKG" && npm install --silent --omit=dev --no-audit --no-fund >&2)
  fi
  node "$VENDORED_PKG/bin/skill-lint.js" "$TARGET" --json >"$TMP_OUT" 2>&1
else
  # Fallback: override via SKILL_LINT_PACKAGE env (git URL, tarball, or npm spec).
  SKILL_LINT_PACKAGE="${SKILL_LINT_PACKAGE:-github:LichAmnesia/skill-lint}"
  npx --yes "$SKILL_LINT_PACKAGE" "$TARGET" --json >"$TMP_OUT" 2>&1
fi
LINT_EXIT=$?
set -e

# ── Interpret output ──
if [[ "$LINT_EXIT" -eq 3 ]] || [[ ! -s "$TMP_OUT" ]]; then
  echo "${RED}[error]${RST} skill-lint failed (exit $LINT_EXIT):" >&2
  cat "$TMP_OUT" >&2
  exit 3
fi

# Parse verdict from JSON
case "$JSON_PARSER" in
  jq)
    VERDICT=$(jq -r '.verdict.label // "UNKNOWN"' "$TMP_OUT" 2>/dev/null || echo "UNKNOWN")
    SCORE=$(jq -r '.verdict.score // 0' "$TMP_OUT" 2>/dev/null || echo "0")
    FINDING_COUNT=$(jq -r '.findings | length' "$TMP_OUT" 2>/dev/null || echo "0")
    ;;
  python3)
    VERDICT=$(python3 -c "import json,sys; d=json.load(open('$TMP_OUT')); print(d.get('verdict',{}).get('label','UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")
    SCORE=$(python3 -c "import json,sys; d=json.load(open('$TMP_OUT')); print(d.get('verdict',{}).get('score',0))" 2>/dev/null || echo "0")
    FINDING_COUNT=$(python3 -c "import json,sys; d=json.load(open('$TMP_OUT')); print(len(d.get('findings',[])))" 2>/dev/null || echo "0")
    ;;
esac

# ── Render findings summary ──
echo ""
echo "${BLD}Verdict: ${VERDICT}${RST} (score=${SCORE}, findings=${FINDING_COUNT})"

if [[ "$FINDING_COUNT" -gt 0 ]]; then
  echo ""
  echo "Findings (top ${FINDING_COUNT}):"
  case "$JSON_PARSER" in
    jq)
      jq -r '.findings[] | "  [\(.ruleId) \(.severity)] \(.title) — \(.file): \(.message)"' "$TMP_OUT" 2>/dev/null | head -20
      ;;
    python3)
      python3 -c "
import json
d = json.load(open('$TMP_OUT'))
for f in d.get('findings', [])[:20]:
    print(f\"  [{f.get('ruleId','?')} {f.get('severity','?')}] {f.get('title','?')} — {f.get('file','?')}: {f.get('message','?')}\")
" 2>/dev/null
      ;;
  esac
fi

# ── Full JSON dump (verbose) ──
if [[ "$VERBOSE" -eq 1 ]]; then
  echo ""
  echo "${BLD}Full JSON:${RST}"
  cat "$TMP_OUT"
fi

# ── Verdict handling ──
echo ""
case "$VERDICT" in
  SAFE)
    echo "${GRN}✅ SAFE${RST} — skill passed all checks. Install allowed."
    exit 0
    ;;
  WARN)
    echo "${YEL}⚠️  WARN${RST} — medium-risk signals found. Review before install."
    if [[ "$FORCE_WARN" -eq 1 ]]; then
      echo "${YEL}[--force-warn]${RST} Proceeding with install override."
      exit 0
    else
      if [[ -t 0 ]]; then
        read -r -p "Proceed with install anyway? [y/N] " REPLY
        if [[ "$REPLY" =~ ^[yY]([eE][sS])?$ ]]; then
          echo "Proceeding."
          exit 0
        fi
      fi
      echo "Install rejected. Re-run with --force-warn to override."
      exit 1
    fi
    ;;
  TOXIC)
    echo "${RED}❌ TOXIC${RST} — critical/high risk signals. Install BLOCKED."
    echo "Per ADR-013, TOXIC verdict is never overridable via this script."
    exit 2
    ;;
  UNKNOWN|*)
    echo "${RED}[error]${RST} could not parse verdict from skill-lint output" >&2
    cat "$TMP_OUT" >&2
    exit 3
    ;;
esac
