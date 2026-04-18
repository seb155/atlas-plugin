---
name: atlas-routines
description: "Cloud-scheduled recurring tasks via Anthropic Routines API. Headless execution, no local session required. Trigger: /atlas routines, 'set up cloud routine', 'schedule headless task'. Subcommands: create, delete, list, run."
effort: medium
thinking_mode: adaptive
superpowers_pattern: [none]
see_also: [atlas-loop, reminder-scheduler]
tier: core
version: 6.0.0-alpha.1
---

# atlas-routines — Cloud Scheduled Tasks

> **Goal**: Schedule recurring Claude tasks that run on Anthropic's cloud, no local session needed.
> **Decision**: ADR-0002 (complementary to atlas-loop / CronCreate in-session).

## When to Invoke

- "Set up cloud routine"
- "Schedule headless task"
- "Run X every morning even if I'm not logged in"
- "Daily/weekly automation"
- "Cross-session workflow"

## Decision Tree (vs atlas-loop)

```
Need scheduling?
├─ Active CC session + want results in session?
│   └─ atlas-loop (CronCreate)  — local
└─ Headless / cloud / cross-session?
    └─ atlas-routines (this skill) — Anthropic cloud
```

## Subcommands

### `create` — Schedule a new routine

```bash
/atlas routines create --schedule="0 8 * * 1-5" --task="morning brief: summarize overnight emails + GitHub activity"
/atlas routines create --interval=daily --task="weekly report aggregation"
```

Behavior:
- `--schedule="<cron>"` → Pass cron expression directly (avoid :00 / :30 marks per CC best practices)
- `--interval=daily|weekly|monthly` → Convenience shortcuts
- `--task="<description>"` → The prompt to execute
- `--max-output-tokens=N` → Cap response size (optional)

Returns: routine ID for delete/run

### `delete <id>` — Remove a routine

```bash
/atlas routines delete <routine_id>
```

### `list` — Show all routines

```bash
/atlas routines list
```

Format: table (id, schedule, task summary, last run, next run, enabled).

### `run <id>` — Trigger immediately (one-off)

```bash
/atlas routines run <routine_id>
```

Useful for testing or manual triggers without waiting for next scheduled fire.

## Implementation Pattern

The skill instructs Claude to use the **RemoteTrigger** tool (CC native) with the Routines API endpoints:

```
list:    GET  /v1/code/triggers
get:     GET  /v1/code/triggers/{trigger_id}
create:  POST /v1/code/triggers (body required)
update:  POST /v1/code/triggers/{trigger_id} (body, partial)
run:     POST /v1/code/triggers/{trigger_id}/run (optional body)
```

## Best Practices

- **Schedule expressions**: avoid `0 9 * * *` (everyone's 9am) — pick `7 9 * * *` instead
- **Cost predictability**: routines bill at standard API rates per execution; estimate frequency × tokens
- **Failure handling**: Routines retry per Anthropic policy; check status via `list`
- **Authentication**: RemoteTrigger uses session OAuth token, no manual key needed

## Examples

```bash
# Daily morning brief at off-peak minute
/atlas routines create --schedule="11 8 * * *" --task="brief moi sur emails non-lus + PRs ouverts"

# Weekly review every Friday 5pm
/atlas routines create --schedule="13 17 * * 5" --task="weekly retrospective: wins, blockers, next week priorities"

# Monthly cost analysis
/atlas routines create --schedule="7 9 1 * *" --task="cost report previous month: API spend + budget burn"
```

## When NOT to use

- Active session polling → use `atlas-loop` (in-session, immediate)
- One-off task → just execute it now, don't schedule
- Long-running monitor → use `Monitor` tool (streaming events)

## Migration from atlas-loop

If you set up `atlas-loop` recurring tasks that should survive session close, migrate to atlas-routines:

```bash
# Old (in-session, dies with REPL)
/atlas loop start --interval=1h --task="check CI"

# New (cloud, persistent)
/atlas routines create --schedule="3 * * * *" --task="check CI status of feat/v6 branch"
```

## Related Skills

- `atlas-loop` (in-session CronCreate, complementary)
- `reminder-scheduler` (one-shot reminders)
- `atlas-team` (parallel agents, not loops)

## See ADR

`.blueprint/adrs/0002-routines-vs-croncreate.md` for design rationale.
