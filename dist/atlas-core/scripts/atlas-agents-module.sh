#!/usr/bin/env bash
# ATLAS Starship Custom Module — Subagent Visibility Indicator
#
# Reads ~/.atlas/runtime/agents.json (populated by SP-AGENT-VIS Phase 1
# subagent-output-capture hook) and emits a compact status indicator:
#   🤖2▶ 1✓    (2 running, 1 completed in last 30min)
#   🤖3▶       (3 running only)
#   🤖2▶ 1✗    (2 running, 1 failed)
#   (empty)    (no agents tracked)
#
# CShip consumes this via [custom.atlas_agents] command. Empty output =
# CShip hides the module.
#
# Plan: .blueprint/plans/keen-nibbling-umbrella.md Layer 2.
set -euo pipefail

AGENTS_FILE="${ATLAS_DIR:-$HOME/.atlas}/runtime/agents.json"

# Bail silently if registry doesn't exist yet (first session before any subagent ran)
[ -f "$AGENTS_FILE" ] || exit 0

# Require python3 OR jq; prefer python3 for time math
if ! command -v python3 &>/dev/null; then
  # jq fallback: running count only (no time filter on completed)
  if command -v jq &>/dev/null; then
    running=$(jq -r '[.[] | select(.status == "running" or .status == "spawning")] | length' "$AGENTS_FILE" 2>/dev/null || echo 0)
    [ "$running" -gt 0 ] 2>/dev/null && echo "🤖${running}▶"
  fi
  exit 0
fi

# Preferred path: python3 with 30-min completed/failed filter
python3 -c "
import json, sys
from datetime import datetime, timezone, timedelta

try:
    with open('${AGENTS_FILE}') as f:
        data = json.load(f)
except Exception:
    sys.exit(0)

cutoff = datetime.now(timezone.utc) - timedelta(minutes=30)
running = sum(1 for a in data.values() if a.get('status') in ('running', 'spawning'))
done = 0
failed = 0

for a in data.values():
    finished = a.get('finished_at')
    if not finished:
        continue
    try:
        ts = datetime.fromisoformat(finished.replace('Z', '+00:00'))
    except Exception:
        continue
    if ts < cutoff:
        continue
    if a.get('status') == 'completed':
        done += 1
    elif a.get('status') == 'failed':
        failed += 1

parts = []
if running > 0:
    parts.append(f'{running}▶')
if done > 0:
    parts.append(f'{done}✓')
if failed > 0:
    parts.append(f'{failed}✗')

if parts:
    print('🤖' + ' '.join(parts))
" 2>/dev/null || exit 0
