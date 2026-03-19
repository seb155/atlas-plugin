---
name: morning-brief
description: "Compile morning brief: today's agenda, important emails, open tasks, active projects, suggestions. The daily command center."
---

# Morning Brief

Compile a comprehensive daily brief from all data sources.
Triggered by `/atlas brief` or `/atlas brief morning`.

## Commands

| Command | Action |
|---------|--------|
| `/atlas brief` | Full morning brief |
| `/atlas brief morning` | Alias for full brief |
| `/atlas brief pre-meeting <name>` | Pre-meeting focused brief |

## Process

### 1. Fetch Data (Parallel)

Dispatch data fetches in parallel for speed. Use subagents (Sonnet) for each source:

| # | Source | API / Command | Fallback |
|---|--------|---------------|----------|
| 1 | Full Brief | `GET /pa/brief` | Fallback to individual endpoints |
| 2 | Tasks | `GET /pa/tasks?status=pending&status=in_progress` | Show "No tasks" |
| 3 | Knowledge | `GET /pa/knowledge?limit=10&sort=-updated_at` | Skip section |
| 4 | Git Activity | Included in brief (`recent_commits`) | `git log --oneline -5` |
| 5 | Emails | `GET /pa/emails?importance=high` | Show "No email data" |
| 6 | Live Sessions | Included in brief (`active_sessions`) | Skip section |
| 7 | Features | Included in brief (`feature_summary`) | Skip section |

**The `/pa/brief` endpoint now returns all 7 sources in one call** (sessions, features, commits are embedded). Use it as primary source, individual endpoints as fallback.

**Error handling**: If an API is unavailable, skip that section gracefully with a note.
Never block the entire brief because one source failed.

### 2. Synthesize (Opus)

After all data is fetched, synthesize with Opus-level reasoning:
- Identify priorities and conflicts
- Cross-reference tasks with calendar events
- Generate actionable suggestions based on context
- Flag overdue items and approaching deadlines

### 3. Display Format

```
ATLAS | MORNING BRIEF
---------------------------------------------------
{date} | {day of week}

AGENDA
  {HH:MM} {event title} ({participants})
  {HH:MM} {event title}
  ... or "No events today"

EMAILS ({N} important / {M} total)
  {sender}: {subject} -- {1-line summary}
  {sender}: {subject} -- {1-line summary}
  ... or "No important emails"

TASKS ({N} open, {X} overdue)
  [{priority}] {task title} (due: {date})
  [{priority}] {task title} (due: {date})
  ... or "All tasks complete"

ACTIVE SESSIONS ({N} live)
  🟢 {user} — {feature_id} ({model}, {duration}, {tool_count} tools, ctx {pct}%)
  ... or "No active sessions"

FEATURES IN PROGRESS ({N})
  🟡 {FEAT-NNN} {name} ({progress}%)
  ... or "No active features"

RECENT COMMITS
  {hash} {message}
  {hash} {message}
  ... or "No recent commits"

KNOWLEDGE UPDATES
  {title} -- {snippet} ({date})
  ... or skip if empty

SUGGESTIONS
  Based on your agenda and tasks:
  - {actionable suggestion 1}
  - {actionable suggestion 2}
  - {actionable suggestion 3}
---------------------------------------------------
```

### 4. Close with Decision

End EVERY brief with AskUserQuestion:

```
"What do you want to focus on?"
```

Options should be derived from the brief content:
- Top 2-3 tasks or agenda items as concrete choices
- "Something else" as a free-form option

## Pre-Meeting Variant

Triggered by: `/atlas brief pre-meeting <meeting-name>`

### Modified Process

1. **Identify the meeting** from calendar data or user input
2. **Fetch focused context**:
   - Meeting details (time, participants, agenda)
   - Past interactions with participants (from knowledge)
   - Related tasks and action items
   - Relevant recent work (git commits in related areas)
   - Previous meeting notes if available
3. **Display focused brief**:

```
ATLAS | PRE-MEETING BRIEF
---------------------------------------------------
{meeting name}
{date} {time} | {duration} | {location/link}

PARTICIPANTS
  {name} ({role}) -- {last interaction summary}
  ...

CONTEXT
  {relevant background from knowledge base}

OPEN ACTION ITEMS
  [{status}] {action item} (owner: {name})
  ...

YOUR PREP
  - {what to prepare / review}
  - {talking points based on open items}
  - {decisions needed}

RECENT RELATED WORK
  {relevant commits or changes}
---------------------------------------------------
```

4. **Close with**: AskUserQuestion "Ready for the meeting? Anything to prep?"

## Data Source Details

### Calendar (`GET /pa/brief`)
Returns compiled brief from backend including:
- Today's events with times, participants, locations
- Upcoming deadlines
- Schedule conflicts

### Tasks (`GET /pa/tasks`)
Query params:
- `status=pending&status=in_progress` for active items
- Sort by priority then due_date
- Flag overdue items (due_date < today)

### Knowledge (`GET /pa/knowledge`)
Recent entries that may be relevant:
- Sort by updated_at descending
- Limit to 10 most recent
- Include only entries with high relevance

### Git (`git log`)
Recent development activity:
```bash
git log --oneline -5 --format="%h %s (%ar)"
```

### Emails (`GET /pa/emails`)
High-importance emails:
- Filter by importance=high
- Include sender, subject, 1-line AI summary
- Group by urgency if many

## Model Strategy

| Phase | Model | Why |
|-------|-------|-----|
| Data fetching | Sonnet subagents | Parallel, efficient |
| Synthesis | Opus | Cross-reference, prioritize, suggest |
| Display | Opus | Final formatting with persona |

## Edge Cases

- **No data at all**: Show the brief skeleton with "No data available" sections. Suggest setting up integrations.
- **API errors**: Show available data, note which sources failed at the bottom.
- **Weekend/holiday**: Adjust suggestions (lighter tone, fewer work items).
- **First run ever**: Welcome message + explain what each section will show once data flows.
