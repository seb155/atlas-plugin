---
name: swimlane-tracker
description: Parse SWIMLANES.md + FEATURES.md to render 8-lane cross-cutting quality matrix. Audit per-feature checklist completeness.
model: sonnet
user_invocable: false
---

# Swimlane Tracker

Render cross-cutting quality matrix from `.blueprint/SWIMLANES.md` + `.blueprint/FEATURES.md`. Show 8 swimlane dimensions per feature.

## When to Use

- User says "swimlanes", "quality matrix", "cross-cutting"
- `/atlas board swimlanes` command
- After completing a feature task (show swimlane gaps)

## Process

1. **Read** `.blueprint/SWIMLANES.md` — extract 8 swimlane definitions
2. **Read** `.blueprint/FEATURES.md` — extract all features with validation matrix
3. **Cross-reference** — for each feature, assess each swimlane dimension
4. **Render** ASCII matrix: features (rows) × swimlanes (columns)
5. **Suggest** gaps — features missing critical swimlane checks

## Board Format

```
🏛️ ATLAS │ Swimlane Matrix — {date}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Feature          │ 🔒  │ 🎨  │ 🧪  │ 📊  │ 🌐  │ ♿  │ 📖  │ 🚀  │ Score
─────────────────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┼──────
▼ 🔧 Eng Digit  │     │     │     │     │     │     │     │     │
  FEAT-008       │ ✅  │ ✅  │ ⏳  │ ✅  │ ⏳  │ ⏳  │ ✅  │ ✅  │ 5/8
  FEAT-002       │ ✅  │ ✅  │ ⏳  │ ✅  │ ⏳  │ ⏳  │ ⏳  │ ✅  │ 4/8
▼ 📋 PM Ctrl    │     │     │     │     │     │     │     │     │
  FEAT-019 ✅    │ ✅  │ ✅  │ ✅  │ ✅  │ ⏳  │ ⏳  │ ⏳  │ ✅  │ 5/8
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💡 Gap: 12 features missing i18n checks
💡 Gap: 15 features missing a11y audit
🎯 Next: FEAT-008 needs E2E test (🧪 swimlane)
```

## Swimlane Assessment Rules

| Swimlane | Auto-detect from | Manual override |
|----------|-----------------|-----------------|
| 🔒 Security | RBAC in router + audit_trail model exists | Feature-level notes |
| 🎨 UX | Lucide imports, theme tokens in component | Figma link |
| 🧪 Testing | Validation matrix BE/FE/E2E/HITL status | Manual status |
| 📊 Analytics | structlog usage, correlation_id in service | SLO notes |
| 🌐 i18n | No hardcoded strings in component | Translation file exists |
| ♿ a11y | ARIA attributes in component | axe-core report |
| 📖 Docs | .blueprint/ doc exists for feature | API docs auto-gen |
| 🚀 Perf | Valkey cache or TQ staleTime configured | Load test results |
