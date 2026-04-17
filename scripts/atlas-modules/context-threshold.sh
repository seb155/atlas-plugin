#!/usr/bin/env bash
# ATLAS Module: Context Threshold Resolver (model-aware autocompact)
#
# Returns the optimal CLAUDE_AUTOCOMPACT_PCT_OVERRIDE percentage
# based on the currently active Claude model's context window size.
#
# Logic:
#   - Opus 4.7 with [1m] suffix   → 92  (of 1M tokens = 920K)
#   - Other 1M-context models      → 92
#   - Standard 200K models         → 83
#   - Unknown / fallback           → 83  (safe conservative default)
#
# Detection chain (first hit wins):
#   1. CLI arg "$1" (explicit model ID)
#   2. Env var $CLAUDE_MODEL_ID (set by CC hooks or user)
#   3. State file ~/.atlas/state/context-threshold.json
#   4. Capabilities file ~/.atlas/runtime/capabilities.json
#   5. Fallback: 83
#
# Usage:
#   bash scripts/atlas-modules/context-threshold.sh [model_id]
#
# Output: single integer to stdout (83 or 92)
# Exit:   0 always (fallback on any error)

set -euo pipefail

readonly THRESHOLD_1M=92   # 920K of 1M — optimum margin
readonly THRESHOLD_200K=83 # 166K of 200K — safe default
readonly STATE_FILE="${HOME}/.atlas/state/context-threshold.json"
readonly CAPABILITIES_FILE="${HOME}/.atlas/runtime/capabilities.json"

# Returns 92 if model has 1M context, 83 otherwise.
# Arg $1: model ID string (e.g., "claude-opus-4-7[1m]")
resolve_threshold_from_model() {
  local model_id="${1:-}"

  # Empty model = safe fallback
  if [[ -z "$model_id" ]]; then
    echo "$THRESHOLD_200K"
    return 0
  fi

  # Check for 1M context indicators
  if [[ "$model_id" == *"[1m]"* ]] \
    || [[ "$model_id" == *"-1m"* ]] \
    || [[ "$model_id" == *"1million"* ]]; then
    echo "$THRESHOLD_1M"
    return 0
  fi

  # Known 1M context models (even without suffix — future-proofing)
  case "$model_id" in
    *opus-4-[67]*|*sonnet-4-6*)
      # These support 1M context by default in most deployments
      echo "$THRESHOLD_1M"
      return 0
      ;;
  esac

  # Standard 200K default
  echo "$THRESHOLD_200K"
}

# Returns 92 or 83 based on context_size.
# Arg $1: context size in tokens (integer)
resolve_threshold_from_size() {
  local context_size="${1:-0}"

  # Numeric check
  if ! [[ "$context_size" =~ ^[0-9]+$ ]]; then
    echo "$THRESHOLD_200K"
    return 0
  fi

  # > 500K tokens = treat as 1M context
  if (( context_size > 500000 )); then
    echo "$THRESHOLD_1M"
  else
    echo "$THRESHOLD_200K"
  fi
}

main() {
  local explicit_model="${1:-}"
  local resolved_model=""
  local resolved_size=""

  # Priority 1: explicit CLI arg
  if [[ -n "$explicit_model" ]]; then
    resolve_threshold_from_model "$explicit_model"
    return 0
  fi

  # Priority 2: environment variable
  if [[ -n "${CLAUDE_MODEL_ID:-}" ]]; then
    resolve_threshold_from_model "$CLAUDE_MODEL_ID"
    return 0
  fi

  # Priority 3: state file (written by context-threshold-injector hook)
  if [[ -r "$STATE_FILE" ]] && command -v jq >/dev/null 2>&1; then
    resolved_model=$(jq -r '.model // ""' "$STATE_FILE" 2>/dev/null || echo "")
    resolved_size=$(jq -r '.context_size // 0' "$STATE_FILE" 2>/dev/null || echo "0")

    if [[ -n "$resolved_model" && "$resolved_model" != "null" ]]; then
      resolve_threshold_from_model "$resolved_model"
      return 0
    fi

    if [[ "$resolved_size" -gt 0 ]]; then
      resolve_threshold_from_size "$resolved_size"
      return 0
    fi
  fi

  # Priority 4: capabilities.json (written by atlas-discover-addons.sh)
  if [[ -r "$CAPABILITIES_FILE" ]] && command -v jq >/dev/null 2>&1; then
    resolved_model=$(jq -r '.version_info.model // ""' "$CAPABILITIES_FILE" 2>/dev/null || echo "")

    if [[ -n "$resolved_model" && "$resolved_model" != "null" ]]; then
      resolve_threshold_from_model "$resolved_model"
      return 0
    fi
  fi

  # Priority 5: safe fallback
  echo "$THRESHOLD_200K"
}

main "$@"
