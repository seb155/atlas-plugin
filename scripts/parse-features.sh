#!/usr/bin/env bash
# Parse .blueprint/FEATURES.md and output compact feature summary for session context injection
# Usage: ./parse-features.sh [path-to-FEATURES.md]
set -euo pipefail

FEATURES_FILE="${1:-.blueprint/FEATURES.md}"

if [ ! -f "$FEATURES_FILE" ]; then
  echo "No FEATURES.md found"
  exit 0
fi

# Count features by status
total=$(grep -c "^## Feature: FEAT-" "$FEATURES_FILE" 2>/dev/null || echo 0)
active=$(grep -c "🟡 IN_PROGRESS" "$FEATURES_FILE" 2>/dev/null || echo 0)
done_count=$(grep -c "✅ DONE" "$FEATURES_FILE" 2>/dev/null || echo 0)
planned=$(grep -c "📐 PLANNED" "$FEATURES_FILE" 2>/dev/null || echo 0)
backlog=$(grep -c "📋 BACKLOG" "$FEATURES_FILE" 2>/dev/null || echo 0)

echo "📌 Feature Board: ${total} features | ${active} active | ${done_count} done | ${planned} planned | ${backlog} backlog"

# List active features with validation summary
if [ "$active" -gt 0 ]; then
  echo ""
  echo "🟡 Active features:"
  # Extract feature name + validation status for active ones
  # Markdown table format: | **Layer** | Status | TestedBy | Date | Method | Notes |
  awk -F'|' '
    /^## Feature: FEAT-/ { feat=$0; sub(/^## Feature: /, "", feat); in_feat=1; status=""; be=""; fe=""; e2e=""; hitl="" }
    in_feat && /IN_PROGRESS/ { status="active" }
    in_feat && status=="active" && /\*\*BE Unit\*\*/ { gsub(/[[:space:]]/, "", $3); be=$3 }
    in_feat && status=="active" && /\*\*FE Unit\*\*/ { gsub(/[[:space:]]/, "", $3); fe=$3 }
    in_feat && status=="active" && /\*\*E2E Workflow\*\*/ { gsub(/[[:space:]]/, "", $3); e2e=$3 }
    in_feat && status=="active" && /\*\*HITL Review\*\*/ { gsub(/[[:space:]]/, "", $3); hitl=$3; printf "  • %s  BE:%s FE:%s E2E:%s HITL:%s\n", feat, be, fe, e2e, hitl; status="" }
  ' "$FEATURES_FILE" 2>/dev/null || true
fi

# Suggestions
echo ""
echo "🎯 Suggestions:"

# Find features ready for HITL (all tests pass but HITL pending)
grep -B30 "HITL Review.*🔵 PENDING" "$FEATURES_FILE" 2>/dev/null | grep "^## Feature:" | sed 's/^## Feature: /  → Ready for HITL: /' || true

# Find features with E2E failing
grep -B30 "E2E Workflow.*❌" "$FEATURES_FILE" 2>/dev/null | grep "^## Feature:" | sed 's/^## Feature: /  ⚠️ E2E failing: /' || true
