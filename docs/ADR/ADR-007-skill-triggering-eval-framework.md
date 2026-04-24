# ADR-007: Skill-Triggering Eval Framework

**Status**: Accepted
**Date**: 2026-04-19
**Deciders**: Seb Gagnon
**Source**: Benchmark 2026-04-19 (plan `joyful-hare`, Batch 1)
**Source repo**: obra/superpowers (`tests/skill-triggering/`)
**Related**: ADR-011 (description convention — tested by this framework), ADR-008 (CSO audit, pending — uses this as verification), ADR-013 (security gate — different concern)

---

## Context

ATLAS ships **106 skills** across three tiers (core, dev-addon, admin-addon) as of v5.31.0. Current quality assurance:
- Manual review by Seb when a skill misbehaves
- No regression tests
- No measurement of whether skill descriptions trigger the right skill on natural user prompts

This creates three risks:
1. **Silent drift**: editing `description` field may break skill activation without any signal. Only detected when Seb notices wrong skill fired (or no skill fired).
2. **Ambiguous dispatch**: multiple skills may have overlapping triggers, and Claude picks one non-deterministically. No way to measure overlap.
3. **Cold-start failure**: new skills added without testing their descriptions fire on realistic prompts.

obra/superpowers solved this with **skill-triggering eval framework** (`tests/skill-triggering/`):
- Naive prompts per skill (natural language, no skill name mention)
- `claude -p --plugin-dir` runs non-interactively with `--max-turns 3`
- `--output-format stream-json` emits tool invocations
- grep for `"name":"Skill"` + skill identifier → PASS/FAIL
- Regression detection via pass-rate tracking over time

Evidence of value: obra uses this as their primary QA mechanism for skill description changes. Documented case: description "code review between tasks" caused Claude to do ONE review even though skill flowchart mandates TWO — eval framework caught the regression before ship.

ATLAS has **zero coverage** currently — maximum blind spot given 106 skills scale.

## Decision

Port obra's skill-triggering framework to ATLAS:
- Location: `tests/skill-triggering/` in atlas-plugin repo
- Scripts: `run-test.sh <skill> <prompt>` + `run-all.sh` (iterates all skills)
- Prompts: `prompts/<skill-name>.txt` — one naive prompt per ATLAS skill
- Coverage target: **all 106 ATLAS skills** (user chose Full scope 2026-04-19 11:34 EDT)
- CI integration: **both manual + nightly Woodpecker** (user chose `Les deux`)

## Rationale

1. **Measurement closes the loop**: without pass/fail signal, description edits = blind changes. With eval, every description edit becomes a tested hypothesis.

2. **106 skills scale demands automation**: manual review at this scale is impossible. Automated eval is the only viable QA.

3. **Complements CSO audit (ADR-008)**: REC-002 CSO audit will rewrite many descriptions. Without eval framework, we can't prove the audit IMPROVED things. Eval provides baseline → change → post-change measurement.

4. **Low cost, high coverage**: `claude -p` is native CC primitive. Stream-json is stable. Grep is deterministic. No new dependencies.

5. **Coverage target = 100% of skills**: partial coverage creates survivorship bias (we measure the skills we care about, don't measure the ones we forgot). User explicitly chose Full scope.

## Consequences

### Positive

- **Regression detection**: any description edit re-running eval catches drift
- **Description quality measurement**: poor descriptions → low trigger rate → feedback signal to improve
- **Baseline for REC-002 CSO audit**: before/after measurement becomes possible
- **Confidence for new skills**: new contributions include eval prompt, pass rate gate ships
- **Reduced dependency on Seb's manual observation**: quality surfaced by CI

### Negative

- **Maintenance burden**: 106 prompts to maintain as skills evolve. Mitigated by treating prompts as part of skill definition (commit together).
- **Not all skills have clean naive triggers**: meta/hook/reference skills invoked programmatically → 20-30% may never trigger naively. Must be marked as "eval-exempt" with rationale.
- **Token cost**: nightly runs × 106 invocations × 3 turns × small model = ~5-10K tokens/night = negligible
- **Flaky runs**: LLM non-determinism may cause false FAILs. Mitigated by 3-run majority voting if needed (future enhancement).

### Risks

- **Coverage illusion**: 100% prompts doesn't mean 100% coverage of possible triggering conditions. One prompt per skill tests ONE scenario. Future work: multi-prompt per skill.
  - *Mitigation*: document in framework README that single-prompt coverage is minimum bar, not sufficient condition
- **Nightly cost creep**: if ATLAS grows to 500+ skills, cost proportional. OK for now, revisit at 300 skills.
- **Stream-json format drift**: if Claude Code changes output schema, parser breaks. Pin CC version in CI, update when needed.

## Alternatives considered

### A1 — Top-20 coverage only (8-12h)

Rejected by user: selected Full 131 scope. Partial coverage creates blind spots.

### A2 — Integration with product analytics (track real user prompts)

Rejected for now: user is solo Seb currently, not enough traffic for meaningful analytics. Revisit post G Mining pilot when multi-tenant usage data exists.

### A3 — LLM-as-judge for richer eval (not just trigger, also quality)

Deferred to future — this is REC-035 (autorater pattern from Ar9av/PaperOrchestra). Layer on top of REC-001 once basic eval is proven.

### A4 — Keep manual review, skip framework

Rejected: doesn't scale. Plan `joyful-hare` Batch 1 found ATLAS has 0 skill-activation tests — unacceptable posture at 106 skills.

## Implementation path

- [x] **Phase 1 (this ADR, 2026-04-19)**: decision documented
- [ ] **Phase 2**: port harness (`run-test.sh`, `run-all.sh`) with ATLAS adaptations
- [ ] **Phase 3**: enumerate all 106 skills, categorize (naive-triggerable vs exempt)
- [ ] **Phase 4**: draft prompts for each triggerable skill (Opus batch-generate from descriptions, then curate)
- [ ] **Phase 5**: `.woodpecker/skill-eval.yml` nightly pipeline
- [ ] **Phase 6**: baseline run, establish pass rate target (initial: ≥70%, stretch: ≥85%)

## Verification

Run `bash tests/skill-triggering/run-all.sh` — produces:
- Per-skill PASS/FAIL status
- Overall pass rate
- Logged stream-json output per failure for debugging

Woodpecker nightly runs this and posts issue label `skill-eval-regression` if pass rate drops >5% vs previous baseline.

## References

- obra/superpowers: `tests/skill-triggering/run-test.sh:1-76` (original harness)
- obra/superpowers: `tests/skill-triggering/prompts/*.txt` (sample naive prompts)
- ATLAS benchmark report: `synapse/.blueprint/reports/atlas-benchmark-report-2026-04-19.md` §Per-repo #1 (obra/superpowers Force 3)
- ATLAS benchmark matrix: REC-001 (priority 10/10, highest impact of entire benchmark)

---

*ADR-007 authored 2026-04-19 by ATLAS (Opus 4.7) as plan `joyful-hare` Path B item #2.*
