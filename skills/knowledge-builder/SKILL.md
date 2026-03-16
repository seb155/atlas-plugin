---
name: knowledge-builder
description: "Learn facts, preferences, relationships about the user. Confidence-based with reinforcement. Powers the ATLAS learning engine."
---

# Knowledge Builder

Extract, store, and reinforce knowledge about the user. This skill powers the ATLAS
learning engine — building a structured understanding of the user over time through
explicit statements, observed patterns, and inferred context.

## Trigger Phrases

Activate this skill when:
- User says "I prefer X", "I always do Y", "remember that I..."
- User corrects ATLAS: "no, I like X not Y" (contradiction = update)
- User shares personal/professional info: "I work at...", "my team uses..."
- ATLAS observes a repeated pattern (2+ occurrences in session)
- User asks: "what do you know about me?", "what have you learned?"

## API Configuration

**Base URL**: `http://localhost:8001/api/v1/pa`
**Auth**: `Authorization: Bearer $SYNAPSE_TOKEN`

## Knowledge Categories

| Category | Examples | Default Confidence |
|----------|----------|--------------------|
| `preference` | "I prefer dark mode", "I like concise answers" | 0.8 (explicit) |
| `skill` | "I'm expert in PLC programming", "I know Python" | 0.8 (explicit) |
| `goal` | "I want to ship Synapse v2 by Q2" | 0.8 (explicit) |
| `habit` | "I usually review PRs in the morning" | 0.6 (observed) |
| `context` | "I work on THM-012 project" | 0.8 (explicit) |
| `interest` | "I'm interested in MBSE patterns" | 0.6 (observed) |
| `relationship` | "John is my tech lead", "I report to Marie" | 0.8 (explicit) |

## Confidence Rules (NON-NEGOTIABLE)

| Source | Initial Confidence | Rule |
|--------|-------------------|------|
| Explicit statement | 0.8 | User directly states a fact |
| Observed pattern (2+ times) | 0.6 | ATLAS notices repeated behavior |
| Inferred from context | 0.4 | ATLAS deduces from indirect evidence |
| Reinforced (seen again) | min(existing + 0.1, 1.0) | Each confirmation bumps confidence |
| Contradicted | **HITL GATE** | Ask user which value is correct |
| Decayed (90+ days no reinforcement) | existing - 0.1 | Stale knowledge loses confidence |

## Learning a New Fact

### Step 1 — Extract knowledge from conversation

Parse the user's message or observed behavior to identify:
- **category**: One of the categories above
- **key**: Normalized identifier (e.g. `preferred_editor`, `expertise_plc`, `team_lead`)
- **value**: The knowledge value (string, can be structured)
- **source**: How this was learned (`explicit`, `observed`, `inferred`)

### Step 2 — Check for existing knowledge

```bash
# Search for existing entry with same key
curl -s "http://localhost:8001/api/v1/pa/knowledge?category={category}&search={key}" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN"
```

If an entry exists with the **same value** → reinforce (Step 3a).
If an entry exists with a **different value** → contradiction (Step 3b).
If no entry exists → create new (Step 3c).

### Step 3a — Reinforce existing knowledge

The UPSERT endpoint handles this automatically — it increments `reinforcement_count`
and bumps confidence by 0.1 (capped at 1.0) on conflict.

```bash
curl -s -X POST http://localhost:8001/api/v1/pa/knowledge/learn \
  -H "Authorization: Bearer $SYNAPSE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "category": "preference",
    "key": "editor",
    "value": "neovim",
    "confidence": 0.8,
    "source": "explicit"
  }'
```

Show: `Reinforced: [preference] editor = neovim (confidence: 90%, seen 3x)`

### Step 3b — HITL Gate: Contradiction detected

When the new value contradicts an existing entry, STOP and ask the user:

```
Contradiction detected:
  Existing: [preference] editor = vscode (confidence: 80%, seen 2x)
  New:      [preference] editor = neovim (source: explicit)

Which is correct?
  (a) Keep "vscode" (ignore new)
  (b) Update to "neovim" (replace)
  (c) Both are valid (context-dependent — explain when each applies)
```

Use AskUserQuestion. Never silently overwrite.

### Step 3c — Create new knowledge

```bash
curl -s -X POST http://localhost:8001/api/v1/pa/knowledge/learn \
  -H "Authorization: Bearer $SYNAPSE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "category": "skill",
    "key": "plc_programming",
    "value": "Expert — Studio 5000, PlantPAx 5.20, structured text",
    "confidence": 0.8,
    "source": "explicit",
    "metadata": {
      "learned_from": "conversation",
      "session_date": "2026-03-15"
    }
  }'
```

Show: `Learned: [skill] plc_programming = "Expert — Studio 5000, PlantPAx 5.20" (confidence: 80%)`

## Querying Knowledge

### List all knowledge
```bash
curl -s "http://localhost:8001/api/v1/pa/knowledge" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN"
```

### Filter by category
```bash
curl -s "http://localhost:8001/api/v1/pa/knowledge?category=preference" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN"
```

### Search knowledge
```bash
curl -s "http://localhost:8001/api/v1/pa/knowledge?search=python" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN"
```

Display as table:

```
| Category   | Key              | Value                     | Confidence | Seen |
|------------|------------------|---------------------------|------------|------|
| preference | editor           | neovim                    | 90%        | 3x   |
| skill      | plc_programming  | Expert — Studio 5000      | 80%        | 1x   |
| goal       | synapse_v2_ship  | Ship by Q2 2026           | 80%        | 2x   |
| habit      | pr_review_time   | Morning (before standup)  | 60%        | 2x   |
```

## Periodic Review

When confidence is low or knowledge is stale, proactively suggest a review:

```
Knowledge review suggested (3 low-confidence entries):
  [habit] meeting_preference = "async over sync" (40%, inferred)
  [interest] rust_adoption = "considering for CLI tools" (40%, inferred)
  [context] team_size = "5 engineers" (50%, observed once)

Want to confirm, update, or remove these?
```

Use AskUserQuestion for the review.

## Passive Learning (Background)

During normal conversation, watch for learnable signals:
- User corrects ATLAS behavior → learn the preference
- User repeatedly uses a pattern → observe and learn after 2+ occurrences
- User mentions tools, frameworks, people → build context entries

For passive observations, accumulate silently until 2+ occurrences, then inform:
```
Pattern observed: You've mentioned using "bun" instead of "npm" 3 times.
Learned: [preference] package_manager = bun (confidence: 60%, observed)
```

## Privacy & Control

- All knowledge is per-user, never shared across users
- User can view all entries: "what do you know about me?"
- User can delete any entry: "forget that I prefer X"
- User can export all knowledge (via API)
- No knowledge is used outside the user's own sessions

```bash
# Delete a knowledge entry
curl -s -X DELETE "http://localhost:8001/api/v1/pa/knowledge/{entry_id}" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN"
```
