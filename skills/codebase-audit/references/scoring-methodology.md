# Codebase Audit — Scoring Methodology

## 1. Scoring Formula

```
# Per dimension
base_score      = 10.0
deductions      = P0 * 2.0 + P1 * 1.0 + P2 * 0.5 + P3 * 0.2
bonuses         = min(0.5, CI * 0.2 + docs * 0.2 + resolved * 0.1)
dimension_score = clamp(0, 10, base_score - deductions + bonuses)

# Overall
weighted_score = SUM( dimension_score[i] * weight_pct[i] )   # weights sum to 1.0
```

## 2. Grade Mapping

| Grade | Range | Meaning |
|-------|-------|---------|
| A+ | >= 9.5 | Exceptional — industry-leading |
| A  | >= 9.0 | Excellent — ready for scrutiny |
| A- | >= 8.5 | Very good — minor polish only |
| B+ | >= 8.0 | Good — standard best practices |
| B  | >= 7.5 | Above average — some gaps |
| B- | >= 7.0 | Adequate — notable gaps in 1-2 areas |
| C  | >= 6.0 | Below average — systematic remediation |
| D  | >= 5.0 | Poor — address before production |
| F  | < 5.0  | Failing — fundamental issues |

## 3. Preset Weights (%)

Each row sums to 100.

| Dimension | generic | synapse | saas | library |
|-----------|---------|---------|------|---------|
| security | 5 | 14 | 11 | 4 |
| testing | 5 | 10 | 10 | 18 |
| enterprise | 5 | 12 | 2 | 0 |
| data_integrity | 5 | 10 | 1 | 0 |
| architecture | 5 | 8 | 6 | 6 |
| observability | 5 | 4 | 5 | 2 |
| compliance | 5 | 4 | 2 | 0 |
| code_quality | 5 | 5 | 6 | 7 |
| dep_health | 5 | 4 | 4 | 6 |
| documentation | 5 | 4 | 3 | 15 |
| type_safety | 5 | 4 | 5 | 10 |
| infrastructure | 5 | 3 | 3 | 0 |
| dx | 5 | 3 | 8 | 8 |
| ai_readiness | 5 | 3 | 2 | 3 |
| tech_debt | 5 | 3 | 3 | 4 |
| api_design | 5 | 3 | 5 | 12 |
| performance | 5 | 2 | 10 | 5 |
| accessibility | 5 | 2 | 7 | 1 |
| i18n | 5 | 1 | 4 | 1 |
| cost_efficiency | 5 | 1 | 3 | 1 |

## 4. Industry Benchmarks

| Dimension | Median | Top 10% | Top 1% |
|-----------|--------|---------|--------|
| security | 6.5 | 8.5 | 9.5 |
| testing | 5.5 | 8.0 | 9.2 |
| enterprise | 5.0 | 7.5 | 9.0 |
| data_integrity | 6.0 | 8.0 | 9.3 |
| architecture | 6.0 | 8.0 | 9.0 |
| observability | 4.5 | 7.5 | 9.0 |
| compliance | 5.0 | 7.0 | 8.8 |
| code_quality | 6.0 | 8.5 | 9.5 |
| dep_health | 5.5 | 8.0 | 9.2 |
| documentation | 4.0 | 7.0 | 8.5 |
| type_safety | 5.0 | 8.0 | 9.5 |
| infrastructure | 5.5 | 7.5 | 9.0 |
| dx | 5.0 | 7.5 | 9.0 |
| ai_readiness | 3.0 | 6.5 | 8.5 |
| tech_debt | 5.0 | 7.5 | 9.0 |
| api_design | 5.5 | 8.0 | 9.2 |
| performance | 6.0 | 8.5 | 9.5 |
| accessibility | 4.0 | 7.0 | 9.0 |
| i18n | 3.5 | 6.5 | 8.5 |
| cost_efficiency | 5.0 | 7.5 | 9.0 |

## 5. Score History JSONL Schema

Append one JSON per line to `.blueprint/_audit-history/codebase-audit-history.jsonl`:

```json
{
  "version": "1.0",
  "date": "2026-04-08T15:30:00Z",
  "git_sha": "abc1234",
  "git_branch": "main",
  "preset": "synapse",
  "overall_score": 7.8,
  "grade": "B+",
  "dimensions": {
    "security": {"score": 8.2, "grade": "B+", "p0": 0, "p1": 1, "p2": 2, "p3": 3}
  },
  "total_findings": {"p0": 2, "p1": 8, "p2": 15, "p3": 12},
  "agents_dispatched": 9,
  "duration_seconds": 720,
  "mode": "full"
}
```

## 6. Delta Comparison

When previous audit JSON exists:

| Operation | Logic |
|-----------|-------|
| Dimension delta | `current_score - previous_score` |
| New findings | In current, absent in previous (by `check_id + file`) |
| Resolved findings | In previous, absent in current (by `check_id + file`) |
| Trend | `>=+0.5` = up, `<=-0.5` = down, else stable |

## 7. Quick Mode

4 agents audit the **8 highest-weighted dimensions** per preset.

```
quick_overall = audited_weighted_sum / audited_weight_total * 10
```

- Grade prefixed with `~` (approximation): `~B+`
- JSONL `mode` = `"quick"`, unaudited dimensions omitted
