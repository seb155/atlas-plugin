#!/usr/bin/env bash
# Export top ATLAS skills to Cursor .mdc rules format
# Usage: ./scripts/export-cursor.sh [output_dir]
#
# Converts SKILL.md → Cursor .mdc rules by:
# 1. Extracting frontmatter (name, description)
# 2. Stripping ATLAS-specific syntax (breadcrumbs, persona, HITL gates)
# 3. Outputting .mdc format with Cursor-compatible frontmatter
#
# Part of ATLAS SOTA Competitive Upgrade (precious-crafting-pike)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${1:-${ROOT_DIR}/dist/cursor-rules}"

# Top 15 skills to export (most universal, least ATLAS-specific)
EXPORT_SKILLS=(
  brainstorming
  code-review
  code-simplify
  context-discovery
  decision-log
  deep-research
  executing-plans
  finishing-branch
  git-worktrees
  plan-builder
  scope-check
  session-retrospective
  systematic-debugging
  tdd
  verification
)

mkdir -p "$OUTPUT_DIR"

# ATLAS-specific patterns to strip
strip_atlas_syntax() {
  sed \
    -e '/^🏛️ ATLAS/d' \
    -e '/─────────────────────────────/d' \
    -e '/📌 Recap/d' \
    -e '/🎯 Next Steps/d' \
    -e '/💡 Recommendation/d' \
    -e '/AskUserQuestion/d' \
    -e '/TaskCreate/d' \
    -e '/TaskUpdate/d' \
    -e '/HITL gate/Id' \
    -e '/^\$ARGUMENTS$/d' \
    -e 's/ATLAS skill/rule/g' \
    -e 's/atlas-admin://g' \
    -e '/^## Session Start Banner/,/^## /d' \
    -e '/^## Persona & Response/,/^## /d'
}

EXPORTED=0
SKIPPED=0

for skill in "${EXPORT_SKILLS[@]}"; do
  SKILL_MD="${ROOT_DIR}/skills/${skill}/SKILL.md"

  if [ ! -f "$SKILL_MD" ]; then
    echo "  ⚠️  Skipped ${skill} (SKILL.md not found)"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # Extract frontmatter
  NAME=$(python3 -c "
import yaml, sys
text = open('$SKILL_MD').read()
if text.startswith('---'):
    end = text.find('\n---', 3)
    if end > 0:
        fm = yaml.safe_load(text[3:end])
        print(fm.get('name', '$skill'))
" 2>/dev/null || echo "$skill")

  DESC=$(python3 -c "
import yaml, sys
text = open('$SKILL_MD').read()
if text.startswith('---'):
    end = text.find('\n---', 3)
    if end > 0:
        fm = yaml.safe_load(text[3:end])
        print(fm.get('description', ''))
" 2>/dev/null || echo "")

  # Extract body (everything after second ---)
  BODY=$(python3 -c "
text = open('$SKILL_MD').read()
if text.startswith('---'):
    end = text.find('\n---', 3)
    if end > 0:
        print(text[end+4:])
    else:
        print(text)
else:
    print(text)
" 2>/dev/null || cat "$SKILL_MD")

  # Write .mdc file
  OUTPUT_FILE="${OUTPUT_DIR}/${skill}.mdc"
  {
    echo "---"
    echo "description: ${DESC}"
    echo "globs: []"
    echo "alwaysApply: false"
    echo "---"
    echo ""
    echo "$BODY" | strip_atlas_syntax
  } > "$OUTPUT_FILE"

  EXPORTED=$((EXPORTED + 1))
  echo "  ✅ ${skill} → ${OUTPUT_FILE##*/}"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Exported: ${EXPORTED} skills"
echo "Skipped:  ${SKIPPED} skills"
echo "Output:   ${OUTPUT_DIR}/"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
