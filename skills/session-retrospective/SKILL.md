---
name: session-retrospective
description: "End-of-session review. Capture lessons learned, update memory, note improvements, verify task completion. The self-improvement loop."
---

# Session Retrospective

## When to Run
- Before `/a-end` or `/a-handoff`
- When ending a work session
- After completing a major feature/phase

## Process

### 1. Task Completion Check
- Run TaskList → verify all tasks are completed or documented
- Any in_progress tasks → note what's remaining

### 2. Lessons Learned
- What surprised you? (unexpected complexity, gotchas)
- What worked well? (patterns, approaches to repeat)
- What would you do differently? (mistakes to avoid)

Save significant lessons to memory (if applicable):
```markdown
# memory/lessons.md (append)
- #{N}: {lesson} — {context}
```

### 3. Improvements Discovered
During the session, did you notice:
- Tech debt? (hardcoded values, duplicated code, missing tests)
- Performance issues? (slow queries, large bundles)
- Security gaps? (missing validation, RBAC holes)
- Documentation gaps? (missing docs, outdated docs)
- SOTA upgrades? (newer library versions, better patterns)

Add to `.blueprint/IMPROVEMENTS.md`:
```markdown
## {date} — Session: {description}

### 🔴 CRITICAL
- {issue}

### 🟡 IMPORTANT
- {issue}

### 🟢 NICE-TO-HAVE
- {issue}

### 🚀 SOTA
- {upgrade opportunity}
```

### 4. Plan Updates
- Were any plans modified? → update .blueprint/plans/INDEX.md
- New decisions made? → verify they're in decisions.jsonl
- Scope changed? → update the plan

### 5. Summary
Produce a concise session summary:

```
📋 Session Summary — {date}

✅ Completed: {list of completed tasks}
⏳ In Progress: {list of remaining tasks}
📝 Decisions: {key decisions made}
💡 Improvements: {N} items added to IMPROVEMENTS.md
🎓 Lessons: {key lessons}
```
