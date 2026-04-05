#!/usr/bin/env bash
# manifest-cost-calculator.sh — Calculate execution costs from manifest
#
# Reads a manifest JSON and produces a detailed cost breakdown.
# Token estimates: 1h work ≈ 50K input + 15K output (baseline).
# Adjusted by task type complexity factors.
#
# Usage:
#   bash scripts/manifest-cost-calculator.sh <manifest.json>
#   bash scripts/manifest-cost-calculator.sh .claude/execution-manifest.json
#   bash scripts/manifest-cost-calculator.sh .claude/execution-manifest.json --budget 10.00
#
# Output:
#   - Per-task cost breakdown
#   - Per-model aggregation
#   - Total cost vs all-Opus comparison
#   - Budget check (if --budget flag provided)
#
# Dependencies: jq (required), bc (required)

set -euo pipefail

# --- Arguments ---
MANIFEST="${1:-}"
BUDGET="${3:-}"  # --budget flag value

if [[ -z "$MANIFEST" ]]; then
  echo "ERROR: No manifest file specified"
  echo "Usage: bash scripts/manifest-cost-calculator.sh <manifest.json> [--budget <usd>]"
  exit 1
fi

if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: Manifest file not found: $MANIFEST"
  exit 1
fi

# Parse --budget flag
if [[ "${2:-}" == "--budget" && -n "$BUDGET" ]]; then
  BUDGET_CAP="$BUDGET"
else
  BUDGET_CAP=""
fi

# --- Check dependencies ---
for CMD in jq bc; do
  if ! command -v "$CMD" &>/dev/null; then
    echo "ERROR: $CMD is required but not installed"
    exit 1
  fi
done

# --- Pricing (2026-04 rates per million tokens) ---
# Source: https://docs.anthropic.com/en/docs/about-claude/models
OPUS_INPUT=15.00
OPUS_OUTPUT=75.00
SONNET_INPUT=3.00
SONNET_OUTPUT=15.00
HAIKU_INPUT=0.25
HAIKU_OUTPUT=1.25

# --- Complexity factors (from model-rules.yaml) ---
# Maps task type → (input_factor, output_ratio)
get_complexity() {
  local TYPE="$1"
  case "$TYPE" in
    architecture)  echo "3.0 0.8" ;;
    db_migration)  echo "2.5 1.0" ;;
    implementation) echo "2.0 1.5" ;;
    review)        echo "2.5 0.3" ;;
    testing)       echo "1.5 1.2" ;;
    validation)    echo "1.0 0.3" ;;
    search)        echo "0.5 0.1" ;;
    lint)          echo "0.0 0.0" ;;
    *)             echo "2.0 1.5" ;;  # default = implementation
  esac
}

# --- Get model pricing ---
get_pricing() {
  local MODEL="$1"
  case "$MODEL" in
    opus)   echo "$OPUS_INPUT $OPUS_OUTPUT" ;;
    sonnet) echo "$SONNET_INPUT $SONNET_OUTPUT" ;;
    haiku)  echo "$HAIKU_INPUT $HAIKU_OUTPUT" ;;
    det|null|"") echo "0 0" ;;
    *)      echo "$SONNET_INPUT $SONNET_OUTPUT" ;;  # default = sonnet
  esac
}

echo "=========================================="
echo "  Execution Manifest Cost Calculator"
echo "=========================================="
echo ""

PLAN_NAME=$(jq -r '.plan.name // "Unknown"' "$MANIFEST")
TASK_COUNT=$(jq '.tasks | length' "$MANIFEST")

echo "Plan: $PLAN_NAME"
echo "Tasks: $TASK_COUNT"
echo ""

# --- Per-task cost calculation ---
echo "--- Per-Task Cost Breakdown ---"
echo ""
printf "  %-8s %-25s %-8s %-6s %10s %10s %10s\n" \
  "ID" "Name" "Model" "Type" "Input Tok" "Output Tok" "Cost USD"
printf "  %-8s %-25s %-8s %-6s %10s %10s %10s\n" \
  "--------" "-------------------------" "--------" "------" "----------" "----------" "----------"

TOTAL_COST=0
TOTAL_INPUT=0
TOTAL_OUTPUT=0
OPUS_COST=0; OPUS_TASKS=0; OPUS_TOKENS=0
SONNET_COST=0; SONNET_TASKS=0; SONNET_TOKENS=0
HAIKU_COST=0; HAIKU_TASKS=0; HAIKU_TOKENS=0
DET_TASKS=0
ALL_OPUS_COST=0

while IFS= read -r line; do
  TID=$(echo "$line" | jq -r '.id')
  TNAME=$(echo "$line" | jq -r '.name' | cut -c1-25)
  TMODEL=$(echo "$line" | jq -r '.model // "sonnet"')
  TTYPE=$(echo "$line" | jq -r '.type // "implementation"')
  THOURS=$(echo "$line" | jq -r '.estimated_hours // 1')

  # Get complexity factors
  read -r CFACTOR ORATIO <<< "$(get_complexity "$TTYPE")"

  # Calculate tokens
  # Base: 50K input + 15K output per hour
  # Adjusted: input * complexity_factor, output = input * output_ratio
  INPUT_TOKENS=$(echo "$THOURS * 50000 * $CFACTOR" | bc)
  OUTPUT_TOKENS=$(echo "$INPUT_TOKENS * $ORATIO" | bc)
  INPUT_TOKENS_INT=$(printf "%.0f" "$INPUT_TOKENS")
  OUTPUT_TOKENS_INT=$(printf "%.0f" "$OUTPUT_TOKENS")

  # Get pricing
  read -r P_IN P_OUT <<< "$(get_pricing "$TMODEL")"

  # Calculate cost: (input_tokens / 1M * input_price) + (output_tokens / 1M * output_price)
  TASK_COST=$(echo "scale=4; ($INPUT_TOKENS / 1000000 * $P_IN) + ($OUTPUT_TOKENS / 1000000 * $P_OUT)" | bc)

  # Calculate all-opus cost for comparison
  OPUS_EQUIV=$(echo "scale=4; ($INPUT_TOKENS / 1000000 * $OPUS_INPUT) + ($OUTPUT_TOKENS / 1000000 * $OPUS_OUTPUT)" | bc)
  ALL_OPUS_COST=$(echo "scale=4; $ALL_OPUS_COST + $OPUS_EQUIV" | bc)

  # Accumulate totals
  TOTAL_COST=$(echo "scale=4; $TOTAL_COST + $TASK_COST" | bc)
  TOTAL_INPUT=$(echo "$TOTAL_INPUT + $INPUT_TOKENS_INT" | bc)
  TOTAL_OUTPUT=$(echo "$TOTAL_OUTPUT + $OUTPUT_TOKENS_INT" | bc)

  # Per-model aggregation
  case "$TMODEL" in
    opus)
      OPUS_COST=$(echo "scale=4; $OPUS_COST + $TASK_COST" | bc)
      OPUS_TASKS=$((OPUS_TASKS + 1))
      OPUS_TOKENS=$(echo "$OPUS_TOKENS + $INPUT_TOKENS_INT + $OUTPUT_TOKENS_INT" | bc)
      ;;
    sonnet)
      SONNET_COST=$(echo "scale=4; $SONNET_COST + $TASK_COST" | bc)
      SONNET_TASKS=$((SONNET_TASKS + 1))
      SONNET_TOKENS=$(echo "$SONNET_TOKENS + $INPUT_TOKENS_INT + $OUTPUT_TOKENS_INT" | bc)
      ;;
    haiku)
      HAIKU_COST=$(echo "scale=4; $HAIKU_COST + $TASK_COST" | bc)
      HAIKU_TASKS=$((HAIKU_TASKS + 1))
      HAIKU_TOKENS=$(echo "$HAIKU_TOKENS + $INPUT_TOKENS_INT + $OUTPUT_TOKENS_INT" | bc)
      ;;
    det|null|"")
      DET_TASKS=$((DET_TASKS + 1))
      ;;
  esac

  printf "  %-8s %-25s %-8s %-6s %10s %10s %10.2f\n" \
    "$TID" "$TNAME" "$TMODEL" "$TTYPE" "$INPUT_TOKENS_INT" "$OUTPUT_TOKENS_INT" "$TASK_COST"

done < <(jq -c '.tasks[]' "$MANIFEST")

# --- Per-model aggregation ---
echo ""
echo "--- Cost by Model ---"
echo ""
printf "  %-8s %6s %12s %10s\n" "Model" "Tasks" "Tokens" "Cost USD"
printf "  %-8s %6s %12s %10s\n" "--------" "------" "------------" "----------"

if [[ "$OPUS_TASKS" -gt 0 ]]; then
  printf "  %-8s %6d %12d %10.2f\n" "Opus" "$OPUS_TASKS" "$OPUS_TOKENS" "$OPUS_COST"
fi
if [[ "$SONNET_TASKS" -gt 0 ]]; then
  printf "  %-8s %6d %12d %10.2f\n" "Sonnet" "$SONNET_TASKS" "$SONNET_TOKENS" "$SONNET_COST"
fi
if [[ "$HAIKU_TASKS" -gt 0 ]]; then
  printf "  %-8s %6d %12d %10.2f\n" "Haiku" "$HAIKU_TASKS" "$HAIKU_TOKENS" "$HAIKU_COST"
fi
if [[ "$DET_TASKS" -gt 0 ]]; then
  printf "  %-8s %6d %12d %10.2f\n" "DET" "$DET_TASKS" "0" "0.00"
fi
printf "  %-8s %6s %12s %10s\n" "--------" "------" "------------" "----------"
TOTAL_TASKS=$((OPUS_TASKS + SONNET_TASKS + HAIKU_TASKS + DET_TASKS))
TOTAL_TOKENS=$(echo "$TOTAL_INPUT + $TOTAL_OUTPUT" | bc)
printf "  %-8s %6d %12d %10.2f\n" "TOTAL" "$TOTAL_TASKS" "$TOTAL_TOKENS" "$TOTAL_COST"

# --- All-Opus comparison ---
echo ""
echo "--- Cost Comparison ---"
echo ""
if (( $(echo "$ALL_OPUS_COST > 0" | bc -l) )); then
  SAVINGS=$(echo "scale=4; $ALL_OPUS_COST - $TOTAL_COST" | bc)
  SAVINGS_PCT=$(echo "scale=1; ($SAVINGS / $ALL_OPUS_COST) * 100" | bc)
  printf "  All-Opus cost:   \$%.2f\n" "$ALL_OPUS_COST"
  printf "  Optimized cost:  \$%.2f\n" "$TOTAL_COST"
  printf "  Savings:         \$%.2f (%s%%)\n" "$SAVINGS" "$SAVINGS_PCT"
else
  echo "  No token-consuming tasks found"
fi

# --- Budget check ---
if [[ -n "$BUDGET_CAP" ]]; then
  echo ""
  echo "--- Budget Check ---"
  echo ""
  OVER=$(echo "$TOTAL_COST > $BUDGET_CAP" | bc -l)
  if [[ "$OVER" -eq 1 ]]; then
    EXCESS=$(echo "scale=2; $TOTAL_COST - $BUDGET_CAP" | bc)
    echo "  OVER BUDGET by \$$EXCESS"
    echo "  Budget: \$$BUDGET_CAP | Estimated: \$$(printf '%.2f' "$TOTAL_COST")"
    echo ""
    echo "  Suggestions:"
    echo "  - Use --fast flag to aggressively downgrade models"
    echo "  - Split large tasks to reduce per-task token estimates"
    echo "  - Review if any Opus tasks can safely use Sonnet"
    exit 2
  else
    REMAINING=$(echo "scale=2; $BUDGET_CAP - $TOTAL_COST" | bc)
    echo "  WITHIN BUDGET"
    echo "  Budget: \$$BUDGET_CAP | Estimated: \$$(printf '%.2f' "$TOTAL_COST") | Remaining: \$$REMAINING"
  fi
fi

echo ""
echo "=========================================="
