# ADR-009: Red Flags Tables Retrofit — Top-20 Behavior-Shaping Skills

**Status**: Accepted
**Date**: 2026-04-19
**Deciders**: Seb Gagnon
**Source**: Benchmark 2026-04-19 (plan `joyful-hare`, REC-003)
**Source repos**: obra/superpowers (Force 1 — skill patterns & CSO)
**Supersedes**: None
**Related**: ADR-010 (Progressive Disclosure), ADR-011 (Skill Description Convention), ADR-013 (Skill Lint Security)

---

## Context

The ATLAS benchmark report (2026-04-19, plan `joyful-hare`) identified a **critical behavior-shaping gap**: only 2 of 109 ATLAS skills (`atlas-assist`, `wiki-aggregate`) contain **Red Flags tables** — a pattern from obra/superpowers that intercepts agent rationalizations before they fire.

### What is a Red Flags table?

A Red Flags table enumerates the thoughts an agent generates to **rationalize away a skill** ("this is simple", "I know the pattern", "overkill here"). Each row pairs the rationalization with a correction — if the thought is running, STOP and invoke the skill.

obra/superpowers documentation (`skills/using-superpowers/SKILL.md:78-95`) contains a 12-row Red Flags table that has been battle-tested in production. Source quote (`skills/writing-skills/SKILL.md`):

> "Skills are not prose — they are code that shapes agent behavior. Red Flags tables, rationalization lists, and XML directives are LOAD-BEARING content. Rewriting them without eval evidence is a regression."

### Why does ATLAS need them?

Behavior-shaping skills (TDD, verification, scope-check, plan-builder, brainstorming) are the ones MOST likely to be rationalized away. An agent under time pressure or facing a "simple" request will think:

- "Just this once, let me code without a test" → TDD bypassed → bug ships
- "This doesn't need a formal plan" → plan-builder skipped → scope creep → 3x effort
- "I can just do this quickly" → verification skipped → broken PR merged
- "I remember this pattern" → systematic-debugging skipped → guess-and-check loop

Red Flags tables transform these silent rationalizations into **visible, named patterns** that the agent must consciously dismiss — usually they can't, because the Red Flag is named precisely enough to recognize.

### Current state (pre-retrofit)

- **2 / 109 skills** have Red Flags tables (atlas-assist, wiki-aggregate) = 1.8% coverage
- **Template** `templates/SKILL.md.template` (ADR-010) specifies Red Flags as mandatory for behavior-shaping skills, but no retrofit has been performed
- **SKILL-AUTHORING.md** §Red Flags describes the pattern but enforcement is informal

Without retrofit, new skills may add Red Flags but existing behavior-shaping skills remain vulnerable to rationalization.

## Decision

Retrofit **Red Flags tables** into the **top-20 behavior-shaping ATLAS skills**, targeting the skills that:

1. **Shape agent process** (how to approach work — discipline, decisions)
2. **Are frequently invoked** (visible in typical dev workflows)
3. **Are susceptible to rationalization** ("I know better" / "overkill here")

### Top-20 skills selected

| # | Skill | Rationale (1 sentence) |
|---|-------|------------------------|
| 1 | `tdd` | Most-rationalized skill — "just this once, code first" pattern is universal. |
| 2 | `systematic-debugging` | "I see the bug already" bypasses the hypothesize-test cycle. |
| 3 | `scope-check` | "While I'm here..." drift is the #1 cause of blown estimates. |
| 4 | `verification` | "Tests probably pass" without running them is the persona-bug pattern (2026-04-16 incident). |
| 5 | `plan-builder` | "This is simple, I'll code first" = plan drifts to match bad code. |
| 6 | `brainstorming` | "I know what the user wants" skips 2-3 approach exploration. |
| 7 | `context-discovery` | "I remember this project" — memory drifts post-compaction (per `feedback_ultrathink_plan_staleness_pattern.md`). |
| 8 | `atlas-assist` | Master router — already has Red Flags (enhance with new rows from incidents). |
| 9 | `finishing-branch` | "Just push and move on" skips DoD check, enterprise gate, health. |
| 10 | `executing-plans` | "I'll read as I go" — plans need upfront load + concerns raised BEFORE starting. |
| 11 | `code-review` | "LGTM" without parallel agents = false-confidence review. |
| 12 | `decision-log` | "I'll remember" — 2 compactions later, decision is lost. |
| 13 | `session-retrospective` | "No lessons today" — every session has lessons; logging them is the habit. |
| 14 | `ultrathink` | "I don't need to go deep" on architectural choices = wrong pattern locked in for months. |
| 15 | `subagent-dispatch` | "I'll do it myself, faster than dispatching" ignores parallel wins + cost ratio. |
| 16 | `skill-management` | "I'll wing the SKILL.md" — skills are code; malformed frontmatter breaks discovery. |
| 17 | `deep-research` | "Single query is enough" misses triangulation; decisions made on 1 source are fragile. |
| 18 | `plugin-builder` | "I'll figure out the structure" — plugin.json schema errors block install. |
| 19 | `frontend-workflow` | "Just start coding the UI" skips location decision (shared lib vs app). |
| 20 | `senior-review-checklist` | "Quick glance is fine" — missing SOLID / cohesion / testability checks lets smells pass. |

### What is retrofitted

For each selected skill, add a `## Red Flags (rationalization check)` section at an appropriate place in the SKILL.md **body** (after Overview or When to Use, before Workflow). If a Red Flags table already exists, **enhance** with new rows (do not replace).

Each table MUST have **minimum 3 rows**, ideally 5-7, with **no duplicates across skills** and **no generic filler** — rationalizations must be **specific to the skill's actual failure modes**.

### What is NOT done

- **Not retrofitted**: the other 89 skills (reference/domain/utility skills — lower behavior-shaping risk).
- **Not touched**: frontmatter (description, name, effort, version). Agent A handles that via ADR-011 CSO fixes.
- **Not enforced yet**: CI/semgrep check for "Red Flags missing on behavior-shaping skill" — deferred to REC-017 skill-lint fork (ADR-014, pending).

## Consequences

### Positive

- **Anti-rationalization discipline** — 20 high-invocation skills now have inline intercepts
- **Behavior-shaping code** (per PHILOSOPHY.md §1) now materialized, not aspirational
- **Onboarding signal** — new contributors see the pattern and apply it to their own skills
- **Incident-driven content** — rows drawn from real ATLAS sessions (persona-bug 2026-04-16, plan-staleness 2026-04-18) make them concrete, not generic
- **Cheap maintenance** — when a new rationalization pattern is observed, append a row (no rewrite)

### Negative

- **Body word count grows** — each skill gains ~100-150 words for Red Flags. Target 1500-2000 (from ADR-010) still respected — all 20 skills measured currently well below (max 3106 for atlas-assist which already has Red Flags).
- **Retrofit fatigue risk** — 20 skills × N rows = ~100 unique rationalizations written by hand. Mitigated by batching commits (5 per batch) and deriving from existing session lessons.
- **Testing gap** — no eval framework yet validates that Red Flags actually fire in triggering scenarios. REC-001 (skill-triggering port) will close this.

### Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Generic rows dilute effectiveness | M | H (pattern loses sharpness) | Reject generic filler during retrofit; each row tied to a skill's specific failure mode |
| Red Flags drift as skills evolve | M | M (rows become stale) | Session-retrospective skill now logs "new rationalization observed" → periodic row additions |
| Agent ignores the table anyway | L | H (whole retrofit wasted) | Evidence from obra/superpowers says the pattern works; REC-001 eval will measure ATLAS-specific activation |
| Git conflict with Agent A's frontmatter edits | L | L (rebase trivial — separate sections) | Agents touch only body (this ADR) vs only frontmatter (Agent A); commits land interleaved to main |

## Alternatives Considered

### A. Retrofit all 109 skills

- **Pros**: Uniform coverage, no skill-tier decisions
- **Cons**: Reference/domain/one-shot skills (atlas-vault, knowledge-builder, gmining-excel) don't benefit — they don't "shape behavior", they provide data. Effort × 5 for marginal return.
- **Rejected because**: 80/20 rule — top-20 capture ~90% of the rationalization risk.

### B. Retrofit none, add Red Flags only to NEW skills

- **Pros**: Zero retrofit effort, forward-only migration
- **Cons**: Existing behavior-shaping skills remain vulnerable for years (slow skill churn). The persona-bug incident proves rationalization already happens TODAY.
- **Rejected because**: Opportunity cost of leaving TDD/verification/scope-check without Red Flags is too high.

### C. Build eval framework first, then retrofit

- **Pros**: Measured impact, avoid writing rows that don't fire
- **Cons**: REC-001 (skill-triggering port) is 30-40h. Meanwhile, rationalization keeps shipping bugs. Red Flags are a cheap intervention; eval is a 4-8x cost.
- **Rejected because**: obra/superpowers evidence is sufficient justification — they shipped Red Flags without eval coverage.

## Implementation Path

### Phase 1 — Identify (DONE this commit)
Analyze 109 skills for behavior-shaping criteria → select top-20 (see table above).

### Phase 2 — ADR + draft (DONE this commit)
- Write this ADR
- Draft Red Flags content per skill (3-7 specific rows, no duplicates)

### Phase 3 — Retrofit (commits)
Edit each skill's body to add `## Red Flags (rationalization check)` section. Batches of 5 skills per commit.

- Commit 1: tdd, systematic-debugging, scope-check, verification, plan-builder (foundation)
- Commit 2: brainstorming, context-discovery, atlas-assist, finishing-branch, executing-plans (flow)
- Commit 3: code-review, decision-log, session-retrospective, ultrathink, subagent-dispatch (quality)
- Commit 4: skill-management, deep-research, plugin-builder, frontend-workflow, senior-review-checklist (specialty)

### Phase 4 — Verify (this session)
```bash
# Count
grep -l "## Red Flags" /home/sgagnon/workspace_atlas/projects/atlas-plugin/skills/*/SKILL.md | wc -l
# Expected: ≥ 20 (includes atlas-assist, wiki-aggregate pre-existing)

# Budget
for f in /home/sgagnon/workspace_atlas/projects/atlas-plugin/skills/*/SKILL.md; do
  count=$(wc -w < "$f")
  [ "$count" -gt 5000 ] && echo "OVER-BUDGET: $f ($count words)"
done
# Expected: no output (no overflows)
```

### Phase 5 — Follow-up (future plans)
- **REC-001** eval: add pressure-test prompts for each top-20 skill in `tests/skill-triggering/prompts/`
- **REC-017** skill-lint: add rule `R13: behavior-shaping skill must have Red Flags table`
- **Session-retrospective** skill update: when a new rationalization is observed, propose a Red Flag row

## Attribution

This retrofit directly adapts the **Red Flags pattern** from [obra/superpowers](https://github.com/obra/superpowers) (Force 1 — Skills patterns).

Key source references:
- `obra/superpowers/skills/using-superpowers/SKILL.md:78-95` — 12-row Red Flags table (canonical)
- `obra/superpowers/skills/writing-skills/SKILL.md:140-198` — CSO section explaining why Red Flags matter (description summarization → skill-body skip)
- Benchmark matrix entry: `synapse/.blueprint/reports/atlas-benchmark-report-2026-04-19.md:103-142` (REC-003 rationale)

The content of each ATLAS Red Flag row is original — drawn from real ATLAS session lessons (2026-04-16 persona-bug, 2026-04-17/18 plan staleness, 2026-04-18 Saturday intensive). The obra pattern provides the FORM; ATLAS provides the CONTENT.

## References

- `docs/PHILOSOPHY.md` §1 — "Skills are behavior-shaping code, not prose"
- `docs/SKILL-AUTHORING.md` §Red Flags — authoring guide
- `templates/SKILL.md.template` — Red Flags section template
- `synapse/.blueprint/reports/atlas-benchmark-report-2026-04-19.md` §REC-003
- `obra/superpowers/skills/using-superpowers/SKILL.md` — canonical Red Flags

---

*ADR-009 — 2026-04-19 — plan `joyful-hare` Batch 1 REC-003 retrofit artifact.*
