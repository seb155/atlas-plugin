#!/usr/bin/env bash
# atlas-eval — LLM-as-judge skill regression runner
# Usage:
#   bash evals/run.sh <skill-name>
#   DRY_RUN=1 bash evals/run.sh <skill-name>      # schema validation only
#   JUDGE_MODEL=claude-opus-4-7 bash evals/run.sh <skill-name>
#
# Plan SSoT: .blueprint/plans/ultrathink-regarde-ce-qui-abundant-petal.md (W1.5)

set -euo pipefail

SKILL_NAME="${1:-}"
JUDGE_MODEL="${JUDGE_MODEL:-claude-sonnet-4-6}"
DRY_RUN="${DRY_RUN:-0}"
PASS_THRESHOLD="${PASS_THRESHOLD:-80}"

if [ -z "$SKILL_NAME" ]; then
  echo "Usage: $0 <skill-name> [--multi-judge]" >&2
  echo "Available skills with golden datasets:" >&2
  ls -1 evals/skills 2>/dev/null | grep -v '^\.template$' | sed 's/^/  - /' >&2
  exit 2
fi

GOLDEN_FILE="evals/skills/${SKILL_NAME}/golden.jsonl"
if [ ! -f "$GOLDEN_FILE" ]; then
  echo "ERROR: golden dataset not found: $GOLDEN_FILE" >&2
  echo "Create it from template: cp evals/skills/.template/golden.jsonl $GOLDEN_FILE" >&2
  exit 1
fi

# Validate JSONL schema
if ! jq -c . "$GOLDEN_FILE" > /dev/null 2>&1; then
  echo "ERROR: $GOLDEN_FILE is not valid JSONL" >&2
  exit 1
fi

ENTRY_COUNT=$(wc -l < "$GOLDEN_FILE")
DATE=$(date +%Y-%m-%d)
RESULTS_DIR="evals/results/${SKILL_NAME}"
RESULTS_FILE="${RESULTS_DIR}/${DATE}.jsonl"
mkdir -p "$RESULTS_DIR"

echo "============================================================"
echo "atlas-eval — skill regression"
echo "============================================================"
echo "  skill        : $SKILL_NAME"
echo "  golden file  : $GOLDEN_FILE ($ENTRY_COUNT entries)"
echo "  judge model  : $JUDGE_MODEL"
echo "  results file : $RESULTS_FILE"
echo "  pass thresh  : $PASS_THRESHOLD"
echo "  dry run      : $DRY_RUN"
echo "============================================================"

# Prepare results file
: > "$RESULTS_FILE"

TOTAL_WEIGHTED_SCORE=0
TOTAL_WEIGHT=0
ENTRY_IDX=0

while IFS= read -r ENTRY; do
  ENTRY_IDX=$((ENTRY_IDX + 1))
  ID=$(echo "$ENTRY" | jq -r '.id')
  INPUT=$(echo "$ENTRY" | jq -r '.input')
  EXPECTED_SUMMARY=$(echo "$ENTRY" | jq -r '.expected_output_summary')
  EXPECTED_FORMAT=$(echo "$ENTRY" | jq -r '.expected_format')
  WEIGHT=$(echo "$ENTRY" | jq -r '.weight // 1.0')

  echo ""
  echo "[$ENTRY_IDX/$ENTRY_COUNT] $ID (weight=$WEIGHT)"

  if [ "$DRY_RUN" = "1" ]; then
    echo "  DRY_RUN: skipping claude invocations"
    SCORE=85
    REASONING="dry-run synthetic score"
    OUTPUT="<dry-run no output>"
  else
    # Step 1: Invoke skill under test
    # Note: this is a placeholder — actual invocation depends on harness wiring.
    # In v1 we assume a thin wrapper: claude --print <prompt> with skill loaded.
    SKILL_PROMPT="Invoke skill '${SKILL_NAME}' on the following input. Return only the skill's final output.

INPUT:
${INPUT}"

    OUTPUT=$(claude --model "$JUDGE_MODEL" --print "$SKILL_PROMPT" 2>/dev/null || echo "<skill invocation failed>")

    # Step 2: Invoke judge
    JUDGE_PROMPT="You are evaluating a skill output against expected behavior. Be strict but fair.

INPUT: ${INPUT}

ACTUAL OUTPUT:
${OUTPUT}

EXPECTED OUTPUT SUMMARY: ${EXPECTED_SUMMARY}
EXPECTED FORMAT: ${EXPECTED_FORMAT}

Score 0-100 based on this rubric:
- 50%: factual coverage of expected_output_summary
- 30%: format adherence to expected_format
- 20%: clarity and actionability

Return JSON only, no markdown fence: {\"score\": <int 0-100>, \"reasoning\": \"<one sentence>\"}"

    JUDGE_RAW=$(claude --model "$JUDGE_MODEL" --print "$JUDGE_PROMPT" 2>/dev/null || echo '{"score":0,"reasoning":"judge invocation failed"}')

    # Strip any markdown fence the judge might add
    JUDGE_JSON=$(echo "$JUDGE_RAW" | sed -e 's/^```json//' -e 's/^```//' -e 's/```$//' | tr -d '\r')

    SCORE=$(echo "$JUDGE_JSON" | jq -r '.score // 0' 2>/dev/null || echo 0)
    REASONING=$(echo "$JUDGE_JSON" | jq -r '.reasoning // "parse-error"' 2>/dev/null || echo "parse-error")
  fi

  # Append result
  TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  jq -nc \
    --arg id "$ID" \
    --arg output "$OUTPUT" \
    --argjson score "$SCORE" \
    --arg reasoning "$REASONING" \
    --arg ts "$TS" \
    --arg judge "$JUDGE_MODEL" \
    --argjson weight "$WEIGHT" \
    '{id: $id, output: $output, score: $score, reasoning: $reasoning, weight: $weight, ts: $ts, judge_model: $judge}' \
    >> "$RESULTS_FILE"

  echo "  score: $SCORE / 100  ($REASONING)"

  # Aggregate (weighted, awk for float math)
  TOTAL_WEIGHTED_SCORE=$(awk -v t="$TOTAL_WEIGHTED_SCORE" -v s="$SCORE" -v w="$WEIGHT" 'BEGIN { printf "%.4f", t + s*w }')
  TOTAL_WEIGHT=$(awk -v t="$TOTAL_WEIGHT" -v w="$WEIGHT" 'BEGIN { printf "%.4f", t + w }')
done < "$GOLDEN_FILE"

# Final aggregate
AVG_SCORE=$(awk -v s="$TOTAL_WEIGHTED_SCORE" -v w="$TOTAL_WEIGHT" 'BEGIN { if (w > 0) printf "%.2f", s/w; else print "0" }')

echo ""
echo "============================================================"
echo "RESULT"
echo "============================================================"
echo "  weighted avg score : $AVG_SCORE / 100"
echo "  threshold          : $PASS_THRESHOLD"

# Compare with awk for float
PASSED=$(awk -v a="$AVG_SCORE" -v t="$PASS_THRESHOLD" 'BEGIN { print (a >= t) ? 1 : 0 }')
if [ "$PASSED" = "1" ]; then
  echo "  status             : PASS"
  echo "============================================================"
  exit 0
else
  echo "  status             : FAIL"
  echo "============================================================"
  exit 1
fi
