---
name: decision-log
description: "Log architectural decisions to .claude/decisions.jsonl. Track non-obvious choices with context, alternatives, and rationale."
effort: low
---

# Decision Log

## Red Flags (rationalization check)

Before deferring a decision-log entry, ask yourself — are any of these thoughts running? If yes, STOP. Unlogged decisions are lost within 2 compactions.

| Thought | Reality |
|---------|---------|
| "I'll remember why we picked this" | You won't. Future-you in 3 weeks has forgotten the alternatives. Log it. |
| "Not architectural enough to log" | Lib choice, data model, pattern = architectural. Low bar. Err on logging. |
| "The plan documents it, no need for JSONL" | Plans get archived. `.claude/decisions.jsonl` is append-only and grep-friendly. Dual-write. |
| "I'll log at session-end in retrospective" | Decisions at session-end lose context (rationale fades by evening). Log now. |
| "Alternatives field is padding" | "Rejected because" is the #1 reason future-you understands the decision. Fill it. |
| "Reversibility is obvious" | EASY / MODERATE / HARD flag guides future refactor risk calculation. State it. |
| "ATLAS_TOPIC is set, but topic memory is redundant" | Dual-write to `.claude/topics/${ATLAS_TOPIC}/decisions.md` — topic context survives branches. |

## When to Log
- Choosing between 2+ approaches
- Selecting a library/framework
- Designing a data model
- Any non-obvious technical choice
- Anything future sessions should know about

## Format

Append to `.claude/decisions.jsonl` (one JSON object per line):

```json
{
  "date": "2026-03-15",
  "subsystem": "rule-engine",
  "decision": "Use JsonLogic for rule conditions",
  "context": "Need a format that works in both Python and JavaScript for rule evaluation",
  "alternatives": [
    {"name": "Rete algorithm", "rejected_because": "Overkill for 500 rules, complex to implement"},
    {"name": "Custom DSL", "rejected_because": "Maintenance burden, no ecosystem"},
    {"name": "Raw SQL conditions", "rejected_because": "Not portable, hard to build UI for"}
  ],
  "rationale": "JsonLogic is standard, RAQB exports to it natively, Python library exists",
  "source": "Context7 @react-awesome-query-builder, WebSearch 'rule engine patterns 2026'",
  "impact": "All rule conditions stored as JSONB, evaluated client and server side",
  "reversibility": "Medium — would require migrating all condition data"
}
```

## Integration with Plans
When making decisions during planning (Section C):
- Log the decision
- Reference it in the plan: "See decision log: {date} {decision}"
- Future sessions can grep decisions.jsonl for context

---

## Topic Memory (SP-ECO v4)

When `ATLAS_TOPIC` env var is set (topic-based session), ALSO write decisions to topic memory.
This is a **DUAL WRITE** — the existing `.claude/decisions.jsonl` write stays unchanged.

### Process

1. Check if `.claude/topics/${ATLAS_TOPIC}/` directory exists
2. If yes: append decision to `.claude/topics/${ATLAS_TOPIC}/decisions.md` in markdown format:

```markdown
## Decision: {title}
**Date**: {YYYY-MM-DD HH:MM TZ}
**Context**: {what prompted this decision}
**Choice**: {what was decided}
**Alternatives rejected**: {what was NOT chosen and why}
**Confidence**: {high/medium/low}
**Reversibility**: {easily reversible / hard to reverse / irreversible}
```

3. Append using bash:
   ```bash
   TOPIC_DIR=".claude/topics/${ATLAS_TOPIC}"
   if [ -d "$TOPIC_DIR" ]; then
     cat >> "$TOPIC_DIR/decisions.md" << 'DECISION'
   ## Decision: {title}
   **Date**: {date}
   **Context**: {context}
   **Choice**: {choice}
   **Alternatives rejected**: {alternatives}
   **Confidence**: {confidence}
   **Reversibility**: {reversibility}

   DECISION
   fi
   ```

4. Topic `decisions.md` is **markdown** (not JSONL) for human readability in topic context
5. If the file doesn't exist yet, create it with a header:
   ```markdown
   # Decisions — {ATLAS_TOPIC}
   > Topic-scoped decision log. See also: `.claude/decisions.jsonl` (global)
   ```
