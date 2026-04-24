# AGENT.md Frontmatter Schema v6.0

> **Scope**: Normative schema for every `agents/*/AGENT.md` file in the ATLAS plugin.
> **Status**: v6.0 — ships with atlas-dev-plugin v6.0.0.
> **Authority**: See `.blueprint/plans/regarde-comment-adapter-atlas-compressed-wave.md` section D (SOTA effort table) + F (frontmatter extensions).
> **Updated**: 2026-04-17

---

## 1. Formal Schema (strict YAML)

```yaml
# ----- REQUIRED -----
name: string                       # kebab-case, matches directory
description: string                # 1 sentence <200 chars, describes what the agent is FOR
model: enum[opus|sonnet|haiku|claude-opus-4-7|claude-sonnet-4-6|claude-haiku-4-5]

# ----- REQUIRED in v6.0 -----
effort: enum[low|medium|high|xhigh|max|auto]
thinking_mode: enum[adaptive]      # only 'adaptive' in v6.0
version: semver-string

# ----- OPTIONAL (isolation + budget) -----
isolation: enum[worktree|none]     # Default 'none'. 'worktree' spawns git worktree per dispatch.
task_budget: integer               # Advisory token ceiling (output tokens). Omit for no cap.

# ----- OPTIONAL (tool governance) -----
disallowedTools: list[string]      # Glob patterns of MCP/tool names to block
allowedTools: list[string]         # If set, whitelist only (takes precedence over disallowedTools)

# ----- OPTIONAL (metadata) -----
tier: list[core|dev|admin]
emoji: single-glyph-string
```

### Enum specifications

| Key | Allowed values | Notes |
|---|---|---|
| `model` | `opus`, `sonnet`, `haiku` (CLI aliases) OR full ID `claude-opus-4-7`, `claude-sonnet-4-6`, `claude-haiku-4-5` | Full IDs recommended for reproducibility. |
| `effort` | `low`, `medium`, `high`, `xhigh`, `max`, `auto` | Defaults documented in SOTA table below. |
| `thinking_mode` | `adaptive` | `extended` rejected by `build.sh` in v6.0. |
| `isolation` | `worktree`, `none` | `worktree` requires `scripts/execution-philosophy/dispatch-worktree.sh` runtime. |
| `task_budget` | positive integer | Soft ceiling; emits warning at 80%, kill at 100%. |

---

## 2. SOTA Effort Allocation — 17 ATLAS Agents (v6.0)

Extracted from plan section D. Override per-agent frontmatter only with documented rationale in commit message.

| Agent | Model | `effort` default | `thinking_mode` | `isolation` | `task_budget` | Justification |
|---|---|---|---|---|---|---|
| plan-architect | claude-opus-4-7 | `max` | adaptive | none | 200000 | 15-section plans, ultrathink |
| systematic-debugging | claude-opus-4-7 | `xhigh` | adaptive | none | 120000 | Edge cases, root-cause hunt |
| code-reviewer | claude-opus-4-7 | `xhigh` | adaptive | worktree | 150000 | Multi-file security review, /ultrareview wrapper |
| infra-expert | claude-opus-4-7 | `xhigh` | adaptive | none | 100000 | GPU, net, Proxmox coordination |
| plan-reviewer | claude-sonnet-4-6 | `high` | adaptive | none | 80000 | Pattern-match on plan quality |
| team-engineer | claude-sonnet-4-6 | `high` | adaptive | worktree | 100000 | Complex implementation (UPGRADED) |
| team-security | claude-sonnet-4-6 | `high` | adaptive | none | 80000 | OWASP + multi-surface |
| data-engineer | claude-sonnet-4-6 | `high` | adaptive | none | 80000 | Schema, migrations |
| devops-engineer | claude-sonnet-4-6 | `high` | adaptive | none | 80000 | IaC + multi-system |
| experiment-runner | claude-sonnet-4-6 | `high` | adaptive | worktree | 80000 | Iteration loop |
| team-tester | claude-sonnet-4-6 | `medium` | adaptive | none | 60000 | Routine test writing |
| team-reviewer | claude-sonnet-4-6 | `medium` | adaptive | none | 60000 | Code quality pass |
| design-implementer | claude-sonnet-4-6 | `medium` | adaptive | none | 60000 | Mockup → React |
| domain-analyst | claude-haiku-4-5 | `medium` | adaptive | none | 40000 | ISA 5.1 classification |
| team-researcher | claude-haiku-4-5 | `medium` | adaptive | none | 40000 | Web synthesis |
| team-coordinator | claude-haiku-4-5 | `low` | adaptive | none | 20000 | Status polling |
| context-scanner | claude-haiku-4-5 | `low` | adaptive | none | 20000 | Stack detection |

### Allocation rules

- **Opus 4.7** default = `xhigh` (Anthropic-recommended). Upgrade to `max` for architecture/ultrathink only.
- **Sonnet 4.6** default = `high`. Downgrade to `medium` for pattern-match / routine tasks only.
- **Haiku 4.5** default = `medium`. Downgrade to `low` for read-only / polling tasks.
- `auto` = explicit opt-in for CLI router decision. Never silent default.
- Never hardcode `low`/`medium` on an Opus 4.7 agent without commit-message justification.

---

## 3. Three Canonical Examples

### 3.1 Opus agent — plan-architect (`max` effort, no isolation)

```yaml
---
name: plan-architect
description: "Ultra-detailed engineering plan builder. Opus 4.7 ultrathink. Runs context discovery, research, brainstorm, drafts 15-section plan, scores 12/15 gate."
model: claude-opus-4-7
effort: max
thinking_mode: adaptive
version: 6.0.0
isolation: none
task_budget: 200000
tier: [core, dev, admin]
emoji: "🏛️"
disallowedTools:
  - mcp__claude-in-chrome__*
  - mcp__plugin_playwright_playwright__*
---
```

**Rationale**: architecture work needs `max` reasoning. `isolation: none` because plans are documentation, not code mutations.

### 3.2 Sonnet agent — code-reviewer (`xhigh` effort + worktree isolation)

```yaml
---
name: code-reviewer
description: "Unified code review. Spec compliance → code quality (two-stage). Wraps /ultrareview. Opus-class reasoning for security + multi-file diffs."
model: claude-opus-4-7
effort: xhigh
thinking_mode: adaptive
version: 6.0.0
isolation: worktree
task_budget: 150000
tier: [core, dev, admin]
emoji: "🔎"
disallowedTools:
  - Write
  - Edit
---
```

**Rationale**: `isolation: worktree` spawns ephemeral worktree per review so the agent can checkout branches without contaminating the caller's tree. `disallowedTools: [Write, Edit]` enforces read-only review.

### 3.3 Haiku agent — team-researcher (`medium` effort, budget-capped)

```yaml
---
name: team-researcher
description: "Web search + docs synthesis. Haiku 4.5. Deep-research decomposition: 2-3 query angles, triangulate, summarize ≤500 words."
model: claude-haiku-4-5
effort: medium
thinking_mode: adaptive
version: 6.0.0
isolation: none
task_budget: 40000
tier: [core, dev]
emoji: "🔍"
disallowedTools:
  - Write
  - Edit
  - Bash
---
```

**Rationale**: Haiku agents are cheap — `medium` effort sufficient for synthesis. `task_budget: 40000` keeps costs predictable across many dispatch calls.

---

## 4. Migration Table v5.x → v6.0

| v5.x key | v6.0 behavior | Action |
|---|---|---|
| `name`, `description`, `model` | Unchanged | Keep |
| `effort` | Required — defaults per SOTA table | Add if missing |
| `thinking_mode` | **NEW** | Add `adaptive` |
| `isolation` | **NEW** optional | Add when agent does code mutations |
| `task_budget` | **NEW** optional | Add advisory ceiling |
| `disallowedTools` / `allowedTools` | Unchanged | Keep |
| `version` | **NEW** | Stamp `6.0.0` |

### Before/After example

**Before (`agents/devops-engineer/AGENT.md`):**

```yaml
---
name: devops-engineer
description: "CI/CD and deployment specialist. Sonnet agent."
model: sonnet
effort: medium
disallowedTools:
  - mcp__claude-in-chrome__*
---
```

**After (v6.0):**

```yaml
---
name: devops-engineer
description: "CI/CD and deployment specialist. Sonnet 4.6. Woodpecker CI, Docker builds, deploy pipelines."
model: claude-sonnet-4-6
effort: high
thinking_mode: adaptive
version: 6.0.0
isolation: none
task_budget: 80000
tier: [dev, admin]
emoji: "🚀"
disallowedTools:
  - mcp__claude-in-chrome__*
  - mcp__plugin_playwright_playwright__*
---
```

Note: `effort` upgraded `medium → high` per SOTA rule (Sonnet default = `high`).

---

## 5. Validation Rules

| Rule ID | Description | Enforcement |
|---|---|---|
| A1 | `name` matches directory | `build.sh` |
| A2 | YAML parses cleanly | `build.sh` |
| A3 | `model` ∈ enum | `build.sh` |
| A4 | `effort` ∈ enum | `build.sh` |
| A5 | `thinking_mode == adaptive` | `test_thinking_migration.bats` |
| A6 | `isolation == worktree` ⇒ runtime spawner available | `build.sh` lazy |
| A7 | `task_budget` positive int if present | `build.sh` |
| A8 | Effort default matches SOTA table unless commit justifies override | `test_effort_levels.bats` |

Exit codes of the AGENT linter mirror the SKILL linter (`0` pass, `2-5` block).

---

**Source of truth**: this file. `dispatch.sh` (Sprint 5, task 5.2) uses these enums verbatim.
