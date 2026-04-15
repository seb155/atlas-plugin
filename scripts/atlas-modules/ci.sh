#!/usr/bin/env bash
# shellcheck shell=bash
# NOTE: Sourced by scripts/atlas-cli.sh (no set -euo pipefail at file level).
# ATLAS CLI Module: CI (Woodpecker) — extended subcommands
# Sourced by atlas-cli.sh — do not execute directly
#
# Extends the `atlas ci` subcommand (originally in subcommands.sh) with:
#   atlas ci                  → pipeline list (legacy _atlas_ci, preserved)
#   atlas ci logs <N>         → step table for pipeline N
#   atlas ci logs <N> --step <name|pid|step_id>  → decoded log for step
#   atlas ci logs <N> --all   → decoded log for all steps sequentially
#
# API (Woodpecker 3.14):
#   GET /api/repos/{repo_id}/pipelines/{number}    — metadata (status, workflows, steps)
#   GET /api/repos/{repo_id}/logs/{number}/{stepID} — step logs (JSON array, base64 .data)
#
# Gotchas documented in skills/ci-management/references/woodpecker-api-paths.md:
#   - step_id != pid — step_id is DB id; pid is position in workflow.
#   - On wrong path, Woodpecker returns SPA HTML 200 (SPA fallback), not 404.

_ATLAS_CI_REPO_ID="${WP_REPO_ID:-1}"
_ATLAS_CI_URL="${WP_URL:-https://ci.axoiq.com}"
_ATLAS_CI_MODULE_VERSION="5.18.0"

# Path to the watch renderer (sibling of this module)
_ATLAS_CI_RENDER_PY="$(dirname "${BASH_SOURCE[0]}")/ci_watch_render.py"

# ─── Helper: ensure WP_TOKEN is loaded ───────────────────────────
_atlas_ci_load_token() {
  if [ -n "${WP_TOKEN:-}" ]; then return 0; fi
  if [ -f "$HOME/.env" ]; then
    WP_TOKEN=$(/bin/grep '^WP_TOKEN=' "$HOME/.env" 2>/dev/null | /usr/bin/cut -d= -f2- | /usr/bin/tr -d '"' || echo "")
    export WP_TOKEN
  fi
  if [ -z "${WP_TOKEN:-}" ]; then
    echo "❌ WP_TOKEN not set. Generate at ${_ATLAS_CI_URL}/user/cli-and-api" >&2
    return 1
  fi
}

# ─── Main dispatcher: atlas ci [<subcommand>] ────────────────────
_atlas_ci_cmd() {
  local sub="${1:-}"
  if [ -z "$sub" ]; then
    _atlas_ci
    return
  fi
  shift
  case "$sub" in
    logs)         _atlas_ci_logs "$@"; return ;;
    status)       _atlas_ci; return ;;
    list|pipelines|pipes) _atlas_ci_pipelines "$@"; return ;;
    pipeline|info) _atlas_ci_pipeline_info "$@"; return ;;
    rerun|restart|retry) _atlas_ci_rerun "$@"; return ;;
    watch|follow) _atlas_ci_watch "$@"; return ;;
    secrets|secret) _atlas_ci_secrets "$@"; return ;;
    agents|agent) _atlas_ci_agents "$@"; return ;;
    version)      echo "atlas-ci-module v${_ATLAS_CI_MODULE_VERSION}"; return 0 ;;
    help|--help|-h) _atlas_ci_help; return 0 ;;
    *) echo "atlas ci: unknown subcommand '$sub' — try 'atlas ci help'" >&2; return 1 ;;
  esac
}

# ─── Help text ───────────────────────────────────────────────────
_atlas_ci_help() {
  cat <<EOF

  atlas ci — Woodpecker CI helpers (v${_ATLAS_CI_MODULE_VERSION})

  PIPELINES:
    atlas ci                                Recent pipelines (short summary)
    atlas ci status                         Same as above (legacy alias)
    atlas ci list [--limit N]               Formatted table of recent pipelines
    atlas ci pipeline <N>                   Detailed JSON summary for pipeline N
    atlas ci rerun <N>                      Retrigger a pipeline
    atlas ci watch <N> [--interval S]       Poll until terminal state

  LOGS:
    atlas ci logs <N>                       Step table for pipeline N
    atlas ci logs <N> --step <name|pid|id>  Decoded logs for a step
    atlas ci logs <N> --all                 Decoded logs for every step

  SECRETS (repo-level):
    atlas ci secrets                        List secrets (names + events)
    atlas ci secrets set <n> <v> [--events] Add or update secret
    atlas ci secrets rm <name>              Delete secret

  AGENTS (admin):
    atlas ci agents                         Agent fleet (id/platform/last_seen)

  META:
    atlas ci help | version

  Environment:
    WP_TOKEN   (required — read from ~/.env if not set)
    WP_URL     (default: https://ci.axoiq.com)
    WP_REPO_ID (default: 1)

  Common workflows:
    # Diagnose a failing pipeline
    atlas ci logs 88 --step backend-lint

    # Rotate deploy SSH key
    atlas ci secrets set ssh_key "\$(cat ~/.ssh/deploy_key)" --events push

    # Retrigger + watch to green
    NEW=\$(atlas ci rerun 88 | awk '/pipeline #[0-9]+\$/{print \$NF}')
    atlas ci watch \$NEW

  Docs: .claude/plugins/cache/atlas-marketplace/atlas-dev/*/skills/ci-management/

EOF
}

# ─── atlas ci logs <pipeline> [--step <X>] [--all] ───────────────
_atlas_ci_logs() {
  local pipeline="${1:-}"
  if [ -z "$pipeline" ]; then
    echo "Usage: atlas ci logs <pipeline> [--step <name|pid|step_id>] [--all]" >&2
    return 1
  fi
  shift

  local step=""
  local all_steps=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --step)
        step="${2:-}"
        if [ -z "$step" ]; then
          echo "❌ --step requires an argument" >&2
          return 1
        fi
        shift 2
        ;;
      --all)  all_steps=1; shift ;;
      -h|--help) _atlas_ci_help; return 0 ;;
      *) echo "unknown option: $1" >&2; return 1 ;;
    esac
  done

  _atlas_ci_load_token || return 1

  # Fetch pipeline metadata
  local meta
  meta=$(/usr/bin/curl -sf --max-time 10 \
    -H "Authorization: Bearer ${WP_TOKEN}" \
    "${_ATLAS_CI_URL}/api/repos/${_ATLAS_CI_REPO_ID}/pipelines/${pipeline}" 2>&1) || {
    echo "❌ Failed to fetch pipeline ${pipeline} metadata." >&2
    echo "   Check WP_TOKEN validity, WP_URL (${_ATLAS_CI_URL}), and pipeline number." >&2
    return 1
  }

  # Guard: metadata must be JSON (not SPA fallback)
  if ! echo "$meta" | /usr/bin/head -c 1 | /bin/grep -q '^{'; then
    echo "❌ Got non-JSON response. WP_URL or WP_TOKEN may be wrong." >&2
    return 1
  fi

  # No --step, no --all → step table
  if [ -z "$step" ] && [ "$all_steps" = "0" ]; then
    _atlas_ci_logs_print_steps "$meta" "$pipeline"
    return 0
  fi

  # Resolve step_id list
  local step_ids
  if [ "$all_steps" = "1" ]; then
    step_ids=$(_atlas_ci_logs_resolve_all "$meta")
  else
    step_ids=$(_atlas_ci_logs_resolve "$meta" "$step")
    if [ -z "$step_ids" ]; then
      echo "❌ Step '${step}' not found in pipeline ${pipeline}." >&2
      echo "   Run 'atlas ci logs ${pipeline}' to list steps." >&2
      return 1
    fi
  fi

  # NOTE: use while-read (not 'for sid in $step_ids') for zsh compatibility:
  # zsh does not split unquoted parameter expansions on newlines by default.
  local sid
  while IFS= read -r sid; do
    [ -z "$sid" ] && continue
    _atlas_ci_logs_fetch "$pipeline" "$sid" "$meta"
  done <<< "$step_ids"
}

# ─── Internal: print step table from metadata JSON ───────────────
_atlas_ci_logs_print_steps() {
  local meta="$1"
  local pipeline="$2"
  # NOTE: avoid 'local status' — zsh marks it readonly
  local pipe_status
  pipe_status=$(/usr/bin/python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('status','?'))" "$meta" 2>/dev/null || echo "?")
  printf "\n  CI Pipeline #%s — status=%s\n\n" "$pipeline" "$pipe_status"
  printf "  %-8s %-5s %-30s %-10s %s\n" "step_id" "pid" "name" "state" "error"
  printf "  %-8s %-5s %-30s %-10s %s\n" "───────" "───" "────────────────────────" "─────" "─────"
  /usr/bin/python3 - "$meta" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
for wf in d.get('workflows', []) or []:
    for s in (wf.get('children') or []):
        state = s.get('state', '?')
        err = s.get('error', '') or ''
        err = (err[:40] + '…') if len(err) > 40 else err
        print(f"  {s['id']:<8} {s['pid']:<5} {s['name']:<30} {state:<10} {err}")
PY
  printf "\n  Usage: atlas ci logs %s --step <name|pid|step_id>\n\n" "$pipeline"
}

# ─── Internal: resolve step token (name/pid/step_id) → step_id ───
_atlas_ci_logs_resolve() {
  local meta="$1"
  local token="$2"
  /usr/bin/python3 - "$meta" "$token" <<'PY'
import json, sys
meta = json.loads(sys.argv[1])
tok = sys.argv[2]
steps = [(s['name'], s['pid'], s['id'])
         for wf in (meta.get('workflows') or [])
         for s in (wf.get('children') or [])]
hits = []
# 1. Numeric — try step_id first, then pid
if tok.isdigit():
    n = int(tok)
    for name, pid, sid in steps:
        if sid == n:
            hits.append(sid); break
    if not hits:
        for name, pid, sid in steps:
            if pid == n:
                hits.append(sid); break
# 2. String — exact, then prefix
if not hits:
    for name, pid, sid in steps:
        if name == tok:
            hits.append(sid); break
if not hits:
    for name, pid, sid in steps:
        if name.startswith(tok):
            hits.append(sid); break
for sid in hits:
    print(sid)
PY
}

# ─── Internal: resolve --all → every step_id ─────────────────────
_atlas_ci_logs_resolve_all() {
  local meta="$1"
  /usr/bin/python3 - "$meta" <<'PY'
import json, sys
meta = json.loads(sys.argv[1])
for wf in (meta.get('workflows') or []):
    for s in (wf.get('children') or []):
        print(s['id'])
PY
}

# ─── Internal: fetch + decode logs for one step ──────────────────
_atlas_ci_logs_fetch() {
  local pipeline="$1"
  local step_id="$2"
  local meta="$3"

  # Extract step name + state for the header
  local info
  info=$(/usr/bin/python3 - "$meta" "$step_id" <<'PY'
import json, sys
meta = json.loads(sys.argv[1])
sid = int(sys.argv[2])
for wf in (meta.get('workflows') or []):
    for s in (wf.get('children') or []):
        if s.get('id') == sid:
            print(f"{s.get('name','?')}|{s.get('state','?')}|{s.get('pid','?')}")
            sys.exit(0)
PY
)
  local step_name="${info%%|*}"
  local rest="${info#*|}"
  local step_state="${rest%%|*}"
  local step_pid="${rest##*|}"

  printf "\n=== step_id=%s pid=%s name=%s state=%s ===\n\n" \
    "$step_id" "$step_pid" "$step_name" "$step_state"

  # Skipped / pending steps have no logs
  case "$step_state" in
    skipped|pending|killed)
      echo "  (no log — step was ${step_state})"
      return 0
      ;;
  esac

  # Fetch logs JSON (empty 200 OK array when no logs)
  local log_json
  log_json=$(/usr/bin/curl -sf --max-time 30 \
    -H "Authorization: Bearer ${WP_TOKEN}" \
    "${_ATLAS_CI_URL}/api/repos/${_ATLAS_CI_REPO_ID}/logs/${pipeline}/${step_id}" 2>&1) || {
    echo "  (failed to fetch logs — HTTP error)" >&2
    return
  }

  # Sanity: must be JSON array (SPA fallback returns HTML)
  if ! echo "$log_json" | /usr/bin/head -c 1 | /bin/grep -q '^\['; then
    echo "  (unexpected non-JSON log payload — possible API mismatch)"
    return
  fi

  _atlas_ci_logs_decode "$log_json"
}

# ─── Internal: decode a Woodpecker logs JSON array → plain text ──
# Exposed as a named function (not embedded) so tests can call it
# with fixture JSON and assert decoded output.
#
# NOTE (2026-04-14): handle entries with data=None (tracing/metadata rows) —
# previously crashed with "'NoneType' object has no attribute 'rstrip'".
_atlas_ci_logs_decode() {
  local log_json="$1"
  /usr/bin/python3 - "$log_json" <<'PY'
import json, sys, base64
try:
    entries = json.loads(sys.argv[1])
    if not entries:
        print('  (empty log)')
        sys.exit(0)
    entries.sort(key=lambda x: x.get('line', 0))
    for e in entries:
        data = e.get('data')
        if data is None or data == '':
            # Tracing/metadata row with no payload — silently skip.
            continue
        try:
            decoded = base64.b64decode(data).decode('utf-8', errors='replace')
        except Exception:
            decoded = str(data)
        sys.stdout.write(decoded.rstrip('\n') + '\n')
except Exception as ex:
    print(f'  decode error: {ex}', file=sys.stderr)
PY
}

# =============================================================================
# v5.14.1+ — Expanded Woodpecker subcommands
# (atlas ci pipelines | rerun | watch | secrets | agents | pipeline)
# =============================================================================

# ─── atlas ci pipelines [--limit N] — list recent pipelines ──────
_atlas_ci_pipelines() {
  _atlas_ci_load_token || return 1
  local limit=10
  while [ $# -gt 0 ]; do
    case "$1" in
      --limit) limit="${2:-10}"; shift 2 ;;
      -h|--help) echo "Usage: atlas ci pipelines [--limit N]"; return 0 ;;
      *) shift ;;
    esac
  done
  local resp
  resp=$(/usr/bin/curl -sf --max-time 10 \
    -H "Authorization: Bearer ${WP_TOKEN}" \
    "${_ATLAS_CI_URL}/api/repos/${_ATLAS_CI_REPO_ID}/pipelines?per_page=${limit}" 2>&1) || {
    echo "❌ Failed to fetch pipelines" >&2; return 1
  }
  printf "\n  Recent pipelines (repo_id=%s):\n\n" "$_ATLAS_CI_REPO_ID"
  printf "  %-5s %-12s %-14s %-28s %-10s %s\n" "N" "status" "event" "branch" "commit" "msg"
  printf "  %-5s %-12s %-14s %-28s %-10s %s\n" "────" "────────" "───────" "──────────" "────────" "────"
  /usr/bin/python3 - "$resp" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
for p in d:
    icon = {'success':'✅','failure':'❌','pending':'⏳','running':'▶','killed':'☠','error':'💥'}.get(p.get('status','?'),'?')
    msg = (p.get('message','') or '').split('\n',1)[0][:40]
    branch = (p.get('branch','?') or '?')[:26]
    sha = (p.get('commit','') or '?')[:8]
    st_label = f"{icon}{p.get('status','?')}"
    print(f"  #{p.get('number','?'):<4} {st_label:<12} {p.get('event','?'):<14} {branch:<28} {sha:<10} {msg}")
PY
  echo ""
}

# ─── atlas ci rerun <N> — retrigger a pipeline ───────────────────
_atlas_ci_rerun() {
  _atlas_ci_load_token || return 1
  local pipeline="${1:-}"
  if [ -z "$pipeline" ]; then
    echo "Usage: atlas ci rerun <pipeline_number>" >&2
    return 1
  fi
  local code
  code=$(/usr/bin/curl -s -o /tmp/wp_rerun.json -w "%{http_code}" \
    -X POST \
    -H "Authorization: Bearer ${WP_TOKEN}" \
    "${_ATLAS_CI_URL}/api/repos/${_ATLAS_CI_REPO_ID}/pipelines/${pipeline}")
  if [ "$code" = "200" ] || [ "$code" = "201" ]; then
    local new_num
    new_num=$(/usr/bin/python3 -c "import json; d=json.load(open('/tmp/wp_rerun.json')); print(d.get('number','?'))" 2>/dev/null || echo "?")
    echo "✅ Pipeline #${pipeline} retriggered → new pipeline #${new_num}"
    echo "   Track: atlas ci watch ${new_num}"
  else
    echo "❌ Rerun failed (HTTP ${code})" >&2
    /usr/bin/head -3 /tmp/wp_rerun.json 2>/dev/null
    return 1
  fi
}

# ─── atlas ci watch <N> [--live] [--interval S] [--tail N] ────────────
# Without --live: legacy mode (one-line per state change, default 20s poll)
# With --live: rich TUI/plain frame with timeline, log tail, progress, freeze detection (default 3s poll)
_atlas_ci_watch() {
  # Handle help flag BEFORE requiring pipeline arg
  case "${1:-}" in
    -h|--help|"")
      if [ "${1:-}" = "" ]; then
        echo "Usage: atlas ci watch <pipeline_number> [--live] [--interval S] [--tail N] [--freeze-threshold S]" >&2
        return 1
      fi
      cat <<'EOF'
Usage: atlas ci watch <N> [--live] [--interval S] [--tail N] [--freeze-threshold S]

Modes:
  (no flag)             Legacy: one line per state change, 20s poll (backward compat)
  --live                Rich frame: timeline + log tail + progress + freeze detection (3s poll)

Options:
  --interval S          Override poll interval (default: 20s; 3s with --live)
  --tail N              Last N decoded log lines per running step (default 3, --live only)
  --freeze-threshold S  Seconds without new output to flag as frozen (default 60s, --live only)
  -h, --help            This help
EOF
      return 0
      ;;
  esac
  _atlas_ci_load_token || return 1
  local pipeline="$1"
  shift
  local interval="" live=0 tail=3 freeze=60
  while [ $# -gt 0 ]; do
    case "$1" in
      --live) live=1; shift ;;
      --interval) interval="${2:-}"; shift 2 ;;
      --tail) tail="${2:-3}"; shift 2 ;;
      --freeze-threshold) freeze="${2:-60}"; shift 2 ;;
      -h|--help)
        echo "(use 'atlas ci watch --help' without a pipeline arg)" >&2
        return 0
        ;;
      *) shift ;;
    esac
  done

  if [ "$live" = 1 ]; then
    [ -z "$interval" ] && interval=3
    _atlas_ci_watch_live "$pipeline" "$interval" "$tail" "$freeze"
    return $?
  fi

  # ─── legacy plain watch (preserved verbatim for backward compat) ─────
  [ -z "$interval" ] && interval=20
  echo "⏳ Watching pipeline #${pipeline} (poll every ${interval}s — Ctrl+C to stop)"
  local last_state=""
  while true; do
    local meta
    meta=$(/usr/bin/curl -sf --max-time 10 \
      -H "Authorization: Bearer ${WP_TOKEN}" \
      "${_ATLAS_CI_URL}/api/repos/${_ATLAS_CI_REPO_ID}/pipelines/${pipeline}" 2>/dev/null)
    if [ -z "$meta" ]; then
      /bin/sleep "$interval"
      continue
    fi
    local state
    state=$(/usr/bin/python3 - "$meta" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
wfs = d.get('workflows') or []
counts = {}
fails = []
for wf in wfs:
    for s in (wf.get('children') or []):
        counts[s.get('state','?')] = counts.get(s.get('state','?'),0) + 1
        if s.get('state') == 'failure':
            fails.append(s.get('name','?'))
parts = [d.get('status','?')]
for k in ['running','success','failure','skipped','pending']:
    if counts.get(k,0) > 0:
        parts.append(f'{k}={counts[k]}')
if fails:
    parts.append(f'FAILED={fails[:3]}')
print(' '.join(parts))
PY
)
    if [ "$state" != "$last_state" ]; then
      printf "  [%s] #%s: %s\n" "$(/bin/date +%H:%M:%S)" "$pipeline" "$state"
      last_state="$state"
    fi
    case "$state" in
      success*|failure*|error*|killed*)
        echo "  Terminal: ${state%% *}"
        return 0
        ;;
    esac
    /bin/sleep "$interval"
  done
}

# ─── atlas ci watch --live <N> — rich live monitor ────────────────────
# Polls Woodpecker every <interval>s, fetches per-step logs for running
# steps, tracks last_stdout_ts in a state file (for freeze detection),
# delegates rendering to ci_watch_render.py.
_atlas_ci_watch_live() {
  local pipeline=$1 interval=$2 tail=$3 freeze=$4
  local state_dir
  state_dir=$(/bin/mktemp -d "/tmp/atlas-ci-watch-${pipeline}-XXXXXX")
  local state_file="${state_dir}/state.json"
  local meta_file="${state_dir}/meta.json"
  local logs_dir="${state_dir}/logs"
  /bin/mkdir -p "$logs_dir"
  echo '{}' > "$state_file"

  # shellcheck disable=SC2064  # state_dir must expand at trap-set time
  trap "/bin/rm -rf -- '$state_dir'" EXIT INT TERM

  local tty_flag="--plain"
  [ -t 1 ] && tty_flag="--tty"

  echo "⏳ Live watch pipeline #${pipeline} — interval ${interval}s, freeze ${freeze}s, Ctrl+C to stop"

  while true; do
    local meta
    meta=$(/usr/bin/curl -sf --max-time 10 \
      -H "Authorization: Bearer ${WP_TOKEN}" \
      "${_ATLAS_CI_URL}/api/repos/${_ATLAS_CI_REPO_ID}/pipelines/${pipeline}" 2>/dev/null)
    if [ -z "$meta" ]; then
      /bin/sleep "$interval"
      continue
    fi
    printf '%s' "$meta" > "$meta_file"

    # Identify running step IDs
    local running_ids
    running_ids=$(/usr/bin/python3 - "$meta" <<'PY' 2>/dev/null
import json, sys
d = json.loads(sys.argv[1])
ids = []
for wf in (d.get('workflows') or []):
    for s in (wf.get('children') or []):
        if s.get('state') == 'running':
            ids.append(str(s.get('id') or ''))
print(' '.join(i for i in ids if i))
PY
)

    # Fetch logs for each running step + refresh state file
    local now
    now=$(/bin/date +%s)
    local sid
    for sid in $running_ids; do
      local log_resp
      log_resp=$(/usr/bin/curl -sf --max-time 10 \
        -H "Authorization: Bearer ${WP_TOKEN}" \
        "${_ATLAS_CI_URL}/api/repos/${_ATLAS_CI_REPO_ID}/logs/${pipeline}/${sid}" 2>/dev/null)
      [ -z "$log_resp" ] && continue
      # SPA-HTML guard
      if ! printf '%s' "$log_resp" | /usr/bin/head -c 1 | /bin/grep -q '^\['; then
        continue
      fi
      printf '%s' "$log_resp" > "${logs_dir}/${sid}.json"
      # Update state: refresh last_stdout_ts if log size changed
      /usr/bin/python3 - "$state_file" "$sid" "$now" "${logs_dir}/${sid}.json" <<'PY' 2>/dev/null || true
import json, os, sys
state_path, sid, now, log_path = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
try:
    state = json.load(open(state_path))
except Exception:
    state = {}
size = os.path.getsize(log_path) if os.path.exists(log_path) else 0
meta = state.get('_meta', {})
prev = meta.get(sid, {})
if size != prev.get('size'):
    state[sid] = now
    meta[sid] = {'size': size}
    state['_meta'] = meta
    with open(state_path, 'w') as f:
        json.dump(state, f)
PY
    done

    # Render frame
    /usr/bin/python3 "$_ATLAS_CI_RENDER_PY" "$meta_file" \
      --logs-dir "$logs_dir" \
      --state "$state_file" \
      --tail "$tail" \
      --freeze-threshold "$freeze" \
      "$tty_flag"

    # Check terminal pipeline state
    local pstatus
    pstatus=$(/usr/bin/python3 -c \
      "import json; print(json.load(open('$meta_file')).get('status','?'))" 2>/dev/null || echo '?')
    case "$pstatus" in
      success|failure|error|killed)
        echo ""
        echo "  Terminal pipeline state: ${pstatus}"
        return 0
        ;;
    esac

    /bin/sleep "$interval"
  done
}

# ─── atlas ci secrets [list|set|rm] ──────────────────────────────
_atlas_ci_secrets() {
  _atlas_ci_load_token || return 1
  local action="${1:-list}"
  shift 2>/dev/null || true
  case "$action" in
    list|ls) _atlas_ci_secrets_list ;;
    add|set) _atlas_ci_secrets_set "$@" ;;
    rm|remove|delete) _atlas_ci_secrets_rm "$@" ;;
    rotate-ssh) _atlas_ci_secrets_rotate_ssh "$@" ;;
    help|--help|-h)
      cat <<EOF

  atlas ci secrets — manage Woodpecker repo-level secrets

  Usage:
    atlas ci secrets [list]                           List secrets (metadata only)
    atlas ci secrets set <name> <value> [--events X]  Add or update a secret
    atlas ci secrets rm <name>                        Delete a secret
    atlas ci secrets rotate-ssh [options]             Rotate SSH deploy key end-to-end

  Events (comma-separated): push, pull_request, tag, deployment, cron
  Default events: push

  Rotate-ssh options:
    --name <secret>           WP secret name (default: ssh_key)
    --targets <csv>           SSH host aliases (e.g. vm801,vm802,nb-vm550)
    --user <name>             Remote user (default: sgagnon)
    --comment <text>           Key comment (default: woodpecker-ci-<repo>-<date>)
    --store-bw <item-name>    Also store private in Bitwarden (requires bw unlocked)
    --dry-run                 Show plan without executing

  Examples:
    atlas ci secrets
    atlas ci secrets set ssh_key "\$(cat ~/.ssh/deploy_key)" --events push
    atlas ci secrets set forgejo_ci_bot_token "\$FG_TOKEN" --events pull_request,push
    atlas ci secrets rm old_secret
    atlas ci secrets rotate-ssh --targets vm801,vm802,nb-vm550
    atlas ci secrets rotate-ssh --targets vm801 --store-bw "Woodpecker CI deploy key"

EOF
      ;;
    *) echo "Unknown secrets action: $action — try 'atlas ci secrets help'" >&2; return 1 ;;
  esac
}

_atlas_ci_secrets_rotate_ssh() {
  # End-to-end SSH key rotation for Woodpecker CI deploy.
  # Replaces 6 manual steps with a single command. Safe: requires HITL confirm.
  local name="ssh_key"
  local targets=""
  local user="sgagnon"
  local comment="woodpecker-ci-$(basename "$PWD")-$(date +%Y%m%d)"
  local bw_item=""
  local dry_run=false
  while [ $# -gt 0 ]; do
    case "$1" in
      --name) name="$2"; shift 2 ;;
      --targets) targets="$2"; shift 2 ;;
      --user) user="$2"; shift 2 ;;
      --comment) comment="$2"; shift 2 ;;
      --store-bw) bw_item="$2"; shift 2 ;;
      --dry-run) dry_run=true; shift ;;
      *) shift ;;
    esac
  done
  if [ -z "$targets" ]; then
    echo "❌ --targets required (comma-separated host aliases)" >&2
    echo "   Example: atlas ci secrets rotate-ssh --targets vm801,vm802,nb-vm550" >&2
    return 1
  fi

  echo ""
  echo "🔑 SSH Key Rotation Plan"
  echo "  WP Secret:  ${name}"
  echo "  Targets:    ${targets} (user=${user})"
  echo "  Comment:    ${comment}"
  [ -n "$bw_item" ] && echo "  BW backup:  ${bw_item}"
  $dry_run && echo "  Mode:       DRY RUN — no changes"
  echo ""

  if $dry_run; then
    echo "Would:"
    echo "  1. ssh-keygen -t ed25519 -C '${comment}' -f /tmp/atlas_rotate_ssh -N ''"
    for h in $(echo "$targets" | /usr/bin/tr ',' ' '); do
      echo "  2. ssh ${h}: remove woodpecker-ci entries + add new pub key"
    done
    echo "  3. PATCH WP secret '${name}' via API"
    [ -n "$bw_item" ] && echo "  4. Create BW secure note '${bw_item}' with priv+pub"
    echo "  5. rm /tmp/atlas_rotate_ssh*"
    return 0
  fi

  # Step 1: generate keypair
  local tmpkey="/tmp/atlas_rotate_ssh_$$"
  /usr/bin/ssh-keygen -t ed25519 -C "${comment}" -f "${tmpkey}" -N "" -q
  local pub priv
  pub=$(/bin/cat "${tmpkey}.pub")
  priv=$(/bin/cat "${tmpkey}")

  # Step 2: deploy public key to each target (POSIX-compatible host split)
  local deploy_ok=0 deploy_fail=0
  for h in $(echo "$targets" | /usr/bin/tr ',' ' '); do
    # Detect if host needs sudo (root user with target user != root)
    local default_user
    default_user=$(/usr/bin/ssh -G "$h" 2>/dev/null | /bin/grep '^user ' | /usr/bin/awk '{print $2}')
    local cmd
    if [ "$default_user" = "root" ] && [ "$user" != "root" ]; then
      cmd="sudo -u ${user} bash -c \"sed -i '/woodpecker-ci/d' /home/${user}/.ssh/authorized_keys && echo '${pub}' >> /home/${user}/.ssh/authorized_keys\""
    else
      cmd="sed -i '/woodpecker-ci/d' ~/.ssh/authorized_keys && echo '${pub}' >> ~/.ssh/authorized_keys"
    fi
    if /usr/bin/ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$h" "$cmd" 2>/dev/null; then
      echo "  ✅ ${h}: pub key deployed"
      deploy_ok=$((deploy_ok+1))
    else
      echo "  ❌ ${h}: SSH failed" >&2
      deploy_fail=$((deploy_fail+1))
    fi
  done

  if [ "$deploy_fail" -gt 0 ]; then
    echo ""
    echo "⚠ ${deploy_fail} target(s) failed. NOT updating WP secret to avoid breaking deploy." >&2
    /bin/rm -f "${tmpkey}" "${tmpkey}.pub"
    return 1
  fi

  # Step 3: update WP secret via existing set helper
  _atlas_ci_secrets_set "$name" "$priv" --events deployment,push

  # Step 4: optional Bitwarden backup
  if [ -n "$bw_item" ] && command -v bw >/dev/null; then
    if bw status 2>/dev/null | /usr/bin/grep -q unlocked; then
      /usr/bin/python3 - "$bw_item" "$pub" "$priv" "$targets" "$comment" <<'PY'
import json, subprocess, sys, os
name, pub, priv, targets, comment = sys.argv[1:6]
tpl = subprocess.run(['bw','get','template','item'], capture_output=True, text=True, env={**os.environ})
item = json.loads(tpl.stdout)
item.update({
    'type': 2,
    'name': name,
    'notes': f'Woodpecker CI deploy key (rotated {comment}).\nTargets: {targets}\n\n=== PUBLIC ===\n{pub}\n=== PRIVATE ===\n{priv}',
    'secureNote': {'type': 0},
    'fields': [
        {'name':'Targets','value':targets,'type':0},
        {'name':'Rotated','value':comment,'type':0},
    ],
})
enc = subprocess.run(['bw','encode'], input=json.dumps(item), capture_output=True, text=True, env={**os.environ})
create = subprocess.run(['bw','create','item', enc.stdout.strip()], capture_output=True, text=True, env={**os.environ})
try:
    r = json.loads(create.stdout)
    print(f"  ✅ BW item created: id={r['id']}")
except Exception:
    print(f"  ⚠ BW create unclear: {create.stderr[:120]}")
PY
    else
      echo "  ⚠ Bitwarden not unlocked — skipping BW backup. Run: bw unlock" >&2
    fi
  fi

  # Step 5: cleanup
  /bin/rm -f "${tmpkey}" "${tmpkey}.pub"
  echo ""
  echo "✅ Rotation complete. Next push/deploy will use the new key."
}

_atlas_ci_secrets_list() {
  local resp
  resp=$(/usr/bin/curl -sf --max-time 10 \
    -H "Authorization: Bearer ${WP_TOKEN}" \
    "${_ATLAS_CI_URL}/api/repos/${_ATLAS_CI_REPO_ID}/secrets")
  if [ -z "$resp" ]; then
    echo "(no secrets or API error)"
    return 1
  fi
  printf "\n  Secrets for repo %s:\n\n" "$_ATLAS_CI_REPO_ID"
  printf "  %-30s %-28s\n" "name" "events"
  printf "  %-30s %-28s\n" "──────" "──────"
  /usr/bin/python3 - "$resp" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
for s in d:
    name = s.get('name','?')
    events = ','.join(s.get('events') or [])
    print(f"  {name:<30} {events:<28}")
PY
  echo ""
}

_atlas_ci_secrets_set() {
  local name="${1:-}"
  local value="${2:-}"
  if [ -z "$name" ] || [ -z "$value" ]; then
    echo "Usage: atlas ci secrets set <name> <value> [--events X,Y]" >&2
    return 1
  fi
  shift 2
  local events="push"
  while [ $# -gt 0 ]; do
    case "$1" in
      --events) events="${2:-push}"; shift 2 ;;
      *) shift ;;
    esac
  done
  # Build JSON body with Python (handles quoting safely)
  local body
  body=$(/usr/bin/python3 -c "
import json, sys
events_list = [e.strip() for e in sys.argv[3].split(',') if e.strip()]
print(json.dumps({'name': sys.argv[1], 'value': sys.argv[2], 'events': events_list, 'images': []}))
" "$name" "$value" "$events")
  # Try POST first (create). On conflict, try PATCH (update).
  local code
  code=$(/usr/bin/curl -s -o /tmp/wp_secret.json -w "%{http_code}" \
    -X POST \
    -H "Authorization: Bearer ${WP_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$body" \
    "${_ATLAS_CI_URL}/api/repos/${_ATLAS_CI_REPO_ID}/secrets")
  if [ "$code" = "200" ] || [ "$code" = "201" ]; then
    echo "✅ Secret '${name}' added (events=${events})"
  elif [ "$code" = "409" ] || [ "$code" = "500" ] || [ "$code" = "422" ]; then
    # Exists — try update via PATCH
    code=$(/usr/bin/curl -s -o /tmp/wp_secret.json -w "%{http_code}" \
      -X PATCH \
      -H "Authorization: Bearer ${WP_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "$body" \
      "${_ATLAS_CI_URL}/api/repos/${_ATLAS_CI_REPO_ID}/secrets/${name}")
    if [ "$code" = "200" ] || [ "$code" = "204" ]; then
      echo "✅ Secret '${name}' updated (events=${events})"
    else
      echo "❌ Secret update failed (HTTP ${code})" >&2
      /usr/bin/head -3 /tmp/wp_secret.json 2>/dev/null
      return 1
    fi
  else
    echo "❌ Secret add failed (HTTP ${code})" >&2
    /usr/bin/head -3 /tmp/wp_secret.json 2>/dev/null
    return 1
  fi
}

_atlas_ci_secrets_rm() {
  local name="${1:-}"
  if [ -z "$name" ]; then
    echo "Usage: atlas ci secrets rm <name>" >&2
    return 1
  fi
  local code
  code=$(/usr/bin/curl -s -o /dev/null -w "%{http_code}" \
    -X DELETE \
    -H "Authorization: Bearer ${WP_TOKEN}" \
    "${_ATLAS_CI_URL}/api/repos/${_ATLAS_CI_REPO_ID}/secrets/${name}")
  if [ "$code" = "200" ] || [ "$code" = "204" ]; then
    echo "✅ Secret '${name}' removed"
  else
    echo "❌ Secret rm failed (HTTP ${code})" >&2
    return 1
  fi
}

# ─── atlas ci agents — list agent fleet (admin) ──────────────────
_atlas_ci_agents() {
  _atlas_ci_load_token || return 1
  local code
  code=$(/usr/bin/curl -s -o /tmp/wp_agents.json -w "%{http_code}" \
    -H "Authorization: Bearer ${WP_TOKEN}" \
    "${_ATLAS_CI_URL}/api/agents?per_page=50")
  if [ "$code" != "200" ]; then
    echo "❌ Fetching agents failed (HTTP ${code}) — requires admin token." >&2
    return 1
  fi
  printf "\n  Woodpecker agent fleet:\n\n"
  printf "  %-4s %-20s %-30s %-10s %s\n" "id" "name" "platform" "backend" "last_contact"
  printf "  %-4s %-20s %-30s %-10s %s\n" "────" "────" "────────" "───────" "──────────"
  /usr/bin/python3 - <<'PY'
import json
try:
    d = json.load(open('/tmp/wp_agents.json'))
    if not isinstance(d, list):
        print(f"  (unexpected response: {str(d)[:80]})")
    else:
        for a in d:
            last = a.get('last_contact') or 0
            name = (a.get('name','?') or '?')[:18]
            platform = (a.get('platform','?') or '?')[:28]
            print(f"  {a.get('id','?'):<4} {name:<20} {platform:<30} {a.get('backend','?'):<10} {last}")
except Exception as e:
    print(f"  parse error: {e}")
PY
  echo ""
}

# ─── atlas ci pipeline <N> — single pipeline JSON summary ────────
_atlas_ci_pipeline_info() {
  _atlas_ci_load_token || return 1
  local pipeline="${1:-}"
  if [ -z "$pipeline" ]; then
    echo "Usage: atlas ci pipeline <number>" >&2
    return 1
  fi
  local meta
  meta=$(/usr/bin/curl -sf --max-time 10 \
    -H "Authorization: Bearer ${WP_TOKEN}" \
    "${_ATLAS_CI_URL}/api/repos/${_ATLAS_CI_REPO_ID}/pipelines/${pipeline}") || {
    echo "❌ Fetch failed" >&2; return 1
  }
  /usr/bin/python3 - "$meta" "$pipeline" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
n = sys.argv[2]
print(f"\n  Pipeline #{n}")
print(f"    status:    {d.get('status')}")
print(f"    event:     {d.get('event')}")
print(f"    branch:    {d.get('branch')}")
print(f"    commit:    {(d.get('commit','') or '?')[:40]}")
print(f"    author:    {d.get('author')}")
msg = (d.get('message','') or '').split('\n',1)[0][:80]
print(f"    message:   {msg}")
print(f"    started:   {d.get('started')}")
print(f"    finished:  {d.get('finished')}")
errs = d.get('errors') or []
if errs:
    print(f"    errors ({len(errs)}):")
    for e in errs[:5]:
        print(f"      [{e.get('type','?')}] {e.get('message','')[:80]}")
print(f"    workflows:")
for wf in d.get('workflows') or []:
    steps = wf.get('children') or []
    counts = {}
    for s in steps:
        counts[s.get('state','?')] = counts.get(s.get('state','?'),0) + 1
    print(f"      {wf.get('name','?'):<20} state={wf.get('state','?'):<10} steps={len(steps):<3} {counts}")
print()
PY
}
