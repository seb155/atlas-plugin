---
name: trace-replay
description: "Interactive timeline replay for distributed traces. Use when 'replay session X', 'show trace', 'why did Y happen', 'trace timeline', or debugging multi-hop session issues."
effort: medium
version: 1.0.0
tier: [admin]
---

# trace-replay — Interactive Timeline Viewer for ATLAS Traces

Post-hoc replay viewer for the JSONL traces produced by `atlas-trace` (W1.1).
Reads `~/.atlas/traces/{session-id}/{trace-id}.jsonl`, builds a span tree from
`parent_span_id` links, and renders an ASCII timeline plus drill-in views.
Companion skills: `atlas-trace` (collector), `skill-scorecard` (W1.2 metrics),
`cost-analytics --tree` (W1.4 cost attribution).

## Subcommands

| Command | Action |
|---------|--------|
| `atlas trace replay --session <id>` | Render full timeline tree for every trace in the session |
| `atlas trace replay --session <id> --trace <trace-id>` | Render one trace only |
| `atlas trace replay --session <id> --filter skill=memory-dream` | Filter spans by `service`/`operation` substring |
| `atlas trace replay --session <id> --depth N` | Truncate the tree at depth N (root = 0) |
| `atlas trace replay --session <id> --time-window ts1..ts2` | Keep spans whose `start_ts` ∈ [ts1, ts2] (ISO-8601) |
| `atlas trace replay --session <id> --span <span_id>` | Span detail view (full attributes, parent chain, child count) |
| `atlas trace replay --session <id> --stats` | Aggregate stats (total spans, errors, duration, hot path) |
| `atlas trace replay --list-sessions` | List session dirs under `~/.atlas/traces/` |

## Output 1 — Tree timeline view

```
trace abc123…  session 2026-04-30  duration 12.4s
├─ Skill memory-dream         3.2s   ok    cost $0.04
│  ├─ Bash:grep              0.1s   ok
│  ├─ Read:MEMORY.md         0.05s  ok
│  └─ Subagent:context-scan  2.8s   ok    cost $0.02
│     └─ Read:CLAUDE.md      0.03s  ok
└─ Skill ship-all             1.1s   error tokens=850
```

- Root spans are detected as those with `parent_span_id == null`.
- Children are sorted by `start_ts` so the tree reads top-to-bottom in real time.
- The `cost`/`tokens` columns are populated when present in `attributes`
  (forward-compat: `skill-scorecard` W1.2 emitter writes `cost_usd` /
  `tokens_in` / `tokens_out` keys; replay shows whichever is available).
- Status icons: `ok` (✅), `error` (❌), `pending` (⏳ — span still open).

## Output 2 — Span detail view (`--span <span_id>`)

```
Span 7f3a-…  Skill memory-dream
─────────────────────────────────────────
trace_id     : abc123-…
parent_span  : (root)
service      : skill
operation    : Skill:memory-dream
start_ts     : 2026-04-30T21:00:00.012Z
end_ts       : 2026-04-30T21:00:03.215Z
duration_ms  : 3203
status       : ok
children     : 3 spans, total 2.95s
attributes   :
  session_id     = sess-abc
  cost_usd       = 0.04
  tokens_in      = 1200
  tokens_out     = 340
  effort         = medium

Parent chain : (root)
Hot child    : Subagent:context-scan (2.8s, 87% of self)
```

## Output 3 — Stats summary (`--stats`)

```
🏛️ ATLAS │ 🎬 TRACE REPLAY │ Stats — session sess-abc

| Metric              | Value                            |
|---------------------|----------------------------------|
| Traces              | 1                                |
| Total spans         | 6                                |
| Root spans          | 2                                |
| Error spans         | 1                                |
| Total duration      | 12.4s (wall)                     |
| Self-time hot path  | Skill memory-dream → Subagent    |
| Slowest span        | Subagent:context-scan (2.8s)     |
| Skills invoked      | 2 (memory-dream, ship-all)       |
| Tools invoked       | 4 (Bash, Read, Read, Subagent)   |
| Cost (when present) | $0.06 total                      |
```

## Storage Source

Traces live exactly where `atlas-trace` (W1.1) writes them:

```
~/.atlas/traces/{session-id}/{trace-id}.jsonl    # one span per line, schema below
~/.atlas/traces/{session-id}/_active             # symlink → current trace_id
~/.atlas/traces/_index.jsonl                     # session/trace index
```

### Span schema (consumed read-only by this skill)

| Field | Type | Used for |
|-------|------|----------|
| `trace_id` | UUIDv4 | Group spans into one trace |
| `span_id` | UUIDv4 | Unique node id |
| `parent_span_id` | UUIDv4 \| null | Tree edges |
| `operation` | string | Tree label (`Bash`, `Skill:memory-dream`, …) |
| `service` | string | Filter axis (`tool`/`skill`/`agent`/`hook`/`manual`) |
| `start_ts` / `end_ts` | ISO-8601 | Sort + duration |
| `duration_ms` | integer | Display |
| `status` | string | `ok`/`error`/`pending` icon |
| `attributes` | object | Detail view + cost/token columns |

This schema is the contract from `atlas-trace` (W1.1, branch
`feat/v7-w1-1-atlas-trace`). Replay never writes — opening the same JSONL
concurrently with the collector is safe.

## Forward-compat with W1.2 scorecards

`skill-scorecard` (W1.2) emits `~/.atlas/scorecards/{skill}/{date}.jsonl`
with one record per skill invocation. When `--with-scorecards` is passed
(future flag), `trace-replay` joins on `trace_id` to attach
`cost_usd`, `tokens_in`, `tokens_out`, `latency_p99_ms` into the same tree.
Until then, the columns fall back to `attributes.cost_usd` /
`attributes.tokens_in` / `attributes.tokens_out` if present, otherwise blank.

## Execution Steps (when invoked by user)

1. **Resolve session dir**: default `~/.atlas/traces/$CLAUDE_SESSION_ID`,
   override with `--session <id>`.
2. **Glob trace files**: `*.jsonl` in the session dir; if `--trace <id>`,
   filter to that one.
3. **Apply filters**: `--filter`, `--depth`, `--time-window` are pre-tree
   filters that drop spans before the tree is built.
4. **Build tree**: index spans by `span_id`, then walk roots
   (`parent_span_id == null`) and append children sorted by `start_ts`.
5. **Render**: ASCII tree (`├─ │  └─`) with operation, duration_ms (humanized),
   status icon, and optional cost/tokens columns when present in attributes.
6. **Drill-in**: `--span` short-circuits to detail view; `--stats` short-circuits
   to aggregate view.

## Verification Commands

```bash
# 1. Bash sanity (no syntax errors)
bash -n scripts/trace-replay.sh

# 2. Seed a test trace (matches W1.1 schema)
mkdir -p ~/.atlas/traces/test-session
TRACE_ID=$(uuidgen 2>/dev/null || python3 -c "import uuid;print(uuid.uuid4())")
cat > ~/.atlas/traces/test-session/$TRACE_ID.jsonl <<EOF
{"trace_id":"$TRACE_ID","span_id":"s1","parent_span_id":null,"operation":"Skill:memory-dream","service":"skill","start_ts":"2026-04-30T21:00:00Z","end_ts":"2026-04-30T21:00:03Z","duration_ms":3000,"status":"ok","attributes":{}}
{"trace_id":"$TRACE_ID","span_id":"s2","parent_span_id":"s1","operation":"Bash:grep","service":"tool","start_ts":"2026-04-30T21:00:00.5Z","end_ts":"2026-04-30T21:00:00.6Z","duration_ms":100,"status":"ok","attributes":{}}
EOF

# 3. Render
bash scripts/trace-replay.sh --session test-session
# Expected: 2-level tree (Skill:memory-dream → Bash:grep)

# 4. Stats
bash scripts/trace-replay.sh --session test-session --stats
# Expected: 1 trace, 2 spans, 0 errors

# 5. Span detail
bash scripts/trace-replay.sh --session test-session --span s1
# Expected: parent=root, children=1
```

## Constraints

- Read-only on `~/.atlas/traces/` (never patches collector output).
- Pure bash + `jq` + `awk` (no Python required for hot path).
- Graceful when a span is `pending` (open, no `end_ts`): renders as `⏳` with
  `pending` status; uses `now() - start_ts` as best-effort duration.
- Filter combination is conjunctive (`--filter` AND `--depth` AND `--time-window`).

## References

- W1.1 collector: `skills/atlas-trace/SKILL.md` (branch `feat/v7-w1-1-atlas-trace`)
- W1.2 scorecards (forward-compat): `skills/skill-scorecard/SKILL.md`
- Plan SSoT: `.blueprint/plans/ultrathink-regarde-ce-qui-abundant-petal.md`
  (Section H W1.3, Section O paths)
- UI text inspiration: `skills/atlas-doctor/SKILL.md`
