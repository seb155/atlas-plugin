#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
# ATLAS — Generate naive prompts from skill descriptions (bootstrap)
# Reads each SKILL.md frontmatter and generates a placeholder prompt
# file in prompts/. Existing prompts are NOT overwritten (preserves
# curated work).
#
# Strategy:
# - Parse YAML frontmatter → extract `description` and `name`
# - Transform description triggers into a naive user prompt
# - Skills with ambiguous/meta triggers → marked EVAL-EXEMPT
#
# Usage:
#   ./generate-prompts.sh          # generate missing prompts
#   ./generate-prompts.sh --force  # overwrite all (destructive)
#   ./generate-prompts.sh --dry    # show what would be generated
#
# Reference: docs/ADR/ADR-007-skill-triggering-eval-framework.md
# ─────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROMPTS_DIR="$SCRIPT_DIR/prompts"
SKILLS_DIR="$PLUGIN_DIR/skills"

FORCE=0
DRY=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --dry) DRY=1 ;;
    --help|-h) sed -n '2,20p' "$0"; exit 0 ;;
  esac
done

mkdir -p "$PROMPTS_DIR"

# Skills categorized as eval-exempt (invoked programmatically, no natural trigger)
EVAL_EXEMPT_SKILLS=(
  "atlas-assist"          # master orchestrator — always loaded
  "discovery"             # capability inspector — manual invocation
  "atlas-doctor"          # diagnostic tool
  "statusline-setup"      # config, not task-triggered
  "hookify"               # meta — creates hooks
  "atlas-dev-self"        # self-development, always invoked manually
  "refs"                  # reference-only, not a real skill dir
)

is_exempt() {
  local s="$1"
  for e in "${EVAL_EXEMPT_SKILLS[@]}"; do
    [[ "$s" == "$e" ]] && return 0
  done
  return 1
}

GENERATED=0
SKIPPED_EXIST=0
EXEMPTED=0
PROCESSED=0

for skill_md in $(find "$SKILLS_DIR" -maxdepth 2 -name "SKILL.md" | sort); do
  skill_dir=$(dirname "$skill_md")
  skill_name=$(basename "$skill_dir")
  prompt_file="$PROMPTS_DIR/${skill_name}.txt"
  PROCESSED=$((PROCESSED + 1))

  # Skip existing unless --force
  if [[ -f "$prompt_file" ]] && [[ "$FORCE" -eq 0 ]]; then
    SKIPPED_EXIST=$((SKIPPED_EXIST + 1))
    continue
  fi

  # Check if exempt
  if is_exempt "$skill_name"; then
    if [[ "$DRY" -eq 1 ]]; then
      echo "EXEMPT: $skill_name"
    else
      cat > "$prompt_file" <<EOF
# EVAL-EXEMPT: meta/programmatic skill without natural naive trigger
# Reason: Invoked by other skills, hooks, or direct CLI commands — not by user prompts.
# To enable eval: remove this comment + write a prompt that would naturally invoke this skill.
EOF
    fi
    EXEMPTED=$((EXEMPTED + 1))
    continue
  fi

  # Extract description from frontmatter (handles both inline and multi-line descriptions)
  # Pull section between first --- and second ---, then extract description
  description=$(awk '/^---$/{c++; next} c==1' "$skill_md" | awk '
    /^description:/ {
      # Strip the key; capture rest of line (could be inline or start of multi-line)
      sub(/^description:[[:space:]]*/, "")
      # Strip leading/trailing quotes
      sub(/^"/, ""); sub(/"$/, "")
      sub(/^\|[[:space:]]*$/, "")
      print
      in_desc = 1
      next
    }
    in_desc && /^[[:space:]]{2,}/ {
      # Continuation line (indented) — part of multi-line
      sub(/^[[:space:]]+/, "")
      print
      next
    }
    /^[a-zA-Z_]+:/ && in_desc { exit }
  ' | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ //;s/ $//')

  if [[ -z "$description" ]]; then
    echo "⚠ $skill_name: no description found in frontmatter, skipping"
    continue
  fi

  # Generate prompt: strip common leading phrases, keep triggering portion
  # Common patterns:
  #   "X. This skill should be used when the user asks to 'A', 'B', 'C'..."
  #   "X. Use when Y..."
  #   "X. Triggers on: ..."
  # Our generated prompt picks first trigger phrase + adds context

  prompt_text=$(echo "$description" | awk '
    {
      # Find first trigger phrase in quotes after "used when" or "Use when"
      if (match($0, /[\x27"]([^\x27"]+)[\x27"]/)) {
        phrase = substr($0, RSTART+1, RLENGTH-2)
        print phrase
      } else {
        # Fall back: use description as-is, Claude must infer
        print $0
      }
    }
  ')

  # If still too literal, add naive framing
  naive_prompt=$(cat <<EOF
$prompt_text

(Generated placeholder from skill description; please review and refine with a more natural user phrasing.)
EOF
)

  if [[ "$DRY" -eq 1 ]]; then
    echo "GEN: $skill_name"
    echo "  → $(echo "$naive_prompt" | head -1)"
  else
    echo "$naive_prompt" > "$prompt_file"
  fi
  GENERATED=$((GENERATED + 1))
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Processed:       $PROCESSED skills"
echo "Generated:       $GENERATED prompt files (new)"
echo "Exempt:          $EXEMPTED skills (marked EVAL-EXEMPT)"
echo "Skipped existing: $SKIPPED_EXIST (use --force to overwrite)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Next: curate prompts/<skill>.txt manually for quality"
