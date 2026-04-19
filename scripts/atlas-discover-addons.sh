#!/usr/bin/env bash
# atlas-discover-addons.sh — Capability Discovery Scanner
#
# Scans ~/.claude/plugins/cache/atlas-marketplace/ for installed ATLAS addons,
# reads each addon's _addon-manifest.yaml + VERSION + counts skills/agents,
# then writes ~/.atlas/runtime/capabilities.json with the unified picture.
#
# Master atlas-assist (in atlas-core) reads this JSON at runtime to adapt
# its persona, pipeline, and active skill list to whatever is installed.
#
# Triggered by: dist/atlas-core/hooks/session-start (sync, ~50ms)
# Idempotent: safe to run multiple times per session.
# Failure mode: writes minimal capabilities.json (core-only fallback).

set -uo pipefail

MARKETPLACE_DIR="${HOME}/.claude/plugins/cache/atlas-marketplace"
OUTPUT_DIR="${HOME}/.atlas/runtime"
OUTPUT_FILE="${OUTPUT_DIR}/capabilities.json"

mkdir -p "$OUTPUT_DIR" 2>/dev/null

# ─── Helpers ────────────────────────────────────────────────────────────

# Read a YAML key (uses yq if available, falls back to grep/sed)
yaml_get() {
  local file="$1" key="$2" default="${3:-}"
  if [ ! -f "$file" ]; then echo "$default"; return; fi
  if command -v yq >/dev/null 2>&1; then
    local v
    v=$(yq -r ".${key} // \"\"" "$file" 2>/dev/null || echo "")
    [ -n "$v" ] && [ "$v" != "null" ] && echo "$v" || echo "$default"
  else
    # Fallback: simple grep (only top-level scalar keys)
    local v
    v=$(grep "^${key}:" "$file" 2>/dev/null | head -1 | sed "s/^${key}:[[:space:]]*//; s/[\"']//g")
    [ -n "$v" ] && echo "$v" || echo "$default"
  fi
}

# Read pipeline_phases array as space-separated list
yaml_get_phases() {
  local file="$1"
  if [ ! -f "$file" ]; then echo ""; return; fi
  if command -v yq >/dev/null 2>&1; then
    yq -r '.pipeline_phases[]' "$file" 2>/dev/null | tr '\n' ' ' | sed 's/ $//'
  else
    # Fallback: parse YAML list manually
    awk '/^pipeline_phases:/{flag=1; next} /^[a-z]/{flag=0} flag && /^  -/{gsub(/^  - /, ""); printf "%s ", $0}' "$file" | sed 's/ $//'
  fi
}

# Count files matching pattern under a directory (max-depth 2)
count_files() {
  local dir="$1" pattern="$2"
  if [ ! -d "$dir" ]; then echo 0; return; fi
  find "$dir" -maxdepth 2 -name "$pattern" -type f 2>/dev/null | wc -l | tr -d ' '
}

# ─── CC CLI canonical source (Tier 1) ───────────────────────────────────
# Fetch `claude plugin list --json` ONCE, reuse for all addons.
# Budget: 2s timeout. Empty string on failure → scanner falls through to Tier 2 (fs).
CLI_JSON=""
CC_CLI_AVAILABLE=false
if command -v claude >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  CLI_JSON=$(timeout 2 claude plugin list --json 2>/dev/null || true)
  if [ -n "$CLI_JSON" ] && echo "$CLI_JSON" | jq -e '.[0]' >/dev/null 2>&1; then
    CC_CLI_AVAILABLE=true
  fi
fi

# Resolve a single addon via CC CLI. Returns "version|installPath" or empty.
# Usage: resolve_addon_via_cli atlas-core
# Note: does NOT filter by `.enabled` — that field is CWD-scoped (same plugin
# shows enabled:true when queried from its project worktree, enabled:false from
# elsewhere). The installed version is identical regardless of scope, so we pick
# the most recently updated entry. Prefer enabled if any exists.
resolve_addon_via_cli() {
  local addon_short="$1"
  [ "$CC_CLI_AVAILABLE" = "true" ] || return 1
  [ -n "${CLI_JSON:-}" ] || return 1
  printf '%s' "$CLI_JSON" | jq -rs --arg n "$addon_short" '
    .[0]
    | map(select(.id == ($n + "@atlas-marketplace")))
    | (map(select(.enabled == true)) + map(select(.enabled != true)))
    | sort_by(.lastUpdated) | reverse
    | .[0]
    | if . == null then empty else "\(.version)|\(.installPath)" end
  ' 2>/dev/null | head -1
}

# ─── Scan addons ────────────────────────────────────────────────────────

declare -a ADDONS_JSON=()
TIER_MAX_PRIORITY=0
TIER_MAX_NAME="core"
TIER_MAX_PERSONA="helpful assistant"
TIER_MAX_PIPELINE="DISCOVER → ASSIST"
TIER_MAX_BANNER="Core"
TIER_MAX_VERSION=""
TOTAL_SKILLS=0
TOTAL_AGENTS=0

if [ ! -d "$MARKETPLACE_DIR" ]; then
  # Marketplace dir missing — write minimal capabilities and exit gracefully
  cat > "$OUTPUT_FILE" <<EMPTYEOF
{
  "schema_version": "1.1",
  "computed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "resolved_at_unix": $(date -u +%s),
  "source": "empty",
  "cc_cli_available": ${CC_CLI_AVAILABLE},
  "marketplace_found": false,
  "tier": "unknown",
  "addons": [],
  "skills_total": 0,
  "agents_total": 0,
  "persona": "helpful assistant",
  "pipeline": "DISCOVER → ASSIST",
  "banner_label": "Unknown"
}
EMPTYEOF
  exit 0
fi

# Track source aggregation: cli | fs | mixed
SOURCES_SEEN=""

# Iterate over each addon directory: atlas-marketplace/<name>/<version>/
for addon_dir in "$MARKETPLACE_DIR"/atlas-*/; do
  [ -d "$addon_dir" ] || continue

  addon_short=$(basename "$addon_dir")  # e.g. "atlas-core"
  addon_source="fs"
  version_dir=""

  # Tier 1: canonical CC CLI
  cli_result=$(resolve_addon_via_cli "$addon_short")
  if [ -n "$cli_result" ]; then
    addon_version_cli="${cli_result%%|*}"
    install_path="${cli_result##*|}"
    # Normalize trailing slash for downstream path consumers
    version_dir="${install_path%/}/"
    if [ -d "$version_dir" ]; then
      addon_source="cli"
    else
      # CC reports this plugin but dir missing — fall through to fs scan
      version_dir=""
    fi
  fi

  # Tier 2: filesystem scan (legacy fallback, preserved verbatim)
  if [ -z "$version_dir" ]; then
    version_dir=$(ls -1d "${addon_dir}"*/ 2>/dev/null | sort -V | tail -1)
    [ -d "$version_dir" ] || continue
    addon_source="fs"
  fi

  SOURCES_SEEN="${SOURCES_SEEN}${addon_source} "

  manifest="${version_dir}_addon-manifest.yaml"

  # Read manifest fields (with sensible defaults if missing)
  addon_name=$(yaml_get "$manifest" "name" "$addon_short")
  tier=$(yaml_get "$manifest" "tier" "unknown")
  priority=$(yaml_get "$manifest" "tier_priority" "0")
  persona=$(yaml_get "$manifest" "persona_contribution" "")
  banner=$(yaml_get "$manifest" "banner_label" "")
  pipeline=$(yaml_get_phases "$manifest")

  # Prefer CLI-reported version (canonical), fall back to VERSION file
  if [ "$addon_source" = "cli" ] && [ -n "${addon_version_cli:-}" ]; then
    addon_version="$addon_version_cli"
  else
    version_file="${version_dir}VERSION"
    addon_version=$(cat "$version_file" 2>/dev/null | tr -d '[:space:]' || echo "?")
  fi

  # Count skills + agents
  skill_n=$(count_files "${version_dir}skills" "SKILL.md")
  agent_n=$(count_files "${version_dir}agents" "AGENT.md")

  # Aggregate totals
  TOTAL_SKILLS=$((TOTAL_SKILLS + skill_n))
  TOTAL_AGENTS=$((TOTAL_AGENTS + agent_n))

  # Pick highest tier (priority wins) for persona/pipeline/banner
  if [ "$priority" -gt "$TIER_MAX_PRIORITY" ] 2>/dev/null; then
    TIER_MAX_PRIORITY="$priority"
    TIER_MAX_NAME="$tier"
    [ -n "$persona" ] && TIER_MAX_PERSONA="$persona"
    [ -n "$pipeline" ] && TIER_MAX_PIPELINE="$(echo "$pipeline" | sed 's/ / → /g')"
    [ -n "$banner" ] && TIER_MAX_BANNER="$banner"
    TIER_MAX_VERSION="$addon_version"
  fi

  # Append addon entry to JSON array (now with .source)
  ADDONS_JSON+=("$(printf '{"name":"%s","tier":"%s","version":"%s","priority":%s,"skills":%s,"agents":%s,"path":"%s","source":"%s"}' \
    "$addon_name" "$tier" "$addon_version" "$priority" "$skill_n" "$agent_n" "$version_dir" "$addon_source")")
done

# Aggregate top-level .source field (cli | fs | mixed | empty)
AGGREGATED_SOURCE="empty"
case "$(echo "$SOURCES_SEEN" | tr ' ' '\n' | sort -u | grep -v '^$' | tr '\n' ',' | sed 's/,$//')" in
  "cli")     AGGREGATED_SOURCE="cli" ;;
  "fs")      AGGREGATED_SOURCE="fs" ;;
  "cli,fs"|"fs,cli") AGGREGATED_SOURCE="mixed" ;;
  "")        AGGREGATED_SOURCE="empty" ;;
  *)         AGGREGATED_SOURCE="fs" ;;
esac

# ─── Write capabilities.json ────────────────────────────────────────────

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
NOW_UNIX=$(date -u +%s)
ADDONS_LIST=$(IFS=,; echo "${ADDONS_JSON[*]:-}")

cat > "$OUTPUT_FILE" <<EOF
{
  "schema_version": "1.1",
  "computed_at": "${NOW}",
  "resolved_at_unix": ${NOW_UNIX},
  "source": "${AGGREGATED_SOURCE}",
  "cc_cli_available": ${CC_CLI_AVAILABLE},
  "marketplace_found": true,
  "version": "${TIER_MAX_VERSION:-?}",
  "tier": "${TIER_MAX_NAME}",
  "tier_priority": ${TIER_MAX_PRIORITY},
  "addons": [${ADDONS_LIST}],
  "skills_total": ${TOTAL_SKILLS},
  "agents_total": ${TOTAL_AGENTS},
  "persona": "${TIER_MAX_PERSONA}",
  "pipeline": "${TIER_MAX_PIPELINE}",
  "banner_label": "${TIER_MAX_BANNER}"
}
EOF

# Optional: pretty-print if jq is available (for human inspection)
if command -v jq >/dev/null 2>&1; then
  jq . "$OUTPUT_FILE" > "${OUTPUT_FILE}.tmp" && /bin/mv -f "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"
fi

# Exit 0 on success — no stdout (silent for hook integration)
exit 0
