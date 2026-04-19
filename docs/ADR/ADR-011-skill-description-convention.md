# ADR-011: ATLAS Skill Description Convention

**Status**: Accepted
**Date**: 2026-04-19
**Deciders**: Seb Gagnon
**Source**: Benchmark 2026-04-19 (plan `joyful-hare`, Batch 1)
**Source repos**: anthropics/claude-plugins-official, obra/superpowers
**Supersedes**: None (no prior formal convention documented)
**Related**: ADR-008 (CSO audit, pending), ADR-009 (Red Flags retrofit, pending)

---

## Context

ATLAS ships 131 skills across three tiers (core=28, dev=36, admin=67). Audit of current `description` frontmatter reveals three inconsistent styles:

1. **Anthropic canonical** (e.g., `vision-alignment`):
   > "Strategic idea intake and roadmap integration. This skill should be used when the user says 'nouvelle idée', 'idea', 'feature request'..."

2. **Hybrid** (e.g., `self-propose`, `gms-onboard`):
   > "Self-improvement engine. Aggregates dream reports... Use when 'self-propose', 'improve yourself'..."

3. **Pure workflow summary** (e.g., `knowledge-builder`, `user-profiler`):
   > "Learn facts, preferences, relationships about the user. Confidence-based with reinforcement."
   > "Build and display the user's complete profile. Expertise map, interests, working style..."

Style 3 is a **CSO violation** (Claude Search Optimization, documented in obra/superpowers):

> "When a description summarizes the skill's workflow, Claude may follow the description instead of reading the full skill content. A description saying 'code review between tasks' caused Claude to do ONE review, even though the skill's flowchart clearly showed TWO reviews."

Source: `obra/superpowers/skills/writing-skills/SKILL.md:140-198`

Anthropic official documentation (`anthropics/claude-plugins-official/plugins/plugin-dev/skills/skill-development/SKILL.md:158-182`) requires:
- Third-person format
- "This skill should be used when..." framing
- Specific trigger phrases users would say

obra/superpowers (`writing-skills/SKILL.md`) requires:
- "Use when [triggering conditions]" framing
- No workflow summary
- Keyword coverage (error messages, symptoms, synonyms)

Both standards agree: **description must describe WHEN to use, NOT WHAT the skill does or HOW it works.**

Without a formal convention, ATLAS risks:
- Growing CSO violations as skill count expands (131 → 200+)
- Poor skill activation on natural language prompts
- Maintenance drift as contributors follow different styles

## Decision

ATLAS adopts a **hybrid convention** combining the strengths of both sources:

### Mandatory structure

```yaml
---
name: skill-name-kebab-case
description: "{PURPOSE_CLAUSE}. {TRIGGER_CLAUSE}"
effort: low | medium | high
---
```

### `{PURPOSE_CLAUSE}` — 1 sentence, ≤20 words

Identifies the skill's domain/goal. Answers "what is this skill for?"

Examples:
- ✅ "Strategic idea intake and roadmap integration."
- ✅ "Post-deploy G3 gate on dev/staging/prod."
- ✅ "Self-improvement engine from dream reports + retrospectives."
- ❌ "Aggregates dream reports, retrospectives, workflow analytics, and intuitions to propose system improvements." (too detailed — WHAT IT DOES not WHAT IT'S FOR)

### `{TRIGGER_CLAUSE}` — Anthropic canonical or obra shorthand

Two acceptable forms:

#### Form A — Anthropic canonical (preferred for user-facing skills)

> "This skill should be used when the user asks to '{phrase1}', '{phrase2}', '{phrase3}', or {contextual-trigger}."

Use when skill is invoked through user natural language (slash commands, chat requests).

Example (`vision-alignment`):
> "Strategic idea intake and roadmap integration. This skill should be used when the user says 'nouvelle idée', 'idea', 'feature request', 'what if', 'on devrait', 'cherry pick features', or arrives with a new task needing alignment with the mega plan."

#### Form B — obra shorthand (acceptable for meta/internal skills)

> "Use when {triggering condition or symptom}."

Use when skill is invoked automatically by other skills or by hooks/CI (not user-initiated via natural language). Shorter, less redundant.

Example (`scope-check`):
> "Scope drift detector. Use when touching files outside original task scope, before proceeding with changes."

### Forbidden patterns

1. ❌ **No workflow summary in description** — Claude will follow the summary and skip skill body. CSO rule.
2. ❌ **No first person** — "I help you..." — description injected into system prompt.
3. ❌ **No future tense or speculation** — "Will scan files..." — present tense imperative.
4. ❌ **No bullet lists in description** — single string, comma-separated phrases.
5. ❌ **Max 500 characters total** (name + description). Aligns with both standards.

### Style comparison table

| Source | Style | ATLAS decision |
|--------|-------|----------------|
| Anthropic official | "This skill should be used when..." + exact phrases | ✅ Form A (default) |
| obra/superpowers | "Use when..." + triggering conditions | ✅ Form B (shorthand) |
| ATLAS legacy (pure workflow) | "Learn facts, preferences..." | ❌ Violation — migrate |
| Industry (Vue/React docs) | "Provides X" / "Manages Y" | ❌ Violation |

## Consequences

### Positive

- **Skill activation reliability improves**: naive prompts trigger correct skill
- **CSO compliance**: Claude reads skill body instead of trusting description alone
- **Discoverability**: Form A's exact phrases are grep-optimized
- **Contributor guidance**: new skills follow clear rules, less review iteration
- **Audit baseline**: CSO audit (REC-002, ADR-008 pending) has target shape to enforce

### Negative

- **Migration cost**: 131 existing skills need audit + possibly rewrite (effort L, 30-40h — covered in REC-002)
- **Minor length inflation**: exact phrases add characters; must stay under 500 char budget
- **Hybrid rules = more nuance**: contributors need to understand Form A vs B contexts

### Risks

- **Drift**: without enforcement lint, new skills may slip into Style 3
  - *Mitigation*: add `validate-skill-frontmatter.sh` lint script (REC-013 scope expansion)
- **Over-formulaic descriptions**: if all skills use identical "This skill should be used when..." opener, LLM may desensitize
  - *Mitigation*: encourage varied opening verbs in PURPOSE_CLAUSE

## Alternatives considered

### A1 — Pure Anthropic official (no shorthand)

Rejected: creates verbose descriptions for meta/internal skills that never get user-triggered. Form B exists for internal skills where "This skill should be used when the user asks to..." is nonsensical.

### A2 — Pure obra "Use when..." (no enumeration)

Rejected: loses keyword coverage. Anthropic's exact-phrase enumeration measurably improves Claude's skill selection on near-match prompts.

### A3 — No formal convention (status quo)

Rejected: 131 skills already drifting into 3 styles. Without convention, drift accelerates. Skill quality gates (REC-001 eval framework) become harder to interpret.

### A4 — Machine-generated from skill body (LLM description writer)

Rejected: introduces circular dependency (skill body shapes description, description shapes skill activation). Also non-deterministic — same skill body → different descriptions across CI runs.

## Implementation path

- [ ] **Phase 1 (this ADR, completed)**: document convention in `docs/ADR/ADR-011-*`
- [ ] **Phase 2 (REC-013 expansion, ~3-5h)**: add `scripts/validate-skill-frontmatter.sh` — lint current description format
- [ ] **Phase 3 (REC-002 plan, ~30-40h)**: audit 131 skills against this ADR — categorize (Conform/Hybrid/Violation), migrate violations
- [ ] **Phase 4 (REC-001 plan, ~12-20h)**: skill-triggering eval framework (port obra `tests/skill-triggering/`) validates description quality on naive prompts
- [ ] **Ongoing**: new skills added via `plugin-builder` / `skill-management` MUST follow Form A or B. Lint blocks non-conforming.

## References

- obra/superpowers `skills/writing-skills/SKILL.md:140-198` — CSO rule origin, evidence-based
- anthropics/claude-plugins-official `plugins/plugin-dev/skills/skill-development/SKILL.md:158-182` — third-person + phrases
- ATLAS benchmark report 2026-04-19 §Per-repo Analysis #1 (obra/superpowers Force 1), #2 (anthropics Force 1)
- ATLAS benchmark matrix 2026-04-19 (REC-011)

---

*ADR authored 2026-04-19 by ATLAS (Opus 4.7) as part of plan `joyful-hare`. Accepted by Seb Gagnon 2026-04-19 via direct execution approval.*
