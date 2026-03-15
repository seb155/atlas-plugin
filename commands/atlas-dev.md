# /atlas-dev — Enterprise Development Router

Route development work through the Atlas Dev pipeline.

## Usage
```
/atlas-dev                    # Auto-detect task type from context
/atlas-dev feature "desc"     # New feature
/atlas-dev refactor "desc"    # Refactoring
/atlas-dev bugfix "desc"      # Bug fix
/atlas-dev research "query"   # Deep research
/atlas-dev plan "subsystem"   # Generate/extend plan for subsystem
```

## Pipeline

Invoke the following skills in order based on task type:

### Feature / Refactor
1. **DISCOVER**: `context-discovery` skill → scan project
2. **PLAN**: `plan-builder` skill → 15 sections, Opus ultrathink, 12/15 gate
   - HITL GATE: user approves plan
3. **WORKTREE**: `git-worktrees` skill → isolated branch (if non-trivial)
4. **IMPLEMENT**: `executing-plans` or `subagent-dispatch` skill → TDD with Sonnet
5. **VERIFY**: `verification` skill → tests + E2E + security + perf
   - If fail → fix (max 2 attempts) → escalate
6. **SHIP**: `finishing-branch` skill → commit + PR + CI + cleanup

### Bugfix
1. **DISCOVER**: `context-discovery` skill
2. **DEBUG**: `systematic-debugging` skill → hypothesize → verify → fix
3. **PLAN**: `plan-builder` skill (bugfix variant — lighter)
4. **IMPLEMENT**: `tdd` skill → failing test for bug → fix → pass
5. **VERIFY**: `verification` skill
6. **SHIP**: `finishing-branch` skill

### Research
1. **DISCOVER**: `context-discovery` skill
2. **RESEARCH**: WebSearch + Context7 deep dive
3. **REPORT**: Present findings with recommendations

### Plan
1. **DISCOVER**: `context-discovery` skill
2. **PLAN**: `plan-builder` skill for specified subsystem
3. Save to `.blueprint/plans/{subsystem}.md`

## Non-Negotiable Rules

- Plans = Opus 4.6 ultrathink, max tokens
- Implementation = Sonnet 4.6 subagents
- TaskCreate at start, TaskUpdate throughout
- AskUserQuestion for ALL questions
- Quality gate 12/15 on all plans
- Max 2 fix attempts before escalating
- Visual output: ASCII diagrams, mockups, tables, emojis
