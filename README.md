# Atlas Dev — Enterprise Development Plugin for Claude Code

Full dev cycle plugin that replaces superpowers. Pipeline: DISCOVER → PLAN → IMPLEMENT → VERIFY → SHIP.

## Features

- **15-Section Plans** (A-O): Technical + Enterprise + Execution coverage
- **Quality Gate**: 12/15 minimum score before implementation
- **Context Discovery**: Auto-detect any tech stack (React, Vue, Django, Go, Rust, etc.)
- **Opus Ultrathink**: Plans always use the best model with maximum thinking
- **Living Plans**: Plans live in `.blueprint/plans/`, Git versioned, extend-not-replace
- **Forgejo-Native**: PR, CI, releases, worktrees integrated
- **Continuous Improvement**: Notes improvements, proposes SOTA upgrades
- **Task Lists**: Always track progress with TaskCreate/TaskUpdate
- **Visual Output**: ASCII diagrams, mockups, tables, emojis

## Installation

```bash
# From Forgejo (private)
claude plugins add https://forgejo.axoiq.com/atlas/atlas-dev-plugin.git

# From local directory
claude plugins add /path/to/atlas-dev-plugin

# Remove superpowers (if replacing)
claude plugins remove superpowers
```

## Usage

The plugin activates automatically at session start. Just talk to Claude:

```
"I want to add X to the system"     → Full pipeline activates
"Plan the Y subsystem"              → Plan builder with 15 sections
"Fix the bug in Z"                  → Debugging + TDD pipeline
"/atlas-dev feature 'description'"  → Explicit pipeline invocation
```

## Skills (13)

| Skill | Description |
|-------|-------------|
| `using-atlas-dev` | Master skill (auto-injected at session start) |
| `context-discovery` | 8-phase project scanner |
| `plan-builder` | 15-section plan generator |
| `brainstorming` | Collaborative design exploration |
| `tdd` | Test-driven development cycle |
| `systematic-debugging` | Structured debugging approach |
| `executing-plans` | Plan executor with subagents |
| `subagent-dispatch` | Sonnet subagent task dispatch |
| `git-worktrees` | Feature branch isolation |
| `finishing-branch` | PR + CI + cleanup |
| `verification` | Tests + E2E + security + perf |
| `scope-check` | Drift detection |
| `decision-log` | Architecture decision tracking |
| `session-retrospective` | End-of-session lessons |

## Agents (4)

| Agent | Model | Description |
|-------|-------|-------------|
| `plan-architect` | Opus | Plan generator with ultrathink |
| `plan-reviewer` | Sonnet | Quality gate scorer (12/15) |
| `code-reviewer` | Sonnet | Spec + quality review |
| `context-scanner` | Haiku | Fast context discovery |

## Project Customization

The plugin is generic. Customize per-project with:
- `.claude/rules/plan-quality.md` — Project-specific plan rules
- `.blueprint/PLAN-TEMPLATE.md` — Custom plan template
- `.blueprint/plans/INDEX.md` — Subsystem plans index
- `CLAUDE.md` — Project principles and constraints

## License

UNLICENSED — Private use only.
