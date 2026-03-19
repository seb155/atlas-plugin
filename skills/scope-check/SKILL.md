---
name: scope-check
description: "Detect scope drift. Are you touching files outside the original task? Stop and verify before proceeding."
---

# Scope Check

## When to Check
- Before modifying a file not listed in the plan
- When a task is taking longer than expected
- When you notice yourself "fixing one more thing"
- When you're refactoring code adjacent to the task

## Process

1. **Compare**: What files were you SUPPOSED to touch? (from plan Section N)
2. **Actual**: What files have you ACTUALLY touched? (`git diff --name-only`)
3. **Delta**: Any files in actual but NOT in plan?

If delta exists:
```
⚠️ SCOPE CHECK

Planned files: {list from plan}
Actual files: {list from git diff}
Out of scope: {delta list}

Is this drift intentional?
```

Use AskUserQuestion:
- "Yes, this is needed for the feature" → continue, update plan
- "No, I got sidetracked" → revert out-of-scope changes, refocus
- "Add it as a separate task" → create new task, finish current first

## Feature Branch Scope Guard

When on a `feature/*` branch, check if edited files belong to the feature's subsystem:

1. **Detect current branch**: `git branch --show-current`
2. **If `feature/*`**: look up the feature in `.blueprint/FEATURES.md` by branch name
3. **Get subsystem**: the feature's `Subsystem` field (e.g., SynapseCAD, Rules, UX)
4. **Check edited files**: `git diff --name-only` — do they relate to the subsystem?

**Subsystem → file mapping heuristics**:
- SynapseCAD → `**/synapsecad*`, `**/drawing*`
- Rules → `**/rule*`, `**/classification*`
- UX / Data → `**/tree*`, `**/version*`
- Platform → `**/auth*`, `**/admin*`, `**/atlas*`
- PLC → `**/plc*`, `**/l5x*`

If mismatch:
```
⚠️ FEATURE SCOPE: You're on feature/{name} (subsystem: {subsystem})
   but editing: {file} (looks like a different subsystem)
   → Continue anyway? Or switch branch first?
```

This is a WARNING, not a blocker. The developer decides.

## Signs of Drift
- "While I'm here, I'll also fix..."
- "This needs a small refactor first..."
- "Let me update this related component..."
- Touching > 2x the files listed in the plan
