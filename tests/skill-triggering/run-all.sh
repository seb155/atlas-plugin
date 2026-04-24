#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
# ATLAS — Run all skill-triggering evals
# Iterates every prompt in prompts/ and runs run-test.sh against
# the corresponding skill. Reports summary with pass rate.
#
# Usage:
#   ./run-all.sh                  # run all prompts
#   ./run-all.sh --fail-under 80  # fail if pass rate < 80%
#   ./run-all.sh --skill foo,bar  # only test named skills
#   ./run-all.sh --quiet          # suppress per-test output
#
# Exit codes:
#   0 = all PASSed (or pass rate ≥ --fail-under threshold)
#   1 = regression (pass rate below threshold)
#   2 = error (missing harness, no prompts, etc.)
#
# Reference: docs/ADR/ADR-007-skill-triggering-eval-framework.md
# ─────────────────────────────────────────────────────────────────────

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPTS_DIR="$SCRIPT_DIR/prompts"
FAIL_UNDER=0   # 0 = don't enforce threshold
SKILLS_FILTER=""
QUIET=0

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fail-under) FAIL_UNDER="$2"; shift 2 ;;
    --skill) SKILLS_FILTER="$2"; shift 2 ;;
    --quiet|-q) QUIET=1; shift ;;
    --help|-h)
      sed -n '2,25p' "$0"
      exit 0
      ;;
    *)
      echo "[error] unknown flag: $1" >&2
      exit 2
      ;;
  esac
done

# Colors
if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
  RED=''; GRN=''; YEL=''; BLD=''; RST=''
else
  RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'; BLD=$'\033[1m'; RST=$'\033[0m'
fi

# Preflight
if [[ ! -d "$PROMPTS_DIR" ]]; then
  echo "${RED}[error]${RST} prompts/ dir missing: $PROMPTS_DIR" >&2
  exit 2
fi

# Collect prompt files
if [[ -n "$SKILLS_FILTER" ]]; then
  PROMPT_FILES=()
  IFS=',' read -ra SKILLS <<< "$SKILLS_FILTER"
  for s in "${SKILLS[@]}"; do
    if [[ -f "$PROMPTS_DIR/${s}.txt" ]]; then
      PROMPT_FILES+=("$PROMPTS_DIR/${s}.txt")
    else
      echo "${YEL}[warn]${RST} no prompt file for --skill=$s"
    fi
  done
else
  mapfile -t PROMPT_FILES < <(find "$PROMPTS_DIR" -maxdepth 1 -name "*.txt" | sort)
fi

if [[ ${#PROMPT_FILES[@]} -eq 0 ]]; then
  echo "${RED}[error]${RST} no prompts found" >&2
  exit 2
fi

TOTAL=${#PROMPT_FILES[@]}
echo "${BLD}ATLAS Skill-Triggering Eval${RST}"
echo "Testing ${TOTAL} skills..."
echo ""

PASSED=0
FAILED=0
SKIPPED=0
PASS_LIST=()
FAIL_LIST=()
SKIP_LIST=()

for prompt_file in "${PROMPT_FILES[@]}"; do
  skill=$(basename "$prompt_file" .txt)

  # Skip if prompt file is empty (placeholder)
  if [[ ! -s "$prompt_file" ]]; then
    echo "${YEL}⊘ SKIP${RST}: $skill (empty prompt — placeholder)"
    SKIPPED=$((SKIPPED + 1))
    SKIP_LIST+=("$skill")
    continue
  fi

  # Skip if marked eval-exempt (first line comment `# EVAL-EXEMPT:`)
  if head -1 "$prompt_file" | grep -q "^# EVAL-EXEMPT:"; then
    reason=$(head -1 "$prompt_file" | sed 's/^# EVAL-EXEMPT: *//')
    echo "${YEL}⊘ SKIP${RST}: $skill (eval-exempt: $reason)"
    SKIPPED=$((SKIPPED + 1))
    SKIP_LIST+=("$skill")
    continue
  fi

  if [[ "$QUIET" -eq 1 ]]; then
    if bash "$SCRIPT_DIR/run-test.sh" "$skill" "$prompt_file" 3 > /tmp/eval-$skill.log 2>&1; then
      PASSED=$((PASSED + 1))
      PASS_LIST+=("$skill")
      echo "${GRN}✅${RST} $skill"
    else
      FAILED=$((FAILED + 1))
      FAIL_LIST+=("$skill")
      echo "${RED}❌${RST} $skill"
    fi
  else
    echo ""
    echo "${BLD}━━━ $skill ━━━${RST}"
    if bash "$SCRIPT_DIR/run-test.sh" "$skill" "$prompt_file" 3; then
      PASSED=$((PASSED + 1))
      PASS_LIST+=("$skill")
    else
      FAILED=$((FAILED + 1))
      FAIL_LIST+=("$skill")
    fi
  fi
done

# ── Summary ──
echo ""
echo "${BLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo "${BLD}📊 Eval Summary${RST}"
echo "   Total:   $TOTAL"
echo "   ${GRN}PASS:${RST}    $PASSED"
echo "   ${RED}FAIL:${RST}    $FAILED"
echo "   ${YEL}SKIP:${RST}    $SKIPPED"

# Compute pass rate excluding skipped
EVALUABLE=$((TOTAL - SKIPPED))
if [[ "$EVALUABLE" -gt 0 ]]; then
  PASS_RATE=$(( (PASSED * 100) / EVALUABLE ))
  echo "   Pass rate (of evaluable): ${PASS_RATE}%"
else
  PASS_RATE=0
  echo "   No evaluable tests (all skipped)"
fi
echo "${BLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"

if [[ "$FAILED" -gt 0 ]]; then
  echo ""
  echo "${RED}Failed skills:${RST}"
  for s in "${FAIL_LIST[@]}"; do echo "  - $s"; done
fi

# ── Threshold check ──
if [[ "$FAIL_UNDER" -gt 0 ]]; then
  if [[ "$PASS_RATE" -lt "$FAIL_UNDER" ]]; then
    echo ""
    echo "${RED}❌ REGRESSION${RST}: pass rate ${PASS_RATE}% < threshold ${FAIL_UNDER}%"
    exit 1
  fi
  echo ""
  echo "${GRN}✅ OK${RST}: pass rate ${PASS_RATE}% ≥ threshold ${FAIL_UNDER}%"
fi

exit 0
