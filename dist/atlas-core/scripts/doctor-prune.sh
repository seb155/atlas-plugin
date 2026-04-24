#!/usr/bin/env bash
# doctor-prune.sh — Prune orphan plugin cache versions
#
# Claude Code's marketplace cache accumulates versioned dirs over time (grace
# period ~7 days). For atlas-core this commonly reaches 20-35 versions.
# This script removes orphans with safety rails:
#
#   - KEEP:   any version referenced by `claude plugin list --json` (active)
#   - KEEP:   up to 2 most recent orphan versions per plugin (safety net)
#   - DELETE: everything else
#
# Default mode is --dry-run (no filesystem change). Use --confirm to apply.
# Refuses to run without `claude` + `jq` in PATH.

set -uo pipefail

CACHE_DIR="$HOME/.claude/plugins/cache/atlas-marketplace"
DRY_RUN=true

# --- Parse args ---
for arg in "$@"; do
  case "$arg" in
    --confirm) DRY_RUN=false ;;
    --dry-run) DRY_RUN=true ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--dry-run|--confirm]

Prune orphan ATLAS plugin cache versions.

  --dry-run   Print what would be deleted without touching filesystem (default)
  --confirm   Actually delete orphan versions

Safety: keeps the active version (per \`claude plugin list\`) + 2 orphans.
EOF
      exit 0
      ;;
    *)
      echo "Unknown arg: $arg (use --help)" >&2
      exit 2
      ;;
  esac
done

# --- Safety checks ---
if ! command -v claude >/dev/null 2>&1; then
  echo "ERROR: claude CLI not in PATH — refusing to prune (can't determine active versions)" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not in PATH" >&2
  exit 1
fi
if [ ! -d "$CACHE_DIR" ]; then
  echo "Cache dir not found: $CACHE_DIR"
  exit 0
fi

# --- Get active installPaths ---
ACTIVE_PATHS=$(claude plugin list --json 2>/dev/null | \
  jq -r '.[] | select(.id | endswith("@atlas-marketplace")) | .installPath' | sort -u)

if [ -z "$ACTIVE_PATHS" ]; then
  echo "ERROR: \`claude plugin list\` returned no ATLAS plugins — aborting (prevents wiping cache)" >&2
  exit 1
fi

echo "Active versions (from claude plugin list):"
echo "$ACTIVE_PATHS" | sed 's|^|  |'
echo ""

# --- Iterate each addon, decide per version ---
TOTAL_KEPT=0
TOTAL_DELETED=0

for addon_dir in "$CACHE_DIR"/atlas-*/; do
  [ -d "$addon_dir" ] || continue
  addon_name=$(basename "$addon_dir")

  # All versions sorted semver descending (most recent first)
  all_versions=$(ls -1d "${addon_dir}"*/ 2>/dev/null | sort -rV)
  [ -z "$all_versions" ] && continue

  # Find active version path for THIS plugin
  active_for_this=""
  while IFS= read -r p; do
    case "$p" in
      *"/$addon_name/"*) active_for_this="${p%/}/"; break ;;
    esac
  done <<< "$ACTIVE_PATHS"

  echo "=== $addon_name ==="

  kept_orphans=0
  while IFS= read -r v; do
    [ -z "$v" ] && continue
    base=$(basename "${v%/}")

    if [ "${v%/}/" = "$active_for_this" ]; then
      echo "  KEEP (active):  $base"
      TOTAL_KEPT=$((TOTAL_KEPT + 1))
    elif [ "$kept_orphans" -lt 2 ]; then
      echo "  KEEP (orphan):  $base"
      kept_orphans=$((kept_orphans + 1))
      TOTAL_KEPT=$((TOTAL_KEPT + 1))
    else
      if $DRY_RUN; then
        echo "  [DRY-RUN] del:  $base"
      else
        echo "  DELETE:         $base"
        rm -rf "$v" 2>/dev/null
      fi
      TOTAL_DELETED=$((TOTAL_DELETED + 1))
    fi
  done <<< "$all_versions"
done

echo ""
if $DRY_RUN; then
  echo "Summary: $TOTAL_KEPT kept, $TOTAL_DELETED would be deleted."
  echo "Run with --confirm to apply."
else
  echo "Summary: $TOTAL_KEPT kept, $TOTAL_DELETED deleted."
fi
