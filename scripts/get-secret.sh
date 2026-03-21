#!/usr/bin/env bash
# ATLAS Secret Resolution — 4-tier fallback
# Usage: get-secret.sh SECRET_NAME
# Returns: the secret value (stdout) or exits 1 if not found
#
# Tier 1: Environment variable ($SECRET_NAME)
# Tier 2: Source ~/.env then check again
# Tier 3: Keyring-cached BW_SESSION → bw get password
# Tier 4: Interactive bw unlock (if BW_PASSWORD set)

set -euo pipefail

export NODE_OPTIONS="${NODE_OPTIONS:---no-deprecation}"  # suppress bw punycode warning
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRET_NAME="${1:?Usage: get-secret.sh SECRET_NAME}"

# Tier 1: Environment variable (already set)
VALUE="${!SECRET_NAME:-}"
[ -n "$VALUE" ] && echo "$VALUE" && exit 0

# Tier 2: Source ~/.env and re-check
if [ -f "${HOME}/.env" ]; then
  set +u
  source "${HOME}/.env" 2>/dev/null || true
  set -u
  VALUE="${!SECRET_NAME:-}"
  [ -n "$VALUE" ] && echo "$VALUE" && exit 0
fi

# Tier 3+4: Vaultwarden CLI (if provider configured)
PROVIDER=$(python3 -c "
import json, os
try:
    with open(os.path.expanduser('~/.atlas/config.json')) as f:
        print(json.load(f).get('secrets',{}).get('provider','env'))
except: print('env')
" 2>/dev/null || echo "env")

if [ "$PROVIDER" = "vaultwarden" ] && command -v bw &>/dev/null; then
  # Tier 3: Try keyring-cached BW_SESSION first
  if [ -z "${BW_SESSION:-}" ]; then
    BW_SESSION=$("${SCRIPT_DIR}/atlas-keyring.sh" get bw_session 2>/dev/null || true)
    [ -n "$BW_SESSION" ] && export BW_SESSION
  fi

  # Tier 4: Try auto-unlock via keyring master password or BW_PASSWORD env
  if [ -z "${BW_SESSION:-}" ]; then
    # Try keyring-stored master password first
    _keyring_pw=$("${SCRIPT_DIR}/atlas-keyring.sh" get bw_master_password 2>/dev/null || true)
    if [ -n "$_keyring_pw" ]; then
      BW_SESSION=$(BW_PASSWORD="$_keyring_pw" bw unlock --passwordenv BW_PASSWORD --raw 2>/dev/null || true)
    elif [ -n "${BW_PASSWORD:-}" ]; then
      # Fallback: BW_PASSWORD from env
      BW_SESSION=$(bw unlock --passwordenv BW_PASSWORD --raw 2>/dev/null || true)
    fi
    unset _keyring_pw
    if [ -n "$BW_SESSION" ]; then
      export BW_SESSION
      # Cache session for next time
      "${SCRIPT_DIR}/atlas-keyring.sh" set bw_session "$BW_SESSION" 2>/dev/null || true
    fi
  fi

  # Resolve secret via bw
  if [ -n "${BW_SESSION:-}" ]; then
    VALUE=$(BW_SESSION="$BW_SESSION" bw get password "$SECRET_NAME" 2>/dev/null || true)
    [ -n "$VALUE" ] && echo "$VALUE" && exit 0
  fi
fi

# Not found
exit 1
