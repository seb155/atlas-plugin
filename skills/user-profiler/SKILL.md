---
name: user-profiler
description: "Build and display the user's complete profile. Expertise map, interests, working style, relationships, goals. Human context engineering."
effort: medium
---

# User Profiler

**HUMAN.md** — context engineering for the human. Powered by PA API knowledge entries.

## Commands

| Command | Action |
|---------|--------|
| `/atlas profile show` | Display full profile card |
| `/atlas profile audit` | Score completeness, report gaps |
| `/atlas profile update` | Interactive gap-filling session |
| "show my profile" / "what do you know about me?" | Alias for show |
| "how complete is my profile?" | Alias for audit |

## API

**Base**: `http://localhost:8001/api/v1/pa` | **Auth**: `Bearer $SYNAPSE_TOKEN`

| Endpoint | Purpose |
|----------|---------|
| `GET /knowledge` | All knowledge entries |
| `GET /knowledge?category=relationship` | Relationships only |
| `GET /profile` | Copilot profile |
| `POST /knowledge/learn` | Save entry `{category, key, value, confidence, source}` |
| `DELETE /knowledge/{id}` | Delete entry |
| `DELETE /knowledge/reset` | Full reset |

## Profile Show

1. Fetch all knowledge entries + relationships + copilot profile
2. Render ASCII profile card with sections: **Identity**, **Expertise Map** (bar charts from skill confidence), **Interests**, **Working Style**, **Key Relationships**, **Current Goals**, **Profile Stats**
3. Empty sections show "No data yet — use `/atlas profile update` to add."

## Profile Audit

Score 7 dimensions: `(coverage * 0.6) + (confidence * 0.4)`, capped 100%.

| Dimension | Category Filter | Min Entries |
|-----------|----------------|-------------|
| Identity | `context` (name, role, company, location) | 4 |
| Expertise | `skill` | 5 |
| Interests | `interest` | 3 |
| Habits | `habit` | 3 |
| Relationships | `relationship` | 3 |
| Goals | `goal` | 2 |
| Communication | `preference` (language, style, format) | 3 |

Output: dimension scores + overall % + gaps detected + recommended actions.

## Profile Update (Interactive)

1. Run audit to find gaps
2. AskUserQuestion for each gap (ONE at a time, natural language)
3. Save via `POST /knowledge/learn` with `confidence: 0.9` (explicit source)
4. Show progress tracker after each answer
5. Re-run audit, show improvement delta

## Privacy & Control (NON-NEGOTIABLE)

| Rule | Detail |
|------|--------|
| Per-user | Never shared across users |
| Viewable | User sees everything stored |
| Editable | Modify any entry via conversation or API |
| Deletable | Delete any entry or full reset |
| Consent | First-time HITL gate required |
| Local | No data leaves Synapse instance |
