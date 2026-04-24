# ADR 0005 — Phase 6.5 Parallel Platform Scaffolding (v6.0 → v6.1)

**Status**: SCAFFOLD (full implementation deferred to v6.0 → v6.1)
**Date**: 2026-04-23
**Approver**: Seb Gagnon (HITL Gate 2 batch approval covers v6 scope)
**Related**: Plan v6 Dimensions 6 (Quality), 7 (Lifecycle), 8 (Team Orchestration)

## Context

The v6 plan declares Phase 6.5 Parallel Platform Infrastructure — 4 workers (engineer/architect/infra-expert/engineer) running in parallel to deliver:

- **Worker A** (engineer/sonnet-4.6): SOTA Quality Infrastructure (FSDD, DoD native, E2E mandatory, docs auto-sync, arch SOTA)
- **Worker B** (engineer/sonnet-4.6): Native Lifecycle Automation (roadmap/sprint/task, handoff/learn/end autonomous)
- **Worker C** (architect/opus-4.7[1m]): Team DAG Orchestration + Model Registry enforcement (L1-L8 layers)
- **Worker D** (infra-expert/sonnet-4.6): Native Infra/Network/SSO/Secrets registries

Total estimated effort: ~40h parallel wall-clock, ~80h summed across workers.

## Current State (v6.0.0-alpha.10)

**Already delivered** (foundational work overlapping Phase 6.5):

- ✅ **Model Registry enforcement partial** (Worker C): 3 Opus AGENT.md migrated to `[1m]` + doc mandate in model-benchmarks SKILL.md
- ✅ **Philosophy Engine** (Worker C): Iron Laws + Red Flags + hard-gate-linter + L8 SHA256
- ✅ **Autonomy Engine** (Worker A/C hybrid): session-state schema + autonomy-gate helper + 3 skill integrations + persistence
- ✅ **Flow Telemetry** (Worker A): flow-analytics skill + skill-usage-tracker hook
- ✅ **Native Memory** (Worker B): memory-auto-index hook + memory-dream skill (pre-existing)
- ✅ **Native Rules Loading** (Worker A foundation): rules-conditional-loader hook + _meta.yaml schema

**Not yet delivered** (true Phase 6.5 scope):

- ⏳ **FSDD** (Feature-Spec Driven Development) — `.blueprint/specs/` + `spec-first` skill
- ⏳ **DoD Native Integration** — TaskCreate enhancement with dod_tier field
- ⏳ **E2E Test Infrastructure Mandatory** — `e2e-scaffold` skill + route-smoke-entry validation
- ⏳ **Docs Auto-Sync** — `docs-sync` skill (OpenAPI → devhub auto-gen)
- ⏳ **Architecture SOTA Patterns** — `.claude/rules/architecture-sota.md` + `senior-review-checklist` 9th dim
- ⏳ **Native Roadmap/Sprint** — `.atlas/roadmap.yaml` + `roadmap-manager` + `sprint-planner` skills
- ⏳ **Auto-handoff** — trigger on context > 85%
- ⏳ **Native Infrastructure Registry** — `~/.atlas/infrastructure/inventory.yaml` + `infra-context-injector` hook
- ⏳ **Native SSO Integration** — `~/.atlas/sso/session.yaml` + `atlas-auth` CLI
- ⏳ **Native Secrets Policy** — `~/.atlas/secrets/policy.yaml` + `atlas-secret` helper

## Decision

**DEFER full Phase 6.5 to v6.1 release cycle**, ship current v6.0 with:
- Phase 6.5 partial delivery via Philosophy Engine + Autonomy Engine + Flow Telemetry
- Comprehensive ADR (this document) scaffolding the 10 remaining workstreams
- Worker assignments preserved for future parallel-team session

## Rationale

1. **v6.0 scope already delivers 50% of Phase 6.5 value** via foundations (Philosophy, Autonomy, Flow, Memory, Rules)
2. **Remaining work is highly independent** — 10 workstreams can parallelize perfectly with Team approach
3. **Session-level constraints** — Full Phase 6.5 requires multi-session team orchestration (~40h parallel), not feasible in single-session continuation
4. **v6.1 provides natural milestone** — alpha/beta/GA cycle for v6.0 complete, then dedicate v6.1 cycle to Phase 6.5 team spawn

## Consequences

### Positive

- ✅ v6.0 ships on time with 7/9 phases + Sprint 1 P1 80% complete
- ✅ Clear roadmap for v6.1 with 10 well-scoped workstreams
- ✅ Foundations in place make Phase 6.5 additive (not rewriting v6.0)
- ✅ Parallel team work possible once v6.0 shipped (no interdependencies)

### Negative

- ⚠️ v6.0 GA features are limited vs original Phase 6.5 ambition
- ⚠️ Users must wait v6.1 for FSDD, native roadmap, infra registries
- ⚠️ Mitigations rely on v6.0 maturity + 7-day monitoring (Phase 8)

## Implementation Plan for v6.1

### Sprint 1 (Week 1)
- Worker A: FSDD foundation (`.blueprint/specs/` schema + `spec-first` skill scaffolding)
- Worker B: Roadmap schema (`.atlas/roadmap.yaml` + `roadmap-manager` skill)
- Worker C: Team DAG scheduling (critical path + topological sort in `execution-strategy`)
- Worker D: Infrastructure inventory schema (`~/.atlas/infrastructure/inventory.yaml`)

### Sprint 2 (Week 2)
- Worker A: DoD native + E2E mandatory gates
- Worker B: Sprint-planner skill + auto-handoff trigger
- Worker C: Model registry L3-L8 enforcement layers
- Worker D: SSO integration + secrets policy

### Sprint 3 (Week 3)
- Worker A: Docs auto-sync + architecture-sota rule
- Worker B: Learn automation (auto-learn.sh enhancement)
- Worker C: (completion buffer for Worker D SSO/secrets if overflowing)
- Worker D: (completion buffer)

### Sprint 4 (Week 4 — integration)
- All workers: Integration tests, 4-worker manifest execution, v6.1 GA prep

## Verification (v6.1)

```bash
# After v6.1 ship, verify Phase 6.5 deliverables:
ls .blueprint/specs/                             # FSDD specs dir
ls ~/.atlas/roadmap.yaml                         # Roadmap registry
ls ~/.atlas/infrastructure/inventory.yaml        # Infra registry
ls ~/.atlas/sso/session.yaml                     # SSO state
ls ~/.atlas/secrets/policy.yaml                  # Secrets policy
which atlas-auth atlas-secret                    # CLI helpers
bats tests/bats/test_fsdd.bats                   # FSDD regression tests
```

## References

- Plan v6: `.blueprint/plans/le-plugin-atlas-core-devrais-adaptive-treasure.md` (Phase 6.5, ~40h)
- Master SOTA review: `memory/atlas-v6-sota-review-2026-04-23.md`
- Phase 5 delivered skills: autonomy-gate, flow-analytics, memory-auto-index, rules-conditional-loader
- Worker allocation inspired by: ADR-0001 MCP consolidation, ADR-0002 Routines vs CronCreate

## Revisit Triggers

This ADR should be revisited if:
- v6.0 GA user feedback indicates urgency on specific Phase 6.5 items
- v6.1 sprint planning reveals scope issues (over/under-estimated)
- New Anthropic SDK features change Worker C scope (model enforcement)
- Team available for parallel spawn (requires Seb + dedicated window)

**Revisit calendar**: v6.1 sprint-planning (2-4 weeks post-v6.0 GA)

## Version History

- **v1.0** (2026-04-23): Initial scaffold ADR — Phase 6.5 deferred decision documented during v6.0.0-alpha.10 session
