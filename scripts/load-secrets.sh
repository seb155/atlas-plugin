#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# ATLAS Secret Loader — Single source of truth for all secrets
# © 2026 AXOIQ Inc.
#
# Called by: atlas launcher (before CC), session-start hook, direnv
# Priority: Vaultwarden → GNOME Keyring → ~/.env fallback
#
# Interactive mode: if ATLAS_INTERACTIVE=1 and gum available,
# prompts for Vaultwarden master password when no cached session.
# ═══════════════════════════════════════════════════════════════

# Avoid re-sourcing in same shell (idempotent guard)
[ "${_ATLAS_SECRETS_LOADED:-}" = "1" ] && return 0 2>/dev/null || true

# ─── Priority 1: Vaultwarden (cached 8h via keyring) ──────────
_atlas_try_vaultwarden() {
  command -v bw &>/dev/null || return 1

  # Ensure bw is configured with server URL
  local server_url
  server_url=$(python3 -c "
import json, os
try:
    with open(os.path.expanduser('~/.atlas/config.json')) as f:
        print(json.load(f).get('secrets',{}).get('vaultwarden_server',''))
except: pass
" 2>/dev/null)
  if [ -n "$server_url" ]; then
    bw config server "$server_url" &>/dev/null 2>&1 || true
  fi

  # Try cached session from keyring
  local bw_session
  bw_session=$(secret-tool lookup service bw-session key atlas 2>/dev/null || echo "")

  # Validate cached session is still alive
  if [ -n "$bw_session" ]; then
    if ! bw unlock --check --session "$bw_session" &>/dev/null 2>&1; then
      bw_session=""  # expired, need re-unlock
    fi
  fi

  if [ -z "$bw_session" ]; then
    # Try unlock via keyring-stored master password
    local master_pw
    master_pw=$(secret-tool lookup service vaultwarden key master-password 2>/dev/null || echo "")

    # Interactive mode: ask user if no cached password and gum available
    if [ -z "$master_pw" ] && [ "${ATLAS_INTERACTIVE:-0}" = "1" ] && command -v gum &>/dev/null; then
      echo ""
      gum style --foreground 214 --bold "🔑 Vaultwarden Unlock"
      gum style "  Unlock your vault to load API tokens (FORGEJO, SYNAPSE, etc.)"
      master_pw=$(gum input --password --header "Master password:" --placeholder "Enter Vaultwarden password" 2>/dev/null)

      # Offer to save to keyring for future sessions
      if [ -n "$master_pw" ] && command -v secret-tool &>/dev/null; then
        if gum confirm "Save password to GNOME Keyring? (avoids re-entering)" 2>/dev/null; then
          echo "$master_pw" | secret-tool store --label "Vaultwarden Master" service vaultwarden key master-password 2>/dev/null
          gum style --foreground 46 "  ✓ Saved to keyring"
        fi
      fi
    fi

    if [ -n "$master_pw" ]; then
      bw_session=$(echo "$master_pw" | bw unlock --raw 2>/dev/null || echo "")
      # Cache session for 8h
      if [ -n "$bw_session" ] && command -v secret-tool &>/dev/null; then
        echo "$bw_session" | secret-tool store --label "ATLAS BW Session" service bw-session key atlas 2>/dev/null
      fi
    fi
  fi

  [ -z "$bw_session" ] && return 1

  export BW_SESSION="$bw_session"

  # Sync vault (background, non-blocking)
  (bw sync --session "$bw_session" &>/dev/null &)

  # Resolve individual secrets
  local val
  val=$(bw get password "forgejo-api-token" --session "$bw_session" 2>/dev/null) && export FORGEJO_TOKEN="$val"
  val=$(bw get password "synapse-api-token" --session "$bw_session" 2>/dev/null) && export SYNAPSE_TOKEN="$val"
  val=$(bw get password "forgejo-ci-bot-token" --session "$bw_session" 2>/dev/null) && export FORGEJO_CI_BOT_TOKEN="$val"

  # Report success in interactive mode
  if [ "${ATLAS_INTERACTIVE:-0}" = "1" ] && command -v gum &>/dev/null; then
    local count=0
    [ -n "${FORGEJO_TOKEN:-}" ] && count=$((count + 1))
    [ -n "${SYNAPSE_TOKEN:-}" ] && count=$((count + 1))
    [ -n "${FORGEJO_CI_BOT_TOKEN:-}" ] && count=$((count + 1))
    gum style --foreground 46 "  ✓ Vault unlocked — ${count} tokens loaded"
  fi

  return 0
}

# ─── Priority 2: GNOME Keyring (secret-tool) ──────────────────
_atlas_try_keyring() {
  command -v secret-tool &>/dev/null || return 1

  local val
  val=$(secret-tool lookup service forgejo key api-token 2>/dev/null) && export FORGEJO_TOKEN="$val"
  val=$(secret-tool lookup service synapse key api-token 2>/dev/null) && export SYNAPSE_TOKEN="$val"

  [ -n "${FORGEJO_TOKEN:-}" ]
}

# ─── Priority 3: Environment file fallback ─────────────────────
_atlas_try_env_file() {
  [ -f "${HOME}/.env" ] && source "${HOME}/.env" 2>/dev/null || true
  [ -f "${HOME}/.env.local" ] && source "${HOME}/.env.local" 2>/dev/null || true
}

# ─── Main: try each provider in order ─────────────────────────
_atlas_try_vaultwarden 2>/dev/null || \
_atlas_try_keyring 2>/dev/null || \
_atlas_try_env_file

# Mark as loaded (idempotent)
export _ATLAS_SECRETS_LOADED=1
