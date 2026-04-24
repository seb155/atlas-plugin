# ATLAS Plugin — Philosophy

> **Created**: 2026-04-19 as outcome of benchmark plan `joyful-hare` (Batch 1)
> **Source inspirations**: obra/superpowers, anthropics/claude-plugins-official, AXOIQ operational reality
> **Status**: Living document — updated as ATLAS evolves

---

## Why this document exists

After a benchmark of 6 leading agent-skill frameworks (2026-04-19), it became clear that ATLAS lacks an explicit philosophy statement. Without it:

- New contributors can't align on *why* we make certain choices
- Skills drift into inconsistent styles
- Partnership decisions (G Mining, other enterprises) lack a codified stance
- Future Claude sessions lose context between compactions

This document captures the non-negotiables.

---

## 1. Skills are behavior-shaping code, not prose

The single most important lesson from obra/superpowers (`skills/writing-skills/SKILL.md`):

> "Skills are not prose — they are code that shapes agent behavior. If you modify skill content: run adversarial pressure testing, show before/after eval results."

Consequences for ATLAS:
- **Every skill edit is a behavior change.** Reviewers must ask "does this alter Claude's actions?" not "does this read well?"
- **Red Flags tables, rationalization lists, and XML directives are LOAD-BEARING content.** Rewriting them without eval evidence is a regression.
- **Prose quality is secondary to behavioral precision.** Short, direct imperatives beat polished paragraphs.

Validation mechanism: skill-triggering eval framework (REC-001, future port of `obra/superpowers/tests/skill-triggering/`).

## 2. Deterministic core, AI-accelerated periphery

AXOIQ products (Synapse, GMS App, Atlas) target mining engineering — a domain where **a wrong number kills the CAPEX estimate**. Therefore:

- **The application runs deterministic**: database-first, rule-based, zero AI dependency at inference
- **The development assistant (ATLAS)** is AI-augmented but human-gated
- **HITL (Human-In-The-Loop) gates are non-negotiable** for mutations: every meaningful change requires an explicit Seb approval before action

ATLAS skills MUST preserve this split. A skill that adds runtime AI dependency to Synapse is an anti-pattern.

Reference: Synapse `CLAUDE.md` Principles 1-5.

## 3. Frameworks before frictions

Seb's telos (from `user_cognitive_pattern_hid.md`):

> "Bâtir les frameworks externes qui permettent à un système cognitif hyperactif de participer au monde sans se collapser — d'abord pour moi, puis pour les autres qui portent le même pattern cognitif."

ATLAS is one such framework. Its skills should *reduce* cognitive load, not add it.

Concretely:
- **Skills that enforce discipline (TDD, verification, scope-check) are high-value.**
- **Skills that duplicate existing ergonomics or add ceremony are LOW-value.**
- **When ATLAS imposes a rule, it must explain *why* so the human can override knowingly.**

The purpose is empowerment, not bureaucracy.

## 4. Opus-default, Sonnet-routine, Haiku-cheap

From `CLAUDE.md` global:

> "Opus = default brain. Sonnet = routine-only. When in doubt → Opus."

Per-task allocation:
| Task | Model | Why |
|------|-------|-----|
| Architecture, plans, brainstorming | Opus 4.7 max | Deep reasoning required |
| Complex debugging, multi-file edits | Opus 4.7 xhigh | Edge cases proliferate |
| Routine implementation (clear path) | Sonnet 4.6 high | 98% Opus coding, 5x cheaper |
| Spec checklist, git ops, tabulation | Haiku 4.5 low | Cheapest capable |

"ultrathink" keyword → bump effort to max (Opus only).

## 5. Testing funnel is sacred (4 gates)

From `.claude/rules/testing-funnel.md`:
- **G0 pre-commit** (<10s): ruff, mypy, gitleaks, semgrep ERROR
- **G1 pre-push** (<30s): pytest-testmon + vitest --changed on affected
- **G2 CI affected** (<5min): full CI on path-filtered changes
- **G3 post-deploy smoke** (<60s): real HTTP + auth + DB + LLM
- **G4 nightly E2E** (<15min): Playwright on staging

ATLAS plugin's own CI must aspire to the same structure. Skills that weaken the funnel (e.g., `--no-verify`, `--tb=long`) are violations.

## 6. Mock budget rule — orchestrators need real smoke

From `.claude/rules/testing-mock-budget.md` (incident 2026-04-16):

> "Services with 3+ DI deps MUST ship at least one smoke test that hits real HTTP + real DB + real LLM. The persona-bug class proves mock-only tests pass green while production breaks."

Any ATLAS skill that orchestrates multiple services must include smoke-level validation, not just unit-level mocks.

## 7. Tiered architecture for scale (not dogma)

ATLAS ships 131 skills across core (28) / dev (36) / admin (67). This **tiered architecture** is right for our scale, not a universal good:

| Skill count | Architecture | Rationale |
|-------------|--------------|-----------|
| < 30 skills | Library (single plugin) | Context loading cheap, UX simple |
| 30-80 skills | Optional tiering | Balance depending on user segment |
| > 80 skills | Tiered mandatory | Context budget requires progressive loading |

Source: MiniMax-AI/skills benchmark (17 skills → library) vs ATLAS (131 → tiered). See ADR-016 (pending).

## 8. Quebec French ↔ English parity

Seb's working language is Quebec French. ATLAS must:
- Respond in French (Quebec variant) by default
- Keep code comments, docs, and technical terms in English
- Preserve diacritical marks (é, à, î, ç) — never substitute with ASCII
- Bilingual content is NOT a feature — primary is French, English is for cross-team/client comms

Reference: global `CLAUDE.md` Langue section.

## 9. Rules over willpower (external framework)

ATLAS enforces rules through mechanical means, not discipline:

| Rule | Mechanism | Why |
|------|-----------|-----|
| No-ship Friday | Pre-push lefthook | Weekend buffer |
| Solo velocity cap 15/24h | Pre-commit warn | Cognitive rest |
| CI config freeze | Time-based rule | Break fire-fighting loop |
| Plugin cache read-only | Hook blocks writes | Prevent corruption |
| HITL gates | Interactive prompts | Human review required |

Rules are not optional. They are NOT "we try to avoid". They are mechanical constraints. If a rule fires, the default action is PAUSE + explain, not override.

## 10. Evidence over memory

When ATLAS memory (MEMORY.md, plans, ADRs) conflicts with filesystem/git reality → trust the filesystem.

Memory drift happens. Plans grow stale. Reality wins. Always audit before acting on remembered state.

Reference: `feedback_ultrathink_plan_staleness_pattern.md` (2026-04-18).

---

## What ATLAS is NOT

- **NOT a replacement for engineering judgment.** Skills guide, not decide.
- **NOT a general-purpose agent.** Scoped to Synapse engineering + AXOIQ workflows + G Mining pilot.
- **NOT a multi-harness framework (yet).** Claude Code only until strategic shift. Ref: Benchmark 2026-04-19 scope decision.
- **NOT an eval-less system (long-term).** Skills without eval coverage are technical debt. REC-001 in flight.
- **NOT a commercial product yet.** Currently single-tenant (Seb), migrating to multi-tenant for G Mining pilot 2026-05+.

## What ATLAS WILL BECOME

Over the next 3-6 months:
- **Eval-covered skill library** (REC-001 skill-triggering port → 131 skills with activation tests)
- **Security-gated marketplace** (REC-015 skill-lint at install time)
- **Self-extending via memory-dream** (REC-026 skill proposal from recurring corrections)
- **Multi-tenant safe** (Synapse `project_id` pattern extended to ATLAS operations)

## Licensing & ethos

ATLAS is an internal AXOIQ tool, not open-source. Decisions favor:
- **Seb's productivity** (primary beneficiary)
- **G Mining deployment readiness** (commercial constraint)
- **AXOIQ team learning** (others who adopt same cognitive pattern)
- **Pragmatism over ideology** — if a pattern works for Seb's reality, ship it.

---

## References

- obra/superpowers `CLAUDE.md`, `skills/writing-skills/SKILL.md`
- anthropics/claude-plugins-official `plugins/plugin-dev/skills/skill-development/SKILL.md`
- AXOIQ Synapse `CLAUDE.md`, `.claude/rules/*.md`
- User profile: `memory/user_cognitive_pattern_hid.md`
- Benchmark report: `synapse/.blueprint/reports/atlas-benchmark-report-2026-04-19.md`

---

*PHILOSOPHY.md v1.0 — authored 2026-04-19 by ATLAS (Opus 4.7) as plan `joyful-hare` Batch 1 REC-007. Living doc — update when principles evolve.*
