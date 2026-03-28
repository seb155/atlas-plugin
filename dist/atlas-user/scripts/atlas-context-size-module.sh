#!/usr/bin/env bash
# ATLAS Starship Custom Module — Context window size (1M indicator)
# Shows "1M" for Max plan Opus, "200K" for standard.
# CShip exports CSHIP_CONTEXT_SIZE and CSHIP_MODEL_ID.
set -euo pipefail

SIZE="${CSHIP_CONTEXT_SIZE:-200000}"
MODEL="${CSHIP_MODEL_ID:-unknown}"

# Determine real context budget based on model + plan
# Opus 4.6 on Max plan = 1M tokens
# Sonnet 4.6 = 200K tokens
# Haiku 4.5 = 200K tokens
if [ "$SIZE" -gt 200000 ] 2>/dev/null; then
  echo "1M"
elif echo "$MODEL" | grep -qi 'opus.*\[1m\]'; then
  echo "1M"
elif echo "$MODEL" | grep -qi 'opus'; then
  # Check subscription type from credentials
  CREDS="${HOME}/.claude/.credentials.json"
  if [ -f "$CREDS" ]; then
    SUB=$(python3 -c "import json; print(json.load(open('$CREDS')).get('claudeAiOauth',{}).get('subscriptionType',''))" 2>/dev/null)
    [ "$SUB" = "max" ] && echo "1M" && exit 0
  fi
  echo "200K"
else
  # Sonnet/Haiku = 200K
  echo "200K"
fi
