#!/usr/bin/env bash
# ATLAS Cross-Platform Keyring Helper
# Usage: atlas-keyring.sh get|set|set-persistent|delete KEY [VALUE]
#
# Actions:
#   set            — store in fastest available backend (keyctl > python > file)
#   set-persistent — store in encrypted OS keyring only (survives reboot, no TTL)
#   get            — read from all backends (keyctl → python → file)
#   delete         — remove from all backends
#
# Backends (auto-detected, priority order):
#   1. keyctl (Linux kernel keyring — RAM only, fast, no popup, 8h TTL)
#   2. Python keyring (macOS Keychain / WinCred / GNOME Keyring — persistent, encrypted)
#   3. File-based (~/.atlas/.secrets/, chmod 600) — last resort

set -euo pipefail

ACTION="${1:?Usage: atlas-keyring.sh get|set|set-persistent|delete KEY [VALUE]}"
KEY="${2:?Key required}"
VALUE="${3:-}"
SERVICE="atlas-plugin"
KEYCTL_TTL=28800  # 8 hours

case "$ACTION" in
  set)
    # Backend 1: keyctl (Linux kernel keyring — RAM only, fast, no popup)
    if command -v keyctl &>/dev/null; then
      KID=$(keyctl add user "atlas_${KEY}" "$VALUE" @u)
      keyctl timeout "$KID" "$KEYCTL_TTL"
    # Backend 2: Python keyring (macOS Keychain / WinCred)
    elif python3 -c "import keyring" 2>/dev/null; then
      python3 << PYEOF
import keyring
keyring.set_password("${SERVICE}", "${KEY}", """${VALUE}""")
PYEOF
    # Backend 3: File-based (chmod 600)
    else
      mkdir -p "${HOME}/.atlas/.secrets" && chmod 700 "${HOME}/.atlas/.secrets"
      printf '%s' "$VALUE" > "${HOME}/.atlas/.secrets/${KEY}"
      chmod 600 "${HOME}/.atlas/.secrets/${KEY}"
    fi
    ;;

  get)
    RESULT=""
    # Backend 1: keyctl (Linux — fast, no popup)
    if command -v keyctl &>/dev/null; then
      RESULT=$(keyctl print "$(keyctl search @u user "atlas_${KEY}" 2>/dev/null)" 2>/dev/null || true)
    fi
    # Backend 2: Python keyring (macOS / Windows)
    if [ -z "$RESULT" ] && python3 -c "import keyring" 2>/dev/null; then
      RESULT=$(python3 -c "
import keyring
v = keyring.get_password('${SERVICE}', '${KEY}')
print(v or '', end='')
" 2>/dev/null || true)
    fi
    # Backend 3: File fallback
    if [ -z "$RESULT" ] && [ -f "${HOME}/.atlas/.secrets/${KEY}" ]; then
      RESULT=$(cat "${HOME}/.atlas/.secrets/${KEY}")
    fi
    printf '%s' "$RESULT"
    ;;

  set-persistent)
    # Persistent storage only (survives reboot). For secrets like master passwords.
    # Skips keyctl (volatile) — uses Python keyring (OS-encrypted) or file fallback.
    if python3 -c "import keyring" 2>/dev/null; then
      python3 << PYEOF
import keyring
keyring.set_password("${SERVICE}", "${KEY}", """${VALUE}""")
PYEOF
    else
      mkdir -p "${HOME}/.atlas/.secrets" && chmod 700 "${HOME}/.atlas/.secrets"
      printf '%s' "$VALUE" > "${HOME}/.atlas/.secrets/${KEY}"
      chmod 600 "${HOME}/.atlas/.secrets/${KEY}"
    fi
    ;;

  delete)
    # Clean ALL backends
    python3 -c "
import keyring
try: keyring.delete_password('${SERVICE}', '${KEY}')
except: pass
" 2>/dev/null || true
    if command -v keyctl &>/dev/null; then
      keyctl unlink "$(keyctl search @u user "atlas_${KEY}" 2>/dev/null)" @u 2>/dev/null || true
    fi
    rm -f "${HOME}/.atlas/.secrets/${KEY}" 2>/dev/null || true
    ;;

  *)
    echo "Usage: atlas-keyring.sh get|set|set-persistent|delete KEY [VALUE]" >&2
    exit 1
    ;;
esac
