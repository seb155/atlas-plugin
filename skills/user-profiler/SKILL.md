---
name: user-profiler
description: "Build and display the user's complete profile. Expertise map, interests, working style, relationships, goals. Human context engineering."
---

# User Profiler

Build and maintain a rich, structured profile of the user. Like CLAUDE.md is context
engineering for AI, this is **HUMAN.md** — context engineering for the human.
Powered by knowledge entries, relationships, and copilot profile data from the PA API.

## Commands

| Command | Action |
|---------|--------|
| `/atlas profile show` | Display the full profile card |
| `/atlas profile audit` | Score profile completeness, report gaps |
| `/atlas profile update` | Interactive gap-filling session |
| "show my profile" | Alias for profile show |
| "what do you know about me?" | Alias for profile show |
| "how complete is my profile?" | Alias for profile audit |

## API Configuration

**Base URL**: `http://localhost:8001/api/v1/pa`
**Auth**: `Authorization: Bearer $SYNAPSE_TOKEN`

## Profile Show

### Step 1 — Fetch all knowledge entries

```bash
curl -s "http://localhost:8001/api/v1/pa/knowledge" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN"
```

### Step 2 — Fetch relationships

```bash
curl -s "http://localhost:8001/api/v1/pa/knowledge?category=relationship" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN"
```

### Step 3 — Fetch copilot profile (if exists)

```bash
curl -s "http://localhost:8001/api/v1/pa/profile" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN"
```

### Step 4 — Compile and render the profile card

Organize entries by category and render as a rich ASCII profile:

```
+========================================================================+
|                        HUMAN PROFILE CARD                              |
+========================================================================+

  IDENTITY
  --------
  Name:       {from knowledge: identity.name}
  Role:       {from knowledge: context.role}
  Company:    {from knowledge: context.company}
  Location:   {from knowledge: context.location}
  Timezone:   {from knowledge: preference.timezone}

  EXPERTISE MAP
  -------------
  I&C Engineering    [##########--------]  90%   Expert
  Python             [########----------]  80%   Advanced
  PLC / Studio 5000  [########----------]  80%   Advanced
  React / TypeScript [######------------]  60%   Intermediate
  PostgreSQL         [#######-----------]  70%   Advanced
  DevOps / Docker    [######------------]  60%   Intermediate

  (Bars derived from skill entries — confidence = proficiency estimate)

  INTERESTS
  ---------
  - MBSE patterns for mining projects
  - AI-assisted engineering workflows
  - Deterministic rule engines
  - Enterprise architecture

  WORKING STYLE
  -------------
  Package Manager:    bun (never npm/yarn)
  Language:           French (Quebec) default, English for code
  Approach:           Sprints (3-5 days), completeness > speed
  Reviews:            {from habit entries}
  Communication:      {from preference entries}

  KEY RELATIONSHIPS
  -----------------
  {name}      {role}           {relationship_type}
  --------    ---------------  -------------------
  (From relationship knowledge entries)

  CURRENT GOALS
  -------------
  1. {from goal entries, sorted by confidence}
  2. ...

  PROFILE STATS
  -------------
  Total entries:      {count}
  High confidence:    {count >= 0.8}
  Needs review:       {count < 0.5}
  Last updated:       {most recent entry date}

+========================================================================+
```

Adapt sections based on available data. If a section has no entries, show it
with "No data yet — use `/atlas profile update` to add."

## Profile Audit

Score the profile across 7 dimensions. Each dimension is scored 0-100% based
on the number and confidence of knowledge entries in that category.

### Scoring Algorithm

For each dimension, calculate:
- **Coverage**: number of entries / expected minimum entries
- **Confidence**: average confidence of entries in category
- **Score**: (coverage * 0.6) + (confidence * 0.4), capped at 100%

### Dimensions & Expected Minimums

| Dimension | Category Filter | Min Entries | What to Look For |
|-----------|----------------|-------------|------------------|
| Identity | `context` keys: name, role, company, location | 4 | Basic who-am-I |
| Expertise | `skill` | 5 | Technical skills with proficiency |
| Interests | `interest` | 3 | What the user cares about |
| Habits | `habit` | 3 | Working patterns, routines |
| Relationships | `relationship` | 3 | Team, reports, collaborators |
| Goals | `goal` | 2 | Current objectives |
| Communication | `preference` keys: language, style, format | 3 | How user wants to interact |

### Audit Output

```
PROFILE COMPLETENESS AUDIT
==========================

  Dimension       Score    Status
  --------------- -------- --------
  Identity        100%     Complete
  Expertise        80%     Good
  Interests        60%     Fair
  Habits           33%     Gaps
  Relationships    0%      Missing
  Goals            50%     Fair
  Communication    66%     Fair

  OVERALL SCORE:  56%  (Fair — 4 dimensions need attention)

  GAPS DETECTED
  -------------
  - Missing: team structure (no relationship entries)
  - Missing: working hours / timezone preference
  - Low confidence: meeting preference (40%, needs confirmation)
  - Stale: project deadline goal (last seen 45 days ago)

  RECOMMENDED ACTIONS
  -------------------
  1. Run `/atlas profile update` to fill 3 critical gaps
  2. Review 2 low-confidence entries
  3. Add team/relationship context for better collaboration support
```

## Profile Update (Interactive Gap-Filling)

When gaps are detected, run an interactive session to fill them.

### Step 1 — Run audit to find gaps

### Step 2 — For each gap, ask ONE question at a time

Use AskUserQuestion for each gap. Keep questions natural and conversational:

- "What timezone do you work in?"
- "Who are the key people you work with? (name + role)"
- "What are your top 3 current goals?"
- "Do you prefer detailed or concise responses?"

### Step 3 — Save each answer via knowledge-builder

For each answer, use the knowledge learn endpoint:

```bash
curl -s -X POST http://localhost:8001/api/v1/pa/knowledge/learn \
  -H "Authorization: Bearer $SYNAPSE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "category": "context",
    "key": "timezone",
    "value": "EST (UTC-5)",
    "confidence": 0.9,
    "source": "explicit"
  }'
```

Confidence for profile update answers = 0.9 (user explicitly provided during dedicated session).

### Step 4 — Show progress after each answer

```
Profile update: 5/8 gaps filled
  [x] Timezone: EST
  [x] Team lead: John Smith
  [x] Working hours: 8am-5pm
  [ ] Communication style
  [ ] Meeting preferences
  ...
```

### Step 5 — Final audit after completion

Re-run audit and show improvement:

```
Profile completeness: 56% -> 82%  (+26%)
  Relationships: 0% -> 66% (added 2 entries)
  Communication: 66% -> 100% (filled 1 gap)
```

## The HUMAN.md Concept

Just as CLAUDE.md provides context for AI, this profile is the human equivalent:
- **CLAUDE.md** = "Here's how to work with this codebase"
- **HUMAN.md** = "Here's how to work with this person"

The profile enables ATLAS to:
- Adapt communication style to the user's preferences
- Route tasks based on expertise
- Respect working hours and timezone
- Reference relationships in context
- Track progress toward goals
- Provide increasingly personalized assistance over time

## Privacy & Control (NON-NEGOTIABLE)

- **Per-user**: Profile data is strictly per-user, never shared
- **Viewable**: User can see everything stored about them at any time
- **Editable**: User can modify any entry via conversation or API
- **Deletable**: User can delete any entry or wipe entire profile

```bash
# View all knowledge
curl -s "http://localhost:8001/api/v1/pa/knowledge" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN"

# Delete specific entry
curl -s -X DELETE "http://localhost:8001/api/v1/pa/knowledge/{entry_id}" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN"

# Delete all knowledge (full reset)
curl -s -X DELETE "http://localhost:8001/api/v1/pa/knowledge/reset" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN"
```

- User must explicitly consent to profile building (first-time HITL gate)
- No data leaves the local Synapse instance
- No third-party services involved
