#!/usr/bin/env bash
# shellcheck shell=bash
# NOTE: Sourced by scripts/atlas-cli.sh (no set -euo pipefail at file level).
# ATLAS CLI Module: Portal — DevHub cockpit sync/status/diff commands
# Sourced by atlas-cli.sh — do not execute directly
#
# Usage:  atlas portal <subcmd> [args]
# Alias:  atlas portal <subcmd>
#
# Env overrides:
#   DEVHUB_URL         Base URL (default: http://localhost:8001)
#   ATLAS_HOOK_TOKEN   Bearer token (scoped to portal:sync-only)
#
# SP-DEVHUB-COCKPIT Wave 2 — T10

# ─── Helpers ──────────────────────────────────────────────────

_portal_base_url() {
  echo "${DEVHUB_URL:-http://localhost:8001}"
}

# Resolve ATLAS_HOOK_TOKEN from env or ~/.env fallback
_portal_token() {
  if [ -n "${ATLAS_HOOK_TOKEN:-}" ]; then
    echo "$ATLAS_HOOK_TOKEN"
    return
  fi
  if [ -f "$HOME/.env" ] && command -v grep &>/dev/null; then
    local tok
    tok=$(grep '^ATLAS_HOOK_TOKEN=' "$HOME/.env" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"'"'")
    [ -n "$tok" ] && echo "$tok" && return
  fi
  echo ""
}

# _portal_curl <path> [extra curl args...] — authenticated curl helper
_portal_curl() {
  local path="${1:-/}"
  shift
  local base url token
  base=$(_portal_base_url)
  url="${base}/api/v1${path}"
  token=$(_portal_token)

  if [ -n "$token" ]; then
    curl -sf --max-time 10 \
      -H "Authorization: Bearer ${token}" \
      -H "Accept: application/json" \
      "$@" "$url"
  else
    curl -sf --max-time 10 \
      -H "Accept: application/json" \
      "$@" "$url"
  fi
}

# _portal_get <path> — GET + return JSON
_portal_get() {
  _portal_curl "${1}" 2>/dev/null
}

# _portal_post <path> [json-body] — POST with JSON body
_portal_post() {
  local path="${1:-}"
  local body="${2:-{}}"
  _portal_curl "${path}" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$body" 2>/dev/null
}

# _portal_pp <json> — pretty-print JSON
_portal_pp() {
  if command -v python3 &>/dev/null; then
    python3 -m json.tool 2>/dev/null <<< "$1" || echo "$1"
  else
    echo "$1"
  fi
}

# _portal_has_json_flag — returns 0 if --json is in "$@"
_portal_has_json_flag() {
  for arg in "$@"; do
    [ "$arg" = "--json" ] && return 0
  done
  return 1
}

# ─── sync ─────────────────────────────────────────────────────
# atlas portal sync [--feature <id>] [--auto] [--json]
# POST /api/v1/devhub/sync/auto

_portal_sync() {
  local feature_id="" auto_mode=false json_mode=false

  while [ $# -gt 0 ]; do
    case "$1" in
      --feature)   feature_id="$2"; shift 2 ;;
      --feature=*) feature_id="${1#*=}"; shift ;;
      --auto)      auto_mode=true; shift ;;
      --json)      json_mode=true; shift ;;
      -h|--help|help) _portal_sync_help; return 0 ;;
      *) shift ;;
    esac
  done

  local auto_val="false"
  $auto_mode && auto_val="true"

  local body
  body=$(python3 -c "
import json, os, sys
payload = {
    'session_id': os.environ.get('CLAUDE_SESSION_ID', 'cli'),
    'source': 'atlas-cli',
    'auto': ${auto_val} == 'true',
}
if sys.argv[1]:
    payload['feature_id'] = sys.argv[1]
print(json.dumps(payload))
" "${feature_id:-}" 2>/dev/null || printf '{"source":"atlas-cli","auto":%s}' "$auto_val")

  printf "\n  ${ATLAS_BOLD}Portal Sync${ATLAS_RESET}\n"
  [ -n "$feature_id" ] && printf "  Feature:   ${ATLAS_CYAN}%s${ATLAS_RESET}\n" "$feature_id"
  $auto_mode           && printf "  Mode:      ${ATLAS_CYAN}auto${ATLAS_RESET}\n"
  printf "  Endpoint:  %s/api/v1/devhub/sync/auto\n" "$(_portal_base_url)"
  printf "  %s\n\n" "──────────────────────────────────────────"

  local data
  data=$(_portal_post "/devhub/sync/auto" "$body")
  local rc=$?

  if [ "$rc" -ne 0 ] || [ -z "$data" ]; then
    printf "  ${ATLAS_DIM}⚠️  Sync endpoint unreachable — DevHub may not be running${ATLAS_RESET}\n\n"
    printf "  Hint: Start backend with \`docker compose up -d\`\n\n"
    return 1
  fi

  if $json_mode; then
    _portal_pp "$data"
    return 0
  fi

  python3 -c "
import json, sys
try:
    d = json.loads(sys.argv[1])
    status  = d.get('status', '?')
    sync_id = d.get('sync_id') or d.get('id', '')
    ts      = d.get('triggered_at') or d.get('timestamp', '')
    files   = d.get('files_synced') or d.get('files', [])
    icon    = '✅' if status in ('queued','ok','accepted','synced','success') else '⚠️ '
    print(f'  {icon} {status}')
    if sync_id: print(f'  ID:       {sync_id}')
    if ts:      print(f'  Time:     {ts}')
    if isinstance(files, list) and files:
        print(f'  Files:    {len(files)} synced')
    elif files:
        print(f'  Files:    {files}')
except Exception as e:
    print(f'  (parse error: {e})')
    print(f'  Raw: {sys.argv[1][:200]}')
" "$data" 2>/dev/null || _portal_pp "$data"

  printf "\n"
}

_portal_sync_help() {
  cat <<'EOF'
atlas portal sync [flags] — trigger DevHub portal sync

POST /api/v1/devhub/sync/auto

Flags:
  --feature <id>    Sync a specific feature by ID
  --auto            Auto-sync mode (uses last known state)
  --json            Raw JSON output

Auth:
  ATLAS_HOOK_TOKEN  Bearer token (scoped to portal:sync-only)
  DEVHUB_URL        Override base URL (default: http://localhost:8001)

Examples:
  atlas portal sync
  atlas portal sync --feature FE-42
  atlas portal sync --auto
  atlas portal sync --json
EOF
}

# ─── status ───────────────────────────────────────────────────
# atlas portal status [--json]
# GET /api/v1/devhub/health + GET /api/v1/devhub/ecosystem

_portal_status() {
  local json_mode=false
  _portal_has_json_flag "$@" && json_mode=true

  printf "\n  ${ATLAS_BOLD}Portal Status${ATLAS_RESET}\n"
  printf "  %s\n\n" "────────────────────────────────────────────────────────────────────"

  # ── Health endpoint ──
  local health
  health=$(_portal_get "/devhub/health")
  if [ -z "$health" ]; then
    printf "  ❌ DevHub unreachable at %s\n\n" "$(_portal_base_url)"
    printf "  Hint: Set DEVHUB_URL or start backend with \`docker compose up -d\`\n\n"
    return 1
  fi

  if $json_mode; then
    printf "=== /devhub/health ===\n"
    _portal_pp "$health"
    local eco
    eco=$(_portal_get "/devhub/ecosystem")
    if [ -n "$eco" ]; then
      printf "\n=== /devhub/ecosystem ===\n"
      _portal_pp "$eco"
    fi
    return 0
  fi

  # ── Health summary ──
  python3 -c "
import json, sys
try:
    d = json.loads(sys.argv[1])
    status     = d.get('status', '?')
    last_sync  = d.get('last_sync_at') or d.get('last_sync', 'N/A')
    sync_count = d.get('sync_count', '?')
    pending    = d.get('pending_changes', 0)
    version    = d.get('version', '?')
    icon = '✅' if status in ('healthy','ok') else '⚠️ ' if status == 'degraded' else '❌'
    print(f'  {icon} {status.upper():<12}  v{version}')
    print(f'  Last sync:   {last_sync}')
    print(f'  Total syncs: {sync_count}')
    if pending:
        print(f'  Pending:     {pending} change(s) awaiting sync')
except Exception as e:
    print(f'  (parse error: {e})')
" "$health" 2>/dev/null

  # ── Ecosystem table ──
  local eco
  eco=$(_portal_get "/devhub/ecosystem")

  if [ -n "$eco" ]; then
    printf "\n  ${ATLAS_BOLD}Applications${ATLAS_RESET}\n"
    printf "  %-3s %-22s %-12s %-26s %-22s\n" "" "App" "Health" "Last Sync" "URL"
    printf "  %s\n" "────────────────────────────────────────────────────────────────────"
    python3 -c "
import json, sys
try:
    d = json.loads(sys.argv[1])
    apps = d.get('apps') or d.get('services') or d.get('data') or []
    if isinstance(d, list):
        apps = d
    for app in apps:
        name      = str(app.get('name') or app.get('app', ''))[:22]
        health    = str(app.get('health') or app.get('status', '?'))[:12]
        last_sync = str(app.get('last_sync_at') or app.get('last_sync', '—'))[:26]
        url       = str(app.get('url', ''))[:22]
        icon = '✅' if health in ('healthy','ok','green') else '⚠️ ' if health in ('degraded','warn') else '❌'
        print(f'  {icon}  {name:<22} {health:<12} {last_sync:<26} {url:<22}')
except Exception as e:
    print(f'  (parse error: {e})')
" "$eco" 2>/dev/null
  else
    printf "\n  ${ATLAS_DIM}(ecosystem endpoint not available)${ATLAS_RESET}\n"
  fi

  printf "\n  ${ATLAS_DIM}Base: $(_portal_base_url)${ATLAS_RESET}\n\n"
}

# ─── diff ─────────────────────────────────────────────────────
# atlas portal diff [--since-last-week] [--since <ISO>] [--json]
# GET /api/v1/devhub/health (drift details)

_portal_diff() {
  local since="" json_mode=false

  while [ $# -gt 0 ]; do
    case "$1" in
      --since-last-week)
        # GNU date (-d) on Linux; BSD date (-v) on macOS
        since=$(date -d '7 days ago' '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
          || date -v-7d '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
          || echo "")
        shift ;;
      --since=*) since="${1#*=}"; shift ;;
      --since)   since="$2"; shift 2 ;;
      --json)    json_mode=true; shift ;;
      -h|--help|help) _portal_diff_help; return 0 ;;
      *) shift ;;
    esac
  done

  local qs=""
  [ -n "$since" ] && qs="?since=${since}"

  printf "\n  ${ATLAS_BOLD}Portal Drift Report${ATLAS_RESET}\n"
  [ -n "$since" ] && printf "  Since:  ${ATLAS_CYAN}%s${ATLAS_RESET}\n" "$since"
  printf "  %s\n\n" "──────────────────────────────────────────────────────"

  local data
  data=$(_portal_get "/devhub/health${qs}")
  if [ -z "$data" ]; then
    printf "  ❌ DevHub unreachable at %s\n\n" "$(_portal_base_url)"
    return 1
  fi

  if $json_mode; then
    _portal_pp "$data"
    return 0
  fi

  python3 -c "
import json, sys
try:
    d = json.loads(sys.argv[1])

    # Drift details — may be nested under 'drift' key
    drift = d.get('drift') or d.get('changes') or {}
    if isinstance(drift, dict):
        drift_items = drift.get('items') or drift.get('changes') or []
    elif isinstance(drift, list):
        drift_items = drift
    else:
        drift_items = []

    status    = d.get('status', '?')
    last_sync = d.get('last_sync_at') or d.get('last_sync', 'N/A')
    drift_cnt = d.get('drift_count') or len(drift_items)

    icon = '✅' if status in ('healthy','ok') else '⚠️ '
    print(f'  {icon} Status:    {status}')
    print(f'  Last sync: {last_sync}')
    print(f'  Drift:     {drift_cnt} item(s)')

    if drift_items:
        print()
        print(f'  {\"File\":<42} {\"Type\":<18} Severity')
        print(f'  {\"─\"*42} {\"─\"*18} {\"─\"*10}')
        for item in drift_items[:20]:
            path     = str(item.get('path') or item.get('file', ''))[:42]
            kind     = str(item.get('type') or item.get('kind', 'change'))[:18]
            severity = str(item.get('severity', 'medium'))
            sev_icon = '🔴' if severity in ('critical','high') else '🟡' if severity == 'medium' else '🟢'
            print(f'  {path:<42} {kind:<18} {sev_icon} {severity}')
        if len(drift_items) > 20:
            print(f'  ... and {len(drift_items)-20} more item(s)')
    else:
        print()
        print('  ✅ No drift detected — portal is in sync')

except Exception as e:
    print(f'  (parse error: {e})')
    print(f'  Raw: {sys.argv[1][:300]}')
" "$data" 2>/dev/null

  printf "\n"
}

_portal_diff_help() {
  cat <<'EOF'
atlas portal diff [flags] — show DevHub portal drift report

GET /api/v1/devhub/health

Flags:
  --since-last-week     Show drift from the past 7 days
  --since <ISO8601>     Show drift since a specific timestamp
  --json                Raw JSON output

Auth:
  ATLAS_HOOK_TOKEN  Bearer token
  DEVHUB_URL        Override base URL (default: http://localhost:8001)

Examples:
  atlas portal diff
  atlas portal diff --since-last-week
  atlas portal diff --since 2026-04-19T00:00:00Z
  atlas portal diff --json
EOF
}

# ─── Main Dispatch ────────────────────────────────────────────

_atlas_portal_cmd() {
  local subcmd="${1:-help}"
  shift 2>/dev/null || true
  case "$subcmd" in
    sync|s)              _portal_sync "$@" ;;
    status|st)           _portal_status "$@" ;;
    diff|d)              _portal_diff "$@" ;;
    -h|--help|help|"")   _portal_help ;;
    *) echo "Unknown portal subcommand: '$subcmd'. Run 'atlas portal help'." >&2; return 1 ;;
  esac
}

_portal_help() {
  cat <<'EOF'
atlas portal — DevHub cockpit sync/status/diff commands

Subcommands:
  sync [--feature <id>] [--auto]   Trigger portal sync (POST /devhub/sync/auto)
  status                           App health + last sync table (5+ apps)
  diff [--since-last-week]         Drift report (GET /devhub/health)

Aliases: s=sync, st=status, d=diff

Global flags:
  --json      Raw JSON output (all commands)
  --help, -h  Show command help

Auth (in order of precedence):
  ATLAS_HOOK_TOKEN   Bearer token scoped to portal:sync-only
  DEVHUB_URL         Override base URL (default: http://localhost:8001)

Examples:
  atlas portal sync
  atlas portal sync --feature FE-42 --json
  atlas portal status
  atlas portal diff --since-last-week
  atlas portal diff --json
EOF
}
