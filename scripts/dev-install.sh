#!/usr/bin/env bash
# dev-install.sh — Build and install plugin tiers to CC cache.
#
# Usage: ./scripts/dev-install.sh [--admin-only | --domains]
#
# Default: builds all 4 tiers (admin, dev, user, worker) and installs them.
# --admin-only: builds and installs only admin tier (quick iteration).
# --domains: builds and installs 6 domain plugins (core, dev, frontend, infra, enterprise, experiential).
#
# After running, restart Claude Code to pick up changes.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$(dirname "$SCRIPT_DIR")"

VERSION=$(cat VERSION | tr -d '[:space:]')
TIER_MARKETPLACE_DIR="$HOME/.claude/plugins/cache/atlas-admin-marketplace"
DOMAIN_MARKETPLACE_DIR="$HOME/.claude/plugins/cache/atlas-marketplace"
DOMAINS=(core dev frontend infra enterprise experiential)

if [ "${1:-}" = "--admin-only" ]; then
  echo "🔨 Building atlas-admin v${VERSION} (quick mode)..."
  ./build.sh admin

  echo ""
  echo "📦 Installing admin only to CC cache..."
  rm -rf "${TIER_MARKETPLACE_DIR}/atlas-admin/"
  mkdir -p "${TIER_MARKETPLACE_DIR}/atlas-admin/${VERSION}"
  cp -r dist/atlas-admin/* "${TIER_MARKETPLACE_DIR}/atlas-admin/${VERSION}/"

  echo ""
  echo "✅ Installed atlas-admin v${VERSION}"
  echo "   Cache: ${TIER_MARKETPLACE_DIR}/"

elif [ "${1:-}" = "--domains" ]; then
  echo "🔨 Building 6 domain plugins v${VERSION}..."
  ./build.sh domains

  echo ""
  echo "📦 Installing domain plugins to CC cache..."
  # Clear ALL cached domain versions to avoid stale confusion
  rm -rf "${DOMAIN_MARKETPLACE_DIR}/"

  for domain in "${DOMAINS[@]}"; do
    src_dir="dist/atlas-${domain}"
    if [ ! -d "$src_dir" ]; then
      echo "  ⚠️  atlas-${domain} not found in dist/, skipping"
      continue
    fi
    local_dir="${DOMAIN_MARKETPLACE_DIR}/atlas-${domain}/${VERSION}"
    mkdir -p "$local_dir"
    cp -r "${src_dir}/." "$local_dir/"
    echo "  ✅ atlas-${domain} → ${local_dir}"
  done

  echo ""
  echo "✅ Installed domain plugins v${VERSION}"
  echo "   Cache: ${DOMAIN_MARKETPLACE_DIR}/"

else
  echo "🔨 Building all 4 tiers v${VERSION}..."
  ./build.sh all

  echo ""
  echo "📦 Installing all plugins to CC cache..."
  # Clear ALL cached versions to avoid stale confusion
  rm -rf "${TIER_MARKETPLACE_DIR}/"

  for tier in admin dev user worker; do
    local_dir="${TIER_MARKETPLACE_DIR}/atlas-${tier}/${VERSION}"
    mkdir -p "$local_dir"
    cp -r "dist/atlas-${tier}/." "$local_dir/"
    echo "  ✅ atlas-${tier} → ${local_dir}"
  done

  echo ""
  echo "✅ Installed 4 plugins v${VERSION}"
  echo "   Cache: ${TIER_MARKETPLACE_DIR}/"
fi

# ─── Sync shell launcher ──────────────────────────────────────
SHELL_SRC="${SCRIPT_DIR}/atlas-cli.sh"
SHELL_DST="${HOME}/.atlas/shell/atlas.sh"
if [ -f "$SHELL_SRC" ]; then
  mkdir -p "$(dirname "$SHELL_DST")"
  cp "$SHELL_SRC" "$SHELL_DST"
  echo "  ✅ atlas-cli.sh → ${SHELL_DST}"
fi

echo ""
echo "⚠️  Restart Claude Code to apply changes."
echo ""
echo "📋 Next steps:"
echo "   1. Restart Claude Code      (picks up plugin changes)"
echo "   2. source ~/.zshrc          (reload shell with new atlas.sh)"
