#!/usr/bin/env bash
# ATLAS CShip Custom Module — 200K token threshold warning badge
# CC v2.1.87+ exposes `exceeds_200k_tokens` field in status line JSON input.
# Expected env var: CSHIP_EXCEEDS_200K_TOKENS ("true" | "false" | "")
# Output: "⚠️ 200K+" (conditional, empty when false/unset)

set -euo pipefail

# Try multiple env var names (CShip naming convention uncertain)
readonly EXCEEDS="${CSHIP_EXCEEDS_200K_TOKENS:-${CSHIP_EXCEEDS_200K:-false}}"

case "$EXCEEDS" in
  true|True|TRUE|1|yes)
    echo "⚠️ 200K+"
    ;;
  *)
    : ;;  # empty → no badge
esac
