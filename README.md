# ATLAS — AXOIQ's Unified AI Engineering Assistant

ONE plugin to replace them all. Auto-routing co-pilot with strategic HITL gates.

## What ATLAS Replaces

- 18 Claude Code plugins (superpowers, feature-dev, code-review, frontend-design, hookify, etc.)
- 10 `/a-*` global commands
- 26 global skills

## Features

- **Auto-Routing**: `using-atlas` master skill detects context and invokes the right workflow
- **16 Subcommands**: dev, tune, review, design, verify, ship, research, present, eng, estimate, context, hooks, simplify, browse, skill, and session management
- **HITL Co-Pilot**: AskUserQuestion gates at every strategic decision point
- **25 Skills**: Planning, TDD, debugging, review, design, optimization, research, and more
- **6 Agents**: plan-architect (Opus), plan-reviewer, code-reviewer, context-scanner (Haiku), experiment-runner, design-implementer (Sonnet)
- **15-Section Plans** (A-O): Quality gate 12/15 minimum
- **`/atlas tune`**: Autonomous optimization loop (inspired by Karpathy's autoresearch)
- **Model Strategy**: Opus 4.6 (plans) → Sonnet 4.6 (implementation) → Haiku 4.5 (triage)

## Installation

```bash
# From Forgejo (private)
claude plugins add https://forgejo.axoiq.com/atlas/atlas-plugin.git

# From local directory
claude plugins add /path/to/atlas-plugin

# Remove old plugins (superpowers, feature-dev, etc.)
claude plugins remove superpowers
```

## Usage

The plugin activates automatically at session start. Just talk naturally:

```
"I want to add X to the system"      → brainstorming → plan-builder → tdd
"Fix the bug in Z"                    → systematic-debugging → tdd
"Review this code"                    → code-review skill
"Optimize the rules"                  → experiment-loop (autoresearch)
"Ship it"                             → finishing-branch skill
"/atlas dev feature 'description'"    → Explicit pipeline invocation
"/atlas tune rule-engine"             → Explicit experiment
```

## Subcommands (16)

| Category | Command | Description |
|----------|---------|-------------|
| **BUILD** | `/atlas dev` | Feature/bugfix/refactor pipeline |
| | `/atlas design` | Frontend UI/UX from specs |
| | `/atlas browse` | Browser automation / E2E |
| | `/atlas eng` | Engineering maintenance |
| **QUALITY** | `/atlas review` | Code review |
| | `/atlas pr-review` | PR review |
| | `/atlas verify` | Quality gates + security |
| | `/atlas simplify` | Code refactoring |
| **OPTIMIZE** | `/atlas tune` | Autonomous optimization |
| | `/atlas estimate` | I&C estimation pipeline |
| **SHIP** | `/atlas ship` | Commit & push |
| | `/atlas end` | Session close |
| | `/atlas handoff` | Session handoff |
| **KNOWLEDGE** | `/atlas research` | Deep research |
| | `/atlas present` | Document generation |
| **META** | `/atlas context` | Context audit |
| | `/atlas hooks` | Create hooks |
| | `/atlas skill` | Create/improve skills |

## Project Customization

The plugin is generic. Customize per-project with:
- `.claude/rules/` — Project-specific rules (plan quality, code quality, UX)
- `.blueprint/plans/` — Subsystem plans (Git versioned)
- `.claude/assay/experiments.yaml` — Experiment definitions for `/atlas tune`
- `CLAUDE.md` — Project principles and constraints

## License

UNLICENSED — Private use only. AXOIQ property.
