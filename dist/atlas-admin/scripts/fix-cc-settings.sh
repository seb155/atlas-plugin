#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# ATLAS — Fix CC settings.json deny rules
# © 2026 AXOIQ Inc.
#
# Problem: CC resérializes settings.json mid-session, restoring
# overly broad deny rules like "Bash(rm -rf /*)".
#
# Run this BEFORE launching CC, or from atlas setup.
# ═══════════════════════════════════════════════════════════════

SETTINGS="${HOME}/.claude/settings.json"

if [ ! -f "$SETTINGS" ]; then
  echo "⚠ No settings.json found at $SETTINGS"
  exit 1
fi

# Remove overly broad rm -rf patterns (keep exact root only)
python3 -c "
import json

with open('$SETTINGS') as f:
    s = json.load(f)

deny = s.get('permissions', {}).get('deny', [])
original_count = len(deny)

# Remove prefix-match patterns that are too broad
remove = [
    'Bash(rm -rf /*)',       # blocks ALL rm -rf /path/...
    'Bash(sudo rm -rf /*)',  # same with sudo
]
deny = [d for d in deny if d not in remove]

# Ensure exact-root blocks remain
for rule in ['Bash(rm -rf /)', 'Bash(sudo rm -rf /)']:
    if rule not in deny:
        deny.append(rule)

s['permissions']['deny'] = deny

with open('$SETTINGS', 'w') as f:
    json.dump(s, f, indent=2)

removed = original_count - len(deny)
if removed > 0:
    print(f'✅ Removed {removed} overly broad deny rules')
else:
    print('✅ Deny rules already clean')
" 2>/dev/null
