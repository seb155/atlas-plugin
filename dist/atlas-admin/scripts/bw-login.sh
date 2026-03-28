#!/usr/bin/env bash
# ATLAS Vaultwarden Login Helper
# Usage: eval $(./scripts/bw-login.sh)                    # interactive unlock
#        eval $(./scripts/bw-login.sh --store-password)    # unlock + save password to keyring
#        eval $(./scripts/bw-login.sh --auto)              # non-interactive (keyring password)
#
# Handles: login (if needed) → unlock → export BW_SESSION
# --store-password: after unlock, stores master password in OS keyring (persistent, encrypted)
# --auto: reads password from keyring, unlocks without user interaction

set -euo pipefail

export NODE_OPTIONS="${NODE_OPTIONS:---no-deprecation}"  # suppress bw punycode warning
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

STORE_PASSWORD=false
AUTO_MODE=false
for arg in "$@"; do
  case "$arg" in
    --store-password) STORE_PASSWORD=true ;;
    --auto) AUTO_MODE=true ;;
  esac
done

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
    if [ "$AUTO_MODE" = "true" ]; then
      echo "echo '🏛️ ATLAS │ ❌ VAULT │ Not logged in — run bw-login.sh interactively first'" >&2
      exit 1
    fi
    echo "echo '🏛️ ATLAS │ 🔐 Login required (password + 2FA)'" >&2
    # Interactive login — user enters password + 2FA
    bw login >&2
    # After login, unlock
    echo "echo '🏛️ ATLAS │ 🔓 Unlocking vault...'" >&2
    BW_SESSION=$(bw unlock --raw 2>/dev/null)
    ;;
  locked)
    # Try keyring-stored master password for non-interactive unlock
    KEYRING_PW=$("${SCRIPT_DIR}/atlas-keyring.sh" get bw_master_password 2>/dev/null || true)
    if [ -n "$KEYRING_PW" ]; then
      echo "echo '🏛️ ATLAS │ 🔓 Auto-unlocking via keyring...'" >&2
      BW_SESSION=$(BW_PASSWORD="$KEYRING_PW" bw unlock --passwordenv BW_PASSWORD --raw 2>/dev/null || true)
      if [ -z "${BW_SESSION:-}" ]; then
        echo "echo '🏛️ ATLAS │ ⚠️ VAULT │ Keyring password rejected (changed?)'" >&2
        if [ "$AUTO_MODE" = "true" ]; then
          exit 1
        fi
        # Fallback to interactive
        echo "echo '🏛️ ATLAS │ 🔓 Falling back to interactive unlock...'" >&2
        BW_SESSION=$(bw unlock --raw 2>/dev/null)
      fi
    elif [ "$AUTO_MODE" = "true" ]; then
      echo "echo '🏛️ ATLAS │ ❌ VAULT │ No keyring password — run: bw-login.sh --store-password'" >&2
      exit 1
    else
      echo "echo '🏛️ ATLAS │ 🔓 Unlocking vault...'" >&2
      BW_SESSION=$(bw unlock --raw 2>/dev/null)
    fi
    ;;
  unlocked)
    echo "echo '🏛️ ATLAS │ ✅ Vault already unlocked'" >&2
    BW_SESSION="${BW_SESSION:-}"
    ;;
esac

if [ -n "${BW_SESSION:-}" ]; then
  # Cache BW_SESSION in volatile keyring (8h TTL via keyctl)
  "${SCRIPT_DIR}/atlas-keyring.sh" set bw_session "$BW_SESSION" 2>/dev/null || true

  # Store master password persistently if requested
  if [ "$STORE_PASSWORD" = "true" ]; then
    echo "echo '🏛️ ATLAS │ 🔐 VAULT │ Enter master password to store in OS keyring:'" >&2
    read -rsp "Master password: " PW_INPUT >&2
    echo >&2
    if [ -n "$PW_INPUT" ]; then
      # Verify the password works
      VERIFY_SESSION=$(BW_PASSWORD="$PW_INPUT" bw unlock --passwordenv BW_PASSWORD --raw 2>/dev/null || true)
      if [ -n "$VERIFY_SESSION" ]; then
        "${SCRIPT_DIR}/atlas-keyring.sh" set-persistent bw_master_password "$PW_INPUT" 2>/dev/null
        echo "echo '🏛️ ATLAS │ ✅ VAULT │ Password stored in OS keyring (encrypted, persistent)'" >&2
        echo "echo '🏛️ ATLAS │ 💡 VAULT │ Future sessions will auto-unlock — no password needed'" >&2
      else
        echo "echo '🏛️ ATLAS │ ❌ VAULT │ Password verification failed — not stored'" >&2
      fi
    fi
  fi

  # Output export command for eval/source
  echo "export BW_SESSION='${BW_SESSION}'"
  echo "echo '🏛️ ATLAS │ ✅ VAULT │ Session cached in keyring (auto-unlock for 8h)'" >&2
else
  echo "echo '🏛️ ATLAS │ ❌ VAULT │ Failed to get session'" >&2
  exit 1
fi
