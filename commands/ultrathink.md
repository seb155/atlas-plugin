# /ultrathink — Deep reasoning mode

Activate deep reasoning for the current question.
Maps to Claude Code's native `ultrathink` keyword (~32K thinking tokens).

## Process

1. Load current context: CLAUDE.md, active plan, MEMORY.md
2. Use maximum thinking effort (ultrathink keyword — highest budget)
3. Analyze from multiple angles:
   - Technical feasibility
   - Architecture impact
   - Risk assessment
   - Alternative approaches
4. Present decision matrix with weighted criteria
5. Recommend with confidence level (HIGH/MEDIUM/LOW)

## Notes

- For simpler queries, use `/effort low|medium|high` instead
- Thinking levels: `think` (~4K) < `think hard` (~10K) < `ultrathink` (~32K tokens)
- Opus model recommended for maximum reasoning quality

ultrathink $ARGUMENTS
