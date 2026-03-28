---
name: code-simplify
description: "Code simplification and refactoring for clarity, consistency, and maintainability. This skill should be used when the user asks to 'simplify this code', 'refactor for clarity', 'clean up code', 'reduce complexity', 'make this more readable', 'simplify recent changes', or mentions improving code elegance without changing functionality."
effort: low
---

# Code Simplification

Refactor code for clarity, consistency, and maintainability while preserving exact functionality.
Focus on recently modified code unless explicitly instructed to review broader scope.

## Core Principles

1. **Preserve Functionality** — Never change what code does, only how it does it. All outputs, behaviors, and side effects remain identical.
2. **Apply Project Standards** — Follow CLAUDE.md and .claude/rules/ conventions (naming, patterns, imports, types).
3. **Clarity Over Brevity** — Explicit readable code beats clever one-liners. NEVER use nested ternaries. Prefer switch/if-else for multiple conditions.
4. **Balance** — Avoid over-simplification that reduces debuggability, removes helpful abstractions, or combines too many concerns.

## Workflow

### 1. Identify Scope
- Default: recently modified files (`git diff --name-only` + `git diff --cached --name-only`)
- If user specifies files/directories: use those
- If user says "everything": scan full codebase (confirm scope via AskUserQuestion first)

### 2. Analyze Opportunities
For each file in scope, look for:
- **Unnecessary complexity**: deep nesting, convoluted control flow
- **Redundant code**: duplicated logic, unused variables/imports, dead code
- **Naming improvements**: unclear variable/function names
- **Consolidation**: related logic spread across multiple places
- **Pattern alignment**: code that doesn't follow project patterns (check PATTERNS.md)
- **Type improvements**: `string` params that should be union types, missing return types
- **Comment cleanup**: remove comments that describe obvious code

### 3. Propose Changes
Present changes grouped by file. For each:
- **What**: brief description of the change
- **Why**: which principle it serves
- **Before/After**: code comparison (keep minimal)

Use AskUserQuestion to confirm before applying changes.

### 4. Apply Refinements
- Apply approved changes using Edit tool
- Run type-check after changes: `bun run type-check` or `tsc --noEmit`
- Run tests if available
- Verify no functionality changed

### 5. Summary
Report:
- Files modified (count + list)
- Types of simplifications applied
- Any issues found but not addressed (with reasons)

## What to Simplify

| Pattern | Action |
|---------|--------|
| Deep nesting (3+ levels) | Extract to named functions |
| Repeated code blocks | Extract to shared util/hook |
| Unclear names | Rename to descriptive names |
| `any` types | Add proper TypeScript types |
| Long functions (50+ lines) | Split into focused functions |
| Inline logic in JSX | Extract to named variables |
| Magic numbers/strings | Extract to named constants |
| Nested ternaries | Convert to switch/if-else |

## What NOT to Change

- Working functionality (even if imperfect)
- External API contracts
- Code outside the specified scope
- Performance-critical code (without profiling)
- Patterns mandated by CLAUDE.md or PATTERNS.md
- Test files (unless specifically asked)

## HITL Gates

- Before applying changes → present summary and get approval via AskUserQuestion
- If changes affect >5 files → break into batches, approve each
- If uncertain about a change → skip it and note it in summary
