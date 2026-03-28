# Experiential Frontmatter Schema

> Extends the base memory frontmatter with experiential, temporal, spatial, and
> type-specific dimensions. All new fields are OPTIONAL. Existing files without
> these fields continue to work identically.

## Design Principles

1. **Additive only** — never breaks existing files
2. **Progressive enrichment** — dream cycle can propose adding fields (via H8 gate)
3. **Inference-first** — auto-learn hook detects signals, not explicit prompts
4. **HITL on writes** — all experiential data creation requires user approval
5. **Privacy-aware** — experiential data excluded from cross-project scans

## Memory Type Ontology (v4)

### Cognitive Architecture Mapping (ACT-R / SOAR)

| Cognitive Layer | ATLAS Types | Function |
|-----------------|-------------|----------|
| **Semantic** | `user`, `reference`, `project` | Stable factual knowledge |
| **Episodic** | `episode`, `reflection` | Experiential narratives |
| **Procedural** | `feedback`, `intuition` | Behavioral rules + tacit knowledge |
| **Temporal** | `temporal` | Time-bounded validity |
| **Social** | `relationship` | Relational graph |

### Type Definitions

| Type | Purpose | Lifecycle | Naming Convention |
|------|---------|-----------|-------------------|
| `user` | User identity (factual) | Permanent, single file | `user_profile.md` |
| `feedback` | User corrections/preferences | **Immutable** (never prune) | `feedback_*.md` or `feedback-*.md` |
| `project` | Technical project knowledge | Active then archivable | `{topic}.md` |
| `reference` | Stable reference material | Long-lived | `{topic}.md` |
| `episode` | Rich session narrative with experiential context | 2-4/week, quarterly archive | `episode-YYYY-MM-DD.md` |
| `intuition` | Gut feelings, emerging patterns, hunches | 1-2/month, validate or archive | `intuition-{topic}.md` |
| `reflection` | Personal growth, retrospectives, meta-learning | 1-2/month | `reflection-YYYY-MM.md` |
| `relationship` | Deep relational context (people, teams) | 5-15 total, updated on interaction | `relationship-{person-slug}.md` |
| `temporal` | Facts with time-bounded validity | Reclassified from project/reference | `temporal-{topic}.md` |

### Knowledge Subtypes (extended)

| Value | Meaning | Types |
|-------|---------|-------|
| `propositional` | Facts, states, measurements | user, project, reference, temporal |
| `prescriptive` | Rules, preferences, constraints | feedback |
| `experiential` | Lived experience, narratives | episode, reflection |
| `tacit` | Intuitive knowledge, patterns | intuition |

## Base Schema (existing, unchanged)

```yaml
---
name: {string}                    # Human-readable name
description: {string}             # 1-2 sentence summary for relevance matching
type: {string}                    # One of 9 types above
relevance: {HIGH|MED|LOW}         # Optional priority signal
knowledge: {string}               # propositional|prescriptive|experiential|tacit
last_accessed: {YYYY-MM-DD}       # Optional recency tracking
---
```

## Experiential Context Fields (all optional)

### Energy & Mood

```yaml
energy: {1-5}
# 1 = depleted (barely functional, need recovery)
# 2 = low (functioning but sluggish, avoid complex decisions)
# 3 = neutral (normal operating capacity)
# 4 = high (sharp, productive, good for architecture work)
# 5 = peak (flow state imminent, rare, protect at all costs)

mood: {string}
# Free-form, examples:
# "focused" — single-task concentration
# "frustrated" — blocked or annoyed
# "curious" — exploring, open to new ideas
# "elated" — breakthrough moment, high satisfaction
# "calm" — steady, sustainable pace
# "anxious" — deadline pressure or uncertainty
# "determined" — pushing through difficulty

confidence: {0.0-1.0}
# Content/decision confidence level
# 0.0-0.3 = uncertain, exploring
# 0.4-0.6 = moderate, acceptable risk
# 0.7-0.8 = high, validated approach
# 0.9-1.0 = very high, proven pattern

time_quality: {deep|focused|fragmented|interrupted|recovery}
# deep = 2h+ uninterrupted, flow achieved
# focused = 1-2h concentrated work
# fragmented = multiple context switches
# interrupted = external disruptions
# recovery = deliberate low-intensity (post-sprint)
```

### Temporal Validity

```yaml
valid_from: {YYYY-MM-DD}
# When this fact became true
# Omit for permanent facts (architecture decisions, lessons)
# Required for: active work status, version claims, team dynamics

valid_until: {YYYY-MM-DD}
# When this fact expires or should be re-validated
# Omit for indefinite validity
# Examples: sprint deadlines, temporary configs, tool trials

decay_rate: {none|slow|medium|fast}
# none = permanent (reference material, architectural decisions)
# slow = months (technology choices, strategic plans)
# medium = weeks (project status, active work, version claims)
# fast = days (current sprint tasks, daily status, energy state)
```

### Spatial / Environment

```yaml
location: {string}
# Where the work happened
# Examples: "home-office", "laptop-mobile", "vm-560", "coffee-shop", "client-site"

environment: {string}
# Qualitative environment description
# Examples: "quiet morning solo", "noisy open office", "collaborative call with team"
```

## Type-Specific Fields

### Episode (`type: episode`)

```yaml
session_id: {string}              # Claude Code session identifier if available
duration_minutes: {int}           # Approximate session length
flow_state: {boolean}             # Was sustained flow achieved?
key_decisions: [{string}]         # 2-5 most important decisions made
blockers_hit: [{string}]          # What slowed progress
energy_arc: {string}              # "steady", "rising", "declining", "peak-then-crash"
```

### Relationship (`type: relationship`)

```yaml
person: {string}                  # Full name
role: {string}                    # Professional role / relationship to user
organization: {string}            # Company / team
strengths: [{string}]             # What this person excels at
growth_areas: [{string}]          # Where they're developing
interaction_style: {string}       # How they prefer to communicate
trust_level: {low|medium|high}    # Current trust / delegation level
collaboration_quality: {string}   # "excellent", "good", "needs-alignment", "difficult"
last_interaction: {YYYY-MM-DD}    # When you last worked together
```

### Intuition (`type: intuition`)

```yaml
pattern_source: [{string}]        # What observations led to this intuition
confidence_trend: {rising|stable|declining}  # Is this feeling getting stronger?
validated: {boolean}              # Has this been confirmed by evidence?
validated_date: {YYYY-MM-DD}      # When validation occurred
domain: {string}                  # "technical", "team", "strategic", "process"
```

### Temporal (`type: temporal`)

```yaml
# Uses valid_from, valid_until, decay_rate from base experiential fields
# Plus:
original_type: {string}           # What type this was reclassified from
reclassified_date: {YYYY-MM-DD}   # When temporal bounds were added
verification_command: {string}    # How to check if still valid
```

### Reflection (`type: reflection`)

```yaml
period: {string}                  # "2026-03", "2026-Q1", "sprint-42"
episodes_reviewed: {int}          # How many episodes informed this reflection
growth_signals: [{string}]        # Positive trends observed
risk_signals: [{string}]          # Concerning trends
strategies_adopted: [{string}]    # What changed as a result
```

## Inference Signal Accumulation

The `auto-learn` hook detects experiential signals from conversation and accumulates
them in `~/.claude/atlas-experiential-signals.json`:

```json
{
  "session_start": "2026-03-27T21:58:00-04:00",
  "signals": [
    {"type": "energy", "value": 3, "source": "inferred", "confidence": 0.6, "raw": "un peu tanne"},
    {"type": "mood", "value": "focused", "source": "inferred", "confidence": 0.7, "raw": "deep in the code"},
    {"type": "time_quality", "value": "deep", "source": "explicit", "confidence": 0.9, "raw": "dans la zone"}
  ],
  "decision_count": 3,
  "blocker_count": 1
}
```

Signal confidence levels:
- `explicit` (user stated directly): 0.8-0.9
- `inferred` (regex pattern match): 0.5-0.7
- `observed` (behavioral pattern over multiple signals): 0.6-0.8

## Backward Compatibility Rules

1. **Grep parsers**: `grep -m1 "type:"` works unchanged (new types are single-word values)
2. **No field required**: Files without new fields function identically
3. **Progressive enrichment**: Dream Phase 3 (H8 gate) can propose adding fields
4. **Type distribution**: Phase 2 step 5 counts all 9 types
5. **D7 scoring**: Accepts all 9 types as valid (not "untyped")
6. **Existing files**: NEVER retroactively add energy/mood (data wasn't available)
7. **Cross-project**: Experiential types excluded from Phase 5 entity reconciliation
