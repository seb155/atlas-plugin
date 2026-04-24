---
name: user-profiler
description: "User profile builder and display. This skill should be used when the user asks to 'show my profile', 'who am I', 'update my profile', '/atlas profile', or when ATLAS needs to refresh the expertise map before personalized routing."
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

### Experiential Summary (v4)
If experiential data exists in memory files, display after Profile Stats:
- **Recent energy trend**: last 3 episodes' energy values as sparkline (e.g., `⚡ 7→8→6`)
- **Active relationships**: count of `relationship-*.md` files with interaction in last 30d
- **Last reflection**: date of most recent `reflection-*.md` file
- **Intuitions pending**: count of `intuition-*.md` files with `validated: false`
If no experiential data exists, show: `🧪 Experiential: No data yet — try /atlas episode create`

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

### Experiential Completeness (v4 sub-score)

In addition to the 7 core dimensions, compute an **Experiential Completeness** sub-score from 3 optional dimensions:

| Dimension | Source | Threshold |
|-----------|--------|-----------|
| Energy Awareness | `episode` memory files (with energy field) | 3 episodes in last 14d |
| Relational Depth | `relationship` memory files | 2 active relationships |
| Growth Tracking | `reflection` memory files | 1 reflection in last 30d |

Scoring: same formula `(coverage * 0.6) + (confidence * 0.4)`, reported separately as **Experiential: {N}%**.
These do NOT affect the main 7D score — they appear as a separate line in audit output.
If no experiential data exists, show: `Experiential: N/A — run /atlas episode create to start tracking.`

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
