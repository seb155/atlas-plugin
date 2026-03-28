---
name: reminder-scheduler
description: "Schedule reminders and follow-ups using Claude Code's CronCreate. Wraps CC native cron for /atlas remind."
effort: low
---

# Reminder Scheduler

Schedule reminders and follow-ups using Claude Code's native cron system.
Triggered by `/atlas remind` or natural language requests about reminders.

## Commands

| Command | Action |
|---------|--------|
| `/atlas remind <when> <what>` | Create a new reminder |
| `/atlas remind list` | List all active reminders (CronList) |
| `/atlas remind cancel <id>` | Cancel a reminder (CronDelete) |

## Process

### 1. Parse Natural Language Time

Extract `<when>` and `<what>` from the user's input. Supported patterns:

| Input Pattern | Parsed As | Cron Strategy |
|---------------|-----------|---------------|
| "in 30 minutes" | now + 30m | One-shot cron at calculated time |
| "in 2 hours" | now + 2h | One-shot cron at calculated time |
| "at 2:30pm" | Today 14:30 (or tomorrow if past) | One-shot cron |
| "tomorrow morning" | Next day ~9:00 AM | One-shot cron |
| "in 3 days" | now + 3 days, 9:00 AM | One-shot cron |
| "every day at 9am" | Daily 09:00 | Recurring cron `0 9 * * *` |
| "every morning" | Daily 09:00 | Recurring cron `0 9 * * *` |
| "every Monday" | Weekly Monday 09:00 | Recurring cron `0 9 * * 1` |
| "every hour" | Hourly at :00 | Recurring cron `0 * * * *` |

Use `date` via Bash to get the current time for calculations:
```bash
date '+%Y-%m-%d %H:%M %Z'
```

### 2. HITL Confirmation (NON-NEGOTIABLE)

ALWAYS confirm the parsed time with the user via AskUserQuestion BEFORE creating the cron:

```
Reminder parsed:
  What: {reminder text}
  When: {human-readable time}
  Cron: {cron expression}
  Type: {one-shot | recurring}

Confirm?
```

Options: Confirm / Edit time / Cancel

### 3. Create the Cron

Use CronCreate with the parsed schedule:
- **One-shot**: Set the cron expression for the specific time
- **Recurring**: Set the repeating cron expression
- **Cron command**: The instruction should tell ATLAS to display the reminder text prominently

### 4. Create Tracking Task (Persistent)

Also create a user_task via the backend API for persistent tracking:

```
POST /pa/tasks
{
  "title": "{reminder text}",
  "source": "reminder",
  "due_date": "{ISO datetime}",
  "priority": "medium",
  "status": "pending",
  "metadata": {
    "type": "reminder",
    "recurring": true/false,
    "cron_expression": "{expression}"
  }
}
```

This ensures the reminder survives session restarts (cron does not).

### 5. Confirmation Output

```
Reminder set
  {reminder text}
  {human-readable schedule}
  Task #{id} created for tracking

Note: Cron is session-only (active while Claude is running).
      Task persists in ATLAS for follow-up.
```

## List Reminders

When the user asks to list reminders:

1. Use **CronList** to show active session crons
2. Also fetch from API: `GET /pa/tasks?source=reminder&status=pending`
3. Display merged view:

```
Active Reminders
  SESSION (live crons)
  {id} | {schedule} | {text} | {next run}

  PERSISTENT (tasks)
  #{id} | {due_date} | {text} | {status}
```

## Cancel Reminder

When the user asks to cancel:

1. Use **CronDelete** with the cron ID
2. Also update the task: `PATCH /pa/tasks/{id}` with `status: "cancelled"`
3. Confirm cancellation

## Important Limitations

### Session-Only Crons
CronCreate crons are **session-scoped** — they die when Claude exits.
For reminders that MUST persist across sessions:
- The user_task with `due_date` is the persistent fallback
- Morning brief (`/atlas brief`) picks up pending tasks with due dates
- Mention this to the user on every reminder creation

### Time Zone
- Always use the user's local timezone (detect from system `date`)
- Display times in local format with TZ indicator

## Follow-Up Pattern

For "follow up with {person} in {time}" requests:
1. Create the reminder as above
2. Add person context to the task metadata:
   ```json
   {
     "metadata": {
       "type": "follow-up",
       "person": "{name}",
       "context": "{any additional context from conversation}"
     }
   }
   ```
3. When the reminder fires, include the person and context in the notification

## Examples

### One-shot
```
User: "remind me at 2pm to prep the meeting"
→ Cron: one-shot at 14:00 today
→ Task: "Prep the meeting" due 14:00
```

### Recurring
```
User: "remind me every morning to check emails"
→ Cron: 0 9 * * * (recurring)
→ Task: "Check emails" recurring, no due_date
```

### Follow-up
```
User: "follow up with Marc in 3 days"
→ Cron: one-shot at 09:00 in 3 days
→ Task: "Follow up with Marc" due in 3 days, person=Marc
```
