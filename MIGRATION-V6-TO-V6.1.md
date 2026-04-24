# Migration Guide — atlas-plugin v6.0 → v6.1.0

**Release**: v6.1.0 "SOTA Workflow Library"
**Date**: 2026-04-24
**Scope**: 46 new workflow skills + session lifecycle + dashboard + CLI picker

## TL;DR

v6.1.0 is **100% additive** over v6.0.0. No breaking changes.
- All v6.0 skills, hooks, agents, commands remain functional.
- All v6.0 Iron Laws (TDD, DBG, DESIGN, VERIFY, PLAN, SCOPE, DISPATCH, COMPLIANCE, CONTEXT) preserved.
- Upgrade = install v6.1.0 package → new workflows + hooks + CLI features appear.

## What's New

### 1. Workflow Library (46 skills × 11 categories)

| Category | Count | Key workflows |
|----------|------:|---------------|
| Programming | 5 | code-change, feature, bug-fix, refactor, plugin-dev |
| Product & Vision | 5 | product-vision, product-roadmap, feature-discovery, client-alignment, pitch-narrative |
| UX / UI Design | 5 | ux-wireframe, ui-mockup, user-flow, design-review, prototype |
| Collaboration | 3 | brainstorm-collab, facilitate-decision, stakeholder-sync |
| Architecture | 4 | architecture, brainstorm-solo, spec-first, system-design |
| Planning | 5 | plan-large, plan-feature, sprint-plan, estimate, sprint-retro |
| Infrastructure | 5 | deploy, infra-change, network, security, incident-response |
| Research | 4 | research-deep, audit, debug-investigation, exploration |
| Documentation | 4 | doc-write, adr-log, retrospective, handoff |
| Data / Analytics | 3 | data-analysis, benchmark, cost-tracking |
| Meta | 3 | quality-gate, audit-ship, incident-postmortem |

Each workflow is an **orchestrator**: it chains existing atlas-plugin skills into enforced pipelines with `workflow_steps[]` + gates (MANDATORY / HARD_GATE / CONDITIONAL) + Iron Law references.

### 2. Three new Iron Laws

- **LAW-WORKFLOW-001**: NO_PUSH_WITHOUT_CI_VERIFY (root-cause fix of 2026-04-23 incident)
- **LAW-WORKFLOW-002**: TASK_FRAMING_BEFORE_CODE (no feature >1h without complexity assessment)
- **LAW-WORKFLOW-003**: FINISHING_BRANCH_BEFORE_PR (no PR without finishing-a-development-branch)

Each with SHA256-signed statement enforced by `hard-gate-linter.sh`.

### 3. Two new foundational skills

- **task-framing**: Complexity assessment (trivial/moderate/complex) driving downstream rigor
- **ci-feedback-loop**: Post-push CI polling until terminal state (Woodpecker API)

### 4. Six new hooks

- **post-git-push** (PostToolUse[Bash]): LAW-WORKFLOW-001 enforcement, logs `.claude/ci-audit.jsonl`
- **pre-git-push** (PreToolUse[Bash]): advisory checks (uncommitted, unresolved CI, force-push)
- **atlas-lock-acquire** (CLI helper): file-lock primary (O.3 revised from git-notes)
- **atlas-lock-release** (CLI helper): lock cleanup on pause/handoff
- **workflow-intent-detect** (UserPromptSubmit): maps natural language → workflow suggestion
- **ci-audit-log** (CLI helper): audit-trail helper for non-push events

### 5. Session lifecycle CLI

New `scripts/atlas-modules/session.sh` with 10 subcommands:

```bash
atlas session start [--intent "..."]   # pickup + lock + dashboard snapshot
atlas session pause                    # release lock, keep session open
atlas session handoff [--end-session]  # smart route (state-detector)
atlas session end-session              # alias for handoff --end-session
atlas session status                   # current workflow + pending gates
atlas session overview [--brief]       # multi-repo dashboard
atlas session who                      # cross-repo active locks
atlas session roadmap                  # plans in current project
atlas session audit                    # progress (stub)
atlas session dream                    # last dream cycles (stub)
```

### 6. Workflow CLI with escape hatches

Extended `scripts/atlas-modules/workflow.sh`:

```bash
atlas workflow list [--category X] [--priority P0]
atlas workflow show <name>
atlas workflow validate
atlas workflow skip <step> [reason]      # NEW — non-HARD_GATE only
atlas workflow abort [reason]            # NEW — clear active workflow
atlas workflow customize                 # NEW — stub for v6.1.x
```

### 7. New CLI picker + ops (Phase 8.5)

New `scripts/atlas-modules/picker.sh`:

```bash
atlas                    # interactive picker (RECENT + ALL)
atlas doctor             # ecosystem health check
atlas sweep [--execute]  # cleanup (dry-run default)
atlas who                # active work across all repos
```

### 8. dev.axoiq.com dashboard (Phase 8 MVP)

New 8th sidebar perspective "ATLAS" on dev-portal:
- `/atlas/overview` — stats (46/11/12/10) + P0 workflows spotlight + category breakdown
- `/api/atlas/workflows` — API route (seed data matching registry)
- 30s polling via React Query + shadcn/ui cards (CIDashboard pattern)

## How to Upgrade

### Automatic (plugin marketplace)

```bash
# In Claude Code:
/plugin update atlas-core
/plugin update atlas-dev
/plugin update atlas-admin
```

### Manual (from source)

```bash
cd ~/workspace_atlas/projects/atlas-plugin
git pull origin main
make dev  # syncs to ~/.claude/plugins/cache/atlas-marketplace/
```

### atlas-cli npm package

```bash
npm install -g @axoiq/atlas-cli@6.1.0
```

## How to Adopt Workflows

### Scenario 1: Programming task

Before v6.1 (ad-hoc):
```
User: "add a feature X"
Claude: [immediately starts coding]
```

After v6.1 (workflow-driven):
```
User: "add a feature X"
→ hooks/workflow-intent-detect fires
→ suggests: "💡 Intent detected: workflow-feature (programming, confidence 0.4)"
→ Claude invokes workflow-feature (9-step chain with Iron Laws)
  1. task-framing (MANDATORY)
  2-3. brainstorming + deep-research (parallelizable)
  4. plan-builder (MANDATORY, 15 sections if complex)
  5. tdd (MANDATORY)
  6. code-review (HARD_GATE)
  7. verification (HARD_GATE)
  8. finishing-branch (HARD_GATE)
  9. ci-feedback-loop (HARD_GATE)
```

### Scenario 2: Product vision for client

```
User: "let's build a product vision for G Mining Q2-Q4"
→ workflow-intent-detect → suggests workflow-product-vision
→ 5-step chain: deep-research → brainstorm-collab → vision-doc → decision-log → stakeholder-sync
→ Output: .blueprint/vision/2026-Q2.md + decision-log entries + stakeholder approval
```

### Scenario 3: Bug fix with reproducer

```
User: "button click doesn't work"
→ workflow-intent-detect → workflow-bug-fix
→ 7-step chain: task-framing → systematic-debugging → tdd (regression test FIRST) → code-review → verification → finishing-branch → ci-feedback-loop
```

## Persona Activation (per-project)

In your project's `.claude/rules/_meta.yaml`, activate categories per persona:

```yaml
workflow_activation:
  programming: [code-change, feature, bug-fix, refactor]    # engineers
  product: [product-vision, feature-discovery]              # PMs
  uxui: [ux-wireframe, ui-mockup, design-review]            # designers
  collab: [brainstorm-collab, facilitate-decision]          # all (HITL-heavy)
  infrastructure: [deploy, security]                         # devops
  planning: [plan-feature, sprint-plan]                      # daily-use
  docs: [retrospective, handoff, adr-log]                    # session lifecycle
```

## Breaking Changes

**NONE**. v6.1 is 100% additive.

## Deprecations

**NONE**. All v6.0 skills, hooks, agents preserved.

## Rollback

If you encounter issues:

```bash
# Via atlas-cli
atlas rollback v6.0.0

# Or manually
/plugin install atlas-core@6.0.11
/plugin install atlas-dev@6.0.11
# Restart Claude Code session
```

## Known Limitations (v6.1.0 scope)

- **Phase 7 polish deferred** (7 items → v6.1.x): ci-audit-digest daily cron, interactive-flow tiered reveal, session-pickup resume, auto-orchestrator intent mapping, intent accuracy corpus, HITL Gate 4 conversational approval, workflow-session-hint smart defaults
- **Phase 8 dashboard MVP** (3/17 tasks): remaining widgets (PR queue, HITL pending, audit trail chart, WebSocket) are v6.1.x polish
- **Phase 8.5 CLI MVP** (4/14 tasks): ink TUI deferred (atlas-cli is bash-first), remaining (shell completion, atlas map, pin/star, .atlasrc.yaml) are v6.1.x
- **cleanup-worktrees bug fix** shipped for future sessions but cached plugin still has bug until next marketplace update

## Post-Upgrade Verification

```bash
# Verify plugin version
atlas --version              # expect 6.1.0

# Verify new workflows
atlas workflow list --priority P0  # expect 10 P0 workflows across categories

# Verify new Iron Laws
grep "LAW-WORKFLOW-" ~/.claude/plugins/cache/atlas-marketplace/atlas-core/6.1.0/scripts/execution-philosophy/iron-laws.yaml

# Verify new hooks
ls ~/.claude/plugins/cache/atlas-marketplace/atlas-core/6.1.0/hooks/post-git-push
ls ~/.claude/plugins/cache/atlas-marketplace/atlas-core/6.1.0/hooks/workflow-intent-detect

# Run smoke tests
bats ~/.claude/plugins/cache/atlas-marketplace/atlas-core/6.1.0/tests/bats/test_workflow_library.bats
# expect: 31/31 PASS
```

## See Also

- Parent plan: `.blueprint/plans/le-plugin-atlas-core-devrais-adaptive-treasure.md` (1600+ lines, Sections M/N/O/P/Q)
- Task breakdown: `.blueprint/plans/v6.1-tasks.md` (103 atomic tasks)
- Handoff: `memory/handoff-2026-04-24-v6.1-phases-1-7-shipped.md`
- v6.0 migration: `MIGRATION-V5-TO-V6.md` (still applies for v5 → v6.1 direct upgrade)

---

**v6.1.0 is shipped to addressing the 2026-04-23 incident structurally.**
Push-without-CI-verify becomes impossible by default — Iron Law enforcement + hooks + workflows ensure the discipline at every layer.
