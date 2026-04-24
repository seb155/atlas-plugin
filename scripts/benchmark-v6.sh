#!/usr/bin/env bash
# ATLAS v6.0 Benchmark Harness — Cost/Accuracy A/B
# ------------------------------------------------------------------
# Runs standardized test prompts through effort-heuristic.sh and
# measures routing accuracy + latency. Emits one JSON file per run
# so v5.23.0 ↔ v6.0.0-alpha.2 can be compared offline.
#
# Hypothesis (plan v6.0):
#   - Accuracy: ≥ +25% absolute vs no-heuristic baseline (v5 had none)
#   - Cost:    ≤ +15% tokens per query (SessionStart 23KB + adaptive thinking)
#
# What IS measured here:
#   - Effort-level classification accuracy on the 14-prompt corpus
#   - Per-prompt latency of the routing decision (nanosecond clock)
#
# What is NOT measured (requires real session runs):
#   - Real Claude API token consumption
#   - End-to-end task quality (would need a judge model)
#   - SessionStart payload overhead (fixed per session, not per query)
#
# Usage:
#   scripts/benchmark-v6.sh              # run corpus, write JSON
#   scripts/benchmark-v6.sh --help       # usage
#
# Output:
#   tests/benchmark-results/bench-<version>-<timestamp>.json
#
# Exit codes:
#   0  success (JSON written, accuracy printed)
#   1  usage error or missing dependency
#   2  accuracy below 70% quality gate

set -euo pipefail

# ----------------------------------------------------------------------------
# Paths
# ----------------------------------------------------------------------------

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
RESULTS_DIR="${PLUGIN_ROOT}/tests/benchmark-results"
HEURISTIC="${PLUGIN_ROOT}/scripts/execution-philosophy/effort-heuristic.sh"
VERSION_FILE="${PLUGIN_ROOT}/VERSION"

# ----------------------------------------------------------------------------
# Dispatch --help
# ----------------------------------------------------------------------------

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  sed -n '2,28p' "$0"
  exit 0
fi

# ----------------------------------------------------------------------------
# Pre-flight
# ----------------------------------------------------------------------------

if [[ ! -x "$HEURISTIC" ]]; then
  echo "ERROR: effort-heuristic.sh not executable at $HEURISTIC" >&2
  exit 1
fi
if [[ ! -f "$VERSION_FILE" ]]; then
  echo "ERROR: VERSION file not found at $VERSION_FILE" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 required for JSON parsing" >&2
  exit 1
fi

mkdir -p "$RESULTS_DIR"

VERSION=$(tr -d '[:space:]' < "$VERSION_FILE")
TIMESTAMP=$(date -u +%Y-%m-%dT%H-%M-%SZ)
OUTPUT="${RESULTS_DIR}/bench-${VERSION}-${TIMESTAMP}.json"

# ----------------------------------------------------------------------------
# Test corpus — 14 prompts, proportional distribution from plan
# ----------------------------------------------------------------------------
# Distribution target:
#   LOW     3/14 (~21%)  trivial file ops / git ops
#   MEDIUM  3/14 (~21%)  review / docs / explanation
#   HIGH    3/14 (~21%)  feature implementation / bugfix
#   XHIGH   3/14 (~21%)  debug / optimize / migrate
#   MAX     2/14 (~14%)  architecture / strategy

declare -a PROMPTS=(
  # LOW
  "commit pending changes with message fix typo|low"
  "bump version and push tag to release|low"
  "grep for TODOs in the codebase|low"

  # MEDIUM
  "review this small pull request for style|medium"
  "explain what atlas-loop does|medium"
  "document the API endpoints in routes.py|medium"

  # HIGH
  "implement user authentication with JWT|high"
  "add feature to support dark mode toggle|high"
  "fix bug in the login form validation|high"

  # XHIGH
  "debug this race condition in the concurrent queue|xhigh"
  "optimize the slow query causing timeout|xhigh"
  "migrate postgres schema without downtime|xhigh"

  # MAX
  "design architecture for a distributed event sourcing system|max"
  "ultrathink the decision framework and mega plan|max"
)

# ----------------------------------------------------------------------------
# Run corpus
# ----------------------------------------------------------------------------

echo "ATLAS Benchmark Harness"
echo "Version    : $VERSION"
echo "Timestamp  : $TIMESTAMP"
echo "Corpus size: ${#PROMPTS[@]} prompts"
echo "Output     : $OUTPUT"
echo ""

# Initialize JSON output
printf '[\n' > "$OUTPUT"
FIRST=true

for entry in "${PROMPTS[@]}"; do
  prompt="${entry%|*}"
  expected="${entry##*|}"

  # Latency measurement (ns → ms float)
  t_start=$(date +%s%N)
  RESOLVED=$(bash "$HEURISTIC" "$prompt" 2>/dev/null || echo "err")
  t_end=$(date +%s%N)
  LATENCY_MS=$(python3 -c "print(round((${t_end}-${t_start})/1000000.0, 2))")

  if [[ "$RESOLVED" == "$expected" ]]; then
    MATCH="true"
    marker="PASS"
  else
    MATCH="false"
    marker="FAIL"
  fi

  printf '  %-4s  %-55s exp=%-6s got=%-6s (%sms)\n' \
    "$marker" "${prompt:0:53}" "$expected" "$RESOLVED" "$LATENCY_MS"

  # Emit JSON entry
  if [[ "$FIRST" == "true" ]]; then
    FIRST=false
  else
    printf ',\n' >> "$OUTPUT"
  fi
  # Escape double-quotes in prompt for JSON safety
  prompt_json=$(printf '%s' "$prompt" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
  cat >> "$OUTPUT" <<JSON
  {
    "prompt": ${prompt_json},
    "expected_effort": "${expected}",
    "resolved_effort": "${RESOLVED}",
    "match": ${MATCH},
    "latency_ms": ${LATENCY_MS},
    "version": "${VERSION}"
  }
JSON
done

printf '\n]\n' >> "$OUTPUT"

# ----------------------------------------------------------------------------
# Validate JSON + compute stats
# ----------------------------------------------------------------------------

TOTAL=${#PROMPTS[@]}
MATCHES=$(python3 -c "import json; d=json.load(open('$OUTPUT')); print(sum(1 for x in d if x['match']))")
ACCURACY=$(python3 -c "print(round($MATCHES/$TOTAL*100, 1))")
AVG_LATENCY=$(python3 -c "import json; d=json.load(open('$OUTPUT')); print(round(sum(x['latency_ms'] for x in d)/len(d), 2))")

echo ""
echo "---------------------------------------"
echo "  Accuracy   : $MATCHES/$TOTAL ($ACCURACY%)"
echo "  Avg latency: ${AVG_LATENCY}ms"
echo "  Output     : $OUTPUT"
echo "---------------------------------------"

# Quality gate: >= 70%
ACCURACY_INT=$(python3 -c "print(int($ACCURACY))")
if [[ $ACCURACY_INT -lt 70 ]]; then
  echo "FAIL: accuracy below 70% quality gate" >&2
  exit 2
fi

exit 0
