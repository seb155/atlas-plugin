---
name: cost-analytics
description: "Claude Code API cost tracking and analytics dashboard. Reads session JSONL files to calculate actual token usage and costs. Supports daily, weekly, monthly, sprint, and per-session views. Use when 'cost', 'usage', 'spending', 'tokens', 'how much', 'budget', 'API cost', '/atlas cost'."
effort: low
---

# Cost Analytics — Claude Code Usage Dashboard

Analyze Claude Code API token usage and costs from local session data. No external API needed — reads directly from `~/.claude/projects/*/*.jsonl`.

## Triggers

- `/atlas cost` or `/cost`
- "how much am I spending on Claude Code?"
- "show me my API costs"
- "token usage this week"
- "cost breakdown by model"

## Subcommands

| Command | Action |
|---------|--------|
| `/atlas cost` | Today's cost summary |
| `/atlas cost daily` | Last 7 days daily breakdown |
| `/atlas cost weekly` | Last 30 days weekly |
| `/atlas cost monthly` | All-time monthly |
| `/atlas cost session` | Per-session costs (last 3 days) |
| `/atlas cost sprint` | Current sprint (5-day window) |
| `/atlas cost status` | One-line for statusline |

## Execution Steps

### Step 1: Check data availability

```bash
SESSION_COUNT=$(find ~/.claude/projects/ -name "*.jsonl" 2>/dev/null | wc -l)
echo "Session files: $SESSION_COUNT"
ls -la ~/.claude/projects/ | head -5
```

### Step 2: Run cost analysis

**Primary method** (ccusage via bun — accurate pricing from LiteLLM):

```bash
# Daily (last 7 days) with per-model breakdown
bun x ccusage@latest daily --since $(date -d '-7 days' '+%Y%m%d') --breakdown

# Weekly summary
bun x ccusage@latest weekly --since $(date -d '-30 days' '+%Y%m%d') --breakdown

# Monthly
bun x ccusage@latest monthly --breakdown

# Per-session
bun x ccusage@latest session --since $(date -d '-3 days' '+%Y%m%d') --breakdown

# JSON output for automation
bun x ccusage@latest daily --since $(date -d '-7 days' '+%Y%m%d') --json --breakdown
```

**Fallback method** (direct JSONL parsing — no dependencies):

```bash
# Use the atlas cost CLI module
bash "${CLAUDE_PLUGIN_ROOT}/scripts/atlas-modules/cost.sh" daily
```

### Step 3: Present dashboard

Format the output as a structured dashboard:

```
ATLAS | Cost Analytics Dashboard
====================================

  Today: $XX.XX (Opus: $XX | Sonnet: $XX | Haiku: $XX)

  Last 7 Days
  | Date       | Sessions | Opus     | Sonnet  | Haiku   | Total    |
  |------------|----------|----------|---------|---------|----------|
  | 2026-04-08 | 5        | $112.06  | $2.58   | $4.88   | $119.52  |
  | 2026-04-07 | 8        | $400.75  | $4.07   | $7.70   | $412.52  |
  | ...        |          |          |         |         |          |
  | TOTAL      |          |          |         |         | $XXXX.XX |

  Model Distribution (7-day)
  | Model    | % of Cost | Avg/Day  |
  |----------|-----------|----------|
  | Opus     | 93.2%     | $XXX.XX  |
  | Sonnet   | 4.1%      | $XX.XX   |
  | Haiku    | 2.7%      | $XX.XX   |

  Cost Insights
  - Avg daily: $XX.XX
  - Projected monthly: $X,XXX
  - Opus/Sonnet ratio: X:1 (target <5:1)
  - Cache hit rate: XX%
```

### Step 4: Cost optimization recommendations

After presenting data, provide actionable insights:

1. **Model mix**: If Opus > 80% of cost, suggest more Sonnet delegation
2. **Cache efficiency**: High cache_read vs cache_write = good caching
3. **Sprint budget**: Compare actual vs expected ($100-200/week target)
4. **Session outliers**: Flag sessions > $50 for review

## Data Sources

| Source | Path | Content |
|--------|------|---------|
| Session JSONL | `~/.claude/projects/*/*.jsonl` | Token usage per API call (`message.usage`) |
| Session metadata | `~/.claude/sessions/*.json` | Session name, PID, start time |
| Stats cache | `~/.claude/stats-cache.json` | Historical daily activity (message/tool counts) |
| History | `~/.claude/history.jsonl` | Session display names and project paths |

## Pricing Reference (2026-04)

| Model | Input/MTok | Output/MTok | Cache Write/MTok | Cache Read/MTok |
|-------|-----------|-------------|------------------|-----------------|
| Opus 4.6 | $15.00 | $75.00 | $18.75 | $1.50 |
| Sonnet 4.6 | $3.00 | $15.00 | $3.75 | $0.30 |
| Haiku 4.5 | $0.25 | $1.25 | $0.3125 | $0.025 |

**Note**: Cache read tokens dominate cost for long sessions (often 90%+ of total tokens).
Opus cache read at $1.50/MTok is 5x more expensive than Sonnet cache read at $0.30/MTok.

## Notes

- All data is local-only, read from `~/.claude/projects/`
- ccusage fetches live pricing from LiteLLM API for accuracy
- Max plan ($200/mo subscription) users: `/cost` is informational only (usage included)
- API key users: costs are actual billing amounts
- The `--json` flag enables piping to jq for custom analysis
