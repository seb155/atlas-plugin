---
name: episode-create
description: "Create a narrative episode file capturing the current session's experiential context — energy, mood, confidence, flow state. Use when 'episode', 'episode create', 'capture session', 'save episode', 'experiential capture', 'how did this session feel', 'session narrative'."
effort: medium
---

# Episode Create — Experiential Session Capture

> Create a rich narrative episode file from the current session. Captures not just WHAT happened,
> but HOW it felt — energy levels, mood, flow state, decision confidence, and energy arc.
> Part of the SP-EXP Experiential Memory Layer (v4).

## When to Use

- End of a significant session (2h+, major decisions, breakthroughs, or frustration)
- When session-start suggests: "Previous session had signals. /atlas episode create to capture."
- When you want to preserve the experiential context, not just the technical facts
- Target: 2-4 episodes per week for good experiential coverage

## Steps

1. **Read signals**: Load `~/.claude/atlas-experiential-signals.json` if it exists (accumulated by auto-learn hook during session)

2. **Read session context**: Scan the current conversation for:
   - Tasks completed
   - Files modified
   - Decisions made
   - Blockers hit
   - Pivots or direction changes

3. **Synthesize narrative**: Generate a narrative episode (NOT a task list — a STORY) with:
   - **The Story**: 2-3 paragraph narrative in first person about what happened and how it felt
   - **Key Moments**: Table with time, moment, energy, significance
   - **Decisions Made**: Table with decision, confidence, reversibility, context
   - **Energy Arc**: Description of the energy trajectory through the session
   - **What I'd Tell My Future Self**: 1-3 sentences of experiential advice (not technical — that's in handoffs)
   - **Patterns Noticed**: Recurring observations across sessions

4. **Auto-populate frontmatter**:
   ```yaml
   ---
   name: Episode — {one-line theme}
   description: {2-sentence narrative summary including emotional arc}
   type: episode
   knowledge: experiential
   energy: {1-5}           # Median of signals, or ask if none
   mood: {string}           # Dominant mood signal, or ask
   confidence: {0.0-1.0}    # Average of decision-related signals
   time_quality: {deep|focused|fragmented|interrupted|recovery}
   flow_state: {boolean}    # true if 2+ "deep focus" signals
   energy_arc: {steady|rising|declining|peak-then-crash}
   duration_minutes: {int}
   session_id: {string}
   key_decisions:
     - {decision 1}
     - {decision 2}
   blockers_hit:
     - {blocker 1}
   ---
   ```
   If no signals file exists, ask the user via AskUserQuestion for energy (1-5) and mood.

5. **HITL gate**: Present the complete episode via AskUserQuestion:
   - Options: "Write as-is" / "Edit (let me adjust)" / "Skip"

6. **Write**: Save to `memory/episode-YYYY-MM-DD.md`
   - If same day exists: use `episode-YYYY-MM-DD-2.md`, `-3.md`, etc.

7. **Cleanup**: Delete `~/.claude/atlas-experiential-signals.json` after successful write

8. **Index update**: Check if MEMORY.md has `## EXPERIENTIAL CONTEXT` section
   - If yes: update episode count
   - If no: add the section:
     ```markdown
     ## EXPERIENTIAL CONTEXT

     | Type | Count | Latest | Note |
     |------|-------|--------|------|
     | Episodes | {N} | {date} | |
     | Relationships | {N} | — | |
     | Intuitions | {N} | — | |
     | Reflections | {N} | — | |
     ```

## Episode vs Other Memory Types

| Aspect | Episode | Session Log | Handoff | Reflection |
|--------|---------|-------------|---------|------------|
| **Focus** | How it FELT | What was DONE | How to RESUME | What was LEARNED |
| **Tone** | Narrative, personal | Factual, terse | Technical, actionable | Analytical, growth |
| **Energy/Mood** | Required | Not captured | Not captured | Aggregated |

## Template Reference

For the full template format, read `${SKILL_DIR}/../memory-dream/references/episode-template.md`
For the frontmatter schema, read `${SKILL_DIR}/../memory-dream/references/experiential-schema.md`
