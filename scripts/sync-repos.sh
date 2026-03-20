#!/usr/bin/env bash
# sync-repos.sh — Bidirectional sync between atlas-plugin repos.
#
# Usage:
#   ./scripts/sync-repos.sh --status          # Show diff report only
#   ./scripts/sync-repos.sh --to-synapse      # Copy missing from dev → synapse
#   ./scripts/sync-repos.sh --to-dev          # Copy missing from synapse → dev
#   ./scripts/sync-repos.sh --both            # Sync both directions
#   ./scripts/sync-repos.sh --dry-run --both  # Preview without copying
#
# Requires: SYNAPSE_PLUGIN and DEV_PLUGIN env vars, or auto-detects from known paths.

set -euo pipefail

# ── Paths ──────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SYNAPSE_PLUGIN="${SYNAPSE_PLUGIN:-$(dirname "$SCRIPT_DIR")}"
DEV_PLUGIN="${DEV_PLUGIN:-$HOME/workspace_atlas/projects/atlas-dev-plugin}"

# ── Flags ──────────────────────────────────────────────────────────────────────
DRY_RUN=false
TO_SYNAPSE=false
TO_DEV=false
STATUS_ONLY=false

for arg in "$@"; do
  case "$arg" in
    --dry-run)     DRY_RUN=true ;;
    --to-synapse)  TO_SYNAPSE=true ;;
    --to-dev)      TO_DEV=true ;;
    --both)        TO_SYNAPSE=true; TO_DEV=true ;;
    --status)      STATUS_ONLY=true ;;
    -h|--help)
      echo "Usage: $0 [--status|--to-synapse|--to-dev|--both] [--dry-run]"
      exit 0 ;;
    *) echo "Unknown flag: $arg"; exit 1 ;;
  esac
done

# Default to --status if no action specified
if ! $TO_SYNAPSE && ! $TO_DEV && ! $STATUS_ONLY; then
  STATUS_ONLY=true
fi

# ── Validation ─────────────────────────────────────────────────────────────────
if [ ! -d "$SYNAPSE_PLUGIN/skills" ]; then
  echo "ERROR: Synapse plugin not found at $SYNAPSE_PLUGIN"
  exit 1
fi
if [ ! -d "$DEV_PLUGIN/skills" ]; then
  echo "ERROR: Dev plugin not found at $DEV_PLUGIN"
  exit 1
fi

# ── Colors ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ── Version Check ──────────────────────────────────────────────────────────────
SYN_VERSION=$(cat "$SYNAPSE_PLUGIN/VERSION" 2>/dev/null || echo "MISSING")
DEV_VERSION=$(cat "$DEV_PLUGIN/VERSION" 2>/dev/null || echo "MISSING")

echo -e "${CYAN}=== ATLAS Plugin Sync ===${NC}"
echo -e "Synapse: $SYNAPSE_PLUGIN (v$SYN_VERSION)"
echo -e "Dev:     $DEV_PLUGIN (v$DEV_VERSION)"
echo ""

if [ "$SYN_VERSION" != "$DEV_VERSION" ]; then
  echo -e "${RED}WARNING: VERSION mismatch! synapse=$SYN_VERSION dev=$DEV_VERSION${NC}"
  echo ""
fi

# ── Diff Functions ─────────────────────────────────────────────────────────────
diff_dirs() {
  local label="$1"
  local syn_dir="$2"
  local dev_dir="$3"

  local only_syn=()
  local only_dev=()

  # Items only in synapse
  if [ -d "$syn_dir" ]; then
    for item in "$syn_dir"/*/; do
      [ -d "$item" ] || continue
      local name=$(basename "$item")
      [ "$name" = "refs" ] && continue  # Skip refs (managed separately)
      if [ ! -d "$dev_dir/$name" ]; then
        only_syn+=("$name")
      fi
    done
  fi

  # Items only in dev
  if [ -d "$dev_dir" ]; then
    for item in "$dev_dir"/*/; do
      [ -d "$item" ] || continue
      local name=$(basename "$item")
      [ "$name" = "refs" ] && continue
      if [ ! -d "$syn_dir/$name" ]; then
        only_dev+=("$name")
      fi
    done
  fi

  # Report
  if [ ${#only_syn[@]} -gt 0 ] || [ ${#only_dev[@]} -gt 0 ]; then
    echo -e "${YELLOW}[$label]${NC}"
    for item in "${only_syn[@]:-}"; do
      [ -n "$item" ] && echo -e "  ${GREEN}+ synapse only:${NC} $item"
    done
    for item in "${only_dev[@]:-}"; do
      [ -n "$item" ] && echo -e "  ${RED}+ dev only:${NC} $item"
    done
    echo ""
  fi

  # Return arrays for sync
  echo "${only_syn[*]:-}" > /tmp/sync_only_syn
  echo "${only_dev[*]:-}" > /tmp/sync_only_dev
}

diff_files() {
  local label="$1"
  local syn_dir="$2"
  local dev_dir="$3"

  local only_syn=()
  local only_dev=()

  if [ -d "$syn_dir" ]; then
    for f in "$syn_dir"/*.md; do
      [ -f "$f" ] || continue
      local name=$(basename "$f")
      if [ ! -f "$dev_dir/$name" ]; then
        only_syn+=("$name")
      fi
    done
  fi

  if [ -d "$dev_dir" ]; then
    for f in "$dev_dir"/*.md; do
      [ -f "$f" ] || continue
      local name=$(basename "$f")
      if [ ! -f "$syn_dir/$name" ]; then
        only_dev+=("$name")
      fi
    done
  fi

  if [ ${#only_syn[@]} -gt 0 ] || [ ${#only_dev[@]} -gt 0 ]; then
    echo -e "${YELLOW}[$label]${NC}"
    for item in "${only_syn[@]:-}"; do
      [ -n "$item" ] && echo -e "  ${GREEN}+ synapse only:${NC} $item"
    done
    for item in "${only_dev[@]:-}"; do
      [ -n "$item" ] && echo -e "  ${RED}+ dev only:${NC} $item"
    done
    echo ""
  fi

  echo "${only_syn[*]:-}" > /tmp/sync_only_syn_files
  echo "${only_dev[*]:-}" > /tmp/sync_only_dev_files
}

# ── Run Diffs ──────────────────────────────────────────────────────────────────
echo -e "${CYAN}--- Differences ---${NC}"
echo ""

diff_dirs "Skills" "$SYNAPSE_PLUGIN/skills" "$DEV_PLUGIN/skills"
SKILLS_ONLY_SYN=$(cat /tmp/sync_only_syn)
SKILLS_ONLY_DEV=$(cat /tmp/sync_only_dev)

diff_dirs "Agents" "$SYNAPSE_PLUGIN/agents" "$DEV_PLUGIN/agents"
AGENTS_ONLY_SYN=$(cat /tmp/sync_only_syn)
AGENTS_ONLY_DEV=$(cat /tmp/sync_only_dev)

diff_files "Commands" "$SYNAPSE_PLUGIN/commands" "$DEV_PLUGIN/commands"
CMDS_ONLY_SYN=$(cat /tmp/sync_only_syn_files)
CMDS_ONLY_DEV=$(cat /tmp/sync_only_dev_files)

# Tests directory check
if [ -d "$SYNAPSE_PLUGIN/tests" ] && [ ! -d "$DEV_PLUGIN/tests" ]; then
  echo -e "${YELLOW}[Tests]${NC}"
  echo -e "  ${GREEN}+ synapse only:${NC} tests/ directory ($(find "$SYNAPSE_PLUGIN/tests" -name "*.py" | wc -l) files)"
  echo ""
fi

if $STATUS_ONLY; then
  echo -e "${CYAN}Done. Use --to-synapse, --to-dev, or --both to sync.${NC}"
  exit 0
fi

# ── Sync Functions ─────────────────────────────────────────────────────────────
sync_item() {
  local src="$1"
  local dst="$2"
  local label="$3"

  if $DRY_RUN; then
    echo -e "  ${YELLOW}[DRY-RUN]${NC} Would copy: $label"
  else
    cp -r "$src" "$dst"
    echo -e "  ${GREEN}[COPIED]${NC} $label"
  fi
}

# ── Execute Sync ───────────────────────────────────────────────────────────────
if $TO_SYNAPSE; then
  echo -e "${CYAN}--- Syncing dev → synapse ---${NC}"
  for skill in $SKILLS_ONLY_DEV; do
    [ -n "$skill" ] && sync_item "$DEV_PLUGIN/skills/$skill" "$SYNAPSE_PLUGIN/skills/" "skill: $skill"
  done
  for agent in $AGENTS_ONLY_DEV; do
    [ -n "$agent" ] && sync_item "$DEV_PLUGIN/agents/$agent" "$SYNAPSE_PLUGIN/agents/" "agent: $agent"
  done
  for cmd in $CMDS_ONLY_DEV; do
    [ -n "$cmd" ] && sync_item "$DEV_PLUGIN/commands/$cmd" "$SYNAPSE_PLUGIN/commands/" "command: $cmd"
  done
  echo ""
fi

if $TO_DEV; then
  echo -e "${CYAN}--- Syncing synapse → dev ---${NC}"
  for skill in $SKILLS_ONLY_SYN; do
    [ -n "$skill" ] && sync_item "$SYNAPSE_PLUGIN/skills/$skill" "$DEV_PLUGIN/skills/" "skill: $skill"
  done
  for agent in $AGENTS_ONLY_SYN; do
    [ -n "$agent" ] && sync_item "$SYNAPSE_PLUGIN/agents/$agent" "$DEV_PLUGIN/agents/" "agent: $agent"
  done
  for cmd in $CMDS_ONLY_SYN; do
    [ -n "$cmd" ] && sync_item "$SYNAPSE_PLUGIN/commands/$cmd" "$DEV_PLUGIN/commands/" "command: $cmd"
  done
  # Sync tests directory
  if [ -d "$SYNAPSE_PLUGIN/tests" ] && [ ! -d "$DEV_PLUGIN/tests" ]; then
    sync_item "$SYNAPSE_PLUGIN/tests" "$DEV_PLUGIN/" "tests/ directory"
  fi
  echo ""
fi

echo -e "${GREEN}Sync complete.${NC}"
