---
name: task-framing
description: "Complexity assessment before starting work. This skill should be used when the user asks to 'frame this task', '/a-frame', before starting any feature >1h, or whenever the scope of work is unclear — enforces LAW-WORKFLOW-002."
effort: low
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [plan-builder, brainstorming, scope-check]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: planning
emoji: "🎯"
triggers: ["frame the task", "how complex is this", "rigor level", "before coding"]
---

<HARD-GATE>
NO FEATURE IMPLEMENTATION >1H WITHOUT TASK-FRAMING.
This skill outputs the rigor level that parameterizes downstream gates.
Signature: sha256:LAW-WORKFLOW-002 (635e7c7cea429759f6cd216286d8ea111fc1ce81203d818630b76dbacb4d018f)
</HARD-GATE>

**Iron Law**: `LAW-WORKFLOW-002` (task-framing-before-code). Override requires HITL AskUserQuestion.

<red-flags>
| Thought | Reality |
|---|---|
| "I know what to build, let me just start coding" | Unframed tasks spawn scope drift. 5 min of framing saves hours. Write it down. |
| "Framing is bureaucracy for a 2-hour feature" | Framing is 5 minutes and PREVENTS the 2-hour feature from becoming a 10-hour refactor. |
| "I'll figure out the scope as I go" | Scope figured-out-as-you-go is scope that DRIFTS. Define done before starting. |
| "This is obviously complex, skip to the plan" | Output still matters: produces rigor tier for downstream gates. Don't skip — 30 seconds. |
</red-flags>

# Task-Framing

## Purpose

Before any feature implementation >1 hour, assess complexity to set the rigor level
for remaining workflow steps. Prevents both over-engineering trivial tasks AND
under-engineering complex ones.

## The 3-Tier Classification

| Tier | Signal | Rigor applied downstream |
|------|--------|--------------------------|
| **Trivial** | <30 min, single file, no branching logic, clear spec | Skip plan-builder. TDD optional. Direct → code-review → verify. |
| **Moderate** | 30 min - 4h, 2-5 files, some branching, known pattern | task-framing → TDD → code-review → verification → ship |
| **Complex** | >4h OR >5 files OR new pattern OR >1 system | Full pipeline: brainstorming → plan-builder (15 sections, Gate 12/15) → TDD → code-review → verification → finishing-branch → ci-feedback-loop |

## Assessment Questions (answer all 5 before classifying)

1. **Time** — How long do you estimate this takes? (<30m / 30m-4h / >4h)
2. **Files** — How many files will be touched? (1 / 2-5 / >5)
3. **Logic** — Is this pattern already used in the codebase? (yes / partial / new)
4. **Systems** — How many subsystems are affected? (1 / 2 / 3+)
5. **Reversibility** — Can this easily be undone? (yes / maybe / no)

**Classification rule**: if ANY answer is in the "complex" column, classify as complex.
If all are "trivial" column, classify as trivial. Otherwise, moderate.

## Output

Produce a brief framing document (~100-200 words) with:

```markdown
## Task Framing: {brief title}

**Tier**: {trivial | moderate | complex}
**Estimated time**: {hours}
**Files affected**: {count — with paths if known}
**Pattern**: {known | adapted | new}
**Reversibility**: {easy | moderate | hard}

**Downstream rigor**:
- {list which workflow steps apply based on tier}

**Scope boundaries**:
- In-scope: {explicit list}
- Out-of-scope: {explicit list — prevents drift}

**Success criteria**:
- {observable condition that signals done}
```

Save to `memory/framing-YYYY-MM-DD-{slug}.md` for audit trail + retro input.

## When NOT to use this skill

- Pure bug fix with reproducer (use `workflow-bug-fix` directly)
- Documentation-only change (use `workflow-doc-write`)
- Continuation of an already-framed workflow (re-frame only on scope change)
- Routine refactor of known pattern <30m (trivial path, frame if in doubt)

## See also

- `plan-builder` — invoked for complex tier
- `brainstorming` — invoked for complex tier (design options)
- `scope-check` — runs during execution to detect drift vs framing
- `workflow-feature`, `workflow-bug-fix`, `workflow-refactor` — consumers
