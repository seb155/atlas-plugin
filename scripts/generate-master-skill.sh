#!/usr/bin/env bash
# Generate tier-specific or domain-specific atlas-assist SKILL.md
# Usage: ./scripts/generate-master-skill.sh <tier|domain> <output_path> [--domain]
#
# Tier mode (default): generates atlas-assist for tier profiles (admin, dev, user, worker)
# Domain mode (--domain): generates atlas-{domain}-assist for domain profiles (core, dev, frontend, ...)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

TIER="$1"
OUTPUT="$2"
DOMAIN_MODE="${3:-}"
VERSION=$(cat VERSION | tr -d '[:space:]')

# Domain mode uses domain profiles, tier mode uses tier profiles
if [ "$DOMAIN_MODE" = "--domain" ]; then
  PROFILE="profiles/domains/${TIER}.yaml"
  SKILL_NAME="atlas-${TIER}-assist"
else
  PROFILE="profiles/${TIER}.yaml"
  SKILL_NAME="atlas-assist"
fi

# Worker tier: generate minimal SKILL.md and exit early
if [ "$TIER" = "worker" ]; then
  cat > "$OUTPUT" <<WORKER_EOF
---
name: ${SKILL_NAME}
description: "ATLAS Worker — minimal task executor for Agent Teams. Zero skills, zero hooks."
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
# Skill emoji map (static — add new skills here)
declare -A EMOJI_MAP=(
  [context-discovery]="🔭" [plan-builder]="🏗️" [brainstorming]="💡" [frontend-design]="🎨"
  [tdd]="🧪" [executing-plans]="⚡" [subagent-dispatch]="🤖" [git-worktrees]="🌿"
  [systematic-debugging]="🔬" [verification]="📊" [code-review]="🔍" [code-simplify]="✨"
  [finishing-branch]="📦" [devops-deploy]="🎯" [experiment-loop]="🧬" [engineering-ops]="⚙️"
  [deep-research]="📚" [document-generator]="📄" [scope-check]="🛡️" [decision-log]="📋"
  [session-retrospective]="🔄" [hookify]="🪝" [browser-automation]="🌐" [skill-management]="🧩"
  [note-capture]="📝" [knowledge-builder]="🧠" [user-profiler]="👤" [reminder-scheduler]="⏰"
  [morning-brief]="☀️" [infrastructure-ops]="🔧" [security-audit]="🔐"
  [plugin-builder]="🔌"
  # v3.3.0 additions
  [statusline-setup]="📟" [feature-board]="📌" [code-analysis]="🔎"
  [enterprise-audit]="🏢" [knowledge-manager]="📖" [platform-update]="🆙"
  [atlas-dev-self]="🔁" [atlas-onboarding]="👋" [atlas-doctor]="🩺"
  [atlas-vault]="🔐" [atlas-location]="📍"
  [youtube-transcript]="🎬"
  [plan-review]="🔍"
  [frontend-workflow]="🎨"
  [test-orchestrator]="🧪"
  [vision-alignment]="🧭"
  [memory-dream]="🌙"
  # v3.26.0 additions (commands→skills migration)
  [session-pickup]="🔄" [ultrathink]="🧠" [ci-management]="🔧"
  [product-health]="🏥" [onboarding-check]="✅" [session-spawn]="🚀"
  [marketplace-manager]="🏪" [programme-manager]="📊" [knowledge-engine]="🗂️"
  # v3.28.0: Agent Teams
  [atlas-team]="👥"
  # v3.43.0: Infrastructure change orchestration
  [infrastructure-change]="🏗️"
)

# Skill category map
declare -A CATEGORY_MAP=(
  [context-discovery]="Planning" [plan-builder]="Planning" [brainstorming]="Planning" [frontend-design]="Planning"
  [tdd]="Implementation" [executing-plans]="Implementation" [subagent-dispatch]="Implementation" [git-worktrees]="Implementation"
  [systematic-debugging]="Quality" [verification]="Quality" [code-review]="Quality" [code-simplify]="Quality"
  [finishing-branch]="Ship" [devops-deploy]="Deploy" [experiment-loop]="Optimize" [engineering-ops]="Optimize"
  [deep-research]="Knowledge" [document-generator]="Knowledge" [scope-check]="Meta" [decision-log]="Meta"
  [session-retrospective]="Meta" [hookify]="Meta" [browser-automation]="Meta" [skill-management]="Meta"
  [note-capture]="Personal" [knowledge-builder]="Personal" [user-profiler]="Personal" [reminder-scheduler]="Personal"
  [morning-brief]="Personal" [infrastructure-ops]="Infrastructure" [security-audit]="Security"
  [plugin-builder]="Meta"
  # v3.3.0 additions
  [statusline-setup]="Infrastructure" [feature-board]="Project" [code-analysis]="Quality"
  [enterprise-audit]="Governance" [knowledge-manager]="Knowledge" [platform-update]="Meta"
  [atlas-dev-self]="Meta" [atlas-onboarding]="Meta" [atlas-doctor]="Meta"
  [atlas-vault]="Security" [atlas-location]="Meta"
  [youtube-transcript]="Knowledge"
  [plan-review]="Quality"
  [frontend-workflow]="Planning"
  [test-orchestrator]="Quality"
  [vision-alignment]="Planning"
  [memory-dream]="Meta"
  # v3.26.0 additions
  [session-pickup]="Meta" [ultrathink]="Meta" [ci-management]="Deploy"
  [product-health]="Quality" [onboarding-check]="Meta" [session-spawn]="Meta"
  [marketplace-manager]="Meta" [programme-manager]="Project" [knowledge-engine]="Knowledge"
  # v3.28.0: Agent Teams
  [atlas-team]="Implementation"
  # v3.43.0: Infrastructure change orchestration
  [infrastructure-change]="Infrastructure"
)

# Skill one-liner descriptions
declare -A DESC_MAP=(
  [context-discovery]="Auto-scan project + CLAUDE.md audit + codemap generation"
  [plan-builder]="Generate ultra-detailed 15-section plans (A-O) with quality gate 12/15"
  [brainstorming]="Collaborative design exploration. 1 question at a time. 2-3 approaches. HITL approval"
  [frontend-design]="UI/UX implementation from specs. Distinctive, production-grade"
  [tdd]="Failing test → minimal impl → pass → commit. Strict TDD cycle"
  [executing-plans]="Load plan → TaskCreate per step → execute with subagents"
  [subagent-dispatch]="Dispatch Sonnet subagents per task. 2-stage review"
  [git-worktrees]="Isolated branch per feature. Safety verification (Forgejo-native)"
  [systematic-debugging]="Hypothesize → verify → fix. Max 2 attempts then escalate"
  [verification]="L1-L4 tests + E2E + security scan + perf benchmarks"
  [code-review]="Code review with confidence filtering. Local or PR mode"
  [code-simplify]="Refactoring for clarity, consistency, maintainability"
  [finishing-branch]="Commit + push + PR + CI + cleanup (conventional commits)"
  [devops-deploy]="Deploy to any env with health checks, validators, data sync"
  [experiment-loop]="Autonomous optimization (autoresearch pattern)"
  [engineering-ops]="I&C maintenance + 4-agent estimation pipeline"
  [deep-research]="Multi-query decomposition → search → triangulate → synthesize"
  [document-generator]="Generate PPTX/DOCX/XLSX with storytelling and layouts"
  [scope-check]="Detect drift. Are you working outside original scope?"
  [decision-log]="Log architectural decisions to .claude/decisions.jsonl"
  [session-retrospective]="End-of-session lessons + session close + handoff context"
  [hookify]="Create Claude Code hooks from conversation patterns"
  [browser-automation]="Browser automation for E2E testing and visual QA"
  [skill-management]="Create, improve, benchmark skills. Plugin development"
  [note-capture]="Quick capture notes with tags, context, linked to meetings/projects"
  [knowledge-builder]="Learn facts/preferences/relationships. Confidence-based"
  [user-profiler]="Build and display user's complete profile"
  [reminder-scheduler]="Schedule reminders via CronCreate"
  [morning-brief]="Compile daily brief: agenda + emails + tasks + suggestions"
  [infrastructure-ops]="Infrastructure management: VMs, containers, networking, monitoring"
  [security-audit]="Security scanning, RBAC audit, vulnerability assessment, compliance"
  [plugin-builder]="Build Claude Code plugins from scratch with correct structure and validation"
  # v3.3.0 additions
  [statusline-setup]="Configure CShip + Starship status line for Claude Code sessions"
  [feature-board]="Feature registry dashboard — kanban, validation matrix, roadmap"
  [code-analysis]="Codebase analysis: dead code, dependency graphs, dataflow tracing"
  [enterprise-audit]="14-dimension enterprise readiness audit for due diligence"
  [knowledge-manager]="Enterprise knowledge layer — coverage, discovery, search, vault"
  [platform-update]="SOTA audit + auto-update for ATLAS plugin and CC environment"
  [atlas-dev-self]="Self-development workflow for the ATLAS plugin itself"
  [atlas-onboarding]="Guided 5-phase setup wizard for new users"
  [atlas-doctor]="System health check with 8-category dashboard and auto-fix"
  [atlas-vault]="Ingest user vault for personalized behavior and trust-based access"
  [atlas-location]="Location profiles, WiFi network trust, and security adaptation"
  [youtube-transcript]="Extract YouTube video transcripts to timestamped markdown files"
  [plan-review]="Iterative plan review with simulation, consolidation, and HITL gates"
  [frontend-workflow]="6-phase iterative UX development with architectural gates and HITL"
  [test-orchestrator]="Test pyramid orchestration: unit, integration, E2E, security, coverage"
  [vision-alignment]="Strategic idea intake — scan mega plan, sub-plans, features, backlog before deciding"
  [memory-dream]="Memory consolidation (CC auto-dream pattern). 4-phase: orient, gather, consolidate, prune"
  # v3.26.0 additions
  [session-pickup]="Resume from handoff file — context reload, rich briefing, scope-locked drill-in"
  [ultrathink]="Deep reasoning mode — maximum thinking budget for complex architectural decisions"
  [ci-management]="CI/CD pipeline management — Forgejo Actions status, logs, rerun, runner fleet"
  [product-health]="Application reality audit — live validation via API, browser, and tests"
  [onboarding-check]="Team readiness audit — 12-check grade A-F with auto-fix mode"
  [session-spawn]="Multi-session orchestration — spawn/continue/list CC sessions in tmux"
  [marketplace-manager]="Marketplace plugin management — publish, version, distribute"
  [programme-manager]="Programme management — mega plan tracking, sub-plan coordination"
  [knowledge-engine]="Enterprise knowledge layer — search, ingest, discover, vectorize"
  # v3.28.0: Agent Teams
  [atlas-team]="Agent Teams blueprints — spawn coordinated worker squads in tmux panes (jarvis, feature, debug, review, audit)"
  # v3.43.0: Infrastructure change orchestration
  [infrastructure-change]="CF Tunnel, Caddy, Authentik, DNS, NetBird change orchestration with pre-flight validation"
)

# Category header emojis
declare -A CATEGORY_EMOJI=(
  [Planning]="🏗️" [Implementation]="⚡" [Quality]="📊" [Ship]="📦"
  [Deploy]="🎯" [Optimize]="🧬" [Knowledge]="📚" [Meta]="🛡️"
  [Personal]="👤" [Infrastructure]="🔧" [Security]="🔐"
  [Project]="📌" [Governance]="🏢"
)

# Build skill list grouped by category
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
  while IFS='|' read -r cat skill; do
    [ -z "$skill" ] && continue
    local emoji="${EMOJI_MAP[$skill]:-❓}"
    local desc="${DESC_MAP[$skill]:-}"
    local cat_emoji="${CATEGORY_EMOJI[$cat]:-📌}"

    if [ "$cat" != "$prev_category" ]; then
      if [ -n "$prev_category" ]; then echo ""; fi
      echo "### ${cat_emoji} ${cat}"
      prev_category="$cat"
    fi
    echo "- ${emoji} **${skill}**: ${desc}"
  done < "${tmpfile}.sorted"

  rm -f "$tmpfile" "${tmpfile}.sorted"
}

# Build emoji map table
build_emoji_table() {
  echo "| Skill | Emoji | Category |"
  echo "|-------|-------|----------|"
  for skill in $ALL_SKILLS; do
    local emoji="${EMOJI_MAP[$skill]:-❓}"
    local cat="${CATEGORY_MAP[$skill]:-Other}"
    echo "| **${skill}** | ${emoji} | ${cat} |"
  done
}

# Generate the SKILL.md
SKILL_LIST=$(build_skill_list)
EMOJI_TABLE=$(build_emoji_table)

cat > "$OUTPUT" <<SKILLEOF
---
name: ${SKILL_NAME}
description: "Master skill for ATLAS ${BANNER_LABEL} — AXOIQ's unified AI engineering assistant. ${SKILL_COUNT} skills, ${AGENT_COUNT} agents. Auto-routing co-pilot with HITL gates."
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

### Skill Emoji Map (MANDATORY — use these consistently)

${EMOJI_TABLE}

### Breadcrumb Examples

\`\`\`
🏛️ ATLAS │ IMPLEMENT › 🧪 tdd › running-tests
🏛️ ATLAS │ VERIFY › 📊 verification › L2-frontend
🏛️ ATLAS │ PLAN › 🏗️ plan-builder › section-C-architecture
🏛️ ATLAS │ ASSIST
\`\`\`

### Activation
- **Slash command**: \`/atlas\` activates the persona explicitly
- **Auto-activation**: When the SessionStart hook injects this skill, persona is always on
- **Deactivation**: User says "stop atlas" or "normal mode"

### Persona Behavior
- **Tone**: ${PERSONA} — decisive, controlled, visual. Facts first.
- **Emojis**: Use skill emojis in breadcrumbs and status. Use category emojis (✅❌⏳) for status.
- **Visuals**: ASCII diagrams, comparison tables, structured reports in EVERY technical response.
- **Decisions**: Always end with actionable recap + next steps + recommendation via AskUserQuestion.
- **Progress**: Task lists and breadcrumbs visible at all times.
- **Concise**: Lead with the answer. Skip preamble. Tables over paragraphs.

## The 1% Rule (MANDATORY)

If you think there is even a 1% chance an ATLAS skill might apply, you MUST invoke it.
This is not optional. Check available skills BEFORE responding. Skills tell you HOW to work.

## Available Skills (${SKILL_COUNT})

${SKILL_LIST}

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

## Non-Negotiable Principles

### Task Lists
- ALWAYS create TaskCreate at start of each phase
- Mark in_progress when starting, completed when done
- Never work without visible task list

### Questions
- ALWAYS use AskUserQuestion for questions (never free text)
- HITL gates on architecture decisions and plan approval

### Visual Documentation Standards

ALL documentation generated (plans, architecture docs, reports) uses rich visual
elements that render in the Dev Explorer dashboard via MarkdownRenderer:

**Mermaid Diagrams** (rendered as SVG in dashboard):
- \`graph TD\` / \`graph LR\` — architecture, system diagrams
- \`sequenceDiagram\` — API/data flows
- \`gantt\` — phase timelines
- \`flowchart TD\` — decision trees
- \`stateDiagram-v2\` — lifecycle, state machines
- \`erDiagram\` — database schemas
- \`pie\` — distribution charts

**GFM Markdown Tables** — ALL comparisons, inventories, matrices
**Code Blocks** with language tags — syntax highlighted
**Bold text** for emphasis
**Markdown headers** (##) for sections, bullet points for lists
**Recommendations** in bold with justification

### Continuous Improvement
- Note ALL improvements, errors, tech debt, backlog items
- Propose SOTA improvements even if full refactoring required
- Maintain \`.blueprint/IMPROVEMENTS.md\`

### Forgejo-Native
- Branches: \`feature/*\` → \`dev\` → \`main\` (PR + CI green)
- Worktrees: 1 per feature, auto isolation
- Versioning: Semver + Git tags + auto release notes
- CI/CD: Forgejo Actions, lean, fast (< 5 min)

### Plans
- 15 sections (A-O): Core + Enterprise + Execution
- Quality gate: 12/15 minimum
- Plans live in \`.blueprint/plans/\` (Git versioned)
- Extend existing plans, don't replace
- Reference \`.blueprint/PLAN-TEMPLATE.md\` for structure

## Intercepting Plan Mode

When the model is about to enter Claude's native plan mode (EnterPlanMode):
1. Check if brainstorming has happened
2. If not → invoke brainstorming skill first
3. If yes → invoke plan-builder skill
4. Plan mode uses context-discovery + plan-builder, not native plan mode

## Red Flags (STOP — you're rationalizing)

| Thought | Reality |
|---------|---------|
| "This is just a simple question" | Check for skills |
| "I need more context first" | Skills tell you HOW to gather context |
| "Let me explore the codebase first" | context-discovery skill does this |
| "This doesn't need a formal plan" | plan-quality rules say otherwise |
| "I'll just do this one thing first" | Check BEFORE doing anything |
| "The skill is overkill" | Use it. Simple things become complex |
SKILLEOF

echo "✅ Generated atlas-assist SKILL.md for tier '${TIER}' (${SKILL_COUNT} skills)"
