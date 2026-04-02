---
name: atlas-analytics
description: "Analytics dashboard for ATLAS hook activity. Reads task-log.jsonl, permission-log.jsonl, atlas-audit.log. Shows task patterns, permission events, session stats. Use when 'analytics', 'hook stats', 'task stats', 'permission stats', 'session stats', '/atlas analytics'."
effort: low
---

# ATLAS Analytics — Hook Activity Dashboard

Read and analyze JSONL log files produced by ATLAS hooks. Provides insights into task creation patterns, permission events, and session activity.

## Subcommands

| Command | Action |
|---------|--------|
| `/atlas analytics` | Full dashboard (all logs) |
| `/atlas analytics tasks` | Task creation patterns from task-log.jsonl |
| `/atlas analytics permissions` | Permission events from permission-log.jsonl |
| `/atlas analytics sessions` | Session activity from atlas-audit.log |

## Data Sources

| Log File | Hook | Content |
|----------|------|---------|
| `~/.claude/task-log.jsonl` | `task-created-log` | Task ID, subject, team, timestamp |
| `~/.claude/permission-log.jsonl` | `permission-denied-log` | Tool, action, input, timestamp |
| `~/.claude/atlas-audit.log` | `session-start` | Session start events, tier, role |
| `~/.claude/compaction-log.txt` | `pre-compact-context` | Compaction triggers |

## Execution Steps

1. **Check which logs exist** — `ls -la ~/.claude/{task-log,permission-log,atlas-audit,compaction-log}*`
2. **For each existing log**, read via Bash and produce a summary table:

### Task Analytics (task-log.jsonl)
```bash
# Count tasks per day
cat ~/.claude/task-log.jsonl | python3 -c "
import json, sys
from collections import Counter
days = Counter()
teams = Counter()
for line in sys.stdin:
    try:
        e = json.loads(line)
        days[e['ts'][:10]] += 1
        teams[e.get('team','solo')] += 1
    except: pass
print('Tasks per day:')
for d, c in sorted(days.items())[-7:]:
    print(f'  {d}: {c}')
print(f'\nTeams: {dict(teams)}')
print(f'Total: {sum(days.values())} tasks')
"
```

### Permission Analytics (permission-log.jsonl)
```bash
cat ~/.claude/permission-log.jsonl | python3 -c "
import json, sys
from collections import Counter
tools = Counter()
for line in sys.stdin:
    try:
        e = json.loads(line)
        tools[e.get('tool','?')] += 1
    except: pass
print('Permission events by tool:')
for t, c in tools.most_common(10):
    print(f'  {t}: {c}')
print(f'Total: {sum(tools.values())} events')
"
```

### Session Analytics (atlas-audit.log)
```bash
grep -c "SESSION_START" ~/.claude/atlas-audit.log 2>/dev/null || echo "0 sessions"
tail -5 ~/.claude/atlas-audit.log 2>/dev/null
```

3. **Present as dashboard**:

```
🏛️ ATLAS │ 📊 Analytics Dashboard
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 Tasks (last 7 days)
| Date       | Count |
|------------|-------|
| 2026-04-01 | 12    |
| 2026-04-02 | 8     |
Total: 20 tasks | Teams: solo(15), feature(5)

🔒 Permissions (all time)
| Tool  | Events |
|-------|--------|
| Bash  | 42     |
| Write | 15     |
Total: 57 events

🖥️ Sessions
Total: 23 sessions | Last: 2026-04-02 11:04 EDT
```

4. **If no logs exist**, inform the user that hooks need to run first to generate data.

## Notes

- All log files are local-only (not committed to git)
- JSONL format allows streaming reads without loading entire file
- Analytics are point-in-time snapshots, not persistent metrics
