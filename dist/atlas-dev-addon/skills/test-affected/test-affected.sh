#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-AXOIQ-Proprietary
# test-affected.sh — G1 pre-push gate: run only tests impacted by changes.
#
# Per .blueprint/plans/hazy-mapping-stallman.md (Synapse repo) Phase 3 T3.2.
# Budget 30s default. Advisory v1 — logs to .claude/ci-health.jsonl without
# blocking. Flip to blocking via env ATLAS_G1_BLOCKING=true (Phase 5).

set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────────
SINCE="HEAD~1"
BUDGET_SEC=30
DRY_RUN=0
ONLY=""
VERBOSE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since) SINCE="$2"; shift 2 ;;
    --budget) BUDGET_SEC="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --only) ONLY="$2"; shift 2 ;;  # backend|frontend
    -v|--verbose) VERBOSE=1; shift ;;
    -h|--help) sed -n '/^# test-affected/,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# ──────────────────────────────────────────────────────────────────────────
# Find repo root + detect changed files
# ──────────────────────────────────────────────────────────────────────────
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || { echo "not in a git repo" >&2; exit 2; })
cd "$REPO_ROOT"

# Include uncommitted changes + diff-range
CHANGED_FILES=$(
  {
    git diff --name-only "$SINCE"..HEAD 2>/dev/null || true
    git diff --name-only --cached 2>/dev/null || true
    git diff --name-only 2>/dev/null || true
  } | sort -u | awk 'NF'
)

if [[ -z "$CHANGED_FILES" ]]; then
  echo "no changed files vs $SINCE — nothing to test" >&2
  exit 0
fi

CHANGED_COUNT=$(echo "$CHANGED_FILES" | wc -l)
[[ $VERBOSE -eq 1 ]] && echo "changed files ($CHANGED_COUNT):" >&2 && echo "$CHANGED_FILES" | sed 's/^/  /' >&2

# ──────────────────────────────────────────────────────────────────────────
# Split by domain
# ──────────────────────────────────────────────────────────────────────────
BACKEND_CHANGED=$(echo "$CHANGED_FILES" | grep -E '^backend/.*\.py$' || true)
FRONTEND_SRC_CHANGED=$(echo "$CHANGED_FILES" | grep -E '^frontend/src/.*\.(ts|tsx|js|jsx)$' || true)
FRONTEND_PKG_CHANGED=$(echo "$CHANGED_FILES" | grep -E '^frontend/packages/.*/src/.*\.(ts|tsx|js|jsx)$' || true)
CONFIG_CHANGED=$(echo "$CHANGED_FILES" | grep -E '^(\.woodpecker|scripts)/' || true)

# ──────────────────────────────────────────────────────────────────────────
# Logging helper
# ──────────────────────────────────────────────────────────────────────────
LOG_DIR="${ATLAS_LOG_DIR:-$HOME/.claude}"
LOG_FILE="$LOG_DIR/ci-health.jsonl"
mkdir -p "$LOG_DIR"

emit_log() {
  local result_json="$1"
  echo "$result_json" >> "$LOG_FILE"
}

# ──────────────────────────────────────────────────────────────────────────
# Run pytest affected (backend)
# ──────────────────────────────────────────────────────────────────────────
run_backend() {
  if [[ -z "$BACKEND_CHANGED" ]]; then
    [[ $VERBOSE -eq 1 ]] && echo "backend: no .py changes, skipping" >&2
    return 0
  fi

  [[ -d backend ]] || { echo "no backend/ dir" >&2; return 0; }

  local pytest_cmd
  if [[ -f backend/.testmondata ]]; then
    pytest_cmd="pytest --testmon -x -q -m 'not slow and not external' --tb=line"
    [[ $VERBOSE -eq 1 ]] && echo "backend: using pytest-testmon" >&2
  else
    # Fallback: derive test files from changed source files
    local test_files=""
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      local base
      base=$(basename "$f" .py)
      # Heuristic: find test_<base>.py or <base>_test.py anywhere in backend/tests/
      local candidates
      candidates=$(find backend/tests -name "test_${base}.py" -o -name "${base}_test.py" 2>/dev/null)
      [[ -n "$candidates" ]] && test_files+="$candidates"$'\n'
    done <<< "$BACKEND_CHANGED"
    test_files=$(echo "$test_files" | sort -u | awk 'NF')
    if [[ -z "$test_files" ]]; then
      [[ $VERBOSE -eq 1 ]] && echo "backend: no test files matched (file-map fallback)" >&2
      return 0
    fi
    pytest_cmd="pytest -x -q --tb=line $test_files"
  fi

  [[ $DRY_RUN -eq 1 ]] && { echo "DRY: cd backend && $pytest_cmd"; return 0; }

  local ts_start=$(date +%s)
  local exit_code=0
  (cd backend && timeout "$BUDGET_SEC" $pytest_cmd 2>&1 | tail -20) || exit_code=$?
  local duration=$(( $(date +%s) - ts_start ))

  emit_log "$(jq -nc --arg gate G1 --arg domain backend --argjson code $exit_code --argjson ms $((duration*1000)) '{gate:$gate,domain:$domain,exit_code:$code,duration_ms:$ms,ts:now|todate}')"

  return $exit_code
}

# ──────────────────────────────────────────────────────────────────────────
# Run vitest --changed (frontend)
# ──────────────────────────────────────────────────────────────────────────
run_frontend() {
  if [[ -z "$FRONTEND_SRC_CHANGED" && -z "$FRONTEND_PKG_CHANGED" ]]; then
    [[ $VERBOSE -eq 1 ]] && echo "frontend: no .ts/.tsx changes, skipping" >&2
    return 0
  fi

  [[ -d frontend ]] || { echo "no frontend/ dir" >&2; return 0; }

  local vitest_cmd="bun x vitest run --changed $SINCE --passWithNoTests --reporter=dot"

  [[ $DRY_RUN -eq 1 ]] && { echo "DRY: cd frontend && $vitest_cmd"; return 0; }

  local ts_start=$(date +%s)
  local exit_code=0
  (cd frontend && timeout "$BUDGET_SEC" $vitest_cmd 2>&1 | tail -15) || exit_code=$?
  local duration=$(( $(date +%s) - ts_start ))

  emit_log "$(jq -nc --arg gate G1 --arg domain frontend --argjson code $exit_code --argjson ms $((duration*1000)) '{gate:$gate,domain:$domain,exit_code:$code,duration_ms:$ms,ts:now|todate}')"

  return $exit_code
}

# ──────────────────────────────────────────────────────────────────────────
# Validate YAML/SH changes (CI config)
# ──────────────────────────────────────────────────────────────────────────
run_config() {
  [[ -z "$CONFIG_CHANGED" ]] && return 0
  local fail=0
  while IFS= read -r f; do
    [[ -z "$f" || ! -f "$f" ]] && continue
    case "$f" in
      *.yml|*.yaml)
        python3 -c "import yaml,sys; yaml.safe_load(open('$f'))" 2>&1 | head -1 \
          && { [[ $VERBOSE -eq 1 ]] && echo "  yaml ok: $f" >&2; } \
          || { echo "  yaml FAIL: $f" >&2; fail=1; }
        ;;
      *.sh)
        bash -n "$f" 2>&1 | head -1 \
          && { [[ $VERBOSE -eq 1 ]] && echo "  sh ok: $f" >&2; } \
          || { echo "  sh FAIL: $f" >&2; fail=1; }
        ;;
    esac
  done <<< "$CONFIG_CHANGED"
  return $fail
}

# ──────────────────────────────────────────────────────────────────────────
# Orchestrate
# ──────────────────────────────────────────────────────────────────────────
overall_exit=0
TS_GLOBAL=$(date +%s)

if [[ -z "$ONLY" || "$ONLY" == "backend" ]]; then
  if ! run_backend; then overall_exit=1; fi
fi

if [[ -z "$ONLY" || "$ONLY" == "frontend" ]]; then
  if ! run_frontend; then overall_exit=1; fi
fi

if [[ -z "$ONLY" ]]; then
  if ! run_config; then overall_exit=1; fi
fi

GLOBAL_DURATION=$(( $(date +%s) - TS_GLOBAL ))

if (( GLOBAL_DURATION > BUDGET_SEC )); then
  echo "⚠ G1 exceeded budget (${GLOBAL_DURATION}s > ${BUDGET_SEC}s) — some tests unrun, CI will catch them"
  emit_log "$(jq -nc --arg gate G1 --arg status budget_exceeded --argjson s $GLOBAL_DURATION '{gate:$gate,status:$status,duration_s:$s,ts:now|todate}')"
fi

# Advisory vs blocking
if (( overall_exit != 0 )); then
  if [[ "${ATLAS_G1_BLOCKING:-false}" == "true" ]]; then
    echo "❌ G1 failed (blocking mode) — fix tests before push"
    exit 1
  else
    echo "⚠ G1 advisory: some tests failed — CI will run the full suite"
    exit 0  # advisory: don't block
  fi
fi

echo "✓ G1 passed (${GLOBAL_DURATION}s)"
exit 0
