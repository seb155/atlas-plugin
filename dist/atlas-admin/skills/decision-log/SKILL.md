---
name: decision-log
description: "Log architectural decisions to .claude/decisions.jsonl. Track non-obvious choices with context, alternatives, and rationale."
effort: low
---

# Decision Log

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
