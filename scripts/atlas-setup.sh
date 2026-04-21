#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
# ATLAS Marketplace Auth Setup (Phase B.2 — Device Flow OAuth)
# Sets up Cloudflare Access Service Token for plugins.axoiq.com access
# via Authentik OAuth device authorization flow (RFC 8628).
#
# Scope:
#   - atlas-bootstrap.sh = initial dev environment (WSL2, CShip, git)
#   - atlas-setup.sh     = marketplace auth credentials (THIS script)
#
# Usage:
#   curl -fsSL https://plugins.axoiq.com/atlas.sh | bash
#   # or
#   ./atlas-setup.sh [--force] [--non-interactive]
#
# What it does:
#   1. Request device code from Authentik OIDC device flow endpoint
#   2. Display user_code + verification_uri, wait for user approval in browser
#   3. Poll token endpoint until approved (exchange Authentik token → CF Service Token)
#   4. Merge CF-Access-Client-Id/Secret into ~/.claude/settings.json marketplace headers
#   5. Run `claude plugin install atlas-core@atlas-marketplace` to complete setup
#
# Requirements: bash 4+, curl, jq
#
# Plan: .blueprint/plans/aujourdhui-su-rmon-ordinateur-clever-blum.md Phase B.2
# ─────────────────────────────────────────────────────────────────────
set -euo pipefail

ATLAS_SETUP_VERSION="1.0.0"
# Authentik OIDC endpoints (discovered 2026-04-21 via OIDC discovery at
# /application/o/atlas-cli-device/.well-known/openid-configuration):
#   device endpoint: /application/o/device/ (GLOBAL, app scoped via client_id param)
#   token endpoint:  /application/o/token/  (GLOBAL)
AUTHENTIK_BASE="${ATLAS_AUTHENTIK_BASE:-https://auth.axoiq.com/application/o}"
AUTHENTIK_DEVICE_URL="${ATLAS_AUTHENTIK_DEVICE_URL:-${AUTHENTIK_BASE}/device/}"
AUTHENTIK_TOKEN_URL="${ATLAS_AUTHENTIK_TOKEN_URL:-${AUTHENTIK_BASE}/token/}"
AUTHENTIK_CLIENT_ID="${ATLAS_AUTHENTIK_CLIENT_ID:-atlas-cli-device}"
CF_EXCHANGE_URL="${ATLAS_CF_EXCHANGE_URL:-https://auth.axoiq.com/atlas/exchange}"
MARKETPLACE_URL="${ATLAS_MARKETPLACE_URL:-https://plugins.axoiq.com/marketplace.json}"
MARKETPLACE_NAME="atlas-axoiq"

SETTINGS_FILE="${HOME}/.claude/settings.json"
POLL_INTERVAL_DEFAULT=5
POLL_TIMEOUT_DEFAULT=300  # 5 min

NON_INTERACTIVE=false
FORCE=false
for arg in "$@"; do
  case "$arg" in
    --non-interactive) NON_INTERACTIVE=true ;;
    --force)           FORCE=true ;;
    --help|-h)
      head -32 "$0" | tail -29
      exit 0
      ;;
    *)
      echo "Unknown flag: $arg (use --help)" >&2
      exit 1
      ;;
  esac
done

# ─────────────────────────────────────────────────────────────────────
# Prerequisites
# ─────────────────────────────────────────────────────────────────────
command -v curl >/dev/null 2>&1 || { echo "ERROR: curl required" >&2; exit 1; }
command -v jq   >/dev/null 2>&1 || { echo "ERROR: jq required (sudo apt install jq)" >&2; exit 1; }

# ─────────────────────────────────────────────────────────────────────
# Idempotency — skip if already configured (unless --force)
# ─────────────────────────────────────────────────────────────────────
if [ -f "$SETTINGS_FILE" ] && [ "$FORCE" != "true" ]; then
  existing_id=$(jq -r --arg name "$MARKETPLACE_NAME" \
    '.marketplaces[]? | select(.name == $name) | .headers["CF-Access-Client-Id"] // empty' \
    "$SETTINGS_FILE" 2>/dev/null || echo "")
  if [ -n "$existing_id" ]; then
    printf '✓ ATLAS marketplace already configured (CF-Access-Client-Id: %s...)\n' \
      "${existing_id:0:8}"
    printf '  Re-run with --force to re-authenticate.\n'
    exit 0
  fi
fi

# ─────────────────────────────────────────────────────────────────────
# Step 1 — Request device code
# ─────────────────────────────────────────────────────────────────────
printf '🔑 ATLAS Marketplace Setup (Phase B.2)\n'
printf '   Requesting device code from Authentik...\n'

device_resp=$(curl -fsS -X POST "${AUTHENTIK_DEVICE_URL}" \
  --data-urlencode "client_id=${AUTHENTIK_CLIENT_ID}" \
  --data-urlencode "scope=openid profile email" 2>&1) || {
  printf 'ERROR: device_authorize request failed:\n%s\n' "$device_resp" >&2
  exit 1
}

device_code=$(echo "$device_resp" | jq -r '.device_code // empty')
user_code=$(echo "$device_resp" | jq -r '.user_code // empty')
verif_uri=$(echo "$device_resp" | jq -r '.verification_uri_complete // .verification_uri // empty')
poll_interval=$(echo "$device_resp" | jq -r '.interval // 5')

if [ -z "$device_code" ] || [ -z "$user_code" ] || [ -z "$verif_uri" ]; then
  printf 'ERROR: device_authorize response missing required fields.\n' >&2
  printf 'Response: %s\n' "$device_resp" >&2
  exit 1
fi

# ─────────────────────────────────────────────────────────────────────
# Step 2 — Display + wait for approval
# ─────────────────────────────────────────────────────────────────────
printf '\n'
printf '   ┌───────────────────────────────────────────────────────┐\n'
printf '   │                                                       │\n'
printf '   │  Ouvre ce lien :                                      │\n'
printf '   │  %-53s│\n' "$verif_uri"
printf '   │                                                       │\n'
printf '   │  Code   : %-44s│\n' "$user_code"
printf '   │                                                       │\n'
printf '   └───────────────────────────────────────────────────────┘\n'
printf '\n'
printf '   Polling every %ds (timeout %ds)...\n' "$poll_interval" "$POLL_TIMEOUT_DEFAULT"
printf '\n'

# Optional: auto-open browser if interactive + xdg-open available
if [ "$NON_INTERACTIVE" != "true" ] && command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$verif_uri" >/dev/null 2>&1 &
fi

# ─────────────────────────────────────────────────────────────────────
# Step 3 — Poll token endpoint
# ─────────────────────────────────────────────────────────────────────
start_ts=$(date +%s)
auth_token=""
while true; do
  now_ts=$(date +%s)
  elapsed=$((now_ts - start_ts))
  if [ "$elapsed" -ge "$POLL_TIMEOUT_DEFAULT" ]; then
    printf 'ERROR: timeout waiting for device approval (%ds)\n' "$POLL_TIMEOUT_DEFAULT" >&2
    exit 1
  fi

  token_resp=$(curl -fsS -X POST "${AUTHENTIK_TOKEN_URL}" \
    --data-urlencode "grant_type=urn:ietf:params:oauth:grant-type:device_code" \
    --data-urlencode "device_code=${device_code}" \
    --data-urlencode "client_id=${AUTHENTIK_CLIENT_ID}" 2>/dev/null || echo '{"error":"curl_fail"}')

  # Success?
  auth_token=$(echo "$token_resp" | jq -r '.access_token // empty')
  if [ -n "$auth_token" ]; then
    printf '✓ Authenticated via Authentik (elapsed %ds)\n' "$elapsed"
    break
  fi

  # Expected pending state
  err=$(echo "$token_resp" | jq -r '.error // empty')
  case "$err" in
    authorization_pending|slow_down)
      printf '.'
      sleep "$poll_interval"
      continue
      ;;
    expired_token|access_denied)
      printf '\nERROR: %s — restart setup to try again\n' "$err" >&2
      exit 1
      ;;
    *)
      printf '\nERROR: unexpected token response: %s\n' "$token_resp" >&2
      exit 1
      ;;
  esac
done

# ─────────────────────────────────────────────────────────────────────
# Step 4 — Exchange Authentik token → CF Access Service Token
# ─────────────────────────────────────────────────────────────────────
printf '   Exchanging for CF Access Service Token...\n'

cf_resp=$(curl -fsS -X POST "$CF_EXCHANGE_URL" \
  -H "Authorization: Bearer ${auth_token}" \
  -H "Content-Type: application/json" 2>&1) || {
  printf 'ERROR: CF exchange failed:\n%s\n' "$cf_resp" >&2
  exit 1
}

cf_id=$(echo "$cf_resp" | jq -r '.client_id // empty')
cf_secret=$(echo "$cf_resp" | jq -r '.client_secret // empty')

if [ -z "$cf_id" ] || [ -z "$cf_secret" ]; then
  printf 'ERROR: CF exchange response missing client_id or client_secret\n' >&2
  exit 1
fi

printf '✓ Received CF Service Token (id: %s...)\n' "${cf_id:0:8}"

# ─────────────────────────────────────────────────────────────────────
# Step 5 — Merge into ~/.claude/settings.json
# ─────────────────────────────────────────────────────────────────────
printf '   Writing CF credentials to %s...\n' "$SETTINGS_FILE"

mkdir -p "$(dirname "$SETTINGS_FILE")"

# Start with empty JSON if settings.json doesn't exist
if [ ! -f "$SETTINGS_FILE" ]; then
  echo '{}' > "$SETTINGS_FILE"
fi

# Build a new marketplaces[] entry and merge using jq
tmp=$(mktemp)
jq --arg name "$MARKETPLACE_NAME" \
   --arg url "$MARKETPLACE_URL" \
   --arg id "$cf_id" \
   --arg secret "$cf_secret" '
  .marketplaces = (
    (.marketplaces // []) |
    map(select(.name != $name)) +
    [{
      name: $name,
      source: "url",
      url: $url,
      headers: {
        "CF-Access-Client-Id": $id,
        "CF-Access-Client-Secret": $secret
      }
    }]
  )
' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"

chmod 600 "$SETTINGS_FILE"

# ─────────────────────────────────────────────────────────────────────
# Step 6 — Install atlas-core plugin (optional if claude CLI available)
# ─────────────────────────────────────────────────────────────────────
printf '\n'
printf '✓ Marketplace auth configured\n'

if command -v claude >/dev/null 2>&1; then
  printf '   Running claude plugin install atlas-core@%s...\n' "$MARKETPLACE_NAME"
  claude plugin install "atlas-core@${MARKETPLACE_NAME}" || {
    printf '⚠ Install failed — run manually: claude plugin install atlas-core@%s\n' \
      "$MARKETPLACE_NAME" >&2
  }
else
  printf '   (claude CLI not found on PATH — install ATLAS manually with:\n'
  printf '      claude plugin install atlas-core@%s)\n' "$MARKETPLACE_NAME"
fi

printf '\n'
printf '🎉 Setup complete. Type: claude\n'
printf '\n'
printf '   To rotate credentials later: ./atlas-setup.sh --force\n'
printf '   To silence auto-updates:     export ATLAS_NO_AUTO_UPDATE=1\n'
