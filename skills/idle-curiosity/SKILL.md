---
name: idle-curiosity
description: "Autonomous exploration engine — discovers under-explored topics, unused skills, and knowledge gaps. CronCreate-based scheduling, max 1 exploration/day, HITL gate on every insight. SP-COGNITION Gap #5 (Curiosity-Driven Learning)."
effort: medium
---

# Idle Curiosity Engine — Autonomous Exploration

> SP-COGNITION Gap #5: Schmidhuber's Curiosity-Driven Learning applied to ATLAS.
> An AI that explores topics it hasn't been asked about, generating insights proactively.
> Every insight passes HITL review — the AI proposes, the human validates.

## When to Use

- `/atlas curiosity` or `/atlas explore` — trigger manual exploration
- Automatically via CronCreate during idle periods (max 1/day)
- During Dream cycle as an optional exploration phase
- User says "explore something", "what should I learn", "find gaps"

## Safety Constraints (NON-NEGOTIABLE)

1. **Max 1 exploration per day** — enforced via throttle file
2. **HITL on every insight** — never auto-save without human approval
3. **Context budget guard** — abort if context > 60% before starting
4. **No external actions** — read-only exploration (WebSearch, file reads, no writes without approval)
5. **Relevance filter** — only explore topics related to active projects or skills

## Process

### Step 1: Identify Exploration Targets

Score each candidate target and pick the highest-scoring one:

**Target Types** (sorted by discovery value):

| Type | Signal | Score |
|------|--------|-------|
| **Unused skill** | Skill exists in profile but never triggered (0 hook-log entries) | 8/10 |
| **Knowledge gap** | Domain referenced in KCs but no memory file exists | 7/10 |
| **Stale domain** | Memory file exists but not updated in 90+ days | 6/10 |
| **Adjacent tech** | Technology used in codebase but no skill/KC covers it | 5/10 |
| **Industry news** | Relevant domain (mining, I&C, EPCM) with recent developments | 4/10 |

**Implementation**:

```bash
# 1. Find unused skills (in profile but 0 entries in hook-log)
HOOK_LOG="$HOME/.claude/hook-log.jsonl"
ALL_SKILLS=$(yq -r '.skills[]' "$PROFILE_PATH" 2>/dev/null)
# Compare with skills triggered in last 30 days from hook-log

# 2. Find knowledge gaps
# Read MEMORY.md → extract referenced topics
# Check if each topic has a corresponding memory file
# Gap = referenced but no file exists

# 3. Find stale domains
# Memory files not modified in 90+ days (but still Tier 0-1)

# 4. Find adjacent tech from codebase
# Grep package.json, requirements.txt, docker-compose.yml for libraries
# Check if any skill covers that library
```

### Step 2: Explore Selected Target

Based on target type, use appropriate exploration method:

**For unused skills**:
```
1. Read the skill's SKILL.md
2. Identify 2-3 scenarios where it could help current work
3. Draft a "Quick Start" for the user
```

**For knowledge gaps**:
```
1. WebSearch for the topic + "best practices 2026"
2. Read top 2-3 results
3. Summarize key findings relevant to the project
```

**For stale domains**:
```
1. Read the existing memory file
2. Check if content is still accurate (WebSearch if needed)
3. Note what changed since last update
```

**For adjacent tech**:
```
1. Identify the library/tool from codebase
2. Check Context7 for latest docs
3. Surface 1-2 features the team might not know about
```

### Step 3: Generate Insight

Structure every insight as:

```markdown
---
name: Curiosity Insight — {topic}
description: "{1-line summary}"
type: reference
retention_tier: 1
source: idle-curiosity
exploration_date: {date}
target_type: {unused_skill|knowledge_gap|stale_domain|adjacent_tech|industry_news}
validated: false
---

# {Topic Title}

## Discovery
{2-3 sentences: what was explored and why}

## Key Findings
1. {finding 1}
2. {finding 2}
3. {finding 3}

## Relevance to Current Work
{1-2 sentences: how this connects to active projects}

## Suggested Action
{concrete next step the user could take}
```

### Step 4: HITL Gate (MANDATORY)

Present insight via AskUserQuestion:

```
🔍 Curiosity Insight: {topic}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{summary}

Key finding: {most interesting finding}
Relevance: {connection to current work}
```

Options:
- **Save** — Write to memory as `curiosity-{slug}.md`
- **Save + Act** — Write + create task for follow-up
- **Discard** — Not relevant, skip
- **Refine** — Explore deeper (uses additional context)

### Step 5: Scheduling (CronCreate)

When user runs `/atlas curiosity --schedule`:

```javascript
CronCreate({
  cron: "17 9 * * 1-5",  // Weekdays at 9:17 AM (off-minute)
  prompt: "Run /atlas curiosity — autonomous exploration. Check context budget first. If > 60%, skip. Otherwise, find the most interesting unexplored topic and present an insight for review.",
  recurring: true
})
```

**Scheduling rules**:
- Weekdays only (Mon-Fri)
- Morning (when energy is typically highest)
- Off-minute (9:17 not 9:00) to avoid API contention
- Auto-expires after 7 days (CC session limit)
- User re-enables each week consciously

## Context Budget Protection

Before ANY exploration:
```bash
# Check if context budget is safe
# If > 60% context used → skip this exploration
# If > 40% → limit to WebSearch only (no deep file reads)
# If < 40% → full exploration allowed
```

## Exploration Log

Each exploration (successful or skipped) is logged:

```jsonl
{"ts":"2026-04-04T09:17:00","target_type":"unused_skill","target":"network-audit","outcome":"saved","context_pct":35}
{"ts":"2026-04-05T09:17:00","target_type":"knowledge_gap","target":"plc-redundancy","outcome":"skipped:context_high","context_pct":72}
```

File: `~/.claude/atlas-curiosity-log.jsonl`

## Anti-Patterns (NEVER do)

- Never explore during active coding sessions (only when idle/fresh)
- Never write files without HITL approval
- Never explore the same topic twice within 30 days
- Never use more than 3 WebSearch calls per exploration
- Never explore topics outside the user's professional domain
- Never share exploration results externally

## Context

- **Inspiration**: Schmidhuber's "Curiosity-Driven Learning" — agents learn faster when they explore areas of maximal learning potential
- **Risk mitigation**: HITL + context guard + 1/day limit + relevance filter
- **Value**: Surfaces knowledge the user "doesn't know they don't know"
- **Memory**: Validated insights become Tier 1 (long-term) memory files
