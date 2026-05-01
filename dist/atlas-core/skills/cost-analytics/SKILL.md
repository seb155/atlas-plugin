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
| `/atlas cost --tree [--depth N] [--window 1d\|7d\|30d]` | Call-tree attribution (skill→subagent→tool) — W1.4 |
| `/atlas cost --flame [--window 1d\|7d\|30d]` | ASCII flame graph: per-skill % cost with proportional bars — W1.4 |
| `/atlas cost --per-skill [--window 7d\|30d\|sprint]` | Aggregated total $ per skill (rolling window) — W1.4 |

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

## Call-Tree Attribution (W1.4)

Beyond aggregate spend, ATLAS attributes cost down the **invocation chain** so you can answer
"which skill is burning my budget?" rather than just "which model?".

### Attribution model

```
session_root
├── skill_invocation (top-level Task / SlashCommand / atlas-* skill name)
│   ├── tool_use (Read/Edit/Bash/Grep/...)
│   └── subagent_spawn (sidechain JSONL in subagents/<id>.jsonl)
│       ├── tool_use ...
│       └── tool_use ...
└── skill_invocation ...
```

- **Root**: each `~/.claude/projects/<proj>/<session>.jsonl` line with `"type":"assistant"`.
- **Skill detection**: heuristic matches on `slug` field (frontmatter `name:` from invoked skill),
  Task tool calls (`subagent_type` parameter), or SlashCommand text. Fallback bucket = `__root__`.
- **Subagent edges**: subagent JSONLs live in `subagents/agent-<id>.jsonl` next to the parent
  session. Parent linkage is via the `Task` tool_use_id that spawned them.
- **Cost per node**: sum of `message.usage` weighted by 2026-04 pricing table below
  (input + output + cache_creation + cache_read).

### `atlas cost --tree`

Renders skill→subagent→tool breakdown as ASCII tree, depth-bounded.

```bash
# Default: last 1 day, depth 3
atlas cost --tree

# Custom window + depth
atlas cost --tree --window 7d --depth 4

# Filter to a single skill
atlas cost --tree --window 7d --skill memory-dream
```

Sample output:

```
ATLAS | Cost Call-Tree (last 7d)  total=$12.07
================================================
__root__                                $4.08  (33.8%)
├── memory-dream                        $4.20  (34.8%)
│   ├── Bash                            $0.18
│   ├── Read                            $0.07
│   └── Task → context-discovery        $1.92
│       ├── Grep                        $0.04
│       └── Read                        $0.83
├── code-review                         $2.41  (20.0%)
│   ├── Read                            $0.61
│   └── Task → senior-review-checklist  $1.10
└── plan-builder                        $1.38  (11.4%)
    └── Bash                            $0.12
```

### `atlas cost --flame`

Right-aligned ASCII flame graph — bar length proportional to $ spend.

```bash
atlas cost --flame --window 7d
```

Sample output:

```
ATLAS | Cost Flame Graph (last 7d)  total=$12.07
================================================
memory-dream            $4.20 (34.8%)  ████████████████████
__root__                $4.08 (33.8%)  ███████████████████
code-review             $2.41 (20.0%)  ███████████
plan-builder            $1.38 (11.4%)  ██████
─ scale: 1 block ≈ $0.20 ──────────────────────────
```

### `atlas cost --per-skill`

Plain table: total $, % share, calls, avg $/invocation. Sorted DESC by spend.

```bash
atlas cost --per-skill --window 30d
```

```
| Skill                    | Total $  | %     | Calls | $/call  |
|--------------------------|----------|-------|-------|---------|
| memory-dream             | $42.10   | 28.4% | 14    | $3.01   |
| code-review              | $28.55   | 19.3% | 22    | $1.30   |
| plan-builder             | $17.90   | 12.1% | 8     | $2.24   |
| __root__                 | $58.55   | 39.5% | n/a   | n/a     |
```

### Implementation notes (for the agent rendering this)

The aggregator is a thin Python parser invoked by the bash module — fall back to it because
ccusage is intentionally model-only (no per-skill granularity).

```bash
python3 - <<'PY'
import json, os, glob, time
from collections import defaultdict

PRICE = {  # 2026-04 — keep in sync with table below
    "claude-opus-4-7":     (5.00, 25.00, 6.25, 0.50),
    "claude-opus-4-6":     (15.00, 75.00, 18.75, 1.50),
    "claude-sonnet-4-6":   (3.00, 15.00, 3.75, 0.30),
    "claude-haiku-4-5":    (0.25, 1.25, 0.3125, 0.025),
}
def cost(model, u):
    if not model or not u: return 0.0
    p = next((v for k,v in PRICE.items() if k in model), PRICE["claude-sonnet-4-6"])
    return (u.get("input_tokens",0)*p[0] + u.get("output_tokens",0)*p[1]
          + u.get("cache_creation_input_tokens",0)*p[2]
          + u.get("cache_read_input_tokens",0)*p[3]) / 1_000_000

WIN = int(os.environ.get("ATLAS_COST_WINDOW_DAYS","1"))
cutoff = time.time() - WIN*86400
totals = defaultdict(float)
tool_totals = defaultdict(lambda: defaultdict(float))
calls = defaultdict(int)

current_skill = "__root__"
for jsonl in glob.glob(os.path.expanduser("~/.claude/projects/*/*.jsonl")):
    if os.path.getmtime(jsonl) < cutoff: continue
    try:
        for line in open(jsonl, "r", errors="ignore"):
            try: d = json.loads(line)
            except: continue
            slug = d.get("slug")
            if slug:
                current_skill = slug
                calls[slug] += 1
            if d.get("type") != "assistant": continue
            msg = d.get("message") or {}
            c = cost(msg.get("model"), msg.get("usage") or {})
            totals[current_skill] += c
            for blk in msg.get("content", []) or []:
                if isinstance(blk, dict) and blk.get("type") == "tool_use":
                    tool_totals[current_skill][blk.get("name","?")] += c
                    break
    except Exception:
        continue

# subagent (sidechain) JSONLs
for sub in glob.glob(os.path.expanduser("~/.claude/projects/*/*/subagents/*.jsonl")):
    if os.path.getmtime(sub) < cutoff: continue
    for line in open(sub, "r", errors="ignore"):
        try: d = json.loads(line)
        except: continue
        if d.get("type") != "assistant": continue
        msg = d.get("message") or {}
        totals["Task→subagent"] += cost(msg.get("model"), msg.get("usage") or {})

grand = sum(totals.values()) or 1.0
for skill, amt in sorted(totals.items(), key=lambda kv: -kv[1]):
    print(f"{skill:30s} ${amt:7.2f}  ({100*amt/grand:5.1f}%)")
PY
```

The above is a **reference implementation**; the production parser belongs in
`scripts/atlas-modules/cost.sh` (extended with `--tree`/`--flame`/`--per-skill` flags). Keep
the bash CLI as the user-facing entrypoint; embed Python only for JSON math.

### Verification

```bash
# Locate a recent session
SESSION=$(ls -t ~/.claude/projects/*/*.jsonl 2>/dev/null | head -1)
[ -n "$SESSION" ] && echo "Newest session: $SESSION"

atlas cost --tree --window 1d --depth 3
atlas cost --flame --window 7d
atlas cost --per-skill --window 7d
```

Expected: top-5 skills ranked by $ with non-zero totals when ≥1 assistant turn lands in the
window. Empty window prints "no sessions in window" and exits 0.

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
| Opus 4.7 | $5.00 | $25.00 | $6.25 | $0.50 |
| Sonnet 4.6 | $3.00 | $15.00 | $3.75 | $0.30 |
| Haiku 4.5 | $0.25 | $1.25 | $0.3125 | $0.025 |

**Note**: Cache read tokens dominate cost for long sessions (often 90%+ of total tokens).
Opus 4.7 cache read at $0.50/MTok is 1.67x more expensive than Sonnet cache read at $0.30/MTok (down from 5x with 4.6).
Opus 4.7 uses new tokenizer that may produce up to +35% tokens vs 4.6 for same text — monitor effective cost.

## Notes

- All data is local-only, read from `~/.claude/projects/`
- ccusage fetches live pricing from LiteLLM API for accuracy
- Max plan ($200/mo subscription) users: `/cost` is informational only (usage included)
- API key users: costs are actual billing amounts
- The `--json` flag enables piping to jq for custom analysis
