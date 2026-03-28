#!/usr/bin/env bash
# Parse .blueprint/FEATURES.md → compact feature summary for session context injection
# Usage: ./parse-features.sh [path-to-FEATURES.md]
# Output: Feature counts, active features with validation icons, proactive suggestions
set -euo pipefail

FEATURES_FILE="${1:-.blueprint/FEATURES.md}"

if [ ! -f "$FEATURES_FILE" ]; then
  echo "No FEATURES.md found"
  exit 0
fi

# Single awk pass: extract everything in one read (no fragile grep -B pipelines)
awk -F'|' '
BEGIN {
  total=0; active=0; done_c=0; planned=0; backlog=0; testing=0
  feat_idx=0
}

# Feature header: ## Feature: FEAT-NNN — Name
/^## Feature: FEAT-[0-9]/ {
  # Save previous feature if exists
  if (feat_idx > 0) {
    feats[feat_idx] = feat_name
    stats[feat_idx] = feat_status
    vbe[feat_idx] = be; vfe[feat_idx] = fe; ve2e[feat_idx] = e2e; vhitl[feat_idx] = hitl
    prog[feat_idx] = progress_val
  }
  feat_idx++; total++
  feat_name = $0; sub(/^## Feature: /, "", feat_name)
  feat_status = ""; be = ""; fe = ""; e2e = ""; hitl = ""; progress_val = ""
}

# Status field in metadata table
/\*\*Status\*\*/ && /IN_PROGRESS/ { feat_status = "active"; active++ }
/\*\*Status\*\*/ && /DONE/ { feat_status = "done"; done_c++ }
/\*\*Status\*\*/ && /PLANNED/ { feat_status = "planned"; planned++ }
/\*\*Status\*\*/ && /BACKLOG/ { feat_status = "backlog"; backlog++ }
/\*\*Status\*\*/ && /TESTING/ { feat_status = "testing"; testing++ }

# Progress field
/\*\*Progress\*\*/ {
  match($0, /[0-9]+%/)
  if (RSTART > 0) progress_val = substr($0, RSTART, RLENGTH)
}

# Validation matrix rows (pipe-delimited: | **Layer** | Status | ...)
/\*\*BE Unit\*\*/ { gsub(/[[:space:]]/, "", $3); be = $3 }
/\*\*FE Unit\*\*/ { gsub(/[[:space:]]/, "", $3); fe = $3 }
/\*\*E2E Workflow\*\*/ { gsub(/[[:space:]]/, "", $3); e2e = $3 }
/\*\*HITL Review\*\*/ { gsub(/[[:space:]]/, "", $3); hitl = $3 }

END {
  # Save last feature
  if (feat_idx > 0) {
    feats[feat_idx] = feat_name
    stats[feat_idx] = feat_status
    vbe[feat_idx] = be; vfe[feat_idx] = fe; ve2e[feat_idx] = e2e; vhitl[feat_idx] = hitl
    prog[feat_idx] = progress_val
  }

  # Summary line
  printf "📌 Feature Board: %d features | %d active | %d done | %d planned | %d backlog\n", total, active, done_c, planned, backlog

  # Active features with validation
  if (active > 0) {
    printf "\n🟡 Active features:\n"
    for (i = 1; i <= feat_idx; i++) {
      if (stats[i] == "active") {
        printf "  • %s %s  BE:%s FE:%s E2E:%s HITL:%s\n", feats[i], prog[i], vbe[i], vfe[i], ve2e[i], vhitl[i]
      }
    }
  }

  # Suggestions
  printf "\n🎯 Suggestions:\n"
  has_suggestion = 0

  for (i = 1; i <= feat_idx; i++) {
    # Ready for HITL: BE+FE pass but HITL pending
    if (vbe[i] ~ /PASS/ && vfe[i] ~ /PASS/ && vhitl[i] ~ /PENDING/) {
      printf "  → Ready for HITL review: %s\n", feats[i]
      has_suggestion = 1
    }
    # E2E failing
    if (ve2e[i] ~ /FAIL|NOT/) {
      printf "  ⚠️ E2E failing: %s\n", feats[i]
      has_suggestion = 1
    }
    # Stale: active but 0% progress
    if (stats[i] == "active" && prog[i] == "0%") {
      printf "  💤 No progress: %s\n", feats[i]
      has_suggestion = 1
    }
  }

  if (!has_suggestion) {
    printf "  ✅ No issues detected\n"
  }
}
' "$FEATURES_FILE"
