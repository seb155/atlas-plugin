# ADR-010: Progressive Disclosure — 3-Level Skill Loading

**Status**: Accepted
**Date**: 2026-04-19
**Deciders**: Seb Gagnon
**Source**: Benchmark 2026-04-19 (plan `joyful-hare`, Batch 1)
**Source repo**: anthropics/claude-plugins-official (`plugins/plugin-dev/skills/skill-development/SKILL.md:77-85`)
**Related**: ADR-011 (description convention — Level 1 of PD), ADR-007 (eval framework — validates PD triggers), SKILL-AUTHORING.md

---

## Context

ATLAS skills currently mix content without structured loading discipline. Symptoms observed:
- Some SKILL.md files exceed 3,000 words (bloat attention budget)
- Inline code examples that would belong in `references/` or `scripts/`
- No consistent use of `scripts/` / `references/` / `assets/` bundled resources
- Assets (PPTX templates, SVG icons) mixed with SKILL.md body in a few skills

Anthropic's canonical skill structure prescribes **Progressive Disclosure** — a 3-level loading model that balances discoverability with context efficiency:

| Level | Content | When loaded | Budget |
|-------|---------|-------------|--------|
| 1 | Metadata (name + description) | **Always** in system prompt | ~100 words |
| 2 | SKILL.md body | When skill **triggers** | < 5k words (target 1,500-2,000) |
| 3 | Bundled resources (scripts/refs/assets) | **On-demand** during execution | Unlimited |

Source: `anthropics/claude-plugins-official/plugins/plugin-dev/skills/skill-development/SKILL.md:77-85`.

**Without PD enforcement**, ATLAS risks:
- Level 1 bloat: descriptions summarizing workflow (CSO violation — already addressed in ADR-011)
- Level 2 bloat: bodies >5k words consume triggered-skill context budget linearly
- Level 3 abuse: references loaded into body instead of files, defeats budget
- `assets/` loaded as context (they aren't meant to be — template outputs only)

## Decision

ATLAS adopts Progressive Disclosure as **mandatory** skill structure. Every skill MUST:

### Level 1 — Metadata (always in context)

Frontmatter only. Follows ADR-011 convention:
```yaml
---
name: skill-name-kebab-case
description: "{PURPOSE_CLAUSE}. {TRIGGER_CLAUSE — Form A or B per ADR-011}"
effort: low | medium | high
version: 0.1.0
metadata:
  category: workflow|meta|domain|infra
  sources: [citations if derived]
---
```

### Level 2 — SKILL.md body (when triggered)

Target: **1,500-2,000 words**. Maximum: **5,000 words** (hard cap).

Must contain:
- Overview (1-2 sentences, core principle)
- When to Use / When NOT to Use
- Red Flags table (if behavior-shaping)
- Workflow steps (imperative form)
- Quick reference (scannable)
- Common mistakes

Must NOT contain:
- Detailed API references (move to `references/`)
- Long code examples >50 lines (move to `scripts/` or inline as snippet)
- Templates, boilerplate HTML/Markdown (move to `assets/`)
- Repeated content from another skill (use cross-reference, no `@` links)

### Level 3 — Bundled resources (on-demand)

```
skills/<name>/
├── SKILL.md             (required, Level 2)
├── scripts/             (Level 3: executable code)
│   ├── validate.sh
│   └── render.py
├── references/          (Level 3: docs loaded into context as needed)
│   ├── patterns.md
│   ├── api-reference.md
│   └── schema.json
└── assets/              (Level 3: files for Claude's OUTPUT, not context)
    ├── template.pptx
    └── logo.svg
```

**Subdir semantics (strict)**:

| Subdir | Content | Load behavior |
|--------|---------|---------------|
| `scripts/` | Executable code (bash, python, node) | May be invoked without loading to context |
| `references/` | Markdown/JSON/YAML docs | Loaded into context when Claude decides |
| `assets/` | Binary or static files (PPTX, PNG, templates) | **NEVER** loaded as context — output only |

## Rationale

1. **Context budget preservation**: 131 skills × 2k body avg = ~262k words = ~350k tokens if all loaded. With Progressive Disclosure, only Level 1 (~100 words × 131 = ~13k tokens) is always active. Level 2 adds ~2k per active skill. Level 3 is pay-per-use.

2. **Separation of concerns**:
   - What the skill IS (Level 1)
   - How to execute (Level 2)
   - Reusable resources (Level 3)

3. **Predictable eval**: REC-001 skill-triggering eval assumes Level 1 alone can drive activation. If Level 1 depends on Level 2 content to trigger, eval is broken.

4. **Scaling to 200+ skills**: ATLAS growth trajectory (G Mining pilot, external contributors) requires this structure or context budget collapses.

## Consequences

### Positive

- Predictable context budget across ATLAS skills
- Clear subdir semantics reduce contributor confusion
- Large reference docs (API schemas, patterns) don't bloat primary flow
- Assets stored near skill but not injected as context — lint clean

### Negative

- Migration cost for existing skills violating PD (covered under REC-002 CSO audit scope)
- Contributors must learn the scripts/references/assets distinction (SKILL-AUTHORING.md documents)
- Some skills naturally want >5k words (e.g., ultrathink decision frameworks) — cap forces decomposition

### Risks

- **Budget creep**: contributors may add to Level 2 body to avoid creating Level 3 subdirs
  - *Mitigation*: `wc -w skills/**/SKILL.md` pre-commit check warns >5000
- **Asset misuse**: contributor puts skill reference docs in `assets/` (wrong — refs go to `references/`)
  - *Mitigation*: clear table in SKILL-AUTHORING.md (above); validate-skill-frontmatter.sh linter (REC-013) checks subdir presence
- **Broken eval on rewrites**: rewriting body per PD may accidentally change triggering conditions
  - *Mitigation*: REC-001 eval runs before/after to catch

## Alternatives considered

### A1 — Single-file skills (no bundled resources)

Rejected: forces all content into SKILL.md, immediate bloat. Used by some personal skill repos (3 KB) but doesn't scale to ATLAS complexity.

### A2 — Flexible — let authors choose structure

Rejected: leads to inconsistency. Hard to enforce token budget, linting, or eval. Current ATLAS situation.

### A3 — 2-level (metadata + body, no bundled)

Rejected: Anthropic canonical shows 3-level is superior for reference-heavy skills (API docs, templates). Not worth deviating from official structure.

### A4 — Go further to 4-level (metadata / trigger body / detailed body / resources)

Rejected: complexity for marginal benefit. 3-level is the sweet spot per Anthropic empirical work.

## Implementation path

- [x] **Phase 1 (this ADR)**: decision documented
- [ ] **Phase 2**: update `templates/SKILL.md.template` with PD structure + subdir guidance
- [ ] **Phase 3**: update `docs/SKILL-AUTHORING.md` with detailed PD section, budget rules, migration notes
- [ ] **Phase 4**: add word-count pre-commit check (`wc -w skills/**/SKILL.md > 5000 → warn`)
- [ ] **Phase 5** (REC-002 future): audit existing skills, migrate violators, measure pass rate via REC-001 eval

## Verification

```bash
# All existing skills body < 5000 words (target 1500-2000)
for f in skills/*/SKILL.md; do
  count=$(wc -w < "$f")
  if [ "$count" -gt 5000 ]; then echo "⚠ $f: $count words (>5000)"; fi
done

# Templates reference PD explicitly
grep -c "Progressive Disclosure" templates/SKILL.md.template
grep -c "Progressive Disclosure" docs/SKILL-AUTHORING.md

# Subdir taxonomy documented
grep -E "scripts/|references/|assets/" docs/SKILL-AUTHORING.md | wc -l  # ≥3
```

## References

- anthropics/claude-plugins-official `plugins/plugin-dev/skills/skill-development/SKILL.md:77-85` — canonical PD definition
- ATLAS benchmark report: §Per-repo #2 (anthropics/claude-plugins-official Force 1)
- ATLAS benchmark matrix: REC-009 (impact 8/10)
- Related ADRs: ADR-011 (Level 1 format), ADR-007 (eval validates Level 1 triggers)

---

*ADR-010 authored 2026-04-19 by ATLAS (Opus 4.7) as plan `joyful-hare` Path B item #3.*
