---
name: auto-orchestrator
description: "Intelligent meta-skill that analyzes intent, scores available skills, detects gaps, and chains optimal pipelines. The brain of ATLAS."
effort: low
inputs:
  intent: string
outputs:
  recommended_skills: list
  execution_plan: markdown
triggers:
  - "auto"
  - "atlas auto"
  - "what should I use"
  - "quel skill"
  - "comment faire"
  - "do the thing"
  - "fais-le"
  - "which skill"
  - "recommend"
---

# Auto-Orchestrator — ATLAS Meta-Skill

> Analyze user intent → score 89+ skills → detect gaps → chain optimal pipeline → execute with HITL gates.

## When to Use

- User doesn't know which skill to use
- User says "auto", "do the thing", "comment faire", "which skill"
- A task could be handled by multiple skills (need optimal routing)
- User wants ATLAS to figure out the best approach autonomously

## Pipeline (6 phases)

### Phase 1: Intent Analysis

Parse the user's request into structured intent:

```
INPUT: "nettoyer le repo et deployer en production"
PARSE:
  actions: [cleanup, deploy]
  targets: [repo (git), production (environment)]
  urgency: now
  scope: full-repo (not single branch)
```

If no argument provided (`/atlas auto` bare):
→ AskUserQuestion: "Qu'est-ce que tu veux accomplir?"

Context enrichment (automatic):
- `git status --short` → dirty files?
- `git worktree list` → stale worktrees?
- `git branch --merged` → stale branches?
- `git log --oneline dev --not main | wc -l` → divergence?

### Phase 2: Skill Scoring

Read `_metadata.yaml` (SSoT for all skills). Score each skill:

```
SCORE = trigger_match(0-40) + weight_bonus(0-20) + io_match(0-20) + context_fit(0-20)

trigger_match:  How many triggers overlap with intent keywords
weight_bonus:   Higher weight = more capable/tested skill
io_match:       Does the skill's input type match our context?
context_fit:    Does the skill make sense for current git/project state?
```

Filter: only skills with score > 40 are candidates.

Present top 3 matches via AskUserQuestion:

```
| # | Skill | Score | What it does |
|---|-------|-------|-------------|
| 1 | ship-all | 95 | Full repo: audit → cleanup → merge PRs → deploy all envs |
| 2 | finishing-branch | 45 | Single branch: commit → PR → merge |
| 3 | devops-deploy | 40 | Deploy only (no cleanup) |
```

### Phase 3: Chain Detection

If no single skill scores > 80%, build a chain:

```
INTENT: "brainstorm + implement + deploy"

CHAIN:
  1. brainstorming      (DISCOVER phase)
  2. plan-builder       (PLAN phase)
  3. executing-plans    (IMPLEMENT phase)
  4. verification       (VERIFY phase)
  5. ship-all           (SHIP phase)

AGENTS (optional):
  - plan-architect (Opus) for Phase 2
  - team-engineer (Sonnet) for Phase 3
```

Present chain via AskUserQuestion with estimated duration.

### Phase 4: Gap Detection

If no skill scores > 60% for any part of the intent:

```
❌ Gap detected: No skill covers "{unmatched_action}"

Available options:
  1. Create a new skill via /atlas skill-management
  2. Handle manually with guidance
  3. Skip this part
```

If user chooses to create:
→ Invoke `skill-management` with pre-filled specs from the intent analysis.

This creates a **flywheel**: every gap → new skill → plugin improves.

### Phase 5: Recommend

Present final recommendation via AskUserQuestion:

- **Option 1** (recommended): The top-scoring skill or chain
- **Option 2**: Alternative approach (different skills)
- **Option 3**: Manual with guidance

Include:
- Estimated time
- HITL gates that will trigger
- Files/systems that will be affected

### Phase 6: Execute

Invoke the chosen skill(s) using the Skill tool.

For chains: invoke sequentially, passing output from one to the next.
HITL gates from each sub-skill are preserved — the user approves at each step.

## Skill Catalog Reference

The orchestrator has access to the full catalog via `_metadata.yaml`:

| Category | Count | Key Skills |
|----------|-------|------------|
| Cognitive | 1 | idle-curiosity |
| Deploy | 3 | ci-management, devops-deploy, deploy-hotfix |
| Governance | 1 | enterprise-audit |
| Implementation | 5 | atlas-team, executing-plans, git-worktrees, subagent-dispatch, tdd |
| Infrastructure | 3 | infrastructure-change, infrastructure-ops, statusline-setup |
| Knowledge | 6 | deep-research, document-generator, knowledge, visual-generator, youtube-transcript |
| Meta | 19 | atlas-analytics/dev-self/doctor/onboarding, decision-log, hookify, memory-dream, platform-update, plugin-builder, scope-check, session-pickup/retrospective/spawn, skill-management, ultrathink |
| Optimize | 2 | engineering-ops, experiment-loop |
| Personal | 10 | episode-create, intuition-log, knowledge-builder, morning-brief/routine, note-capture, relationship-manager, reminder-scheduler, user-profiler, weekly-review |
| Planning | 7 | brainstorming, context-discovery, execution-strategy, frontend-design/workflow, plan-builder, vision-alignment |
| Project | 3 | feature-board, gms-mgmt, programme-manager |
| Quality | 8 | code-analysis, code-review, code-simplify, codebase-audit, plan-review, product-health, systematic-debugging, test-orchestrator, verification |
| Security | 2 | atlas-vault, security-audit |
| Ship | 2 | finishing-branch, ship-all |

## Agent Recommendations

When a skill benefits from a specialized agent:

| Skill | Recommended Agent | Model |
|-------|-------------------|-------|
| plan-builder | plan-architect | Opus |
| executing-plans | team-engineer | Sonnet |
| code-review | code-reviewer | Sonnet |
| security-audit | team-security | Sonnet |
| codebase-audit | context-scanner + team-reviewer | Haiku + Sonnet |

## Non-Negotiable Rules

1. **Adaptive confirmation** based on complexity (not always AskUserQuestion):
   - **TRIVIAL** (single skill, score > 90%): Auto-route, NO AskUserQuestion
   - **MODERATE** (single skill, score > 70%): Auto-route, NO AskUserQuestion
   - **COMPLEX** (multiple candidates, score < 70%, or chain needed): AskUserQuestion to confirm approach
   - **GAP** (no skill matches > 60%): ALWAYS AskUserQuestion
2. **Preserve HITL gates** from sub-skills — don't bypass them
3. **Log the decision** via decision-log skill (what was chosen and why)
4. **Gap flywheel**: every unmatched intent = opportunity to create a skill
5. **Don't over-chain**: if one skill covers 80%+, use it alone
6. **Context distillation**: when dispatching subagents, distill ~20K tokens focused prompt, never forward full session
