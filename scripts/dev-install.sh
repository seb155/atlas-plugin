#!/usr/bin/env bash
# dev-install.sh — Build and install plugin tiers to CC cache.
#
# Usage: ./scripts/dev-install.sh [--admin-only]
#
# Default: builds all 4 tiers (admin, dev, user, worker) and installs them.
# --admin-only: builds and installs only admin tier (quick iteration).
#
# After running, restart Claude Code to pick up changes.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$(dirname "$SCRIPT_DIR")"

VERSION=$(cat VERSION | tr -d '[:space:]')
MARKETPLACE_DIR="$HOME/.claude/plugins/cache/atlas-admin-marketplace"

if [ "${1:-}" = "--admin-only" ]; then
  echo "🔨 Building atlas-admin v${VERSION} (quick mode)..."
  ./build.sh admin

  echo ""
  echo "📦 Installing admin only to CC cache..."
  rm -rf "${MARKETPLACE_DIR}/atlas-admin/"
  mkdir -p "${MARKETPLACE_DIR}/atlas-admin/${VERSION}"
  cp -r dist/atlas-admin/* "${MARKETPLACE_DIR}/atlas-admin/${VERSION}/"

  echo ""
  echo "✅ Installed atlas-admin v${VERSION}"
else
  echo "🔨 Building all 4 tiers v${VERSION}..."
  ./build.sh all

  echo ""
  echo "📦 Installing all plugins to CC cache..."
  # Clear ALL cached versions to avoid stale confusion
  rm -rf "${MARKETPLACE_DIR}/"

  for tier in admin dev user worker; do
    local_dir="${MARKETPLACE_DIR}/atlas-${tier}/${VERSION}"
    mkdir -p "$local_dir"
    cp -r "dist/atlas-${tier}/." "$local_dir/"
    echo "  ✅ atlas-${tier} → ${local_dir}"
  done

  echo ""
  echo "✅ Installed 4 plugins v${VERSION}"
fi

echo "   Cache: ${MARKETPLACE_DIR}/"
echo ""
echo "⚠️  Restart Claude Code to apply changes."
