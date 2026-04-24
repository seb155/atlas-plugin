# ADR-008: CSO Audit Migration (Skill Description Normalization)

**Status**: Accepted
**Date**: 2026-04-19
**Deciders**: Seb Gagnon
**Source**: Benchmark 2026-04-19 (plan `joyful-hare`, REC-002)
**Related**: ADR-011 (description convention — rules), ADR-010 (Progressive Disclosure), ADR-007 (skill-triggering eval framework)
**Supersedes**: None

---

## Context

ATLAS ships 100 top-level skills under `skills/*/SKILL.md` (additional bundled refs skills live at `skills/refs/*` — out of scope for this migration because they are Level-3 documentation references, not activation-time skills).

Before this audit, skill `description` frontmatter drifted across three distinct styles:

1. **Compliant — Form A** (Anthropic canonical): "{PURPOSE}. This skill should be used when the user asks to '…', '…'."
2. **Compliant — Form B** (obra shorthand): "{PURPOSE}. Use when {triggering condition}."
3. **Hybrid**: purpose clause plus triggers, but phrased ambiguously ("Use when 'X', 'Y'…" without the Form A `when the user asks to` framing, or Form A without exact phrases).
4. **Violation — pure workflow**: description summarizes the skill's workflow/steps without any activation trigger (CSO anti-pattern documented in obra/superpowers `writing-skills/SKILL.md:140-198`).
5. **Violation — first person**: "I help you…" (none observed in final pass, but guarded for future contributors).

Tallies from the 2026-04-19 audit of `skills/*/SKILL.md`:

| Category | Count | Share |
|---|---:|---:|
| Compliant-A (Form A canonical) | 9 | 9% |
| Compliant-B (Form B shorthand, clean) | 2 | 2% |
| Hybrid (has triggers, wrong framing) | 25 | 25% |
| Violation — pure workflow | 64 | 64% |
| Violation — first-person | 0 | 0% |
| **Total** | **100** | **100%** |

Without normalization, the 64 workflow-summary violations cause:

- Skills to fail activation on naive prompts (no exact-phrase match for CSO matcher).
- Claude to read the description's workflow summary and skip the body content (documented failure mode in obra `writing-skills/SKILL.md` — "code review between tasks" caused ONE review instead of the body's TWO).
- Skill eval framework (REC-001, ADR-007) scores degraded by malformed descriptions rather than malformed bodies.

## Decision

Execute a one-shot **CSO audit migration** over all 100 top-level skills:

### Migration policy per category

| Category | Action | Rewrite shape |
|---|---|---|
| Compliant-A | KEEP (no change) | — |
| Compliant-B (clean) | KEEP (no change) | — |
| Hybrid | NORMALIZE | Rewrite to Form A (user-facing) or Form B (meta/internal) — preserve existing trigger phrases, add canonical framing. |
| Violation — pure workflow | REWRITE | Extract purpose sentence from body (≤20 words). Add Form A or Form B triggers inferred from skill name + body + slash-command aliases. Drop workflow summary from description. |
| Violation — first-person | REWRITE | Convert to third-person imperative, add Form A/B triggers. |

### Form selection heuristic

- **Form A** (`"This skill should be used when the user asks to 'X', 'Y', 'Z'."`) — for skills invoked via chat, slash commands, or natural language (vast majority).
- **Form B** (`"Use when {condition}."`) — for meta/internal skills invoked by hooks, other skills, or CI (e.g. `scope-check`, `decision-log`, `git-worktrees`, `ci-feedback-loop`-style).

### Preservation rules during rewrite

1. Preserve existing trigger phrases verbatim when present (don't invent new vocab).
2. Preserve Quebec-French phrases (`'nouvelle idée'`, `'on devrait'`, `'grand menage'`).
3. Preserve slash-command aliases in trigger lists (`'/atlas analytics'`, `'/atlas cost'`).
4. Cap name + description at 500 chars (ADR-011).
5. Touch ONLY the `description:` field. Do not modify `name`, `effort`, `version`, `metadata`, `tier`, `category`, `emoji`, or body content.

### Execution in 3 commit batches

1. **Batch 1** — atlas-core tier skills (foundational, highest visibility).
2. **Batch 2** — atlas-dev-addon tier skills (engineering-focused).
3. **Batch 3** — atlas-admin-addon tier skills (infra + governance).

Each batch commits with a `refactor(skills): CSO audit migration batch N/3 (REC-002, ADR-008)` message listing the migrated skills and their prior category. Push at end (one push total) to minimize CI load.

## Consequences

### Positive

- **Activation reliability**: 64 previously-silent skills now match on user trigger phrases.
- **CSO compliance**: Claude reads skill bodies instead of trusting workflow-summary descriptions.
- **Eval baseline**: REC-001 framework (ADR-007) can now measure description quality on a known-normalized set.
- **Contributor cue**: `validate-skill-frontmatter.sh` (future REC-013 task) gets a clean baseline to diff against.
- **Grep discoverability**: exact trigger phrases are searchable across the plugin tree.

### Negative

- **Noise churn**: ~89 files modified in a short window. Mitigated by: touching only 1 line per file, agent B's body edits landing interleaved (no path conflicts), 3-batch commits.
- **Regression risk**: a mis-rewritten description could break activation for a previously-working skill. Mitigated by: REC-001 eval framework runs against each addon post-merge.
- **Review burden**: Seb cannot review 89 rewrites line-by-line. Mitigated by: full before/after log persisted as `docs/CSO-AUDIT-2026-04-19.md` for async review + rollback reference.

### Risks

- **Drift resurgence**: without a lint gate, new skills may revert to workflow-summary style.
  - *Mitigation*: REC-013 (`validate-skill-frontmatter.sh`) is already scoped; this ADR gates its rollout.
- **Over-fitting to Form A**: if all 100 skills end up using `"This skill should be used when the user asks to…"`, the LLM may desensitize to the pattern.
  - *Mitigation*: Form B preserved for ~12 meta/internal skills. Opening verbs in PURPOSE_CLAUSE vary.

## Alternatives considered

### A1 — Leave violations alone, add lint gate for new skills only

Rejected: the 64 existing violations remain silent drag on activation quality. Eval framework (REC-001) can't produce meaningful baselines with 64% noise.

### A2 — Rewrite by LLM pipeline (batch with Opus)

Rejected: non-deterministic output — same body → different descriptions across runs. Reviewer cannot verify 100 rewrites are individually correct. Curated rewrite with ground-truth log is auditable.

### A3 — Defer migration to REC-013 lint rollout

Rejected: REC-013 is a lint (blocking new violations). It does not mutate existing files. Without REC-002, the 64 violations persist indefinitely.

### A4 — Full description rewrite from body (ignoring existing phrases)

Rejected: destroys curated Quebec-French phrases and domain-specific slang that contributors added. Preserves existing triggers when present.

## Implementation path

- [x] **Step 1** — Inventory 100 skills, categorize (this ADR).
- [x] **Step 2** — Write CSO-AUDIT-2026-04-19.md with full before/after table.
- [ ] **Step 3** — Execute migration in 3 commit batches.
- [ ] **Step 4** — Push once at end.
- [ ] **Step 5** — Verify: name+description ≤ 500 chars, JSON schema still valid.
- [ ] **Step 6** — Add CSO-AUDIT-2026-04-19.md as eval baseline for REC-001.
- [ ] **Follow-up (REC-013)** — ship `validate-skill-frontmatter.sh` as pre-commit gate.

## References

- `docs/ADR/ADR-011-skill-description-convention.md` — the rules
- `docs/SKILL-AUTHORING.md` §Frontmatter Rules — style guide v2.0
- `docs/CSO-AUDIT-2026-04-19.md` — full before/after migration log
- obra/superpowers `skills/writing-skills/SKILL.md:140-198` — CSO rule origin
- anthropics/claude-plugins-official `plugins/plugin-dev/skills/skill-development/SKILL.md:158-182` — third-person + phrases
- synapse `.blueprint/reports/atlas-benchmark-matrix-2026-04-19.md` — REC-002 source

---

*ADR authored 2026-04-19 by ATLAS (Opus 4.7) as part of plan `joyful-hare`, REC-002. Accepted by Seb Gagnon 2026-04-19 via direct execution approval.*
