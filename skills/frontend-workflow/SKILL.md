---
name: frontend-workflow
description: "Iterative frontend development workflow. This skill should be used when the user asks to 'build a page', 'create a component', 'design UX', 'implement UI', or needs architecture-first routing from mockup to shared-lib consumer wiring."
effort: high
---

# Frontend Workflow — Iterative UX Development

## Overview

Orchestrates the full frontend development cycle with mandatory HITL gates.
Prevents the common mistake of coding UI before deciding WHERE it lives and HOW it integrates.

**Trigger**: Any task involving UI components, pages, visual features, or frontend work.

## Red Flags (rationalization check)

Before jumping to UI code, ask yourself — are any of these thoughts running? If yes, STOP. Architecture-first isn't a ceremony — it prevents rewriting the same UI 3x.

| Thought | Reality |
|---------|---------|
| "Just start coding the UI, decide location later" | Location (shared lib vs app) is architecturally irreversible. Decide BEFORE coding. |
| "I don't need a mockup, the design is obvious" | ASCII mockup forces explicit layout + data flow decisions. Free-form = ambiguity. |
| "Brainstorm phase for a button? Overkill" | UX convergence (reuse X or build new?) saves weeks of duplicate components. |
| "I'll put it in frontend/src/ for now, refactor later" | "For now" becomes "forever". Decide: shared lib (atlas-components) or app-specific. |
| "Data flow can be wired after the UI works" | Data-provider-first prevents prop-drilling refactors later. Wire before building. |
| "Type-check is fine, skipping visual review" | Visual review catches layout bugs type-check misses. Both gates are mandatory. |
| "Consumer wiring can wait" | Consumer plan (which apps use this?) drives where it lives. Decide upfront. |
| "This component is too small for the full workflow" | Small components accumulate — without workflow, you get 30 one-off variants. |

## The 6 Phases

```
1. BRAINSTORM   → Where? What reuse? Who consumes?  [HITL gate]
2. MOCKUP       → ASCII preview + data flow diagram  [HITL gate]
3. IMPLEMENT    → Build in correct location (shared lib or app)
4. WIRE         → Connect to consumer app (data provider + routing)
5. VALIDATE     → Type-check + build + visual review  [HITL gate]
6. CONSOLIDATE  → Exports, tests, docs, commit
```

## Phase 1: Brainstorm (invoke brainstorming skill)

**MANDATORY** — never skip this phase for UI work.

Ask via AskUserQuestion:

1. **Location**: Where does this component live?
   - `@axoiq/atlas-components/src/{section}/` → shared across apps
   - `frontend/src/pages/` or `frontend/src/components/` → Synapse-only
   - New app → standalone deployment

2. **Reuse audit**: Search for existing components that can be extended
   - Check atlas-components exports (`index.ts`)
   - Check existing pages/components in the consumer app
   - Present findings: "Found X similar component — extend or new?"

3. **Consumer plan**: Which apps will use this?
   - Synapse only → direct implementation
   - Multiple apps → shared library + data provider pattern
   - Present consumer wiring diagram

4. **Data flow**: How does data get to the component?
   - PlatformDataContext pattern (for platform admin)
   - AtlasDataContext pattern (for dev tooling)
   - Direct apiClient (for app-specific)
   - Props from parent (for leaf components)

## Phase 2: Mockup

Present ASCII mockup of the UI with:

```
┌─────────────────────────────────────────┐
│ Header               [Action Buttons]    │
├─────────────────────────────────────────┤
│                                          │
│  {Main content area with components}     │
│                                          │
│  ┌──────┐  ┌──────┐  ┌──────┐          │
│  │Card 1│  │Card 2│  │Card 3│          │
│  └──────┘  └──────┘  └──────┘          │
│                                          │
│  ┌────────────────────────────────────┐  │
│  │ Table / Grid                       │  │
│  │ Col1    Col2    Col3    Actions    │  │
│  │ ...     ...     ...     [Edit]    │  │
│  └────────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

Use AskUserQuestion with preview parameter to show mockup options.

Also show data flow:
```
Consumer App → DataProvider(apiClient) → SharedComponent → useQuery(provider.getX())
```

**HITL gate**: User approves mockup before any implementation.

## Phase 3: Implement

Build in the CORRECT location (decided in Phase 1):

### If shared library (@axoiq/atlas-components):
1. Create types in `src/types/{section}.ts`
2. Create DataContext in `src/{section}/{Section}DataContext.tsx`
3. Create components in `src/{section}/`
4. Add exports to `src/index.ts`

### If app-specific (Synapse):
1. Create types inline or in `src/types/`
2. Create components in `src/components/{section}/` or `src/pages/`
3. Use existing hooks pattern (TanStack Query)

### Rules:
- Hooks < 50 lines, components < 300 lines
- Use `syn-*` tokens for Synapse, raw Tailwind for shared
- Loading + Error + Empty states on EVERY view
- AG Grid for tables, modals for forms, drawers for detail panels
- TanStack Query v5 with queryOptions pattern

## Phase 4: Wire

Connect the component to its consumer:

### For shared library consumers:
1. Create consumer page (e.g., `PlatformPage.tsx`)
2. Create concrete DataProvider with apiClient mapping
3. Add route in App.tsx (TabRedirect pattern for Synapse)
4. Add to nav-config.ts (NavSection in appropriate group)
5. Add to WorkspaceView type union
6. Add to EditorArea.tsx (lazy import + case)

### Checklist:
- [ ] Route added (App.tsx)
- [ ] Navigation entry (nav-config.ts)
- [ ] Type union updated (useWorkspaceStore.ts, useAppStore.ts)
- [ ] EditorArea case added
- [ ] Data provider concrete implementation
- [ ] RBAC protection (ProtectedRoute if admin-only)

## Phase 5: Validate

**HITL gate**: Visual review before consolidation.

1. `bunx tsc --noEmit` — type-check passes
2. `bunx vite build` — build succeeds
3. Visual review:
   - Navigate to the new route in browser
   - Screenshot or describe the rendered UI
   - Ask user: "Does this match the mockup? Any adjustments?"

## Phase 6: Consolidate

1. **Tests**: Create vitest tests for new components
2. **Types**: Ensure all types are exported from index.ts
3. **Docs**: Update relevant .blueprint/ docs if needed
4. **Commit**: Conventional commit with scope

```
feat({scope}): {description}

{body — files created, patterns used, consumer wiring}
```

## Anti-Patterns (NEVER)

- Coding UI before deciding where it lives
- Building in Synapse when it should be shared
- Hardcoding API endpoints in shared components
- Skipping the mockup phase
- Building without type-check validation
- Creating components > 300 lines
- Using inline types instead of shared type files
- Forgetting to wire routing + nav for new pages

## Integration with Other Skills

| Phase | Skill |
|-------|-------|
| 1. Brainstorm | `brainstorming` (invoke) |
| 2. Mockup | `frontend-design` (invoke for aesthetics) |
| 3-4. Implement+Wire | `executing-plans` (if complex) |
| 5. Validate | `verification` (type-check + build) |
| 6. Consolidate | `finishing-branch` (commit + push) |
