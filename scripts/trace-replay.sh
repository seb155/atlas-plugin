#!/usr/bin/env bash
# trace-replay.sh — Interactive timeline replay for atlas-trace JSONL traces.
#
# Reads ~/.atlas/traces/{session-id}/{trace-id}.jsonl produced by the W1.1
# atlas-trace collector and renders an ASCII tree timeline, span detail
# view, or aggregate stats. Read-only.
#
# Schema source of truth: skills/atlas-trace/SKILL.md (branch
# feat/v7-w1-1-atlas-trace).
#
# Usage:
#   trace-replay.sh --session <id> [--trace <trace-id>]
#                   [--filter key=val] [--depth N] [--time-window ts1..ts2]
#                   [--span <span_id>] [--stats]
#                   [--list-sessions]
#
# Exit codes: 0=ok, 1=usage error, 2=missing session, 3=missing dependency.

set -u
set -o pipefail

# --------------------------------------------------------------------------
# Dependency check
# --------------------------------------------------------------------------
for bin in jq awk; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "error: required dependency '$bin' not found in PATH" >&2
    exit 3
  fi
done

# --------------------------------------------------------------------------
# Defaults
# --------------------------------------------------------------------------
TRACES_ROOT="${ATLAS_TRACES_ROOT:-$HOME/.atlas/traces}"
SESSION_ID=""
TRACE_ID=""
FILTER=""
DEPTH=""
TIME_WINDOW=""
SPAN_ID=""
MODE="tree" # tree | span | stats | list-sessions

# --------------------------------------------------------------------------
# Arg parser
# --------------------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --session)
      SESSION_ID="${2:-}"; shift 2 ;;
    --trace)
      TRACE_ID="${2:-}"; shift 2 ;;
    --filter)
      FILTER="${2:-}"; shift 2 ;;
    --depth)
      DEPTH="${2:-}"; shift 2 ;;
    --time-window)
      TIME_WINDOW="${2:-}"; shift 2 ;;
    --span)
      SPAN_ID="${2:-}"; MODE="span"; shift 2 ;;
    --stats)
      MODE="stats"; shift ;;
    --list-sessions)
      MODE="list-sessions"; shift ;;
    -h|--help)
      sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)
      echo "error: unknown argument: $1" >&2
      exit 1 ;;
  esac
done

# --------------------------------------------------------------------------
# list-sessions short-circuit
# --------------------------------------------------------------------------
if [ "$MODE" = "list-sessions" ]; then
  if [ ! -d "$TRACES_ROOT" ]; then
    echo "(no traces directory at $TRACES_ROOT)"
    exit 0
  fi
  echo "Sessions under $TRACES_ROOT:"
  # shellcheck disable=SC2012
  ls -1 "$TRACES_ROOT" 2>/dev/null | grep -v '^_' | while read -r s; do
    if [ -d "$TRACES_ROOT/$s" ]; then
      n=$(find "$TRACES_ROOT/$s" -maxdepth 1 -name '*.jsonl' 2>/dev/null | wc -l)
      printf "  %-40s  %d trace(s)\n" "$s" "$n"
    fi
  done
  exit 0
fi

# --------------------------------------------------------------------------
# Session resolution
# --------------------------------------------------------------------------
if [ -z "$SESSION_ID" ]; then
  SESSION_ID="${CLAUDE_SESSION_ID:-}"
fi
if [ -z "$SESSION_ID" ]; then
  echo "error: --session <id> required (or set CLAUDE_SESSION_ID)" >&2
  exit 1
fi

SESSION_DIR="$TRACES_ROOT/$SESSION_ID"
if [ ! -d "$SESSION_DIR" ]; then
  echo "error: session dir not found: $SESSION_DIR" >&2
  exit 2
fi

# --------------------------------------------------------------------------
# Trace file enumeration
# --------------------------------------------------------------------------
if [ -n "$TRACE_ID" ]; then
  TRACE_FILES=( "$SESSION_DIR/$TRACE_ID.jsonl" )
  if [ ! -f "${TRACE_FILES[0]}" ]; then
    echo "error: trace file not found: ${TRACE_FILES[0]}" >&2
    exit 2
  fi
else
  # shellcheck disable=SC2207
  TRACE_FILES=( $(find "$SESSION_DIR" -maxdepth 1 -name '*.jsonl' 2>/dev/null | sort) )
  if [ "${#TRACE_FILES[@]}" -eq 0 ]; then
    echo "(no trace files in $SESSION_DIR)"
    exit 0
  fi
fi

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

# Humanize duration_ms → "12.4s" or "100ms" or "—" if null.
humanize_ms() {
  local ms="$1"
  if [ -z "$ms" ] || [ "$ms" = "null" ]; then
    printf -- '—'
    return
  fi
  awk -v m="$ms" 'BEGIN {
    if (m >= 1000) printf "%.1fs", m/1000
    else           printf "%dms", m
  }'
}

# Status icon dispatch.
status_icon() {
  case "$1" in
    ok)      printf 'ok    ' ;;
    error)   printf 'error ' ;;
    pending) printf 'pend  ' ;;
    *)       printf '%-6s' "$1" ;;
  esac
}

# Apply pre-tree filters to a JSONL stream on stdin.
# Combines: --filter key=val (substring match in operation/service),
#           --time-window ts1..ts2 (start_ts within window).
apply_filters() {
  local jq_filter='.'
  if [ -n "$FILTER" ]; then
    local key="${FILTER%%=*}"
    local val="${FILTER#*=}"
    case "$key" in
      skill|service)
        jq_filter="$jq_filter | select((.service==\"$val\") or ((.operation // \"\") | test(\"$val\")))"
        ;;
      operation|op)
        jq_filter="$jq_filter | select(((.operation // \"\")) | test(\"$val\"))"
        ;;
      status)
        jq_filter="$jq_filter | select(.status==\"$val\")"
        ;;
      *)
        # Free-form attribute filter
        jq_filter="$jq_filter | select(((.attributes // {}) | .\"$key\" // \"\" | tostring) | test(\"$val\"))"
        ;;
    esac
  fi
  if [ -n "$TIME_WINDOW" ]; then
    local ts1="${TIME_WINDOW%%..*}"
    local ts2="${TIME_WINDOW#*..}"
    jq_filter="$jq_filter | select(.start_ts >= \"$ts1\" and .start_ts <= \"$ts2\")"
  fi
  jq -c "$jq_filter" 2>/dev/null
}

# Build cost/token suffix from attributes (forward-compat with W1.2).
cost_suffix() {
  local attrs_json="$1"
  local cost tokens
  cost=$(printf '%s' "$attrs_json" | jq -r '.cost_usd // empty' 2>/dev/null)
  tokens=$(printf '%s' "$attrs_json" | jq -r '.tokens_in // empty' 2>/dev/null)
  if [ -n "$cost" ]; then
    printf '  cost $%s' "$cost"
  fi
  if [ -n "$tokens" ]; then
    printf '  tokens=%s' "$tokens"
  fi
}

# --------------------------------------------------------------------------
# Render tree (mode=tree)
# --------------------------------------------------------------------------
render_tree() {
  local trace_file="$1"
  local trace_short
  trace_short=$(basename "$trace_file" .jsonl | cut -c1-12)

  # Load filtered spans into temp file (jq slurp once).
  local tmp
  tmp=$(mktemp -t trace-replay.XXXXXX)
  apply_filters < "$trace_file" > "$tmp"

  if [ ! -s "$tmp" ]; then
    echo "(no spans in $trace_file after filters)"
    rm -f "$tmp"
    return
  fi

  # Compute trace metadata.
  local total_ms session_label
  total_ms=$(jq -s 'map(.duration_ms // 0) | max // 0' "$tmp" 2>/dev/null)
  session_label=$(jq -sr 'first as $f | ($f.start_ts // "unknown") | .[0:10]' < "$tmp" 2>/dev/null)
  printf 'trace %s…  session %s  duration %s\n' \
    "$trace_short" "$session_label" "$(humanize_ms "$total_ms")"

  # Walk the tree iteratively. Roots = parent_span_id null.
  # Sort children by start_ts.
  awk_render_tree "$tmp"
  rm -f "$tmp"
}

# Pure-awk recursive walker: build span_id → children map, then render.
awk_render_tree() {
  local tmp="$1"
  local depth_cap="${DEPTH:-9999}"

  # Emit one TSV line per span: span_id <TAB> parent <TAB> start <TAB> op <TAB> dur <TAB> status <TAB> attrs_json
  local tsv
  tsv=$(mktemp -t trace-replay-tsv.XXXXXX)
  # NOTE: do NOT use a RETURN trap here — it can collide with parent traps
  # under set -u. We delete tsv at end of function instead.

  jq -r '
    [ .span_id // "?",
      (.parent_span_id // ""),
      (.start_ts // ""),
      (.operation // "?"),
      (.duration_ms // 0),
      (.status // "ok"),
      (.attributes // {} | tojson)
    ] | @tsv
  ' "$tmp" > "$tsv"

  awk -F'\t' -v cap="$depth_cap" '
    BEGIN { OFS="\t" }
    {
      sid=$1; par=$2; start=$3; op=$4; dur=$5; st=$6; attrs=$7
      span_op[sid]=op
      span_dur[sid]=dur
      span_st[sid]=st
      span_start[sid]=start
      span_attrs[sid]=attrs
      span_par[sid]=par
      if (par == "" || par == "null") {
        roots[++rc]=sid
      } else {
        # accumulate children, comma-joined for later split
        if (children[par] == "") children[par]=sid
        else                      children[par]=children[par] "," sid
      }
    }
    END {
      # Sort each child list by start_ts
      for (p in children) {
        n = split(children[p], arr, ",")
        # Insertion sort by start_ts
        for (i=2;i<=n;i++) {
          j=i
          while (j>1 && span_start[arr[j]] < span_start[arr[j-1]]) {
            t=arr[j]; arr[j]=arr[j-1]; arr[j-1]=t; j--
          }
        }
        children[p]=""
        for (i=1;i<=n;i++) children[p]=children[p] (i==1?"":",") arr[i]
      }
      # Sort roots by start_ts
      for (i=2;i<=rc;i++) {
        j=i
        while (j>1 && span_start[roots[j]] < span_start[roots[j-1]]) {
          t=roots[j]; roots[j]=roots[j-1]; roots[j-1]=t; j--
        }
      }
      for (i=1;i<=rc;i++) {
        is_last = (i==rc) ? 1 : 0
        walk(roots[i], "", is_last, 0, (rc>1))
      }
    }
    function walk(sid, prefix, is_last, depth, multi_root,    line, branch, child_prefix, n, arr, k) {
      if (depth > cap) return
      if (depth==0) {
        branch = multi_root ? (is_last ? "└─ " : "├─ ") : ""
      } else {
        branch = is_last ? "└─ " : "├─ "
      }
      # humanize dur
      d = span_dur[sid]+0
      if (d >= 1000) hum = sprintf("%.1fs", d/1000)
      else           hum = sprintf("%dms", d)
      st = span_st[sid]
      printf "%s%s%-26s %6s  %-5s\n", prefix, branch, span_op[sid], hum, st
      # children
      if (children[sid] == "") return
      n = split(children[sid], arr, ",")
      if (depth==0) {
        child_prefix = multi_root ? (is_last ? "   " : "│  ") : ""
      } else {
        child_prefix = prefix (is_last ? "   " : "│  ")
      }
      for (k=1;k<=n;k++) {
        walk(arr[k], child_prefix, (k==n), depth+1, multi_root)
      }
    }
  ' "$tsv"
  rm -f "$tsv"
}

# --------------------------------------------------------------------------
# Render span detail (mode=span)
# --------------------------------------------------------------------------
render_span_detail() {
  local trace_file="$1"
  local target="$SPAN_ID"

  local span_json
  span_json=$(jq -c --arg sid "$target" 'select(.span_id==$sid)' "$trace_file" 2>/dev/null | head -n1)
  if [ -z "$span_json" ]; then
    return 1
  fi

  local trace_id parent op service start end dur st attrs children_count parent_chain
  trace_id=$(printf '%s' "$span_json" | jq -r '.trace_id')
  parent=$(printf '%s' "$span_json" | jq -r '.parent_span_id // "(root)"')
  op=$(printf '%s' "$span_json" | jq -r '.operation')
  service=$(printf '%s' "$span_json" | jq -r '.service // "?"')
  start=$(printf '%s' "$span_json" | jq -r '.start_ts // "?"')
  end=$(printf '%s' "$span_json" | jq -r '.end_ts // "?"')
  dur=$(printf '%s' "$span_json" | jq -r '.duration_ms // 0')
  st=$(printf '%s' "$span_json" | jq -r '.status // "?"')
  attrs=$(printf '%s' "$span_json" | jq -r '.attributes // {} | to_entries | map("  " + .key + " = " + (.value|tostring)) | .[]' 2>/dev/null)
  children_count=$(jq -c --arg sid "$target" 'select(.parent_span_id==$sid) | .span_id' "$trace_file" 2>/dev/null | wc -l)

  # Parent chain (walk up)
  parent_chain="(root)"
  if [ "$parent" != "(root)" ] && [ "$parent" != "null" ]; then
    parent_chain=""
    local cur="$parent" guard=0
    while [ -n "$cur" ] && [ "$cur" != "null" ] && [ "$guard" -lt 32 ]; do
      local pop
      pop=$(jq -r --arg sid "$cur" 'select(.span_id==$sid) | .operation' "$trace_file" 2>/dev/null | head -n1)
      [ -z "$pop" ] && break
      if [ -z "$parent_chain" ]; then
        parent_chain="$pop"
      else
        parent_chain="$pop > $parent_chain"
      fi
      cur=$(jq -r --arg sid "$cur" 'select(.span_id==$sid) | .parent_span_id // ""' "$trace_file" 2>/dev/null | head -n1)
      guard=$((guard + 1))
    done
  fi

  printf 'Span %s  %s\n' "$target" "$op"
  printf '─────────────────────────────────────────\n'
  printf 'trace_id     : %s\n' "$trace_id"
  printf 'parent_span  : %s\n' "$parent"
  printf 'service      : %s\n' "$service"
  printf 'operation    : %s\n' "$op"
  printf 'start_ts     : %s\n' "$start"
  printf 'end_ts       : %s\n' "$end"
  printf 'duration_ms  : %s\n' "$dur"
  printf 'status       : %s\n' "$st"
  printf 'children     : %s spans\n' "$children_count"
  printf 'attributes   :\n'
  if [ -n "$attrs" ]; then
    printf '%s\n' "$attrs"
  else
    printf '  (none)\n'
  fi
  printf '\nParent chain : %s\n' "$parent_chain"
  return 0
}

# --------------------------------------------------------------------------
# Render stats (mode=stats)
# --------------------------------------------------------------------------
render_stats() {
  local total_traces="${#TRACE_FILES[@]}"
  local tmp
  tmp=$(mktemp -t trace-replay-stats.XXXXXX)
  trap 'rm -f "$tmp"' RETURN

  for f in "${TRACE_FILES[@]}"; do
    apply_filters < "$f" >> "$tmp"
  done

  local total_spans error_spans root_spans dur_total slowest_op slowest_dur
  total_spans=$(wc -l < "$tmp" 2>/dev/null | awk '{print $1}')
  error_spans=$(jq -c 'select(.status=="error")' "$tmp" 2>/dev/null | wc -l)
  root_spans=$(jq -c 'select(.parent_span_id==null)' "$tmp" 2>/dev/null | wc -l)
  dur_total=$(jq -s 'map(select(.parent_span_id==null) | .duration_ms // 0) | add // 0' "$tmp" 2>/dev/null)
  slowest_op=$(jq -s 'sort_by(.duration_ms // 0) | reverse | first | .operation // "—"' "$tmp" 2>/dev/null)
  slowest_dur=$(jq -s 'sort_by(.duration_ms // 0) | reverse | first | .duration_ms // 0' "$tmp" 2>/dev/null)
  local skills_count tools_count cost_total
  skills_count=$(jq -r 'select(.service=="skill") | .operation' "$tmp" 2>/dev/null | sort -u | wc -l)
  tools_count=$(jq -r 'select(.service=="tool") | .operation' "$tmp" 2>/dev/null | sort -u | wc -l)
  cost_total=$(jq -s 'map(.attributes.cost_usd // 0 | tonumber? // 0) | add // 0' "$tmp" 2>/dev/null)

  printf '🏛️ ATLAS │ 🎬 TRACE REPLAY │ Stats — session %s\n\n' "$SESSION_ID"
  printf '| Metric              | Value                            |\n'
  printf '|---------------------|----------------------------------|\n'
  printf '| Traces              | %-32s |\n' "$total_traces"
  printf '| Total spans         | %-32s |\n' "$total_spans"
  printf '| Root spans          | %-32s |\n' "$root_spans"
  printf '| Error spans         | %-32s |\n' "$error_spans"
  printf '| Total duration      | %-32s |\n' "$(humanize_ms "$dur_total") (wall)"
  printf '| Slowest span        | %-32s |\n' "$(echo "$slowest_op" | tr -d '"') ($(humanize_ms "$slowest_dur"))"
  printf '| Skills invoked      | %-32s |\n' "$skills_count"
  printf '| Tools invoked       | %-32s |\n' "$tools_count"
  if [ -n "$cost_total" ] && [ "$cost_total" != "0" ] && [ "$cost_total" != "null" ]; then
    printf '| Cost (when present) | $%-31s |\n' "$cost_total"
  fi
}

# --------------------------------------------------------------------------
# Dispatch
# --------------------------------------------------------------------------
case "$MODE" in
  tree)
    for f in "${TRACE_FILES[@]}"; do
      render_tree "$f"
      echo
    done
    ;;
  span)
    if [ -z "$SPAN_ID" ]; then
      echo "error: --span requires a span_id" >&2
      exit 1
    fi
    found=0
    for f in "${TRACE_FILES[@]}"; do
      if render_span_detail "$f"; then
        found=1
        break
      fi
    done
    if [ "$found" -eq 0 ]; then
      echo "error: span_id '$SPAN_ID' not found in session $SESSION_ID" >&2
      exit 2
    fi
    ;;
  stats)
    render_stats
    ;;
esac

exit 0
