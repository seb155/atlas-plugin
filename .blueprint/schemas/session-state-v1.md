# Session State Schema v1.0

> v6.0 Approved-Mode Autonomy Engine foundation.
> Location: `.claude/session-state.json` (per-project, gitignored, chmod 600)
> Created: 2026-04-23
> Plan ref: `.blueprint/plans/le-plugin-atlas-core-devrais-adaptive-treasure.md` Dimension 4

## Purpose

Tracks per-session autonomy context so Claude can skip redundant `AskUserQuestion` calls on pre-approved decisions. Enables the user directive "fais tout après plan approuvé" to actually skip questions rather than re-asking at every HITL gate.

## Autonomy Modes

| Mode | Behavior |
|------|----------|
| `strict` (default) | Every AskUserQuestion fires normally. Zero skip. Safe default for unknown sessions. |
| `approved` | Questions on gates in `approved_gates` AND tiers in `skip_tiers` auto-approved. Other questions fire. |
| `yolo` | ALL questions skipped EXCEPT those matching `always_ask_actions` or `always_ask_tiers`. Use with caution. |

## Tier Definitions (per `.claude/rules/dod.md`)

- **CODED** (0-20% DoD): code compiles, local tests pass
- **VALIDATING** (21-80% DoD): integration + real data + review
- **VALIDATED** (81-99% DoD): demo-ready + prod-deployable
- **SHIPPED** (100% DoD): live in production

Default `skip_tiers: [CODED, VALIDATING]` means: auto-approve routine implementation gates; ask on demo/prod decisions.

## Immutable Always-Ask Actions (14)

Cannot be disabled even in `yolo` mode. Covers:

| Category | Actions |
|----------|---------|
| **Destructive** | `destructive:rm_rf`, `destructive:git_reset_hard`, `destructive:git_force_push` |
| **Deploy prod** | `deploy:production`, `deploy:main_branch_merge` |
| **Infra shared** | `infra:change_shared_resource` |
| **Finance** | `finance:any_cost_incurring` |
| **Security** | `security:modify_auth`, `security:modify_rbac` |
| **Data** | `data:modify_prod_schema`, `data:delete_persistent` |
| **Communications** | `comm:external_notification`, `comm:slack_post`, `comm:email_send` |

Rationale: irreversibility × blast-radius → always require explicit user confirmation.

## Schema (canonical)

```json
{
  "$schema_version": "1.0",
  "session_id": "uuid-v4",
  "started_at": "ISO-8601 timestamp with tz",
  "ended_at": "ISO-8601 or null",
  "autonomy_mode": "strict | approved | yolo",
  "approved_gates": [
    {
      "gate_id": "plan-arch",
      "approved_at": "ISO-8601",
      "approver": "user | auto",
      "scope": "branch-name | 'session' | 'persistent'",
      "expires_at": "ISO-8601 | null"
    }
  ],
  "skip_tiers": ["CODED", "VALIDATING"],
  "always_ask_tiers": ["VALIDATED", "SHIPPED"],
  "always_ask_actions": ["destructive:rm_rf", "deploy:production", "..."],
  "current_plan": {
    "path": ".blueprint/plans/xxx.md",
    "phase": "Phase 5",
    "task_id": "5.1"
  },
  "current_sprint": {
    "id": "SP-042",
    "started_at": "ISO-8601",
    "target_end": "ISO-8601"
  },
  "task_progress": {
    "total": 0,
    "coded": 0, "validating": 0, "validated": 0, "shipped": 0,
    "hitl_gates_crossed": 0,
    "hitl_gates_skipped_via_approval": 0
  },
  "metadata": {
    "created_by": "autonomy-gate.sh",
    "last_updated": "ISO-8601"
  }
}
```

## Lifecycle

### Creation
SessionStart hook creates `.claude/session-state.json` if missing. Default: `autonomy_mode: strict`.

### Activation (mode promotion)
- User says "fais tout" / "approuve et fais" / "full autonomy" → promote to `approved`
- Plan approved via ExitPlanMode + user confirm → add `plan-arch` to approved_gates

### Expiration
- **Session-level** (default): cleared on session end
- **Persistent** (opt-in via `--persist`): survives across sessions via handoff files
- Approved_gates TTL: optional 24h default for persistent

### Audit Trail
Every gate check + decision logged to `.claude/decisions.jsonl`:
```json
{"ts":"...", "gate_id":"plan-arch", "tier":"CODED", "action":"", "mode":"approved", "decision":"skip", "source":"autonomy-gate"}
```

## CLI Usage (`hooks/autonomy-gate.sh`)

```bash
# Initialize fresh state
./hooks/autonomy-gate.sh init

# Check gate (returns 0=skip or 1=ask)
./hooks/autonomy-gate.sh check <gate_id> <tier> [action]

# Pre-approve a gate
./hooks/autonomy-gate.sh approve <gate_id> [scope]

# Promote mode
./hooks/autonomy-gate.sh set-mode approved

# View state
./hooks/autonomy-gate.sh status
```

## Integration Pattern (for skills)

```bash
# Before (always asks)
question_user "Proceed with deploy?"

# After (checks autonomy-gate first)
if ! hooks/autonomy-gate.sh check "deploy-prod" "SHIPPED" "deploy:production"; then
  question_user "Proceed with deploy?"
fi
# If check returns 0, auto-approved — no question fires
```

## Security Considerations

- **File permissions**: `chmod 600` (user-only read/write)
- **Content**: No secrets, tokens, or PII — only gate identifiers + timestamps + enum values
- **Tampering detection**: `metadata.last_updated` timestamp (future v1.1: checksums)
- **Gitignore**: Always gitignored via `.gitignore` `.claude/session-state.json` entry

## Integration Points (roadmap)

| Component | Integration | Status |
|-----------|-------------|--------|
| AskUserQuestion wrapper | Via `autonomy-gate.sh check` | **Ship v6.0.0-alpha.6** ✅ |
| `executing-plans` skill | Read current_plan + approved_gates | v6.0.0-beta.1 |
| `interactive-flow` skill | Respect skip_tiers per phase | v6.0.0-beta.1 |
| `experiment-loop` skill | Gate decisions via approved_gates | v6.0.0-beta.1 |
| `session-pickup` | Restore approved_gates (--persist) | v6.0.0 GA |
| `session-retrospective` | Record approval history | v6.0.0 GA |

## v1.1 Extensions (v6.1.0 — workflow library)

Added 2026-04-24 for workflow library + session-lifecycle commands (Section O
of parent plan) + event-sourcing pattern (Section Q.2).

### New top-level fields

```yaml
active_workflow:
  name: string              # e.g., "workflow-feature"
  schema_version: integer   # pinned at workflow start (Q.5 migration safety)
  started_at: ISO8601
  worktree: string
  branch: string
  task_id: string           # idempotency key (Q.3)
  completed_steps: list[integer]
  skipped_steps: list[{step: int, reason: string, ts: ISO8601}]
  pending_hitl: list[{step: int, gate: string, asked_at: ISO8601}]

last_session:
  ended_at: ISO8601 | null
  ended_path: enum[close-session|handoff|abandon|null]
  handoff_file: string | null
  resumable: boolean

session_events_file: string     # default ".claude/session-events.jsonl"
session_events_count: integer

local_lock:
  held: boolean
  acquired_at: ISO8601 | null
  heartbeat_at: ISO8601 | null
  lock_file_path: string | null

last_intent:
  detected_at: ISO8601
  input_sample: string
  matched_workflow: string | null
  confidence: float
  user_response: enum[accepted|rejected|ignored]
```

### Session Events Schema (`.claude/session-events.jsonl`, Q.2)

Append-only JSONL. Reducer `scripts/atlas-modules/session-state-reducer.sh`
derives current state from events.

Event types: `workflow_started | step_started | step_completed | step_skipped
| step_failed | hitl_gate_fired | hitl_gate_resolved | workflow_completed
| workflow_handoff | workflow_abandoned | lock_acquired | lock_released
| intent_detected`.

Example:
```jsonl
{"ts":"2026-04-24T06:00:00Z","type":"workflow_started","workflow":"workflow-feature","task_id":"uuid-v4"}
{"ts":"2026-04-24T06:05:00Z","type":"step_started","step":1,"skill":"task-framing"}
{"ts":"2026-04-24T06:15:00Z","type":"step_completed","step":1,"duration_ms":600000,"evidence":["memory/framing.md"]}
```

### Auto-resume flow (Section N.6)

On `/atlas start`, session-pickup reads session-state.json:
1. If `active_workflow` present + `resumable: true` → AskUserQuestion resume/fresh/review
2. If resume: inject condensed step_completed evidence + position at `next_step`
3. If fresh: emit `workflow_abandoned` event + clear active_workflow

### Migration v1.0 → v1.1

- All v1.0 fields preserved (additive only)
- New fields default to `null` / empty lists
- Reducer regenerates cache fields from events.jsonl
- No migration script needed

## Version History

- **v1.0** (2026-04-23): Initial schema — Phase 5 foundation shipped in v6.0.0-alpha.6
- **v1.1** (2026-04-24): Workflow library extensions (active_workflow, events, lock, intent) — v6.1.0 Phase 1 Task 1.9

## References

- Helper: `hooks/autonomy-gate.sh`
- Tests: 3 scenarios validated (strict/approved/immutable)
- Audit trail: `.claude/decisions.jsonl`
- Plan: `.blueprint/plans/le-plugin-atlas-core-devrais-adaptive-treasure.md` Dimension 4
- SOTA review: `~/.claude/projects/.../memory/atlas-v6-sota-review-2026-04-23.md`
