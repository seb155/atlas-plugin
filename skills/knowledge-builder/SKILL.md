---
name: knowledge-builder
description: "Learn facts, preferences, relationships about the user. Confidence-based with reinforcement. Powers the ATLAS learning engine."
effort: medium
---

# Knowledge Builder

Extract, store, and reinforce structured knowledge about the user over time.

## Triggers

- User says "I prefer X", "remember that I...", "I always do Y"
- User corrects ATLAS (contradiction → update)
- User shares personal/professional info
- Repeated pattern observed (2+ occurrences)
- User asks "what do you know about me?"

## API

**Base**: `http://localhost:8001/api/v1/pa` | **Auth**: `Bearer $SYNAPSE_TOKEN`

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/knowledge` | GET | List all (optional: `?category=X&search=Y`) |
| `/knowledge/learn` | POST | Create or reinforce entry (UPSERT) |
| `/knowledge/{id}` | DELETE | Remove entry |

## Categories

| Category | Examples | Default Confidence |
|----------|----------|--------------------|
| `preference` | dark mode, concise answers | 0.8 (explicit) |
| `skill` | PLC programming, Python | 0.8 (explicit) |
| `goal` | ship Synapse v2 by Q2 | 0.8 (explicit) |
| `habit` | review PRs in morning | 0.6 (observed) |
| `context` | works on THM-012 | 0.8 (explicit) |
| `interest` | MBSE patterns | 0.6 (observed) |
| `relationship` | John = tech lead | 0.8 (explicit) |

## Confidence Rules (NON-NEGOTIABLE)

| Source | Confidence | Rule |
|--------|-----------|------|
| Explicit statement | 0.8 | User directly states fact |
| Observed (2+ times) | 0.6 | Repeated behavior noticed |
| Inferred | 0.4 | Deduced from indirect evidence |
| Reinforced | min(existing + 0.1, 1.0) | Each confirmation bumps |
| Contradicted | **HITL GATE** | AskUserQuestion: which is correct? |
| Decayed (90+ days) | existing - 0.1 | Stale knowledge loses confidence |

## Learning Flow

| Step | Action |
|------|--------|
| 1. Extract | Parse message → category, key (normalized), value, source |
| 2. Check | `GET /knowledge?category={cat}&search={key}` |
| 3a. Same value exists | POST `/knowledge/learn` → auto-reinforces (UPSERT bumps confidence +0.1) |
| 3b. Different value | **HITL GATE** — AskUserQuestion: (a) keep old (b) replace (c) both valid (context-dependent) |
| 3c. New entry | POST `/knowledge/learn` with `{category, key, value, confidence, source, metadata}` |

**POST body**: `{category, key, value, confidence, source, metadata: {learned_from, session_date}}`

**Display after learn**: `Learned: [{category}] {key} = "{value}" (confidence: {%})`
**Display after reinforce**: `Reinforced: [{category}] {key} = "{value}" (confidence: {%}, seen {N}x)`

## Periodic Review

When entries have low confidence or 90+ days stale, proactively suggest review via AskUserQuestion. Present as table: category, key, value, confidence, action needed.

## Passive Learning

- Watch for corrections → learn preference
- Track repeated patterns → learn after 2+ occurrences, then inform user
- Mentions of tools/people → build context entries
- Accumulate silently until threshold, then notify

## Privacy

- Per-user only, never shared
- User can view all: "what do you know about me?"
- User can delete: "forget that I prefer X" → `DELETE /knowledge/{id}`
- User can export all via API
