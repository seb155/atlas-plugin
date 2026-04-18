# ADR 0002 — Claude Code Routines vs ATLAS CronCreate

**Status**: PROPOSED (HITL Seb)
**Date**: 2026-04-17
**Context**: ATLAS v6.0 Sprint 6 — autonomous loop strategy alignment with new Anthropic Routines feature
**Deciders**: Seb Gagnon, Claude Opus 4.7 (plan-architect)
**Supersedes**: none
**Superseded by**: none

## Context

Claude Code 2.1.x ships two complementary scheduling capabilities:

1. **CronCreate** (in-session tool) — schedules a prompt to fire at next session tick. Requires CC REPL idle.
2. **Routines** (cloud feature, released 2026-04-14, claudefa.st changelog) — schedules tasks that execute on Anthropic's cloud, no local session needed.

ATLAS exposes the in-session path indirectly via `atlas-loop` (tier core) and `reminder-scheduler` (tier core) skills. The cloud path is currently unsurfaced. Plan v6.0 Section A.2 already flagged "Sprint 6: complément CronCreate pour migrations persistantes" as the alignment moment.

## Decision Matrix

| Criterion         | CronCreate (in-session)         | Routines (cloud)                       |
|-------------------|---------------------------------|----------------------------------------|
| Execution context | Local CC session (must be idle) | Anthropic cloud (no local needed)      |
| Persistence       | Session-only (or `durable: true` to disk) | Anthropic cloud, persistent  |
| Latency           | Immediate when REPL idle        | Scheduled cloud dispatch               |
| Cost              | Local API call                  | Cloud + API call                       |
| Suitable for      | Active dev sessions, polling, idle ticks | Long-running automation, headless tasks |
| Setup overhead    | None (in-session tool)          | Account + config + auth                |
| Visibility        | Statusline + `atlas agents` CLI | Cloud dashboard                        |
| Failure mode      | Skipped if session not idle     | Cloud retry with notifications         |
| Network required  | No (local)                      | Yes (always cloud-bound)               |

## Use Cases by Tool

### CronCreate (in-session)
- Active development session polling (CI status, file changes, build watches)
- User-driven scheduled tasks during a work session (`/atlas remind`)
- Idle-tick recurring checks (every 5/15/30 min while user works on the laptop)
- Session-bounded recurrences that should die with the REPL

### Routines (cloud)
- Daily automation (morning brief, weekly retrospective)
- Long-running background jobs (overnight builds, backup health checks)
- Cross-session workflows (handoff verification, env smoke tests)
- "Always-on" reminders that survive laptop reboot / VPN drop

## Recommendation

**ATLAS adopts BOTH as complementary** (not replacement):

- Keep `atlas-loop` skill wrapping CronCreate (in-session) — already shipped v6.0.0-alpha.1 (Sprint 5)
- Add `atlas-routines` skill (NEW, propose Sprint 7) wrapping Routines API
- Document a single decision tree in skill metadata so the right tool surfaces automatically

### Decision tree for users

```
Need scheduling?
├─ Active CC session? Want results in session?
│   └─ atlas-loop (CronCreate)
└─ Headless / cloud / cross-session?
    └─ atlas-routines (when implemented)
```

## Implementation Status

| Skill           | Tool wrapped | Status                                                       |
|-----------------|--------------|--------------------------------------------------------------|
| `atlas-loop`    | CronCreate   | Shipped v6.0.0-alpha.1 (Sprint 5)                            |
| `reminder-scheduler` | CronCreate | Shipped (tier core, used by `/atlas remind`)            |
| `atlas-routines`| Routines API | Proposed for v6.x (Sprint 7+, pending API stability check)   |

## HITL Questions for Seb

1. **Adoption stance**: Adopter Routines en complément (les deux skills coexistent) ou exclusif (migrer atlas-loop vers Routines)?
2. **Priorité**: atlas-routines à Sprint 7 (juste après ship v6.0 GA), ou défer post-v6 GA pour laisser l'API Anthropic mûrir?
3. **Migration path**: devrait-on migrer les skills time-based existantes (`morning-brief`, `weekly-review`, `idle-curiosity`) vers Routines (cloud) plutôt que CronCreate in-session?

## Followup work (if approved)

- Investigate Routines API surface (docs, auth, schedule format, quotas)
- Prototype `atlas-routines` skill (mirror `atlas-loop` SKILL.md pattern)
- ADR 0002b on migration of existing time-based skills (morning-brief, weekly-review, idle-curiosity)
- Update `.blueprint/SKILL-CATALOG.md` with the dual-scheduling story

## Sources

- Anthropic Routines announcement (2026-04-14, claudefa.st changelog)
- ATLAS `atlas-loop` SKILL.md (v6.0.0-alpha.1, Sprint 5)
- ATLAS `reminder-scheduler` SKILL.md (tier core)
- Plan v6.0 Section A.2 — "Sprint 6: complément CronCreate pour migrations persistantes"
- ADR 0001 (browser consolidation, same v6.0 dedup framing)
