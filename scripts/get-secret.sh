#!/usr/bin/env bash
# ATLAS Secret Resolution — 3-tier fallback
# Usage: get-secret.sh SECRET_NAME
# Returns: the secret value (stdout) or exits 1 if not found
#
# Tier 1: Environment variable ($SECRET_NAME)
# Tier 2: Source ~/.env then check again
# Tier 3: Vaultwarden CLI (bw get password) if configured

set -euo pipefail

SECRET_NAME="${1:?Usage: get-secret.sh SECRET_NAME}"

# Tier 1: Environment variable (already set)
VALUE="${!SECRET_NAME:-}"
[ -n "$VALUE" ] && echo "$VALUE" && exit 0

# Tier 2: Source ~/.env and re-check
if [ -f "${HOME}/.env" ]; then
  set +u  # .env may reference unset vars
  source "${HOME}/.env" 2>/dev/null || true
  set -u
  VALUE="${!SECRET_NAME:-}"
  [ -n "$VALUE" ] && echo "$VALUE" && exit 0
fi

# Tier 3: Vaultwarden CLI (if provider configured)
PROVIDER=$(python3 -c "
import json, os
try:
    with open(os.path.expanduser('~/.atlas/config.json')) as f:
        print(json.load(f).get('secrets',{}).get('provider','env'))
except: print('env')
" 2>/dev/null || echo "env")

if [ "$PROVIDER" = "vaultwarden" ] && command -v bw &>/dev/null; then
  # Try to unlock if no session
  if [ -z "${BW_SESSION:-}" ] && [ -n "${BW_PASSWORD:-}" ]; then
    BW_SESSION=$(bw unlock --passwordenv BW_PASSWORD --raw 2>/dev/null || true)
    export BW_SESSION
  fi
  if [ -n "${BW_SESSION:-}" ]; then
    VALUE=$(BW_SESSION="$BW_SESSION" bw get password "$SECRET_NAME" 2>/dev/null || true)
    [ -n "$VALUE" ] && echo "$VALUE" && exit 0
  fi
fi

# Not found
exit 1
