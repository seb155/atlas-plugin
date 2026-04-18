#!/usr/bin/env bash
# SPDX-License-Identifier: LicenseRef-AXOIQ-Proprietary
# smoke-gate.sh — wrapper around Synapse's scripts/smoke.sh
#
# Finds the repo, delegates to the harness, tees output, optionally
# creates a Forgejo issue via scripts/smoke-report.py.
#
# This skill is intentionally thin — the actual harness lives in the
# Synapse repo (portable bash + yq + jq + curl). This wrapper makes it
# invokable as /atlas smoke-gate.

set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────
# Args
# ──────────────────────────────────────────────────────────────────────────
ENV_NAME="dev"
ONLY=""
JSON_OUT=""
CREATE_ISSUE=0
VERBOSE=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_NAME="$2"; shift 2 ;;
    --only) ONLY="$2"; shift 2 ;;
    --json-out) JSON_OUT="$2"; shift 2 ;;
    --create-issue) CREATE_ISSUE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -v|--verbose) VERBOSE=1; shift ;;
    -h|--help) sed -n '/^# smoke-gate/,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# ──────────────────────────────────────────────────────────────────────────
# Locate harness (must be run from within a repo that has scripts/smoke.sh)
# ──────────────────────────────────────────────────────────────────────────
REPO=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
HARNESS="$REPO/scripts/smoke.sh"
REPORTER="$REPO/scripts/smoke-report.py"
YAML="$REPO/scripts/smoke-endpoints.yml"

if [[ ! -x "$HARNESS" ]]; then
  cat >&2 <<EOF
error: smoke harness not found at $HARNESS

The smoke-gate skill expects the calling repo to ship its own:
  scripts/smoke.sh            (harness)
  scripts/smoke-endpoints.yml (SSoT of endpoints)
  scripts/smoke-report.py     (optional — for --create-issue)

See .blueprint/plans/hazy-mapping-stallman.md Section E for the schema,
or copy from https://forgejo.axoiq.com/axoiq/synapse/src/branch/dev/scripts/
EOF
  exit 2
fi

# ──────────────────────────────────────────────────────────────────────────
# Build output dir + file path
# ──────────────────────────────────────────────────────────────────────────
if [[ -z "$JSON_OUT" ]]; then
  mkdir -p "$REPO/memory/smoke-reports" 2>/dev/null || mkdir -p "$HOME/.claude/smoke-reports"
  TS=$(date -u +%Y%m%dT%H%M%SZ)
  JSON_OUT="${REPO}/memory/smoke-reports/smoke-${ENV_NAME}-${TS}.json"
  [[ -d "$(dirname "$JSON_OUT")" ]] || JSON_OUT="$HOME/.claude/smoke-reports/smoke-${ENV_NAME}-${TS}.json"
fi

# ──────────────────────────────────────────────────────────────────────────
# Invoke harness
# ──────────────────────────────────────────────────────────────────────────
harness_args=(--env "$ENV_NAME" --json-out "$JSON_OUT")
[[ -n "$ONLY" ]] && harness_args+=(--only "$ONLY")
[[ $VERBOSE -eq 1 ]] && harness_args+=(--verbose)

echo "== /atlas smoke-gate env=$ENV_NAME out=$JSON_OUT ==" >&2

if [[ $DRY_RUN -eq 1 ]]; then
  echo "DRY: $HARNESS ${harness_args[*]}"
  exit 0
fi

EXIT=0
"$HARNESS" "${harness_args[@]}" || EXIT=$?

# ──────────────────────────────────────────────────────────────────────────
# On red: optionally create Forgejo issue
# ──────────────────────────────────────────────────────────────────────────
if (( EXIT != 0 )) && (( CREATE_ISSUE == 1 )); then
  if [[ -x "$REPORTER" ]]; then
    echo "== creating Forgejo issue =="  >&2
    python3 "$REPORTER" "$JSON_OUT" --create-issue --tag smoke-fail --tag "env-$ENV_NAME" \
      || echo "issue creation failed (check FORGEJO_TOKEN)" >&2
  else
    echo "note: $REPORTER not executable — issue creation skipped" >&2
  fi
fi

# Summary line (JSON one-liner to stdout for programmatic consumers)
if [[ -f "$JSON_OUT" ]]; then
  jq -c '{env, run, failed, passed, generated_at}' < "$JSON_OUT"
fi

exit $EXIT
