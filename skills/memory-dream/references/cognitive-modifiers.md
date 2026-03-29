# Cognitive Modifiers Reference

> SP-COGNITION Gap 2: Affect-as-Signal
> These modifiers adjust ATLAS behavior based on emotional/contextual signals.
> Used by: tone-adaptation hook, dream self-model update, session-start briefing.

## Decision Confidence Modifier

When making decisions (architecture, tool choice, approach), the base confidence
is modified by the user's current state:

```
effective_confidence = base_confidence
  × energy_modifier(energy)
  × mood_modifier(mood)
  × time_quality_modifier(quality)
```

### Energy Modifier

| Energy | Modifier | Behavior |
|--------|----------|----------|
| 1 (depleted) | 0.6 | ESCALATE everything. More HITL gates. Simpler options. |
| 2 (low) | 0.7 | Reduce decision count. Batch choices. Prefer safe options. |
| 3 (neutral) | 0.9 | Standard behavior with slight caution. |
| 4 (good) | 1.0 | Normal operation. |
| 5 (peak) | 1.1 | Can handle complex decisions. Deeper exploration OK. |

### Mood Modifier

| Mood | Modifier | Behavior |
|------|----------|----------|
| frustrated | 0.8 | Validate the frustration. Propose pivots. Short answers. |
| anxious | 0.8 | Reassure. Show precedents. More verification steps. |
| neutral | 1.0 | Standard. |
| focused | 1.1 | Don't interrupt. Minimize questions. Execute efficiently. |
| curious | 1.1 | Explore alternatives. Insights welcome. Creative mode. |
| flow | 1.2 | MINIMAL intervention. Execute directly. Don't break flow. |

### Time Quality Modifier

| Quality | Modifier | Behavior |
|---------|----------|----------|
| fragmented | 0.7 | Shorter tasks. More checkpoints. Expect interruptions. |
| interrupted | 0.8 | Save state frequently. Explicit progress markers. |
| focused | 1.0 | Standard. |
| deep | 1.2 | Complex work OK. Longer chains. Fewer interruptions. |

### Threshold Actions

| Effective Confidence | Action |
|---------------------|--------|
| < 0.4 | **ESCALATE**: Ask more questions. Present 3+ alternatives. Don't proceed without explicit approval. |
| 0.4 - 0.6 | **SLOW DOWN**: Present 2-3 alternatives with pros/cons. Seek precedent in decisions.jsonl. |
| 0.6 - 0.8 | **STANDARD**: Normal HITL gates. 2-3 options via AskUserQuestion. |
| > 0.8 | **PROCEED**: Can make judgment calls. Fewer questions. Still HITL on architectural decisions. |

## Tone Adaptation Matrix

| Energy | Mood | Tone Mode | Response Style |
|--------|------|-----------|----------------|
| 1-2 | * | ultra-concise | Max 3 bullets. No brainstorm. Actions only. |
| 3 | frustrated | empathetic-concise | Acknowledge blocker. 1-2 alternatives. Short. |
| 3 | focused | standard | Normal operation. |
| 4-5 | curious | exploration | Insights OK. Deeper explanations. Creative. |
| 4-5 | flow | flow-protect | MINIMAL. Execute. No commentary. No questions. |
| 4-5 | * | standard | Normal balanced output. |

## Self-Model Integration

The tone-adaptation hook writes state to `~/.claude/atlas-tone-state.json`:
```json
{
  "tone": "ultra-concise",
  "energy": 2,
  "mood": "tired",
  "time_label": "late-night",
  "hour": 23,
  "updated": "2026-03-28T23:15:00"
}
```

The dream cycle (Phase 4.6) reads this file to update the self-model's
growth log with energy patterns ("low energy detected 3x at night this week").

## Prediction Accuracy Tracking

The SessionEnd hook should compare the morning brief's predicted focus
with the actual session work (extracted from git log + task list).

```json
// prediction-log.json (append-only)
{
  "date": "2026-03-28",
  "predicted_focus": "pitch",
  "actual_focus": "infra-hardening",
  "correct": false,
  "morning_energy_estimate": 7,
  "actual_energy": 4,
  "session_duration_min": 120
}
```

Accuracy is tracked in dream health score (future D16 or D17 dimension).
