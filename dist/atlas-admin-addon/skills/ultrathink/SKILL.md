---
name: ultrathink
description: "Deep reasoning mode with structured decision frameworks. 6 subcommands: adr, matrix, risk, tradeoff, compare, chain. Auto-detects analysis type from topic. Persists decisions via decision-log. Triggers on: /ultrathink, 'think deeply about', 'analyze thoroughly', 'ultrathink'."
effort: medium
depends_on: [decision-log]
triggers: ["ultrathink", "think deeply", "analyze thoroughly", "deep analysis", "architectural decision"]
---

# Ultrathink — Deep Reasoning Mode

Activate maximum thinking budget (~32K tokens) with **structured decision frameworks**.
Maps to Claude Code's native `ultrathink` keyword for highest reasoning quality.

## Red Flags (rationalization check)

Before skipping ultrathink on a significant decision, ask yourself — are any of these thoughts running? If yes, STOP. Architectural choices locked in without deep reasoning cost months.

| Thought | Reality |
|---------|---------|
| "I don't need to go deep — I know the answer" | Then use the framework to CONFIRM it. Knowing unmeasured = guessing. |
| "Matrix scoring is busywork" | Weighted matrix makes tradeoffs VISIBLE. Gut-feel hides them. |
| "This isn't architectural enough for ADR" | Tech stack, data model, lib choice = architectural. Low bar. Run `ultrathink adr`. |
| "I'll just use /effort max without the framework" | /effort bumps tokens. ultrathink adds STRUCTURE (ADR / matrix / risk / tradeoff). Different tools. |
| "Decision-log at end is enough" | ultrathink → decision-log is a PIPELINE. ultrathink produces the log payload. |
| "Risk matrix is overkill for dev work" | Pre-deploy risks (data loss, security gaps) deserve 15 min. Post-incident postmortem costs days. |
| "Single option, no comparison needed" | Even single-option decisions have alternatives (do-nothing, defer). Name them. |
| "No prior decisions to chain to" | Check `.claude/decisions.jsonl` first. You might contradict a 2-week-old choice. |

## v5.7.0+ Native `/effort` (Phase 4)

For simple effort bumps, prefer CC native `/effort` (v2.1.84+):

```bash
/effort high     # bump current session effort to high
/effort max      # bump to maximum (equivalent to ultrathink keyword per-turn)
/effort auto     # reset to default (auto-adaptive)
```

Keep `ultrathink` skill for **structured frameworks**:
- ADR (architectural decisions)
- Risk analysis matrix
- Tradeoff comparison
- Decision chain with rationale
- Auto-persist via `decision-log` skill

`/effort` = simple knob. `ultrathink` = framework + persistence.

## Thinking Levels

| Level | Keyword | Budget | Use Case |
|-------|---------|--------|----------|
| Standard | `think` | ~4K tokens | Simple analysis |
| Deep | `think hard` | ~10K tokens | Moderate complexity |
| Maximum | `ultrathink` | ~32K tokens | Architecture, risk, multi-angle |

## Subcommands

### `ultrathink adr <topic>` — Architecture Decision Record

Use for: technology choices, design patterns, infrastructure changes.

**Template** (fill EVERY section):

```
## ADR: {topic}

**Date**: {YYYY-MM-DD}
**Status**: PROPOSED | ACCEPTED | DEPRECATED | SUPERSEDED
**Deciders**: {who is involved}

### Context
{What is the issue? What forces are at play? What constraints exist?}

### Decision
{What is the change that we're proposing/doing?}

### Consequences

| Type | Consequence |
|------|-------------|
| ✅ Positive | {benefit 1} |
| ✅ Positive | {benefit 2} |
| ⚠️ Negative | {tradeoff 1} |
| ⚠️ Negative | {tradeoff 2} |
| 🔄 Neutral | {side effect} |

### Alternatives Considered

| Alternative | Pros | Cons | Why Rejected |
|-------------|------|------|--------------|
| {option A} | {pros} | {cons} | {reason} |
| {option B} | {pros} | {cons} | {reason} |

### Confidence: {HIGH | MEDIUM | LOW}
### Reversibility: {EASY | MODERATE | HARD | IRREVERSIBLE}
```

---

### `ultrathink matrix <topic>` — Weighted Decision Matrix

Use for: choosing between 2-5 options with multiple criteria.

**Process**:
1. Identify 5-8 relevant criteria for the topic
2. Assign weights 1-5 (5 = most important)
3. Score each option per criterion (1-5)
4. Calculate weighted totals
5. Present the matrix

**Template**:

```
## Decision Matrix: {topic}

| Criteria | Weight | {Option A} | {Option B} | {Option C} |
|----------|--------|------------|------------|------------|
| {criterion 1} | {w} | {score}/5 | {score}/5 | {score}/5 |
| {criterion 2} | {w} | {score}/5 | {score}/5 | {score}/5 |
| {criterion 3} | {w} | {score}/5 | {score}/5 | {score}/5 |
| {criterion 4} | {w} | {score}/5 | {score}/5 | {score}/5 |
| {criterion 5} | {w} | {score}/5 | {score}/5 | {score}/5 |
| **Weighted Total** | | **{total}** | **{total}** | **{total}** |

### Winner: {option} ({total} pts)
### Confidence: {HIGH | MEDIUM | LOW}
### Key Insight: {the single most important differentiator}
```

---

### `ultrathink risk <topic>` — Risk Assessment Matrix

Use for: evaluating dangers, pre-deployment analysis, migration risks.

**Template**:

```
## Risk Assessment: {topic}

| # | Risk | Probability | Impact | Score | Mitigation | Residual Risk |
|---|------|-------------|--------|-------|------------|---------------|
| R1 | {risk description} | {1-5} | {1-5} | {P×I} | {mitigation strategy} | {LOW/MED/HIGH} |
| R2 | {risk description} | {1-5} | {1-5} | {P×I} | {mitigation strategy} | {LOW/MED/HIGH} |
| R3 | {risk description} | {1-5} | {1-5} | {P×I} | {mitigation strategy} | {LOW/MED/HIGH} |

### Risk Map
```
     Impact →
  P  1  2  3  4  5
  r  ─────────────
  o 5│        R?
  b 4│     R?
  . 3│  R?
    2│
  ↑ 1│
```

### Overall Risk Level: {LOW | MEDIUM | HIGH | CRITICAL}
### Go/No-Go Recommendation: {GO | GO WITH MITIGATIONS | NO-GO}
### Confidence: {HIGH | MEDIUM | LOW}
```

---

### `ultrathink tradeoff <A> vs <B>` — Trade-off Analysis

Use for: when two approaches have clear pros/cons and neither is obviously better.

**Template**:

```
## Trade-off Analysis: {A} vs {B}

| Dimension | {A} | {B} | Edge |
|-----------|-----|-----|------|
| Cost | {assessment} | {assessment} | {A or B} |
| Complexity | {assessment} | {assessment} | {A or B} |
| Time to implement | {assessment} | {assessment} | {A or B} |
| Reversibility | {assessment} | {assessment} | {A or B} |
| Team impact | {assessment} | {assessment} | {A or B} |
| Maintenance burden | {assessment} | {assessment} | {A or B} |
| Risk | {assessment} | {assessment} | {A or B} |

### Score: {A} = {count} edges, {B} = {count} edges
### Recommendation: {A or B}
### Key Trade-off: {the ONE thing that tips the balance}
### Confidence: {HIGH | MEDIUM | LOW}
```

---

### `ultrathink compare <A> vs <B> [vs <C>]` — Multi-Dimension Comparison

Use for: head-to-head comparison with auto-detected dimensions.

**Process**:
1. Detect relevant dimensions from the topic context:
   - Library/tool → add: ecosystem maturity, community size, docs quality, last release
   - Architecture → add: scalability, coupling, testability, deployment complexity
   - Infrastructure → add: cost, availability, vendor lock-in, operational overhead
   - Process → add: team adoption, learning curve, tooling support
2. Score each option 1-5 per dimension
3. Present comparison with visual indicators

**Template**:

```
## Comparison: {A} vs {B} [vs {C}]

| Dimension | {A} | {B} | [{C}] |
|-----------|-----|-----|-------|
| {auto-detected 1} | {"★".repeat(score)} {score}/5 | ... | ... |
| {auto-detected 2} | {"★".repeat(score)} {score}/5 | ... | ... |
| {auto-detected 3} | {"★".repeat(score)} {score}/5 | ... | ... |
| {auto-detected 4} | {"★".repeat(score)} {score}/5 | ... | ... |
| {auto-detected 5} | {"★".repeat(score)} {score}/5 | ... | ... |
| {auto-detected 6} | {"★".repeat(score)} {score}/5 | ... | ... |

### Summary
- **{A}**: Best for {use case}. Strongest in {dimension}.
- **{B}**: Best for {use case}. Strongest in {dimension}.
- [{C}: Best for {use case}. Strongest in {dimension}.]

### Recommendation: {winner} for {specific context}
### Confidence: {HIGH | MEDIUM | LOW}
```

---

### `ultrathink chain <subsystem>` — Reasoning Chain (Cross-Session)

Use for: building on previous decisions for the same subsystem.

**Process**:
1. Load previous decisions:
   ```bash
   grep '"subsystem":"<subsystem>"' .claude/decisions.jsonl | tail -5
   ```
2. Also check topic memory if `ATLAS_TOPIC` is set:
   ```bash
   [ -d ".claude/topics/${ATLAS_TOPIC}" ] && cat ".claude/topics/${ATLAS_TOPIC}/decisions.md"
   ```
3. Present as "Decision History" before new analysis
4. Run consistency check against the new recommendation
5. Flag contradictions explicitly

**Template**:

```
## Reasoning Chain: {subsystem}

### Decision History (last 5)
| Date | Decision | Rationale |
|------|----------|-----------|
| {date} | {decision 1} | {short rationale} |
| {date} | {decision 2} | {short rationale} |

### Current Analysis
{Use the appropriate framework (ADR/matrix/risk/tradeoff/compare) for the new question}

### Consistency Check
- ✅ Consistent with: {previous decision} — {why}
- ⚠️ Contradicts: {previous decision} — {explain the contradiction}
- 💡 Evolves: {previous decision} — {how this builds on it}

### Confidence: {HIGH | MEDIUM | LOW}
```

---

## Auto-Routing (No Subcommand)

When `ultrathink <topic>` is invoked WITHOUT a subcommand, auto-detect the framework:

| Keywords in topic | Framework |
|-------------------|-----------|
| `should`, `choose`, `pick`, `select`, `which` | **matrix** |
| `risk`, `danger`, `failure`, `what could go wrong` | **risk** |
| `vs`, `versus`, `compare`, `between`, `or` | **compare** |
| `tradeoff`, `trade-off`, `pros cons` | **tradeoff** |
| `history`, `previous`, `chain`, `evolution` | **chain** |
| Default (architecture, design, pattern) | **adr** |

Display: "Detected analysis type: **{type}**. Override: `ultrathink {type} <topic>`"

## Decision Persistence

After EVERY ultrathink analysis:
1. Present the structured output
2. Prompt: "**Log this decision?** (invokes decision-log)"
3. If yes, invoke the `decision-log` skill with pre-populated fields:
   - `decision`: the recommended option/approach
   - `alternatives`: rejected options with reasons
   - `rationale`: scoring summary or key insight
   - `subsystem`: auto-detected from topic or ask user
   - `source`: `ultrathink:{subcommand}`
   - `reversibility`: from the analysis
   - `impact`: from the analysis

## Notes

- Opus model recommended for maximum reasoning quality
- For simpler queries, use `/effort low|medium|high` instead
- All templates produce structured output — never free-form prose
- Reasoning chains enable cross-session architectural memory

ultrathink $ARGUMENTS
