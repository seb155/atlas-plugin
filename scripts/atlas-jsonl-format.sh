#!/usr/bin/env bash
# ATLAS Subagent JSONL Transcript Formatter (SP-AGENT-VIS Layer 3)
#
# Reads a Claude Code subagent JSONL transcript from stdin and emits
# colorized human-readable lines. Schema empirically validated
# 2026-04-13 against real output_file samples (see plan Section F).
#
# Usage:
#   tail -f ~/.atlas/.../agent-abc.jsonl | atlas-jsonl-format.sh
#   cat transcript.jsonl | atlas-jsonl-format.sh | less -R
#   atlas-jsonl-format.sh --raw < transcript.jsonl   (no coloring, raw passthrough)
#
# JSONL event schema:
#   {"type":"user",      "message":{"role":"user",      "content": "string" | [tool_result,...]}}
#   {"type":"assistant", "message":{"role":"assistant", "content":[text, tool_use, ...]}}
#
# Content block types in message.content[]:
#   text        -> 💬 {text[:200]}                (cyan)
#   tool_use    -> 🔧 {name} {input description}  (gold)
#   tool_result -> ✓ {tool_use_id} (green) OR ✗ error (red)
#
# Plan: .blueprint/plans/keen-nibbling-umbrella.md Layer 3, Section F.
set -eu

# ─── Raw passthrough mode ───────────────────────────────────────
if [ "${1:-}" = "--raw" ]; then
  exec cat
fi

# ─── ANSI colors ────────────────────────────────────────────────
GOLD='\033[38;5;214m'
CYAN='\033[1;36m'
GREEN='\033[0;32m'
RED='\033[1;31m'
DIM='\033[2m'
RESET='\033[0m'

# Ensure jq available
if ! command -v jq &>/dev/null; then
  echo "atlas-jsonl-format: jq required (sudo apt install jq)" >&2
  exec cat  # passthrough
fi

# ─── Main loop ──────────────────────────────────────────────────
while IFS= read -r line; do
  [ -z "$line" ] && continue

  # Extract top-level type (user | assistant | other)
  type=$(printf '%s' "$line" | jq -r '.type // empty' 2>/dev/null || true)

  case "$type" in
    assistant)
      # Iterate content blocks
      printf '%s' "$line" | jq -c '.message.content[]? // empty' 2>/dev/null | while IFS= read -r block; do
        btype=$(printf '%s' "$block" | jq -r '.type // empty' 2>/dev/null)
        case "$btype" in
          text)
            text=$(printf '%s' "$block" | jq -r '.text // ""' 2>/dev/null | head -c 200 | tr '\n' ' ')
            [ -n "$text" ] && printf "${CYAN}💬 %s${RESET}\n" "$text"
            ;;
          tool_use)
            name=$(printf '%s' "$block" | jq -r '.name // "?"' 2>/dev/null)
            desc=$(printf '%s' "$block" | jq -r '.input.description // .input.command // .input.file_path // .input.query // ""' 2>/dev/null | head -c 120 | tr '\n' ' ')
            printf "${GOLD}🔧 %s${RESET} %s\n" "$name" "$desc"
            ;;
          thinking)
            # Extended thinking blocks — show 1-line preview
            think=$(printf '%s' "$block" | jq -r '.thinking // ""' 2>/dev/null | head -c 100 | tr '\n' ' ')
            [ -n "$think" ] && printf "${DIM}🧠 %s${RESET}\n" "$think"
            ;;
          *)
            # Unknown block type — show dimly
            preview=$(printf '%s' "$block" | head -c 60)
            printf "${DIM}… %s${RESET}\n" "$preview"
            ;;
        esac
      done
      ;;

    user)
      # User event: either string content or array of tool_result blocks
      content_kind=$(printf '%s' "$line" | jq -r '.message.content | if type == "array" then "array" else "string" end' 2>/dev/null)
      if [ "$content_kind" = "array" ]; then
        # Array: tool_result blocks (and potentially other types)
        printf '%s' "$line" | jq -c '.message.content[]? // empty' 2>/dev/null | while IFS= read -r block; do
          btype=$(printf '%s' "$block" | jq -r '.type // empty' 2>/dev/null)
          case "$btype" in
            tool_result)
              tool_use_id=$(printf '%s' "$block" | jq -r '.tool_use_id // "?"' 2>/dev/null)
              tool_use_short="${tool_use_id:0:18}"
              # Check for error (some tool_results have error field or is_error=true)
              is_error=$(printf '%s' "$block" | jq -r '.is_error // false' 2>/dev/null)
              if [ "$is_error" = "true" ]; then
                printf "${RED}   ✗ %s error${RESET}\n" "$tool_use_short"
              else
                printf "${GREEN}   ✓ %s${RESET}\n" "$tool_use_short"
              fi
              ;;
            *)
              preview=$(printf '%s' "$block" | head -c 60)
              printf "${DIM}… %s${RESET}\n" "$preview"
              ;;
          esac
        done
      else
        # String content: skip (usually initial prompt, noisy to replay)
        # Show only first user msg as a header if needed:
        user_text=$(printf '%s' "$line" | jq -r '.message.content // "" | if type == "string" then . else "" end' 2>/dev/null | head -c 100 | tr '\n' ' ')
        [ -n "$user_text" ] && printf "${DIM}▶ user: %s${RESET}\n" "$user_text"
      fi
      ;;

    *)
      # Unknown top-level type — show dimly (for debug / schema drift resilience)
      if [ -n "$type" ]; then
        printf "${DIM}… type=%s${RESET}\n" "$type"
      fi
      ;;
  esac
done
