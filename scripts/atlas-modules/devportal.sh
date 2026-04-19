#!/usr/bin/env bash
# shellcheck shell=bash
# NOTE: Sourced by scripts/atlas-cli.sh (no set -euo pipefail at file level).
# ATLAS CLI Module: DevPortal — engineering workspace commands
# Sourced by atlas-cli.sh — do not execute directly
#
# Usage:  atlas devportal <subcmd> [args]
# Alias:  atlas dp <subcmd> [args]
#
# Env overrides:
#   DEVPORTAL_URL    Base URL (default: http://localhost:8001)
#   DEVPORTAL_TOKEN  Bearer token (default: from ~/.atlas/credentials.json)

# ─── Helpers ──────────────────────────────────────────────────

_dp_base_url() {
  echo "${DEVPORTAL_URL:-http://localhost:8001}"
}

_dp_token() {
  if [ -n "${DEVPORTAL_TOKEN:-}" ]; then
    echo "$DEVPORTAL_TOKEN"
    return
  fi
  local creds="$HOME/.atlas/credentials.json"
  if [ -f "$creds" ] && command -v python3 &>/dev/null; then
    python3 -c "
import json, sys
try:
    d = json.load(open('$creds'))
    print(d.get('token') or d.get('access_token') or d.get('devportal_token') or '')
except Exception:
    print('')
" 2>/dev/null
  fi
}

# _dp_curl <path> [extra curl args...]
_dp_curl() {
  local path="${1:-/}"
  shift
  local base url token
  base=$(_dp_base_url)
  url="${base}${path}"
  token=$(_dp_token)

  if [ -z "$token" ]; then
    echo "Error: Not authenticated. Run 'atlas login' first." >&2
    echo "Hint: DevPortal requires CF Access SSO." >&2
    return 1
  fi

  curl -sf --max-time 10 \
    -H "Authorization: Bearer ${token}" \
    -H "Accept: application/json" \
    "$@" "$url"
}

# _dp_get <path> — GET + return JSON
_dp_get() {
  _dp_curl "/api/v1/devportal${1}" 2>/dev/null
}

# _dp_post <path> [json-body] — POST with JSON body
_dp_post() {
  local path="${1:-}"
  local body="${2:-{}}"
  _dp_curl "/api/v1/devportal${path}" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$body" 2>/dev/null
}

# _dp_json_flag — check if --json flag present in $@
_dp_has_json_flag() {
  for arg in "$@"; do
    [ "$arg" = "--json" ] && return 0
  done
  return 1
}

# _dp_pp <json> — pretty-print JSON
_dp_pp() {
  if command -v python3 &>/dev/null; then
    python3 -m json.tool 2>/dev/null <<< "$1" || echo "$1"
  else
    echo "$1"
  fi
}

# ─── Plan Commands ────────────────────────────────────────────

_dp_plan_list() {
  local phase="" sprint="" owner="" json_mode=false
  while [ $# -gt 0 ]; do
    case "$1" in
      --phase)  phase="$2";  shift 2 ;;
      --sprint) sprint="$2"; shift 2 ;;
      --owner)  owner="$2";  shift 2 ;;
      --json)   json_mode=true; shift ;;
      *) shift ;;
    esac
  done

  local qs="?"
  [ -n "$phase" ]  && qs="${qs}phase=${phase}&"
  [ -n "$sprint" ] && qs="${qs}sprint=${sprint}&"
  [ -n "$owner" ]  && qs="${qs}owner=${owner}&"
  qs="${qs%&}"
  [ "$qs" = "?" ] && qs=""

  local data
  data=$(_dp_get "/plans${qs}") || return 1

  if $json_mode; then
    _dp_pp "$data"
    return
  fi

  printf "\n  ${ATLAS_BOLD}PLANS${ATLAS_RESET}\n"
  printf "  %s\n" "─────────────────────────────────────────────────────────────────"
  printf "  %-18s %-36s %-12s %-8s %-6s %-8s\n" \
    "ID" "Title" "Status" "Effort" "Phase" "Sprint"
  printf "  %s\n" "─────────────────────────────────────────────────────────────────"

  python3 -c "
import json, sys
try:
    items = json.loads(sys.argv[1])
    if isinstance(items, dict):
        items = items.get('items') or items.get('plans') or items.get('data') or []
    for p in items:
        pid    = str(p.get('id',''))[:18]
        title  = str(p.get('title',''))[:36]
        status = str(p.get('status',''))[:12]
        effort = str(p.get('effort',''))[:8]
        phase  = str(p.get('phase',''))[:6]
        sprint = str(p.get('sprint',''))[:8]
        print(f'  {pid:<18} {title:<36} {status:<12} {effort:<8} {phase:<6} {sprint:<8}')
except Exception as e:
    print(f'  (parse error: {e})', file=sys.stderr)
" "$data" 2>/dev/null || echo "  (no plans or parse error)"
  echo
}

_dp_plan_show() {
  local plan_id="${1:-}"
  if [ -z "$plan_id" ]; then
    echo "Usage: atlas dp plan show <plan-id>" >&2
    return 1
  fi
  local data
  data=$(_dp_get "/plans/${plan_id}") || return 1
  _dp_pp "$data"
}

_dp_plan_claim() {
  local arg="${1:-}"
  if [ -z "$arg" ]; then
    echo "Usage: atlas dp plan claim <plan-id>/<task-id>" >&2
    return 1
  fi
  local plan_id task_id
  plan_id="${arg%%/*}"
  task_id="${arg#*/}"
  if [ "$plan_id" = "$task_id" ]; then
    echo "Error: expected <plan-id>/<task-id> format" >&2
    return 1
  fi
  local body="{\"assignee\":\"${USER}\"}"
  local data
  data=$(_dp_post "/plans/${plan_id}/tasks/${task_id}/claim" "$body") || return 1
  echo "Claimed task ${task_id} in plan ${plan_id}"
  _dp_pp "$data"
}

_dp_plan_start() {
  local plan_id="${1:-}"
  if [ -z "$plan_id" ]; then
    echo "Usage: atlas dp plan start <plan-id>" >&2
    return 1
  fi
  local body="{\"status\":\"in_progress\"}"
  local data
  data=$(_dp_post "/plans/${plan_id}/status" "$body") || return 1
  echo "Plan ${plan_id} set to in_progress"
  _dp_pp "$data"
}

_dp_plan_cmd() {
  local subcmd="${1:-list}"
  shift 2>/dev/null || true
  case "$subcmd" in
    list|ls)    _dp_plan_list "$@" ;;
    show|get)   _dp_plan_show "$@" ;;
    claim)      _dp_plan_claim "$@" ;;
    start)      _dp_plan_start "$@" ;;
    -h|--help|help|"") _dp_plan_help ;;
    *) echo "Unknown plan subcommand: '$subcmd'. Run 'atlas dp plan help'." >&2; return 1 ;;
  esac
}

_dp_plan_help() {
  cat <<'EOF'
atlas dp plan <subcommand> — manage engineering plans

Subcommands:
  list [--phase G3] [--sprint SP-17] [--owner sgagnon]
                              List plans with optional filters
  show <plan-id>              Show plan details (JSON)
  claim <plan-id>/<task-id>   Claim a task (assigns to current user)
  start <plan-id>             Set plan status to in_progress

Examples:
  atlas dp plan list
  atlas dp plan list --phase G3 --sprint SP-17
  atlas dp plan show SP-DEVPORTAL
  atlas dp plan claim SP-17/T-001
  atlas dp plan start SP-17
EOF
}

# ─── Gate Commands ────────────────────────────────────────────

_dp_gate_cmd() {
  local subcmd="${1:-check}"
  shift 2>/dev/null || true
  case "$subcmd" in
    check) _dp_gate_check "$@" ;;
    -h|--help|help|"") _dp_gate_help ;;
    *) echo "Unknown gate subcommand: '$subcmd'. Run 'atlas dp gate help'." >&2; return 1 ;;
  esac
}

_dp_gate_check() {
  local phase="" plan_id=""
  local pos_arg=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --plan) plan_id="$2"; shift 2 ;;
      --phase) phase="$2"; shift 2 ;;
      *) pos_arg="$1"; shift ;;
    esac
  done
  [ -n "$pos_arg" ] && [ -z "$phase" ] && phase="$pos_arg"

  if [ -z "$phase" ]; then
    echo "Usage: atlas dp gate check <phase> [--plan <plan-id>]" >&2
    return 1
  fi

  local qs="?phase=${phase}"
  [ -n "$plan_id" ] && qs="${qs}&plan_id=${plan_id}"

  local data
  data=$(_dp_get "/gates/check${qs}") || return 1

  printf "\n  Gate Check: %s\n" "$phase"
  printf "  %s\n" "──────────────────────────────"
  python3 -c "
import json, sys
try:
    d = json.loads(sys.argv[1])
    layers = d.get('layers') or d.get('results') or []
    for layer in layers:
        name  = layer.get('name','?')
        ok    = layer.get('pass') or layer.get('ok') or False
        score = layer.get('score','')
        icon  = '✅' if ok else '❌'
        print(f'  {icon} {name:<30} {score}')
    total = d.get('total_score') or d.get('score','')
    status = d.get('status','')
    print(f'\n  Total: {total}  Status: {status}')
except Exception as e:
    print(sys.argv[1])
" "$data" 2>/dev/null || _dp_pp "$data"
  echo
}

_dp_gate_help() {
  cat <<'EOF'
atlas dp gate <subcommand> — check DoD gates

Subcommands:
  check <phase> [--plan <plan-id>]    Verify DoD pass/fail for a phase

Examples:
  atlas dp gate check G3 --plan SP-17
  atlas dp gate check G2
EOF
}

# ─── Catalog Commands ─────────────────────────────────────────

_dp_catalog_cmd() {
  local subcmd="${1:-list}"
  shift 2>/dev/null || true
  case "$subcmd" in
    list|ls)   _dp_catalog_list "$@" ;;
    search|s)  _dp_catalog_search "$@" ;;
    show|get)  _dp_catalog_show "$@" ;;
    -h|--help|help|"") _dp_catalog_help ;;
    *) echo "Unknown catalog subcommand: '$subcmd'. Run 'atlas dp catalog help'." >&2; return 1 ;;
  esac
}

_dp_catalog_list() {
  local kind="" json_mode=false
  while [ $# -gt 0 ]; do
    case "$1" in
      --kind) kind="$2"; shift 2 ;;
      --json) json_mode=true; shift ;;
      *) shift ;;
    esac
  done

  local qs=""
  [ -n "$kind" ] && qs="?kind=${kind}"

  local data
  data=$(_dp_get "/catalog${qs}") || return 1

  if $json_mode; then
    _dp_pp "$data"
    return
  fi

  printf "\n  ${ATLAS_BOLD}CATALOG${ATLAS_RESET}\n"
  printf "  %-20s %-16s %-40s\n" "Name" "Kind" "Description"
  printf "  %s\n" "──────────────────────────────────────────────────────────────────"
  python3 -c "
import json, sys
try:
    items = json.loads(sys.argv[1])
    if isinstance(items, dict):
        items = items.get('items') or items.get('data') or []
    for e in items:
        name = str(e.get('name',''))[:20]
        kind = str(e.get('kind',''))[:16]
        desc = str(e.get('description',''))[:40]
        print(f'  {name:<20} {kind:<16} {desc:<40}')
except Exception as e:
    print(f'  (parse error: {e})', file=sys.stderr)
" "$data" 2>/dev/null || echo "  (no entries or parse error)"
  echo
}

_dp_catalog_search() {
  local query="${1:-}"
  if [ -z "$query" ]; then
    echo "Usage: atlas dp catalog search <query>" >&2
    return 1
  fi
  local encoded_q
  encoded_q=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$query" 2>/dev/null || echo "$query")
  local data
  data=$(_dp_get "/catalog/search?q=${encoded_q}") || return 1
  _dp_pp "$data"
}

_dp_catalog_show() {
  local arg="${1:-}"
  if [ -z "$arg" ]; then
    echo "Usage: atlas dp catalog show <kind>/<name>" >&2
    return 1
  fi
  local kind name
  kind="${arg%%/*}"
  name="${arg#*/}"
  local data
  data=$(_dp_get "/catalog/${kind}/${name}") || return 1
  _dp_pp "$data"
}

_dp_catalog_help() {
  cat <<'EOF'
atlas dp catalog <subcommand> — browse component catalog

Subcommands:
  list [--kind component]     List catalog entries (optional kind filter)
  search <query>              Full-text search
  show <kind>/<name>          Show entry details

Examples:
  atlas dp catalog list
  atlas dp catalog list --kind component
  atlas dp catalog search "pressure transmitter"
  atlas dp catalog show instrument/PT-101
EOF
}

# ─── ADR Commands ─────────────────────────────────────────────

_dp_adr_cmd() {
  local subcmd="${1:-list}"
  shift 2>/dev/null || true
  case "$subcmd" in
    list|ls) _dp_adr_list "$@" ;;
    show)    _dp_adr_show "$@" ;;
    -h|--help|help|"") _dp_adr_help ;;
    *) echo "Unknown adr subcommand: '$subcmd'. Run 'atlas dp adr help'." >&2; return 1 ;;
  esac
}

_dp_adr_list() {
  local status="" json_mode=false
  while [ $# -gt 0 ]; do
    case "$1" in
      --status) status="$2"; shift 2 ;;
      --json) json_mode=true; shift ;;
      *) shift ;;
    esac
  done

  local qs=""
  [ -n "$status" ] && qs="?status=${status}"

  local data
  data=$(_dp_get "/adrs${qs}") || return 1

  if $json_mode; then
    _dp_pp "$data"
    return
  fi

  printf "\n  ${ATLAS_BOLD}ADRs${ATLAS_RESET}\n"
  printf "  %-12s %-10s %-44s %s\n" "ID" "Status" "Title" "Date"
  printf "  %s\n" "─────────────────────────────────────────────────────────────────"
  python3 -c "
import json, sys
try:
    items = json.loads(sys.argv[1])
    if isinstance(items, dict):
        items = items.get('items') or items.get('adrs') or items.get('data') or []
    for a in items:
        aid    = str(a.get('id',''))[:12]
        status = str(a.get('status',''))[:10]
        title  = str(a.get('title',''))[:44]
        date   = str(a.get('date') or a.get('created_at',''))[:10]
        print(f'  {aid:<12} {status:<10} {title:<44} {date}')
except Exception as e:
    print(f'  (parse error: {e})', file=sys.stderr)
" "$data" 2>/dev/null || echo "  (no ADRs or parse error)"
  echo
}

_dp_adr_show() {
  local adr_id="${1:-}"
  if [ -z "$adr_id" ]; then
    echo "Usage: atlas dp adr show <adr-id>" >&2
    return 1
  fi
  local data
  data=$(_dp_get "/adrs/${adr_id}") || return 1
  _dp_pp "$data"
}

_dp_adr_help() {
  cat <<'EOF'
atlas dp adr <subcommand> — manage Architecture Decision Records

Subcommands:
  list [--status accepted]    List ADRs (optional status filter)
  show <adr-id>               Show ADR details

Examples:
  atlas dp adr list
  atlas dp adr list --status accepted
  atlas dp adr show ADR-007
EOF
}

# ─── Roadmap Command ──────────────────────────────────────────

_dp_roadmap() {
  local json_mode=false
  for arg in "$@"; do
    [ "$arg" = "--json" ] && json_mode=true
  done

  local data
  data=$(_dp_get "/roadmap") || return 1

  if $json_mode; then
    _dp_pp "$data"
    return
  fi

  printf "\n  ${ATLAS_BOLD}ROADMAP${ATLAS_RESET}\n"
  printf "  %s\n" "──────────────────────────────────────────────────────────────"
  python3 -c "
import json, sys
try:
    d = json.loads(sys.argv[1])
    phases = d.get('phases') or d.get('items') or d.get('data') or []
    for phase in phases:
        name = phase.get('name') or phase.get('id','?')
        status = phase.get('status','')
        icon = {'done':'✅','active':'🔄','planned':'📋','blocked':'🚫'}.get(status,'  ')
        print(f'  {icon} {name}  [{status}]')
        plans = phase.get('plans') or []
        for p in plans:
            pid = p.get('id','?')
            title = p.get('title','')[:40]
            print(f'       ├─ {pid:<16} {title}')
except Exception as e:
    print(sys.argv[1])
" "$data" 2>/dev/null || _dp_pp "$data"
  echo
}

# ─── Open Command ─────────────────────────────────────────────

_dp_open() {
  local tui=false url
  for arg in "$@"; do
    [ "$arg" = "--tui" ] && tui=true
  done

  local base
  base="${DEVPORTAL_URL:-http://localhost:8001}"
  # Production URL fallback
  local prod_url="https://synapse.axoiq.com"
  url="${base}/devportal"

  if $tui; then
    local data
    data=$(_dp_get "/plans?limit=20") || return 1
    printf "\n  ${ATLAS_BOLD}DevPortal — TUI Preview${ATLAS_RESET}\n"
    printf "  ${ATLAS_DIM}%s${ATLAS_RESET}\n\n" "$url"
    _dp_plan_list --json=false 2>/dev/null
    return
  fi

  # Try to open browser
  if command -v xdg-open &>/dev/null; then
    xdg-open "$url" 2>/dev/null &
    echo "Opening: $url"
  elif command -v open &>/dev/null; then
    open "$url" 2>/dev/null
    echo "Opening: $url"
  else
    echo "DevPortal URL: $url"
    echo "Hint: No browser launcher found (xdg-open / open). Visit URL manually."
  fi
}

# ─── Chat Command ─────────────────────────────────────────────

# _dp_chat_base_url — resolve base URL (ATLAS_ENV=dev → localhost, else prod)
_dp_chat_base_url() {
  if [ -n "${DEVPORTAL_URL:-}" ]; then
    echo "$DEVPORTAL_URL"
    return
  fi
  if [ "${ATLAS_ENV:-}" = "dev" ]; then
    echo "http://localhost:8001"
  else
    echo "https://synapse.axoiq.com"
  fi
}

# _dp_chat_token — resolve auth token (ATLAS_TOKEN > DEVPORTAL_TOKEN > credentials.json)
_dp_chat_token() {
  if [ -n "${ATLAS_TOKEN:-}" ]; then
    echo "$ATLAS_TOKEN"
    return
  fi
  _dp_token
}

# _dp_chat_stream <query> — POST to /devportal/chat/stream, stream SSE to stdout
_dp_chat_stream() {
  local query="${1:-}"
  local base token stream_url
  base=$(_dp_chat_base_url)
  token=$(_dp_chat_token)
  stream_url="${base}/api/v1/devportal/chat/stream"

  if [ -z "$token" ]; then
    echo "Error: Not authenticated. Set ATLAS_TOKEN or run 'atlas login'." >&2
    return 1
  fi

  local body
  body=$(python3 -c "import json,sys; print(json.dumps({'message': sys.argv[1]}))" "$query" 2>/dev/null \
    || printf '{"message":"%s"}' "$query")

  # Attempt primary streaming endpoint
  local http_status
  http_status=$(curl -sS --max-time 30 -o /tmp/_dp_chat_body.tmp -w "%{http_code}" \
    -X POST \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -H "Accept: text/event-stream" \
    -d "$body" \
    "$stream_url" 2>/dev/null)

  if [ "$http_status" = "404" ] || [ "$http_status" = "000" ]; then
    # Degraded fallback — direct MCP search call
    echo "[devportal-chat] Stream endpoint not available (${http_status}), falling back to MCP search..." >&2
    _dp_chat_fallback_search "$query" "$base" "$token"
    return
  fi

  if [ "$http_status" != "200" ]; then
    echo "Error: DevPortal chat returned HTTP ${http_status}." >&2
    cat /tmp/_dp_chat_body.tmp 2>/dev/null >&2
    return 1
  fi

  # Parse and render SSE events from buffered response
  _dp_chat_render_sse /tmp/_dp_chat_body.tmp
}

# _dp_chat_render_sse <file> — render SSE events from file
_dp_chat_render_sse() {
  local file="${1:-}"
  [ ! -f "$file" ] && return 1

  local event="" data=""
  while IFS= read -r line; do
    case "$line" in
      event:*)
        event="${line#event: }"
        event="${event#event:}"
        ;;
      data:*)
        data="${line#data: }"
        data="${data#data:}"
        ;;
      "")
        # Dispatch on event type
        case "$event" in
          status)
            echo "  [${data}]" ;;
          tool_call)
            python3 -c "
import json, sys
try:
    d = json.loads(sys.argv[1])
    name = d.get('tool','?')
    args = json.dumps(d.get('args',{}), separators=(',',':'))
    print(f'  → {name}({args})')
except Exception:
    print(f'  → {sys.argv[1]}')
" "$data" 2>/dev/null || echo "  → $data" ;;
          token)
            printf "%s" "$data" ;;
          done)
            echo ;;
          error)
            echo "Error: $data" >&2 ;;
        esac
        event=""; data=""
        ;;
    esac
  done < "$file"
}

# _dp_chat_fallback_search <query> <base> <token> — degraded MCP direct call
_dp_chat_fallback_search() {
  local query="${1:-}" base="${2:-}" token="${3:-}"
  local mcp_url="${base}/api/v1/devportal/mcp/sse"
  local body
  body=$(python3 -c "
import json, sys
msg = {'jsonrpc':'2.0','id':1,'method':'tools/call','params':{'name':'devportal.search','arguments':{'query':sys.argv[1]}}}
print(json.dumps(msg))
" "$query" 2>/dev/null || echo '{}')

  printf "\n  ${ATLAS_BOLD}Search Results${ATLAS_RESET} (degraded mode)\n"
  printf "  %s\n" "──────────────────────────────────────────────"

  local resp
  resp=$(curl -sS --max-time 15 \
    -X POST \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -H "Accept: text/event-stream" \
    -d "$body" \
    "$mcp_url" 2>/dev/null)

  if [ -z "$resp" ]; then
    echo "  (no response from MCP endpoint)" >&2
    return 1
  fi

  python3 -c "
import json, sys
lines = sys.argv[1].strip().split('\n')
for line in lines:
    if line.startswith('data:'):
        raw = line[5:].strip()
        try:
            d = json.loads(raw)
            result = d.get('result') or d
            items = result.get('items') or result.get('results') or []
            if isinstance(items, list):
                for item in items[:10]:
                    kind = item.get('kind','?')
                    title = item.get('title') or item.get('name','?')
                    score = item.get('score','')
                    print(f'  [{kind}] {title}  {score}')
            else:
                print(json.dumps(result, indent=2))
        except Exception:
            print(f'  {raw}')
" "$resp" 2>/dev/null || echo "  (parse error)"
  echo
}

_dp_chat_help() {
  cat <<'EOF'
atlas dp chat <query> — interactive DevPortal query via MCP

Usage:
  atlas dp chat "<natural language query>"
  atlas dp chat --help

Examples:
  atlas dp chat "show me all SP plans for G3"
  atlas dp chat "what entities are in domain:engineering"
  atlas dp chat "summarize ADR-020"
  atlas dp chat "list active plans owned by sgagnon"
  atlas dp chat "claim task T-001 on SP-17"

Env overrides:
  ATLAS_TOKEN      Bearer token (fallback: DEVPORTAL_TOKEN, ~/.atlas/credentials.json)
  ATLAS_ENV=dev    Use localhost:8001 instead of synapse.axoiq.com
  DEVPORTAL_URL    Override base URL entirely

Modes:
  Primary: POST /api/v1/devportal/chat/stream (SSE streaming)
  Fallback: POST /api/v1/devportal/mcp/sse with devportal.search (if 404)
EOF
}

_dp_chat_cmd() {
  local query=""
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help|help) _dp_chat_help; return 0 ;;
      "") shift ;;
      *) query="${query}${query:+ }$1"; shift ;;
    esac
  done

  if [ -z "$query" ]; then
    echo "Error: Query required. Usage: atlas dp chat \"<query>\"" >&2
    echo "Run 'atlas dp chat --help' for examples." >&2
    return 1
  fi

  printf "\n  ${ATLAS_BOLD}DevPortal Chat${ATLAS_RESET}  ${ATLAS_DIM}%s${ATLAS_RESET}\n" "$query"
  printf "  %s\n\n" "──────────────────────────────────────────────"
  _dp_chat_stream "$query"
  local rc=$?
  rm -f /tmp/_dp_chat_body.tmp 2>/dev/null
  return $rc
}

# ─── Main Dispatch ────────────────────────────────────────────

_atlas_devportal_cmd() {
  local subcmd="${1:-help}"
  shift 2>/dev/null || true
  case "$subcmd" in
    open|o)              _dp_open "$@" ;;
    plan|plans)          _dp_plan_cmd "$@" ;;
    gate|gates)          _dp_gate_cmd "$@" ;;
    catalog|cat)         _dp_catalog_cmd "$@" ;;
    adr|adrs)            _dp_adr_cmd "$@" ;;
    roadmap|road|rm)     _dp_roadmap "$@" ;;
    chat|c)              _dp_chat_cmd "$@" ;;
    -h|--help|help|"")   _dp_help ;;
    *) echo "Unknown devportal subcommand: '$subcmd'. Run 'atlas dp help'." >&2; return 1 ;;
  esac
}

_dp_help() {
  cat <<'EOF'
atlas devportal (alias: dp) — engineering workspace commands

Subcommands:
  open [--tui]                        Open DevPortal in browser (or TUI preview)
  plan list [--phase G3] [--sprint SP-17] [--owner sgagnon]
  plan show <plan-id>
  plan claim <plan-id>/<task-id>
  plan start <plan-id>
  gate check <phase> [--plan <id>]    Verify DoD pass/fail
  catalog list [--kind component]
  catalog search <query>
  catalog show <kind>/<name>
  adr list [--status accepted]
  adr show <adr-id>
  roadmap [--json]                    Structured roadmap tree
  chat "<query>"                      Interactive MCP chat (natural language)

Shortcuts:
  atlas roadmap [--json]              → atlas dp roadmap

Global flags:
  --json      Raw JSON output (most commands)

Auth:
  DEVPORTAL_URL    Override base URL (default: http://localhost:8001)
  DEVPORTAL_TOKEN  Override token (default: from ~/.atlas/credentials.json)
  ATLAS_TOKEN      Alt token (takes priority over DEVPORTAL_TOKEN)
  ATLAS_ENV=dev    Use localhost:8001 for chat commands

Examples:
  atlas dp plan list --phase G3
  atlas dp plan claim SP-17/T-001
  atlas dp gate check G3 --plan SP-17
  atlas dp catalog search "pressure transmitter"
  atlas dp adr list --status accepted
  atlas dp chat "show me all SP plans for G3"
  atlas dp chat "summarize ADR-020"
  atlas roadmap --json
EOF
}
