#!/usr/bin/env bash
# ATLAS CShip Custom Module — Session cost in USD
# CC v2.1.x exposes `cost.total_cost_usd` field in status line JSON input.
# Expected env var: CSHIP_COST_TOTAL_USD (float string, e.g. "0.24")
# Output: "💰 $X.XX" (or empty if zero/unset)

set -euo pipefail

# Try multiple env var names (CShip naming convention uncertain)
readonly COST="${CSHIP_COST_TOTAL_USD:-${CSHIP_COST_USD:-${CSHIP_TOTAL_COST_USD:-0}}}"

# Skip rendering if zero or unset
if [[ -z "$COST" || "$COST" == "0" || "$COST" == "0.0" || "$COST" == "0.00" ]]; then
  exit 0
fi

# Format to 2 decimal places (safe fallback if input malformed)
formatted=$(awk "BEGIN { printf \"%.2f\", ${COST} + 0 }" 2>/dev/null || echo "$COST")

# Only render if > $0.01 (avoid noise)
if awk "BEGIN { exit !(${formatted} >= 0.01) }" 2>/dev/null; then
  echo "💰 \$${formatted}"
fi
