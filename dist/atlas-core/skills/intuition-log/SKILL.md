---
name: intuition-log
description: "Capture a gut feeling or emerging pattern as a persistent intuition file. Use when 'intuition', 'intuition log', 'gut feeling', 'something feels off', 'I have a hunch', 'pattern emerging', 'j'ai un feeling'."
effort: medium
---

# Intuition Log — Tacit Knowledge Capture

> Capture gut feelings, hunches, and emerging patterns that haven't been formalized
> into decisions or lessons yet. Part of the SP-EXP Experiential Memory Layer (v4).

## When to Use

- When you express uncertainty: "something feels off about...", "I have a feeling..."
- When you notice a recurring pattern across sessions
- When a decision is made with low confidence (< 0.5)
- When you want to track a hunch until it's validated or refuted

## Steps

1. **Ask the feeling** via AskUserQuestion:
   "What's the gut feeling or pattern you're noticing?"
   - Free text input (no predefined options — creativity matters here)

2. **Ask supporting observations** via AskUserQuestion:
   "What observations support this intuition? (1-3)"
   - Free text for each observation

3. **Ask domain** via AskUserQuestion:
   "What domain does this relate to?"
   - Options: "Technical" / "Team" / "Strategic" / "Process" / "Product"

4. **Generate file** using the intuition template:
   ```yaml
   ---
   name: Intuition — {one-line description}
   description: {the gut feeling + domain in one sentence}
   type: intuition
   knowledge: tacit
   confidence: {0.4-0.5}  # Initial hunch = low confidence
   domain: {selected domain}
   pattern_source:
     - {observation 1}
     - {observation 2}
   confidence_trend: rising  # Just created
   validated: false
   ---
   ```

   Body includes:
   - **The Feeling**: User's own words
   - **Supporting Observations**: Table (observation, when, weight)
   - **If This Is True...**: Implications
   - **Validation Plan**: How to confirm or refute (table with checks)
   - **Status**: Checklist (accumulating → validated → action taken)

5. **HITL gate**: Present the complete intuition file for review
   - Options: "Write as-is" / "Edit" / "Skip"

6. **Write**: Save to `memory/intuition-{topic-slug}.md`

7. **Cross-reference**: If related to a recent decision in `.claude/decisions.jsonl`, add link

## Lifecycle

```
CREATED (0.3-0.5) → VALIDATING (0.5-0.7) → VALIDATED (0.7-1.0) → lesson/decision
                  → ARCHIVED (declining, >60d)
```

## Template Reference

For full template, read `${SKILL_DIR}/../memory-dream/references/intuition-template.md`
For schema, read `${SKILL_DIR}/../memory-dream/references/experiential-schema.md`
