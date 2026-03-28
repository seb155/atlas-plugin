---
name: atlas-visual-identity
description: "ATLAS visual identity system — hook badges, persona headers, emoji maps, severity levels. Reference for consistent branding across hooks and AI responses."
---

# ATLAS Visual Identity System

> Reference document for consistent ATLAS branding across all outputs.

## Universal Prefix

Every ATLAS output starts with: `🏛️ ATLAS │`

This applies to:
- Hook outputs (SessionStart, PostToolUse, PermissionRequest, etc.)
- AI response headers (breadcrumb persona)
- Session banners

## Hook Badge Format (Minimal Badge)

```
🏛️ ATLAS │ {function_emoji}{severity_emoji} {CATEGORY} │ {message}
   └─ {detail if applicable}
```

### Hook Emoji Map

| Hook | Function | Severity | Category | Example |
|------|----------|----------|----------|---------|
| session-start | 🏛️ | ✅ | SESSION | `🏛️ ATLAS │ ✅ SESSION │ v3.3.0 Admin │ 🐳 6 │ Branch: dev` |
| enterprise-check | 🛡️ | ⚠️ | ENTERPRISE | `🏛️ ATLAS │ 🛡️⚠️ ENTERPRISE │ CORS wildcard detected` |
| test-impact | 🧪 | ℹ️ | TEST IMPACT | `🏛️ ATLAS │ 🧪ℹ️ TEST IMPACT │ foo.py changed` |
| permission-request | ⚠️ | 🛑 | DESTRUCTIVE | `🏛️ ATLAS │ ⚠️🛑 DESTRUCTIVE │ rm -rf detected` |
| post-compact | 🔄 | ✅ | RESTORED | `🏛️ ATLAS │ 🔄✅ RESTORED │ Branch: dev │ 3 plans` |
| session-end | 🏛️ | ℹ️ | SESSION END | `🏛️ ATLAS │ 🏛️ℹ️ SESSION END │ 12 files, 3 orphans` |
| atlas-status-writer | — | — | (silent) | No chat output — writes JSON to session-state.json |

## AI Response Header (Breadcrumb Format)

```
🏛️ ATLAS │ {PHASE} › {skill_emoji} {skill-name} › {current-step}
─────────────────────────────────────────────────────────────────
```

Phases: `DISCOVER` | `PLAN` | `IMPLEMENT` | `VERIFY` | `SHIP` | `DEPLOY` | `ASSIST`

## Session Banner (First Response Only)

```
🏛️ ATLAS │ ✅ SESSION │ v{VERSION} {TIER}
   {SKILL_COUNT} skills │ {AGENT_COUNT} agents │ {CMD_COUNT} commands │ Gate 12/15
```

## Severity Badges

| Badge | When | Usage |
|-------|------|-------|
| ✅ | All good | Session start OK, restore success |
| ℹ️ | Informational, no action needed | Test impact hint, session stats |
| ⚠️ | Attention required | Enterprise warning, suspect pattern |
| 🛑 | Dangerous action, review mandatory | rm -rf, git force, docker prune |

## AI Response Footer

```
─────────────────────────────────────────────────────────────────
📌 Recap
• {key info 1}
• {key info 2}

🎯 Next Steps
  1. {recommended action}
  2. {alternative}

💡 Recommendation: {bold recommendation}
─────────────────────────────────────────────────────────────────
```

## Rules

1. EVERY hook output starts with `🏛️ ATLAS │`
2. EVERY AI response starts with `🏛️ ATLAS │ {PHASE}`
3. Severity badge follows function emoji (no space): `🛡️⚠️`
4. Details on next line with `   └─` indent (3 spaces + unicode box drawing)
5. No emojis in generated documentation — emojis are CLI persona only
6. Professional tone — no excitement, no exclamation marks
7. Tables over prose, facts before opinions
