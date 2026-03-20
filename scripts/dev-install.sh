#!/usr/bin/env bash
# dev-install.sh — Build admin tier and install to CC plugin cache.
#
# Usage: ./scripts/dev-install.sh
#
# After running, restart Claude Code to pick up changes.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$(dirname "$SCRIPT_DIR")"

VERSION=$(cat VERSION | tr -d '[:space:]')
CACHE_DIR="$HOME/.claude/plugins/cache/atlas-admin-marketplace/atlas-admin/$VERSION"

echo "🔨 Building atlas-admin v${VERSION}..."
./build.sh admin

echo ""
echo "📦 Installing to CC cache..."
rm -rf "$CACHE_DIR"
cp -r dist/atlas-admin "$CACHE_DIR"

echo ""
echo "✅ Installed atlas-admin v${VERSION}"
echo "   Cache: $CACHE_DIR"
echo ""
echo "⚠️  Restart Claude Code to apply changes."
