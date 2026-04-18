---
name: scope-check
description: "Detect scope drift. Are you touching files outside the original task? Stop and verify before proceeding."
effort: low
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [brainstorming, plan-builder]
thinking_mode: adaptive
---

<HARD-GATE>
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.
When touching files outside original task scope, STOP and verify with user before proceeding.
Scope drift destroys plans. Symptom fixes are failure.
If you have not completed Phase 1 (investigate why the out-of-scope file needs changing), you cannot propose fixes or expand the scope.
</HARD-GATE>

<red-flags>

| Thought | Reality |
|---|---|
| "Just a tiny fix while I'm here" | "Tiny" fixes untracked in the plan compound into untestable, unreviewable diffs. The plan had a file list for a reason — touching files outside it bypasses review, tests, and rollback paths. STOP. Add to plan or defer. |
| "While I'm here, I'll also fix..." | "While I'm here" is the #1 phrase preceding scope drift incidents. Every adjacent fix doubles your PR review time and halves your merge velocity. Deferred = faster. |
| "This touches something unrelated but..." | "Unrelated but" means "related in a way I have not investigated". Unexamined coupling is how 2-line fixes turn into 200-line surprises. Investigate the coupling BEFORE expanding scope. |
| "Quick fix for now, investigate the real cause later" | First fix sets the pattern. 'Later' never comes. The band-aid becomes permanent and compounds with the next band-aid into an untraceable tangle. STOP. Complete Phase 1 (Root Cause Investigation) FIRST. |
| "Good enough, we can refactor later" | 'Later' is the cemetery where good intentions go. Code merged ships to production. Every refactor-later is a mortgage with compound interest paid in incident reviews. Either fix now (cheapest moment) or file a TaskCreate with owner + deadline — never 'later' as a rhetorical device. |

</red-flags>

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

## Signs of Drift
- "While I'm here, I'll also fix..."
- "This needs a small refactor first..."
- "Let me update this related component..."
- Touching > 2x the files listed in the plan
