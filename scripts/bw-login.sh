#!/usr/bin/env bash
# ATLAS Vaultwarden Login Helper
# Usage: source <(./scripts/bw-login.sh)
#   OR:  eval $(./scripts/bw-login.sh)
#
# Handles: login (if needed) → unlock → export BW_SESSION
# Interactive: prompts for password + 2FA when required

set -euo pipefail

export NODE_OPTIONS="${NODE_OPTIONS:---no-deprecation}"  # suppress bw punycode warning
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read Vaultwarden server from config
VW_SERVER=""
if [ -f "${HOME}/.atlas/config.json" ]; then
  VW_SERVER=$(python3 -c "
import json, os
with open(os.path.expanduser('~/.atlas/config.json')) as f:
    print(json.load(f).get('secrets',{}).get('vaultwarden_server',''))
" 2>/dev/null || true)
fi

# Check bw CLI
if ! command -v bw &>/dev/null; then
  echo "echo '❌ bw CLI not installed. Run: npm install -g @bitwarden/cli'" >&2
  exit 1
fi

# Configure server if needed
if [ -n "$VW_SERVER" ]; then
  CURRENT_SERVER=$(bw config server 2>/dev/null || true)
  if [ "$CURRENT_SERVER" != "$VW_SERVER" ]; then
    echo "echo '🏛️ ATLAS │ 🔐 Configuring Vaultwarden: ${VW_SERVER}'" >&2
    bw config server "$VW_SERVER" >/dev/null 2>&1
  fi
fi

# Check login status
STATUS=$(bw status 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])" 2>/dev/null || echo "unauthenticated")

case "$STATUS" in
  unauthenticated)
    echo "echo '🏛️ ATLAS │ 🔐 Login required (password + 2FA)'" >&2
    # Interactive login — user enters password + 2FA
    bw login >&2
    # After login, unlock
    echo "echo '🏛️ ATLAS │ 🔓 Unlocking vault...'" >&2
    BW_SESSION=$(bw unlock --raw 2>/dev/null)
    ;;
  locked)
    echo "echo '🏛️ ATLAS │ 🔓 Unlocking vault...'" >&2
    BW_SESSION=$(bw unlock --raw 2>/dev/null)
    ;;
  unlocked)
    echo "echo '🏛️ ATLAS │ ✅ Vault already unlocked'" >&2
    BW_SESSION="${BW_SESSION:-}"
    ;;
esac

if [ -n "${BW_SESSION:-}" ]; then
  # Cache in cross-platform keyring for subsequent sessions
  "${SCRIPT_DIR}/atlas-keyring.sh" set bw_session "$BW_SESSION" 2>/dev/null || true
  # Output export command for eval/source
  echo "export BW_SESSION='${BW_SESSION}'"
  echo "echo '🏛️ ATLAS │ ✅ VAULT │ Session cached in keyring (auto-unlock for 8h)'" >&2
else
  echo "echo '🏛️ ATLAS │ ❌ VAULT │ Failed to get session'" >&2
  exit 1
fi
