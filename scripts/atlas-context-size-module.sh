#!/usr/bin/env bash
# ATLAS CShip Custom Module — Context window size indicator
# Shows "1M" or "200K" based on model capability.
#
# Detection priority (first match wins):
#   1. CSHIP_CONTEXT_SIZE env var > 500000 → "1M"
#   2. Model ID contains [1m] suffix → "1M"
#   3. Model is Opus 4.7 or Sonnet 4.6 → "1M" (default for these models)
#   4. Model is Opus (pre-4.7) with Max subscription → "1M"
#   5. Fallback → "200K"
#
# Updated v5.22.0: Opus 4.7 + Sonnet 4.6 default to 1M (per CC v2.1.111+).
# CShip env vars: CSHIP_CONTEXT_SIZE, CSHIP_MODEL_ID

set -euo pipefail

readonly SIZE="${CSHIP_CONTEXT_SIZE:-200000}"
readonly MODEL="${CSHIP_MODEL_ID:-unknown}"

# Priority 1: explicit size from JSON input (most reliable)
if [[ "$SIZE" =~ ^[0-9]+$ ]] && (( SIZE > 500000 )); then
  echo "1M"
  exit 0
fi

# Priority 2: explicit [1m] suffix in model ID
if echo "$MODEL" | grep -qi '\[1m\]'; then
  echo "1M"
  exit 0
fi

# Priority 3: Opus 4.7 and Sonnet 4.6 default to 1M context per CC v2.1.111+
if echo "$MODEL" | grep -qiE 'opus-4-[67]|sonnet-4-6'; then
  echo "1M"
  exit 0
fi

# Priority 4: legacy Opus with Max subscription
if echo "$MODEL" | grep -qi 'opus'; then
  readonly CREDS="${HOME}/.claude/.credentials.json"
  if [[ -r "$CREDS" ]]; then
    SUB=$(python3 -c "import json,sys; print(json.load(open('$CREDS')).get('claudeAiOauth',{}).get('subscriptionType',''))" 2>/dev/null || echo "")
    if [[ "$SUB" == "max" ]]; then
      echo "1M"
      exit 0
    fi
  fi
fi

# Priority 5: fallback (Haiku or unknown)
echo "200K"
