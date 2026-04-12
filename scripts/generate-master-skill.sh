#!/usr/bin/env bash
# Generate tier-specific or domain-specific atlas-assist SKILL.md
# Usage: ./scripts/generate-master-skill.sh <tier|domain-name> <output_path>
#
# Tier mode:   admin, dev, user, worker  → reads profiles/{tier}.yaml
# Domain mode: domain-core, domain-dev, domain-infra, etc. → reads profiles/domain-{name}.yaml
#
# Both modes produce an atlas-assist SKILL.md with skill lists from _metadata.yaml
# SP-DEDUP Phase 2: metadata-driven skill catalog
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

TIER="$1"
OUTPUT="$2"
VERSION=$(cat VERSION | tr -d '[:space:]')

# All profiles live under profiles/{tier}.yaml (including domain-core, domain-dev, etc.)
PROFILE="profiles/${TIER}.yaml"
SKILL_NAME="atlas-assist"

# Only admin tier exposes /atlas-assist in the slash command menu.
# All other tiers/domains are hidden (still usable by CC's internal routing).
if [ "$TIER" = "admin" ]; then
  USER_INVOCABLE="true"
else
  USER_INVOCABLE="false"
fi

# Worker tier: generate minimal SKILL.md and exit early
if [ "$TIER" = "worker" ]; then
  cat > "$OUTPUT" <<WORKER_EOF
---
name: ${SKILL_NAME}
description: "ATLAS Worker — minimal task executor for Agent Teams. Zero skills, zero hooks."
user-invocable: ${USER_INVOCABLE}
---

# ATLAS Worker v${VERSION}

You are a focused task executor in an Agent Teams squad.

## Workflow
1. Read your task assignment (TaskGet)
2. Execute using available tools
3. Mark completed (TaskUpdate)
4. SendMessage results to team lead

## Rules
- Stay on your assigned task — do NOT explore unrelated areas
- If blocked, SendMessage the team lead immediately
- Do NOT invoke other ATLAS skills or use breadcrumb/persona formatting
- Keep outputs concise (< 500 words)
WORKER_EOF
  echo "  ✅ Worker atlas-assist generated ($(wc -l < "$OUTPUT") lines)"
  exit 0
fi

BANNER_LABEL=$(yq -r '.banner_label // "Dev"' "$PROFILE")
PERSONA=$(yq -r '.persona // "senior engineering architect"' "$PROFILE")
PIPELINE=$(yq -r '.pipeline // "DISCOVER → PLAN → IMPLEMENT → VERIFY → SHIP"' "$PROFILE")
TIER_UPPER=$(echo "${TIER}" | sed 's/./\U&/')

# Resolve all skills (with inheritance)
resolve_field() {
  local t="$1"
  local f="$2"
  local p="profiles/${t}.yaml"
  local parent items tier_items
  parent=$(yq -r '.inherits // ""' "$p")
  items=""
  if [ -n "$parent" ] && [ -f "profiles/${parent}.yaml" ]; then
    items=$(resolve_field "$parent" "$f")
  fi
  tier_items=$(yq -r ".${f} // [] | .[]" "$p" 2>/dev/null || true)
  if [ -n "$items" ] && [ -n "$tier_items" ]; then
    echo -e "${items}\n${tier_items}" | sort -u
  elif [ -n "$items" ]; then echo "$items"
  else echo "$tier_items"; fi
}

ALL_SKILLS=$(resolve_field "$TIER" "skills")
SKILL_COUNT=$(echo "$ALL_SKILLS" | grep -c . || echo 0)
ALL_AGENTS=$(resolve_field "$TIER" "agents")
AGENT_COUNT=$(echo "$ALL_AGENTS" | grep -c . || echo 0)
# ─── Load skill metadata from YAML (SSoT: skills/_metadata.yaml) ─────────
METADATA_FILE="${ROOT_DIR}/skills/_metadata.yaml"
if [ ! -f "$METADATA_FILE" ]; then
  echo "ERROR: Missing $METADATA_FILE — run from repo root" >&2; exit 1
fi

declare -A EMOJI_MAP CATEGORY_MAP DESC_MAP CATEGORY_EMOJI WEIGHT_MAP

# Load per-skill maps (emoji, category, description, weight) in a single yq pass
while IFS=$'\t' read -r name emoji category desc weight; do
  [ -z "$name" ] && continue
  EMOJI_MAP["$name"]="$emoji"
  CATEGORY_MAP["$name"]="$category"
  DESC_MAP["$name"]="$desc"
  WEIGHT_MAP["$name"]="${weight:-5}"
done < <(yq -r '.skills | to_entries[] | [.key, .value.emoji, .value.category, .value.description, (.value.weight // 5)] | @tsv' "$METADATA_FILE")

# Load category header emojis
while IFS=$'\t' read -r cat emoji; do
  [ -z "$cat" ] && continue
  CATEGORY_EMOJI["$cat"]="$emoji"
done < <(yq -r '.category_emojis | to_entries[] | [.key, .value] | @tsv' "$METADATA_FILE")

# Build skill list grouped by category (progressive disclosure)
# weight >= 8: show emoji + name + description (inline)
# weight < 8: show emoji + name only (description loads on demand via Skill tool)
build_skill_list() {
  # Build sorted list into temp file to avoid subshell issues
  local tmpfile
  tmpfile=$(mktemp)
  for skill in $ALL_SKILLS; do
    local cat="${CATEGORY_MAP[$skill]:-Other}"
    printf '%s|%s\n' "$cat" "$skill" >> "$tmpfile"
  done
  sort "$tmpfile" > "${tmpfile}.sorted"

  local prev_category=""
  local compact_line=""
  while IFS='|' read -r cat skill; do
    [ -z "$skill" ] && continue
    local emoji="${EMOJI_MAP[$skill]:-❓}"
    local desc="${DESC_MAP[$skill]:-}"
    local cat_emoji="${CATEGORY_EMOJI[$cat]:-📌}"
    local weight="${WEIGHT_MAP[$skill]:-5}"

    if [ "$cat" != "$prev_category" ]; then
      # Flush any pending compact line
      if [ -n "$compact_line" ]; then echo "$compact_line"; compact_line=""; fi
      if [ -n "$prev_category" ]; then echo ""; fi
      echo "### ${cat_emoji} ${cat}"
      prev_category="$cat"
    fi

    if [ "$weight" -ge 8 ]; then
      # Flush compact line before detailed entry
      if [ -n "$compact_line" ]; then echo "$compact_line"; compact_line=""; fi
      echo "- ${emoji} **${skill}**: ${desc}"
    else
      # Compact: collect on one line separated by " | "
      if [ -z "$compact_line" ]; then
        compact_line="- ${emoji} ${skill}"
      else
        compact_line="${compact_line} | ${emoji} ${skill}"
      fi
    fi
  done < "${tmpfile}.sorted"
  # Flush remaining compact line
  if [ -n "$compact_line" ]; then echo "$compact_line"; fi

  rm -f "$tmpfile" "${tmpfile}.sorted"
}

# Generate the SKILL.md
SKILL_LIST=$(build_skill_list)

cat > "$OUTPUT" <<SKILLEOF
---
name: ${SKILL_NAME}
description: "Master skill for ATLAS ${BANNER_LABEL} — AXOIQ's unified AI engineering assistant. ${SKILL_COUNT} skills, ${AGENT_COUNT} agents. Auto-routing co-pilot with HITL gates."
user-invocable: ${USER_INVOCABLE}
---

# ATLAS — AXOIQ's Unified AI Engineering Assistant (${BANNER_LABEL} Tier)

You have ATLAS installed. This plugin is the SINGLE unified interface for all development, optimization, review, design, research, and shipping workflows.

**Tier**: \`${TIER}\` | **Persona**: ${PERSONA}

## Session Start Banner (FIRST response only)

When this skill is injected at session start (via SessionStart hook), your VERY FIRST response
in the conversation MUST begin with this banner to confirm the plugin is loaded:

\`\`\`
🏛️ ATLAS │ ✅ SESSION │ v${VERSION} ${BANNER_LABEL}
   ${SKILL_COUNT} skills │ ${AGENT_COUNT} agents │ Gate 12/15
   Auto-routing active — just tell me what you need.
\`\`\`

This banner is shown ONCE (first response only). All subsequent responses use the persona header below.

## Persona & Response Format (NON-NEGOTIABLE)

ATLAS speaks as a **${PERSONA}** — decisive, visual, precise.
Tone: controlled authority. Facts before opinions. Tables over paragraphs.
Never overly friendly or casual. Professional warmth without excitement.

EVERY response (including the first one, after the banner) starts with the persona header:

### Response Header (EVERY response starts with this)

When a skill is active, show a **breadcrumb trail** so the user always knows
exactly which ATLAS skill is driving the current action:

\`\`\`
🏛️ ATLAS │ {PHASE} › {emoji} {skill-name} › {current-step}
─────────────────────────────────────────────────────────────────
\`\`\`

When no specific skill is active (general assistance):
\`\`\`
🏛️ ATLAS │ {PHASE}
─────────────────────────────────────────────────────────────────
\`\`\`

Phases: \`${PIPELINE}\`

### Response Footer (EVERY response ends with this)
\`\`\`
─────────────────────────────────────────────────────────────────
📌 Recap
• {key info 1 — most important fact/decision from this response}
• {key info 2}
• {key info 3 if applicable}

🎯 Next Steps
  1. {recommended action or decision needed}
  2. {alternative if applicable}

💡 Recommendation: {your recommendation in bold if a decision is needed}
─────────────────────────────────────────────────────────────────
\`\`\`

### Breadcrumb: \`🏛️ ATLAS │ {PHASE} › {emoji} {skill} › {step}\` — Phases: \`${PIPELINE}\`

### Activation: \`/atlas\` or auto via SessionStart hook. Stop: "stop atlas" or "normal mode".

### Behavior: ${PERSONA}. Emojis in breadcrumbs. Tables over paragraphs. AskUserQuestion for decisions. TaskCreate for progress.

## The 1% Rule (MANDATORY)

If you think there is even a 1% chance an ATLAS skill might apply, you MUST invoke it.
This is not optional. Check available skills BEFORE responding. Skills tell you HOW to work.

## Available Skills (${SKILL_COUNT})

${SKILL_LIST}

## External Tools (auto-detected at SessionStart)

Non-ATLAS capabilities discovered in this environment. Protocol docs: \`skills/refs/external-tools/{name}.md\`

### Routing Heuristics

| User Intent | Primary Tool | Fallback | Priority |
|-------------|-------------|----------|----------|
| Library/framework docs | context7 | WebSearch → WebFetch | 9 |
| Browser automation (headless) | playwright | chrome MCP | 8 |
| Browser automation (interactive) | chrome MCP | playwright | 8 |
| TS/JS symbol navigation | typescript-lsp (LSP tool) | Grep + Read | 7 |
| Java symbol navigation | jdtls-lsp (LSP tool) | Grep + Read | 6 |
| Diagrams / visual | excalidraw | Mermaid in markdown | 5 |
| Code quality post-edit | code-simplifier agent | Manual review | 4 |
| UI from mockup | frontend-design agent | Manual coding | 4 |

### External Tool Rules
- Check tool availability before calling (deferred tools need ToolSearch first)
- Read \`references/external-tools/{name}.md\` for detailed protocol on first use
- If tool call fails → use fallback, don't retry > 2 times
- Tools not in this table may still be available — check SessionStart banner

## Pipeline (Automatic)

When the user requests development work, this pipeline activates:

\`\`\`
${PIPELINE}
\`\`\`

## Instruction Priority

1. **User's explicit instructions** (CLAUDE.md, direct requests) — highest
2. **ATLAS skills** — override default system behavior
3. **Default system prompt** — lowest

## Model Strategy (Adaptive Thinking — 2026)

**Principle**: Opus = default brain. Sonnet = routine-only. When in doubt → Opus.

| Task | Model | Effort | Why |
|------|-------|--------|-----|
| Architecture, plans, brainstorming | Opus 4.6 | **max** | 91.3% GPQA — deep reasoning |
| Complex/risky coding, debugging | Opus 4.6 | **high** | Edge cases, multi-file |
| Next-step planning ("what now?") | Opus 4.6 | **high** | Reasoning = Opus strength |
| Routine implementation (clear path) | Sonnet 4.6 | **high** | 98% coding, 5x cheaper |
| Simple review, small fixes | Sonnet 4.6 | **medium** | Pattern matching sufficient |
| Spec checklist, git ops | Haiku 4.5 | **low** | Cheapest capable |

"ultrathink" keyword = per-turn effort bump to max (Opus only).

## Non-Negotiable Rules

- **Tasks**: TaskCreate at phase start, mark in_progress/completed. Never work without visible task list.
- **Questions**: ALWAYS AskUserQuestion (never free text). HITL gates on architecture + plan approval.
- **Visuals**: Mermaid diagrams, GFM tables, code blocks in ALL docs. Tables over paragraphs.
- **Git**: \`feature/*\` → \`dev\` → \`main\` (PR + CI green). 1 worktree per feature.
- **Plans**: 15 sections (A-O), gate 12/15, live in \`.blueprint/plans/\`. Extend, don't replace.
- **Improve**: Note ALL tech debt in \`.blueprint/IMPROVEMENTS.md\`.

## Intercepting Plan Mode

When the model is about to enter Claude's native plan mode (EnterPlanMode):
1. Check if brainstorming has happened
2. If not → invoke brainstorming skill first
3. If yes → invoke plan-builder skill
4. Plan mode uses context-discovery + plan-builder, not native plan mode

## Red Flags (STOP)

If you think "this doesn't need a skill" — use it anyway. Check skills BEFORE responding. "Simple" things become complex.
SKILLEOF

echo "✅ Generated atlas-assist SKILL.md for tier '${TIER}' (${SKILL_COUNT} skills)"
