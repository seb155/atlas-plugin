#!/usr/bin/env bash
# ATLAS Secret Requirement Checker
# Usage: source require-secrets.sh FORGEJO_TOKEN SYNAPSE_TOKEN
#   OR:  require-secrets.sh --check FORGEJO_TOKEN SYNAPSE_TOKEN
#
# Verifies all named secrets are available (env, .env, or keyring/bw).
# Returns 0 if all present, 1 if any missing (with list of missing).
# Use in skills/hooks BEFORE operations that need tokens.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="source"
[ "${1:-}" = "--check" ] && MODE="check" && shift

MISSING=""
for SECRET_NAME in "$@"; do
  # Check current env first (fast)
  VALUE="${!SECRET_NAME:-}"
  if [ -z "$VALUE" ]; then
    # Try get-secret.sh (sources .env + keyring + bw)
    VALUE=$("${SCRIPT_DIR}/get-secret.sh" "$SECRET_NAME" 2>/dev/null || true)
    if [ -n "$VALUE" ]; then
      export "$SECRET_NAME=$VALUE"
    else
      MISSING+="${SECRET_NAME} "
    fi
  fi
done

if [ -n "$MISSING" ]; then
  MISSING="${MISSING% }"
  if [ "$MODE" = "check" ]; then
    echo "🏛️ ATLAS │ 🔐 MISSING SECRETS │ ${MISSING}"
    echo "   └─ Run: /atlas setup credentials"
    exit 1
  else
    # Source mode: export what we found, warn about missing
    echo "🏛️ ATLAS │ 🔐 MISSING │ ${MISSING}" >&2
  fi
fi

exit 0
