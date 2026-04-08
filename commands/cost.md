# /cost - Claude Code Cost Analytics

Show Claude Code API usage costs. Reads local session JSONL files.

## Usage

```
/cost                    # Today's costs
/cost daily              # Last 7 days
/cost weekly             # Weekly summary  
/cost monthly            # Monthly summary
/cost sprint             # Current sprint (5 days)
/cost session            # Per-session breakdown
```

## Implementation

When `/cost` is invoked:

1. **Check bun availability**: `command -v bun`
2. **Run ccusage** with appropriate subcommand:

```bash
# Today
bun x ccusage@latest daily --since $(date '+%Y%m%d') --breakdown

# Daily (last 7 days)
bun x ccusage@latest daily --since $(date -d '-7 days' '+%Y%m%d') --breakdown

# Weekly
bun x ccusage@latest weekly --since $(date -d '-30 days' '+%Y%m%d') --breakdown

# Monthly
bun x ccusage@latest monthly --breakdown

# Per session
bun x ccusage@latest session --since $(date -d '-3 days' '+%Y%m%d') --breakdown

# Sprint (5 days)
bun x ccusage@latest daily --since $(date -d '-5 days' '+%Y%m%d') --breakdown
```

3. **Present summary** with:
   - Daily cost table (date, models, cost)
   - Model distribution (% Opus vs Sonnet vs Haiku)
   - Projected monthly cost
   - Optimization recommendations if Opus > 80% of spend

## Key Insights to Surface

- Average daily cost
- Projected monthly spend (daily_avg * 30)
- Model mix ratio (Opus should be < 30% of total for cost efficiency)
- Cache hit ratio (cache_read / (cache_read + input_tokens))
- Session outliers (any session > $50)

## Pricing Reference

| Model | Input | Output | Cache Write | Cache Read |
|-------|-------|--------|-------------|------------|
| Opus | $15/MTok | $75/MTok | $18.75/MTok | $1.50/MTok |
| Sonnet | $3/MTok | $15/MTok | $3.75/MTok | $0.30/MTok |
| Haiku | $0.25/MTok | $1.25/MTok | $0.31/MTok | $0.025/MTok |
