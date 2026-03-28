---
name: ultrathink
description: "Deep reasoning mode. Activates maximum thinking budget (~32K tokens) for complex architectural decisions, risk assessment, and multi-angle analysis. Triggers on: /ultrathink, 'think deeply about', 'analyze thoroughly'."
effort: low
---

# Ultrathink -- Deep Reasoning Mode

Activate deep reasoning for the current question.
Maps to Claude Code's native `ultrathink` keyword (~32K thinking tokens).

## When to Use

- User says "ultrathink", "think deeply", "analyze thoroughly"
- Complex architectural decisions requiring multi-angle analysis
- Risk assessment with weighted criteria
- When standard reasoning isn't sufficient

## Process

1. Load current context: CLAUDE.md, active plan, MEMORY.md
2. Use maximum thinking effort (ultrathink keyword -- highest budget)
3. Analyze from multiple angles:
   - Technical feasibility
   - Architecture impact
   - Risk assessment
   - Alternative approaches
4. Present decision matrix with weighted criteria
5. Recommend with confidence level (HIGH/MEDIUM/LOW)

## Thinking Levels

| Level | Keyword | Budget | Use Case |
|-------|---------|--------|----------|
| Standard | `think` | ~4K tokens | Simple analysis |
| Deep | `think hard` | ~10K tokens | Moderate complexity |
| Maximum | `ultrathink` | ~32K tokens | Architecture, risk, multi-angle |

## Notes

- For simpler queries, use `/effort low|medium|high` instead
- Opus model recommended for maximum reasoning quality
- Present findings as decision matrix, not prose

ultrathink $ARGUMENTS
