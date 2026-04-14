#!/usr/bin/env bash
# ATLAS CShip Custom Module — Effort level badge
# CC v2.1.84+ exposes `effort` field in status line JSON input.
# Expected env var: CSHIP_EFFORT ("low" | "medium" | "high" | "")
# Output: "📊 low" / "📊 med" / "📊 high" (or empty if not set)

set -euo pipefail

readonly EFFORT="${CSHIP_EFFORT:-}"

case "$EFFORT" in
  low)    echo "📊 low" ;;
  medium) echo "📊 med" ;;
  high)   echo "📊 high" ;;
  *)      : ;;  # empty → no badge (conditional render)
esac
