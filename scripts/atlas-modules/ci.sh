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
    logs)        _atlas_ci_logs "$@"; return ;;
    status|list) _atlas_ci; return ;;
    help|--help|-h)
      _atlas_ci_help
      return 0
      ;;
    *)
      echo "atlas ci: unknown subcommand '$sub' — try 'atlas ci help'" >&2
      return 1
      ;;
  esac
}

# ─── Help text ───────────────────────────────────────────────────
_atlas_ci_help() {
  cat <<'EOF'

  atlas ci — Woodpecker CI helpers

  Usage:
    atlas ci                                     Recent pipelines (default)
    atlas ci status                              Alias for default
    atlas ci logs <pipeline>                     Step table for a pipeline
    atlas ci logs <pipeline> --step <X>          Decoded logs for step X
                                                 (X = name, pid, or step_id)
    atlas ci logs <pipeline> --all               Decoded logs for all steps
    atlas ci help                                This help

  Environment:
    WP_TOKEN   (required — from ~/.env)
    WP_URL     (default: https://ci.axoiq.com)
    WP_REPO_ID (default: 1)

  Examples:
    atlas ci logs 78
    atlas ci logs 78 --step frontend-install
    atlas ci logs 78 --step 12       # by pid
    atlas ci logs 78 --step 1718     # by step_id
    atlas ci logs 78 --all

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
        data = e.get('data', '')
        try:
            decoded = base64.b64decode(data).decode('utf-8', errors='replace')
        except Exception:
            decoded = data
        sys.stdout.write(decoded.rstrip('\n') + '\n')
except Exception as ex:
    print(f'  decode error: {ex}', file=sys.stderr)
PY
}
