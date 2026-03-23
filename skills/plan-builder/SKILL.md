---
name: plan-builder
description: "Generate ultra-detailed 15-section engineering plans (A-O) with quality gate 12/15. Replaces superpowers:writing-plans. Uses context discovery report to pre-fill enterprise sections."
effort: high
---

# Plan Builder

**Model**: ALWAYS Opus 4.6, max thinking effort, max output tokens. Never truncate.
**Announce:** "Building engineering plan using Atlas Dev plan-builder..."

## Workflow

| Step | Action | HITL |
|------|--------|------|
| 1. Load | Read context discovery report + `.blueprint/plans/INDEX.md`. Extending? Load existing plan. Load `.blueprint/PLAN-TEMPLATE.md` | - |
| 2. Research | WebSearch (2026+ best practices) + Context7 (lib docs) → feed Section C | - |
| 3. Brainstorm | AskUserQuestion with 2-3 approaches + comparison table | YES |
| 4. Draft | Fill all 15 sections (see below). N/A sections get 1-line justification | - |
| 5. Quality Gate | Score 15 criteria (gate >= 12/15). If < 12: enrich weak sections, max 2 iterations | - |
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

## Quality Gate (15 criteria, gate >= 12)

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
