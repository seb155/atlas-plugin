---
name: plan-builder
description: "Generate ultra-detailed 15+5 section engineering plans (A-O + execution strategy) with quality gate 16/20. Replaces superpowers:writing-plans. Uses context discovery report to pre-fill enterprise sections."
effort: high
---

# Plan Builder

**Model**: ALWAYS Opus 4.7, max thinking effort, max output tokens. Never truncate.
**Announce:** "Building engineering plan using Atlas Dev plan-builder..."

## Workflow

| Step | Action | HITL |
|------|--------|------|
| 1. Load | Read context discovery report + `.blueprint/plans/INDEX.md`. Extending? Load existing plan. Load `.blueprint/PLAN-TEMPLATE.md`. Check `.blueprint/designs/` for design docs (see Design Doc Integration below) | - |
| 2. Research | Objective research: factual questions only, NO intent in Explore prompts (see Research Objectivity below). WebSearch (2026+) + Context7 (lib docs) → feed Section C | - |
| 3. Brainstorm | AskUserQuestion with 2-3 approaches + comparison table | YES |
| 4. Draft | Fill all 15 sections (see below). N/A sections get 1-line justification | - |
| 4.5 Exec Strategy | For plans > 10 tasks: add execution strategy sections (task types, model alloc, parallelism, cost) | - |
| 5. Quality Gate | Score 20 criteria (gate >= 16/20). If < 16: enrich weak sections, max 2 iterations. Legacy /15 plans: gate >= 12/15 | - |
| 6. Save | `.blueprint/plans/{subsystem}.md` + update INDEX.md + present score. Wait: "go" or "change X" | YES |

## 15 Sections (A-O)

### Core (A-G)

| # | Section | Content |
|---|---------|---------|
| 🔍 A | VISION | WHY + problem + solution + personas + engineering chain impact |
| 📦 B | INVENTAIRE | Current files, tables, configs, hooks to reuse |
| 🏗️ C | ARCHITECTURE | Mermaid diagram + sourced decisions (Context7/WebSearch) |
| 💾 D | DB SCHEMA | CREATE/ALTER TABLE + indexes + Alembic migration |
| ⚙️ E | BACKEND | Service classes, method signatures, before/after for refactors |
| 🔌 F | API | Endpoints table: method, path, auth, request, response, errors |
| 🖥️ G | FRONTEND UX | Mermaid/ASCII mockup + components + hooks + UX convergence |

### Enterprise (H-L)

| # | Section | Content |
|---|---------|---------|
| 🎭 H | PERSONA IMPACT | Matrix: persona x impact x capability x UX x RBAC x test scenario |
| 🔒 I | SECURITY | RBAC table + OWASP checklist + data sensitivity |
| 🤖 J | AI-NATIVE | API for AI agents + structured logging + metrics + health |
| 🖥️ K | INFRASTRUCTURE | Hardware table + perf targets + cache + scaling strategy |
| ♻️ L | REUSABILITY | Multi-company + multi-discipline + config points (YAML import) |

### Execution (M-O)

| # | Section | Content |
|---|---------|---------|
| 📋 M | TRACEABILITY | Audit trail (who/when/what) + versioning + derivation tracking |
| 📅 N | PHASES | Table: phase, content, files, duration, dependencies. Mermaid gantt. |
| ✅ O | VERIFICATION | Backend + frontend + E2E persona + DB + perf + security commands |

## Design Doc Integration

When `.blueprint/designs/{feature}.md` exists (produced by brainstorming skill):

1. **Load** the design doc as pre-resolved context
2. **Pre-fill sections** from design doc content:
   - "Resolved Decisions" → Section A (Vision), Section C (Architecture)
   - "Patterns Found" → Section B (Inventory) — reusable code, anti-patterns to avoid
   - "Phase Sketch" → Section N (Phases) — follow the vertical structure as baseline
   - "Constraints" → Sections H-L (Enterprise)
3. **Resolve "Open Questions"** — research or ask user for remaining unknowns
4. **Do NOT re-ask** questions already resolved in the design doc
5. If no design doc found → proceed normally (brainstorming may not have been run)

## Research Objectivity

When launching Explore agents or sub-agents for research (Step 2):

**Rule**: Research agents must NOT know what feature is being built. They gather FACTS only.

**2-phase approach**:
1. **Generate research questions** (with ticket context): Frame as factual questions
   - GOOD: "How does the endpoint routing work in `backend/routes/`?"
   - GOOD: "What tables and indexes exist for the `instruments` domain?"
   - GOOD: "Trace the data flow from import CSV to material_catalog table."
   - BAD: "How should we implement the new spline feature?"
   - BAD: "What's the best approach for adding tenant filtering?"
2. **Send only questions** to Explore agents — exclude ticket, feature name, and user intent

**Opinion detection** (post-research): Scan research output for opinion words: "should", "recommend", "suggest", "better to", "consider using", "I think". If found → flag to user as potentially contaminated research, but don't block.

## Vertical Plan Constraint (Section N)

Each phase in Section N MUST be an independently testable end-to-end slice:
- Each phase touches at least 2 layers (e.g., DB+API, or API+FE)
- Each phase has a test checkpoint command (how to verify it works)
- **Anti-pattern**: 3+ consecutive same-layer phases (all DB → all API → all FE = HORIZONTAL, reject)
- If a Phase Sketch exists in the design doc, use it as the structural baseline

## Quality Gate (20 criteria, gate >= 16)

### Core Criteria (1-15) — same as before

| # | 1 pt if... | # | 1 pt if... |
|---|-----------|---|-----------|
| 1 | Vision explains WHY + chain impact | 9 | AI-native described |
| 2 | Inventory lists code + reusable hooks | 10 | Infra + perf targets |
| 3 | Architecture has diagram + sourced decisions | 11 | Reusability explained |
| 4 | Full-stack D+E+F+G present | 12 | Traceability + audit trail |
| 5 | Personas with test scenarios | 13 | Phases with files listed |
| 6 | UX convergent (refs ux-rules) | 14 | E2E verification with commands |
| 7 | Research done (Context7/WebSearch) | 15 | Patterns reused (refs existing code) |
| 8 | Security + RBAC covered | | |

### Execution Strategy Criteria (16-20) — NEW

| # | 1 pt if... |
|---|-----------|
| 16 | **Task Classification**: Each task in Section N has a type (architecture/implementation/testing/validation/lint/search) |
| 17 | **Parallelization**: Independent task groups identified with justification (no shared files/deps) |
| 18 | **Model Allocation**: Opus/Sonnet/Haiku/DET assigned per task with rationale (not "all Opus") |
| 19 | **Coordination Plan**: Dependency DAG documented, critical path identified, HITL gates placed |
| 20 | **Cost Estimate**: Token budget per model tier with total and vs-all-Opus comparison |

### Scoring Rules

- **New plans (2026-03-27+)**: Score on /20. Gate >= 16/20.
- **Legacy plans (pre-2026-03-27)**: Score on /15. Gate >= 12/15. Remain valid.
- **Plans < 10 tasks**: Criteria 16-20 optional (mark N/A with justification). Gate remains 12/15.
- **Plans >= 10 tasks**: Criteria 16-20 required. Gate >= 16/20.
- **Migration**: Existing plans do NOT need retroactive update. Only new/extended plans use /20.

## Plan Types (section depth by type)

| Section | Feature | Refactor | Bugfix |
|---------|---------|----------|--------|
| A-B | FULL | FULL | FULL (root cause) |
| C | FULL | LITE (diff) | N/A |
| D-F | IF applicable | IF applicable | N/A |
| G | FULL | LITE | IF applicable |
| H-L | FULL | LITE | N/A (except security) |
| M-O | FULL | FULL | FULL |

## Diagrams

Use **Mermaid** (preferred) for architecture (`graph TD`), phases (`gantt`), data flow (`sequenceDiagram`). Dashboard renders via MarkdownRenderer + Mermaid v11. Tables = GFM markdown.

## Extending Existing Plans

Load full plan → update relevant sections only → keep untouched intact → re-score → git diff shows changes.

## Commit

`plan({subsystem}): {description}`

## Mega Plans (`/atlas plan --mega`)

When `--mega` flag detected OR user says "programme", "mega plan", "multi-plan":

1. Switch to `templates/MEGA-PLAN-TEMPLATE.md` (M1-M16) instead of A-O format
2. Read `.blueprint/plans/INDEX.md` to discover existing sub-plans
3. For each sub-plan found: extract Section A (vision) + dependencies + effort
4. Auto-generate M2 Sub-Plan Registry from discovered sub-plans
5. Build M3 Dependency Graph (Mermaid + ASCII) from sub-plan dependencies
6. Calculate M6 Critical Path (longest weighted path through DAG)
7. Populate M5 Phase Timeline from existing mega plan phases
8. Score against 16 criteria (gate >=10/16)
9. Verify bidirectional links: every sub-plan references mega, mega references every sub-plan

**Quality gate**: 10/16 for programme + ALL sub-plans >= 12/15 individually.

**Output**: Save to `.blueprint/plans/{adjective-verb-noun}.md` (same naming convention).
