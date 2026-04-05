#!/usr/bin/env bash
# manifest-dag-builder.sh — Validate and analyze execution manifest DAG
#
# Reads a manifest JSON, validates the dependency graph (no cycles),
# outputs execution order (topological sort), identifies parallel groups,
# and reports the critical path.
#
# Usage:
#   bash scripts/manifest-dag-builder.sh <manifest.json>
#   bash scripts/manifest-dag-builder.sh .claude/execution-manifest.json
#
# Output:
#   - Dependency validation (cycle detection)
#   - Topological execution order
#   - Parallel groups with task lists
#   - Critical path with total hours
#
# Dependencies: jq (required), python3 (fallback for cycle detection)

set -euo pipefail

# --- Arguments ---
MANIFEST="${1:-}"
if [[ -z "$MANIFEST" ]]; then
  echo "ERROR: No manifest file specified"
  echo "Usage: bash scripts/manifest-dag-builder.sh <manifest.json>"
  exit 1
fi

if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: Manifest file not found: $MANIFEST"
  exit 1
fi

# --- Check dependencies ---
if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required but not installed"
  echo "Install: sudo apt install jq  OR  brew install jq"
  exit 1
fi

# --- Validate JSON ---
if ! jq empty "$MANIFEST" 2>/dev/null; then
  echo "ERROR: Invalid JSON in $MANIFEST"
  exit 1
fi

echo "=========================================="
echo "  Execution Manifest DAG Analysis"
echo "=========================================="
echo ""

# --- Extract task data ---
TASK_COUNT=$(jq '.tasks | length' "$MANIFEST")
PLAN_NAME=$(jq -r '.plan.name // "Unknown"' "$MANIFEST")
PLAN_PATH=$(jq -r '.plan.path // "Unknown"' "$MANIFEST")

echo "Plan: $PLAN_NAME"
echo "Path: $PLAN_PATH"
echo "Tasks: $TASK_COUNT"
echo ""

if [[ "$TASK_COUNT" -eq 0 ]]; then
  echo "WARNING: No tasks found in manifest"
  exit 0
fi

# --- 1. Validate dependencies (all referenced IDs exist) ---
echo "--- Dependency Validation ---"
ERRORS=0

# Get all task IDs
TASK_IDS=$(jq -r '.tasks[].id' "$MANIFEST")

# Check that every depends_on reference points to an existing task
while IFS= read -r line; do
  TASK_ID=$(echo "$line" | jq -r '.id')
  DEPS=$(echo "$line" | jq -r '.depends_on[]? // empty')
  for DEP in $DEPS; do
    if ! echo "$TASK_IDS" | grep -qx "$DEP"; then
      echo "  ERROR: Task $TASK_ID depends on $DEP which does not exist"
      ERRORS=$((ERRORS + 1))
    fi
  done
done < <(jq -c '.tasks[]' "$MANIFEST")

if [[ "$ERRORS" -eq 0 ]]; then
  echo "  All dependency references valid"
else
  echo "  Found $ERRORS invalid dependency references"
  exit 1
fi

# --- 2. Cycle detection (Kahn's algorithm via jq + bash) ---
echo ""
echo "--- Cycle Detection ---"

# Build in-degree map and adjacency list using a temp file approach
TOPO_ORDER=()
declare -A IN_DEGREE
declare -A ADJ_LIST

# Initialize
while IFS= read -r line; do
  TID=$(echo "$line" | jq -r '.id')
  IN_DEGREE["$TID"]=0
  ADJ_LIST["$TID"]=""
done < <(jq -c '.tasks[]' "$MANIFEST")

# Build edges
while IFS= read -r line; do
  TID=$(echo "$line" | jq -r '.id')
  DEPS=$(echo "$line" | jq -r '.depends_on[]? // empty')
  DEP_COUNT=0
  for DEP in $DEPS; do
    DEP_COUNT=$((DEP_COUNT + 1))
    # DEP → TID (DEP blocks TID)
    if [[ -n "${ADJ_LIST[$DEP]:-}" ]]; then
      ADJ_LIST["$DEP"]="${ADJ_LIST[$DEP]} $TID"
    else
      ADJ_LIST["$DEP"]="$TID"
    fi
  done
  IN_DEGREE["$TID"]=$DEP_COUNT
done < <(jq -c '.tasks[]' "$MANIFEST")

# Kahn's algorithm
QUEUE=()
for TID in "${!IN_DEGREE[@]}"; do
  if [[ "${IN_DEGREE[$TID]}" -eq 0 ]]; then
    QUEUE+=("$TID")
  fi
done

PROCESSED=0
while [[ ${#QUEUE[@]} -gt 0 ]]; do
  # Dequeue first element
  CURRENT="${QUEUE[0]}"
  QUEUE=("${QUEUE[@]:1}")
  TOPO_ORDER+=("$CURRENT")
  PROCESSED=$((PROCESSED + 1))

  # Process neighbors
  for NEIGHBOR in ${ADJ_LIST[$CURRENT]:-}; do
    IN_DEGREE["$NEIGHBOR"]=$((IN_DEGREE[$NEIGHBOR] - 1))
    if [[ "${IN_DEGREE[$NEIGHBOR]}" -eq 0 ]]; then
      QUEUE+=("$NEIGHBOR")
    fi
  done
done

if [[ "$PROCESSED" -ne "$TASK_COUNT" ]]; then
  echo "  CYCLE DETECTED! Only $PROCESSED of $TASK_COUNT tasks could be ordered."
  echo "  Tasks involved in cycle:"
  for TID in "${!IN_DEGREE[@]}"; do
    if [[ "${IN_DEGREE[$TID]}" -gt 0 ]]; then
      echo "    - $TID (unresolved deps: ${IN_DEGREE[$TID]})"
    fi
  done
  exit 1
else
  echo "  No cycles detected (DAG is valid)"
fi

# --- 3. Topological execution order ---
echo ""
echo "--- Execution Order (Topological Sort) ---"
STEP=1
for TID in "${TOPO_ORDER[@]}"; do
  # Get task details
  TASK_NAME=$(jq -r --arg id "$TID" '.tasks[] | select(.id == $id) | .name' "$MANIFEST")
  TASK_MODEL=$(jq -r --arg id "$TID" '.tasks[] | select(.id == $id) | .model // "sonnet"' "$MANIFEST")
  TASK_MODE=$(jq -r --arg id "$TID" '.tasks[] | select(.id == $id) | .mode // "solo"' "$MANIFEST")
  TASK_HOURS=$(jq -r --arg id "$TID" '.tasks[] | select(.id == $id) | .estimated_hours // 0' "$MANIFEST")
  TASK_DEPS=$(jq -r --arg id "$TID" '.tasks[] | select(.id == $id) | .depends_on | join(", ")' "$MANIFEST")

  DEPS_DISPLAY="${TASK_DEPS:-none}"
  printf "  %2d. %-8s %-30s [%-6s %-8s %sh] deps: %s\n" \
    "$STEP" "$TID" "$TASK_NAME" "$TASK_MODEL" "$TASK_MODE" "$TASK_HOURS" "$DEPS_DISPLAY"
  STEP=$((STEP + 1))
done

# --- 4. Parallel groups ---
echo ""
echo "--- Parallel Groups ---"
GROUP_COUNT=$(jq '.strategy.parallel_groups | length' "$MANIFEST")

if [[ "$GROUP_COUNT" -eq 0 ]]; then
  echo "  No parallel groups (all tasks sequential)"
else
  jq -r '.strategy.parallel_groups[] | "  Group \(.group_id): [\(.tasks | join(", "))] — \(.reason)"' "$MANIFEST"
fi

# --- 5. Critical path ---
echo ""
echo "--- Critical Path ---"
CRIT_PATH=$(jq -r '.strategy.critical_path | join(" → ")' "$MANIFEST" 2>/dev/null || echo "")
CRIT_HOURS=$(jq -r '.strategy.critical_path_hours // "N/A"' "$MANIFEST")

if [[ -n "$CRIT_PATH" && "$CRIT_PATH" != "null" ]]; then
  echo "  Path: $CRIT_PATH"
  echo "  Hours: $CRIT_HOURS"
else
  echo "  Critical path not calculated (computing from DAG...)"

  # Compute critical path: longest path in DAG using topological order
  declare -A DIST
  declare -A PREV

  # Initialize distances
  for TID in "${TOPO_ORDER[@]}"; do
    DIST["$TID"]=0
    PREV["$TID"]=""
  done

  # Relax edges in topological order (longest path)
  for TID in "${TOPO_ORDER[@]}"; do
    TASK_HOURS=$(jq -r --arg id "$TID" '.tasks[] | select(.id == $id) | .estimated_hours // 0' "$MANIFEST")
    for NEIGHBOR in ${ADJ_LIST[$TID]:-}; do
      NEW_DIST=$(echo "${DIST[$TID]} + $TASK_HOURS" | bc 2>/dev/null || echo "0")
      if (( $(echo "$NEW_DIST > ${DIST[$NEIGHBOR]}" | bc -l 2>/dev/null || echo "0") )); then
        DIST["$NEIGHBOR"]="$NEW_DIST"
        PREV["$NEIGHBOR"]="$TID"
      fi
    done
  done

  # Find the task with the maximum distance (end of critical path)
  MAX_DIST=0
  END_TASK=""
  for TID in "${!DIST[@]}"; do
    if (( $(echo "${DIST[$TID]} > $MAX_DIST" | bc -l 2>/dev/null || echo "0") )); then
      MAX_DIST="${DIST[$TID]}"
      END_TASK="$TID"
    fi
  done

  # Trace back the critical path
  if [[ -n "$END_TASK" ]]; then
    CRIT=()
    CURRENT="$END_TASK"
    while [[ -n "$CURRENT" ]]; do
      CRIT=("$CURRENT" "${CRIT[@]}")
      CURRENT="${PREV[$CURRENT]:-}"
    done

    # Add the end task's own hours
    END_HOURS=$(jq -r --arg id "$END_TASK" '.tasks[] | select(.id == $id) | .estimated_hours // 0' "$MANIFEST")
    TOTAL_CRIT=$(echo "$MAX_DIST + $END_HOURS" | bc 2>/dev/null || echo "0")

    echo "  Computed path: $(IFS=' → '; echo "${CRIT[*]}")"
    echo "  Computed hours: $TOTAL_CRIT"
  else
    echo "  Could not compute critical path"
  fi
fi

# --- 6. Summary ---
echo ""
echo "--- Summary ---"
SEQ_HOURS=$(jq -r '.strategy.total_hours_sequential // 0' "$MANIFEST")
PAR_HOURS=$(jq -r '.strategy.total_hours_parallel // 0' "$MANIFEST")
SPEEDUP=$(jq -r '.strategy.speedup_pct // 0' "$MANIFEST")
MODE=$(jq -r '.strategy.mode // "solo"' "$MANIFEST")

echo "  Strategy mode: $MODE"
echo "  Sequential hours: $SEQ_HOURS"
echo "  Parallel hours: $PAR_HOURS"
echo "  Speedup: ${SPEEDUP}%"
echo ""
echo "=========================================="
