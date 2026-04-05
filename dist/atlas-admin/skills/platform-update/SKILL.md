---
name: platform-update
description: "SOTA audit + auto-update for ATLAS plugin + Claude Code environment. Detects model, CC version, plugin version, researches latest best practices, proposes + applies fixes. /atlas update"
effort: medium
---

# Platform Update — Keep ATLAS + CC Environment at SOTA

**Principle**: AI tooling evolves weekly. This skill ensures ATLAS plugin + Claude Code environment always uses the latest best practices, model capabilities, and features. Run monthly or when noticing degraded performance.

## When to Use

- User says "update", "upgrade", "check environment", "are we up to date?"
- Monthly maintenance (proactive suggestion from session-start)
- After Claude Code version upgrade
- After Anthropic model release (new Opus/Sonnet/Haiku)
- When context quality degrades or agent performance drops

## Process

### Phase 1: DETECT — Environment Snapshot (DET node, 30s)

Collect current state via Bash commands (NO agent reasoning needed):

```bash
# 1. Claude Code version
claude --version 2>/dev/null || echo "CC version: unknown"

# 2. Current model
echo "Model: ${ANTHROPIC_MODEL:-default} | Opus: ${ANTHROPIC_DEFAULT_OPUS_MODEL:-default} | Sonnet: ${ANTHROPIC_DEFAULT_SONNET_MODEL:-default}"

# 3. Context window config
echo "Subagent model: ${CLAUDE_CODE_SUBAGENT_MODEL:-not set}"
echo "Autocompact: ${CLAUDE_AUTOCOMPACT_PCT_OVERRIDE:-not set}"
echo "Max thinking: ${MAX_THINKING_TOKENS:-not set}"

# 4. Plugin version + tier
cat "${CLAUDE_PLUGIN_ROOT}/VERSION" 2>/dev/null || echo "Plugin: not found"
cat "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" 2>/dev/null | grep name

# 5. MCP servers
ls ~/.claude/.mcp*.json 2>/dev/null && cat ~/.claude/.mcp.json 2>/dev/null | grep -o '"[^"]*"' | head -20

# 6. Hooks configured
cat "${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json" 2>/dev/null | grep -o '"[A-Z][a-zA-Z]*"' | sort -u

# 7. Settings
cat ~/.claude/settings.json 2>/dev/null | head -30

# 8. Installed plugins
ls ~/.claude/plugins/cache/ 2>/dev/null
```

### Phase 2: RESEARCH — SOTA Best Practices (AGENT node, Opus)

**This is the critical differentiator.** Don't use static rules — research LIVE what's current:

1. **Context7** → query `/websites/code_claude` for latest CC features + best practices
2. **Context7** → query `/affaan-m/everything-claude-code` for community patterns
3. **WebSearch** → "Claude Code best practices {current_month} {current_year}"
4. **WebSearch** → "Anthropic model updates {current_month} {current_year}"
5. **WebFetch** → `https://code.claude.com/docs/en/changelog` for latest CC changes

Compare research findings vs current environment snapshot.

### Phase 3: AUDIT — Gap Analysis (AGENT node, Sonnet)

Present findings as a scored audit:

```
🏛️ ATLAS │ Platform Update — {date}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 ENVIRONMENT AUDIT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

| Component          | Current           | SOTA              | Status |
|--------------------|-------------------|-------------------|--------|
| Claude Code        | (detected)        | v2.1.92           | (auto) |
| Opus Model         | claude-opus-4-6[1m] | claude-opus-4-6[1m] | ✅ 1M NATIVE |
| Sonnet Model       | claude-sonnet-4-6 | claude-sonnet-4-6 | ✅ 1M NATIVE |
| Haiku Model        | claude-haiku-4-5  | claude-haiku-4-5  | ✅ CURRENT |
| Autocompact        | (detected)        | 85%               | (auto) |
| Plugin Version     | (detected)        | (detected)        | (auto) |
| Forgejo            | (detected)        | (detected)        | (auto) |
| Runner             | (detected)        | (detected)        | (auto) |

📈 Score: (auto-calculated from detection)

🔴 HIGH PRIORITY (if detected):
  1. CC version behind SOTA → `claude update`
  2. ANTHROPIC_DEFAULT_OPUS_MODEL not set → add to settings.json env

🟡 RECOMMENDED:
  3. Autocompact not set → set to 85% for 1M context
  4. Plugin version behind → `make dev` in plugin source

🟢 NOTE:
  5. Opus 4.6 + Sonnet 4.6 have 1M context NATIVELY (API level, April 2026)
  6. CC 2.1.75+ resolves shorthand "opus"/"sonnet" to 1M for Max subscribers
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Phase 4: FIX — Apply Changes (GATE → DET nodes)

**HITL gate**: Present fixes with AskUserQuestion before applying.

For each fix category:

**Settings.json updates:**
```bash
# Read current settings
cat ~/.claude/settings.json

# Propose merge (show diff)
# Apply after user approval via Edit tool
```

**Environment variables** (add to ~/.bashrc or project .env):
```bash
export ANTHROPIC_DEFAULT_OPUS_MODEL='claude-opus-4-6[1m]'
export CLAUDE_CODE_SUBAGENT_MODEL='haiku'
export CLAUDE_AUTOCOMPACT_PCT_OVERRIDE='60'
```

**CC update:**
```bash
claude update  # Only if user approves
```

**Plugin self-update + marketplace publish (ADMIN-ONLY, HITL required):**

⚠️ This updates the plugin for ALL users via the Forgejo marketplace. AskUserQuestion BEFORE every step.

```bash
cd ~/workspace_atlas/projects/atlas-dev-plugin
git pull origin main

# Build ALL tiers (admin + dev + user)
./build.sh all

# Install admin locally
VERSION=$(cat VERSION)
rm -rf ~/.claude/plugins/cache/atlas-admin-marketplace/atlas-admin/${VERSION}
mkdir -p ~/.claude/plugins/cache/atlas-admin-marketplace/atlas-admin/${VERSION}
cp -r dist/atlas-admin/* ~/.claude/plugins/cache/atlas-admin-marketplace/atlas-admin/${VERSION}/
echo "✅ Admin plugin updated locally to v${VERSION}"

# HITL GATE: Publish to Forgejo marketplace for other users?
# AskUserQuestion: "Publish v${VERSION} to Forgejo marketplace? This affects all atlas-dev and atlas-user installs."
# If yes:
git tag "v${VERSION}"
git push origin "v${VERSION}"
# CI auto-publishes to Forgejo Package Registry on v* tags
echo "✅ Published v${VERSION} — CI will build + publish all 3 tiers"
```

### Phase 5: VERIFY — Post-Update Check (DET node)

```bash
# Re-run Phase 1 snapshot
# Compare before/after
# Report delta
```

## Model Routing Reference (2026 SOTA)

Keep this section updated based on Phase 2 research findings.

| Task Type | Model | Why |
|-----------|-------|-----|
| Architecture, planning, brainstorm | Opus 4.6 (1M) | Deep reasoning, full codebase context |
| Implementation, refactoring, fixes | Sonnet 4.6 | 97-99% of Opus coding, lower cost |
| Subagents (explore, review, test) | Sonnet 4.6 | Balance speed + quality |
| Classification, simple validation | Haiku 4.5 | Cheapest capable, 90% of Sonnet |
| Parallel agents (dispatching) | Sonnet 4.6 | Each agent gets own context |

### Context Window Strategy

| Model | Context | Best Use |
|-------|---------|----------|
| Opus 4.6 [1m] | 1M tokens | Full repo analysis, long sessions, complex plans |
| Opus 4.6 | 200K tokens | Standard sessions, single feature work |
| Sonnet 4.6 | 200K tokens | Implementation, most dev work |
| Haiku 4.5 | 200K tokens | Quick tasks, simple queries |

### When to Use 1M Context

- Session will touch >50 files
- Working on cross-cutting concern (refactor, migration)
- Need full codebase understanding for architecture decision
- Long sessions (>3h) where compaction would lose context

### Compaction Strategy

- `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=60` — compact at 60% (preserve more context)
- Compaction preserves images (CC 2.1.72+) but loses textual nuance
- For critical sessions: increase to 70-80% to delay compaction

## Self-Update Schedule

This skill should suggest running `/atlas update` when:
- Session-start detects plugin version < latest on Forgejo
- CC version is >2 minor versions behind
- A new Anthropic model family is detected (Opus 5, etc.)
- Monthly: first session of each month

## CLAUDE.md Best Practices (audit target)

| Rule | Check |
|------|-------|
| W3H format (What, Why, How) | Grep for structure |
| ≤100 lines root CLAUDE.md | `wc -l CLAUDE.md` |
| .blueprint/ for detailed docs | `ls .blueprint/` |
| No hardcoded counts/versions | Grep for specific numbers |
| Stack versions in .blueprint/ not CLAUDE.md | Check for version drift |
