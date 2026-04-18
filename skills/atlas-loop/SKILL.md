---
name: atlas-loop
description: "Autonomous loop pattern. Wraps CronCreate + ScheduleWakeup + Monitor. Trigger: /atlas loop, /loop, 'set up recurring task'. Subcommands: start, stop, status, list."
effort: medium
thinking_mode: adaptive
superpowers_pattern: [none]
see_also: [reminder-scheduler, atlas-team]
tier: core
version: 6.0.0
---

# atlas-loop — Autonomous Loop Pattern

> **Goal**: Run a task on recurring interval (CronCreate) OR self-paced (ScheduleWakeup), with optional Monitor for streaming events.

## When to Invoke

- User says: `/atlas loop <interval> <task>` or `/loop`
- "Check the deploy every 5 minutes"
- "Keep running babysit-prs until I stop"
- "Schedule recurring task"
- "Set up autonomous monitoring of X"

## Subcommands

### `start` — Begin a loop

```bash
/atlas loop start --interval=5m --task="check CI status of feat/v6 branch"
/atlas loop start --schedule="0 9 * * 1-5" --task="morning brief"  # Weekdays 9am
/atlas loop start --dynamic --task="check long build"              # Self-paced via ScheduleWakeup
```

Behavior:
- `--interval=Nm/h` → CronCreate with derived cron expression (avoid :00 / :30 minutes per docs)
- `--schedule="<cron>"` → Pass cron expression directly
- `--dynamic` → Single-shot, then ScheduleWakeup self-decides next interval
- `--max-iterations=N` → Stop after N runs (optional cap)

Returns: loop ID for stop/status

### `stop <id>` — Cancel a loop

```bash
/atlas loop stop <loop_id>
```

### `status` / `list` — Inspect

```bash
/atlas loop status     # Shows active loops + last run + next run
/atlas loop list       # Same as status, table format
```

## Implementation Pattern

The skill instructs Claude to:

1. **Parse subcommand** from user input (start | stop | status | list)
2. **For `start`**:
   - Validate interval/schedule against best practices (see Best Practices below)
   - Avoid `:00` and `:30` minute marks → use offsets like `:07`, `:23`, `:43`
   - Default 1200-1800s for idle ticks
   - Cap recurring at 7 days (CC native auto-expiry)
   - Dispatch to appropriate CC native tool:
     - `--interval` or `--schedule` → **CronCreate** (recurring or one-shot)
     - `--dynamic` → **ScheduleWakeup** with chosen `delaySeconds` + `reason`
   - Echo the loop ID returned by the tool so the user can `stop` it later
3. **For `stop`**:
   - Call **CronDelete** with the provided ID
   - Confirm cancellation
4. **For `status` / `list`**:
   - Call **CronList** → format active jobs as a table (id | cron | next run | prompt)

## Cron Expression Helpers

Convert `--interval` to a cron expression with off-peak minute offset:

| Interval input | Cron expression | Note |
|----------------|-----------------|------|
| `4m`           | `*/4 * * * *`   | Under 5min TTL → cache stays warm |
| `15m`          | `7,22,37,52 * * * *` | Off-peak minutes |
| `1h`           | `7 * * * *`     | 7 minutes past every hour |
| `6h`           | `13 */6 * * *`  | Off-peak minute, every 6 hours |
| `1d`           | `17 9 * * *`    | Daily 09:17 (avoid round hour) |

For `--schedule` passed directly, validate the 5-field cron syntax but trust the user's choice.

## Best Practices (from Anthropic docs)

- **Cache TTL alignment**: Wake intervals < 270s keep the prompt cache warm (5min TTL)
- **Avoid round numbers**: Many agents pick `:00` / `:30` simultaneously → fleet sync issue
- **`reason` field**: Always specify why this delay (telemetry + user visibility)
- **Bound autonomy**: Recurring tasks expire after 7 days (one final fire then auto-delete)
- **Don't pick 300s for ScheduleWakeup**: worst-of-both — pay cache miss without amortizing it. Use < 270s OR > 1200s.
- **Idle default**: 1200-1800s when no specific signal to watch

## Examples

```bash
# Hourly off-peak check
/atlas loop start --schedule="7 * * * *" --task="lint check on dev"
# → 7 minutes past every hour (avoid :00 mark)

# Active development polling (cache stays warm)
/atlas loop start --interval=4m --task="poll CI status"
# → Every 4min (under 5min TTL)

# Long idle babysit
/atlas loop start --interval=25m --task="check long-running migration"
# → 25min interval (one cache miss buys long wait)

# Self-paced via ScheduleWakeup
/atlas loop start --dynamic --task="watch deployment, ping when ready"
# → Initial check, then ScheduleWakeup decides next based on observation
```

## When NOT to Use

- One-off task → just do it, don't schedule
- User wants a single reminder → use `reminder-scheduler` directly
- Streaming events from a long-running process → use **Monitor** tool, not loop
- Parallel multi-agent work → use `atlas-team`, not loop

## Related Skills

- `reminder-scheduler` — one-shot reminders, simpler natural-language wrapper
- `atlas-team` — parallel agents, not loops
- `experiment-loop` (admin tier) — autonomous optimization loop with HITL gates

## Limitations

- **Session-only**: Cron jobs created via CronCreate live only in the current Claude session and die on exit (unless `durable: true` is set, which writes to `.claude/scheduled_tasks.json`)
- **7-day cap**: Recurring jobs auto-expire after 7 days (one final fire then delete)
- **REPL idle requirement**: Jobs only fire while the REPL is idle (not mid-query)
