#!/usr/bin/env bash
# test-worker-plugin.sh — Validate atlas-worker plugin in Claude Code
#
# Run from a FRESH terminal (not inside CC):
#   cd /path/to/your/synapse/project
#   bash /path/to/atlas-dev-plugin/scripts/test-worker-plugin.sh
#
# Tests:
# 1. CC starts with atlas-worker enabled → no hook errors
# 2. Worker SKILL.md is minimal (~20 lines)
# 3. Worker has zero hooks
set -euo pipefail

CACHE="$HOME/.claude/plugins/cache/atlas-admin-marketplace"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION=$(cat "$PLUGIN_ROOT/VERSION" 2>/dev/null | tr -d '[:space:]' || echo "0.0.0")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ATLAS Worker Plugin Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test 1: Cache structure
echo "📦 Test 1: Cache structure"
for tier in admin dev user worker; do
  dir="${CACHE}/atlas-${tier}/${VERSION}"
  if [ -d "$dir" ]; then
    skills=$(ls "$dir/skills/" 2>/dev/null | wc -l)
    hooks_events=$(python3 -c "import json; d=json.load(open('$dir/hooks/hooks.json')); print(len(d.get('hooks',{})))" 2>/dev/null || echo "?")
    echo "  ✅ atlas-${tier}: ${skills} skills, ${hooks_events} hook events"
  else
    echo "  ❌ atlas-${tier}: NOT FOUND at $dir"
  fi
done
echo ""

# Test 2: Worker plugin specifics
echo "🔍 Test 2: Worker plugin content"
worker_dir="${CACHE}/atlas-worker/${VERSION}"
echo "  Skills: $(ls "$worker_dir/skills/")"
echo "  Agents: $(ls "$worker_dir/agents/" 2>/dev/null || echo '(none)')"
echo "  hooks.json: $(cat "$worker_dir/hooks/hooks.json")"
echo "  atlas-assist lines: $(wc -l < "$worker_dir/skills/atlas-assist/SKILL.md")"
echo ""

# Test 3: Marketplace.json
echo "🏪 Test 3: Marketplace consistency"
for tier in admin dev user worker; do
  mkt=$(python3 -c "import json; print(json.load(open('${CACHE}/atlas-${tier}/${VERSION}/.claude-plugin/marketplace.json'))['name'])" 2>/dev/null || echo "ERROR")
  echo "  atlas-${tier}: marketplace = ${mkt}"
done
echo ""

# Test 4: Registry
echo "📋 Test 4: Plugin registry"
python3 -c "
import json
d = json.load(open('$HOME/.claude/plugins/installed_plugins.json'))
for key in sorted(d['plugins'].keys()):
    if 'atlas' in key:
        entries = d['plugins'][key]
        for e in entries:
            print(f'  {key}: scope={e[\"scope\"]}, version={e.get(\"version\",\"?\")}')" 2>/dev/null
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  To test in CC:"
echo "  1. Add to synapse .claude/settings.json enabledPlugins:"
echo '     "atlas-worker@atlas-admin-marketplace": true'
echo "  2. Start new CC session in synapse/"
echo "  3. Ask: 'What ATLAS skills do you see?'"
echo "  4. Spawn a team: '/atlas team jarvis'"
echo "  5. Check worker panes for ATLAS banner"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
