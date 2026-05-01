---
name: atlas-trace
description: "OpenTelemetry-like distributed tracing for ATLAS skill→agent→call chains. Use when the user says 'show traces', 'trace this session', 'atlas trace start', 'atlas trace tail', or when investigating multi-hop request flows."
effort: medium
version: 1.0.0
tier: [admin]
---

# ATLAS Trace — Distributed Tracing for Skill/Agent Chains

OpenTelemetry-like distributed tracing for the ATLAS plugin. Captures every PreToolUse / PostToolUse / SubagentStart / SubagentStop event as a span in a JSONL file scoped to `{session-id}/{trace-id}`. Enables post-hoc replay (W1.3 `trace-replay`), per-skill scorecards (W1.2 `skill-scorecard`), and cost attribution call-trees (W1.4 `cost-analytics --tree`). Auto-instrumentation is opt-in via `ATLAS_TRACE_ENABLED=1`; hook overhead targets <5ms P95.

## Subcommands

| Command | Action |
|---------|--------|
| `/atlas trace start` | Enable tracing for current session (sets `ATLAS_TRACE_ENABLED=1`, generates trace_id) |
| `/atlas trace stop` | Disable tracing for current session |
| `/atlas trace status` | Show whether tracing is active + current trace_id |
| `/atlas trace tail` | Tail the current trace JSONL live (`tail -F`) |
| `/atlas trace ls [--session ID]` | List traces for a session (default = current) |
| `/atlas trace show <trace-id>` | Pretty-print a trace as a span tree |
| `/atlas trace stats <trace-id>` | Aggregate stats: total duration, span count, error count, top-N slow ops |
| `/atlas trace gc [--keep-days N]` | Garbage-collect old traces (default keep 14 days) |

## Span Format (JSONL — one span per line)

```json
{"trace_id":"a3c1f5b2-...","span_id":"b8e2-...","parent_span_id":null,"operation":"Bash","service":"tool","start_ts":"2026-04-30T22:10:33.012Z","end_ts":"2026-04-30T22:10:33.481Z","duration_ms":469,"status":"ok","attributes":{"session_id":"sess-abc","tool":"Bash","cwd":"/home/sgagnon/...","exit_code":0}}
```

### Span fields (mandatory)

| Field | Type | Purpose |
|-------|------|---------|
| `trace_id` | UUIDv4 | Stable across the whole trace (one trace per logical request) |
| `span_id` | UUIDv4 | Unique per span |
| `parent_span_id` | UUIDv4 \| null | `null` for root, parent's span_id otherwise |
| `operation` | string | Tool name (`Bash`, `Read`, `Write`, `Edit`, `Task`, `Skill`...) or skill name when emitted manually |
| `service` | string | One of `tool` \| `skill` \| `agent` \| `hook` \| `manual` |
| `start_ts` | ISO-8601 UTC ms | Span open time |
| `end_ts` | ISO-8601 UTC ms | Span close time (set by finalizer) |
| `duration_ms` | integer | `end_ts - start_ts` (rounded) |
| `status` | string | `ok` \| `error` \| `pending` (only while open) |
| `attributes` | object | Free-form key/value (tool-specific: cwd, exit_code, file_path, prompt_hash, etc.) |

## Storage Layout

```
~/.atlas/traces/{session-id}/{trace-id}.jsonl     # One line per span (open, then patched on close)
~/.atlas/traces/{session-id}/_active              # Symlink to current trace_id (managed by injector)
~/.atlas/traces/_index.jsonl                      # Append-only index: one line per trace_id (for fast list)
```

- **Session ID**: provided by Claude Code via `CLAUDE_SESSION_ID` env var. If missing, hook falls back to `$PPID-$$` shell handle so traces still land somewhere.
- **Trace ID**: generated once per session via `atlas trace start`, persisted in `~/.atlas/traces/{session_id}/_active`. Reused across all spans of that session until `stop`.
- **Atomic append**: spans are appended via `flock`-guarded write so concurrent hooks (parallel agents) don't corrupt the JSONL file.

## Auto-Instrumentation (opt-in)

When `ATLAS_TRACE_ENABLED=1` is set in the shell environment:

1. **PreToolUse** (`hooks/trace-id-injector.sh`) opens a span with `status: "pending"` and pushes the `span_id` onto an in-shell stack (`ATLAS_TRACE_SPAN_STACK`).
2. **PostToolUse** (`hooks/trace-id-finalizer.sh`) pops the latest span_id, computes `end_ts` + `duration_ms`, sets `status` to `ok` or `error`, and rewrites the matching JSONL line via `jq --arg`.
3. **SubagentStart / SubagentStop** are wired analogously via the same two hooks (the injector dispatches by `HOOK_EVENT`).

Overhead budget: <5ms P95 per hook invocation. Implementation uses pure bash + `python3 -c` for JSON only on payload parse (cheaper than spawning `jq` for short-lived spans).

### Manual API for skills

Skills that want to emit a custom span (e.g. a long-running internal phase) can call the helper:

```bash
# Wrap any command in a span:
atlas-trace span "memory-dream:phase-3-consolidation" -- python3 consolidate.py
# Or open/close manually:
SPAN_ID=$(atlas-trace span-open "vision-alignment:roadmap-merge")
# ... do work ...
atlas-trace span-close "$SPAN_ID" --status ok --attr "items_merged=12"
```

The wrapper resolves to a bash function exported by the skill's `run.sh` (or `bin/atlas-trace`) that calls `trace-id-injector.sh manual` directly.

## Execution Steps (when invoked by user)

1. **Detect subcommand** from user message (start | stop | status | tail | ls | show | stats | gc).
2. **For `start`**:
   - Generate `TRACE_ID=$(uuidgen)` (or python `uuid.uuid4()` fallback).
   - Resolve `SESSION_ID="${CLAUDE_SESSION_ID:-fallback-$$}"`.
   - `mkdir -p ~/.atlas/traces/$SESSION_ID && ln -sfn $TRACE_ID ~/.atlas/traces/$SESSION_ID/_active`.
   - Append index entry to `~/.atlas/traces/_index.jsonl`.
   - Print `export ATLAS_TRACE_ENABLED=1 ATLAS_TRACE_ID=$TRACE_ID` for the user to source.
3. **For `show <trace-id>`**:
   - Locate the JSONL file (search across all session dirs).
   - Build span tree via `parent_span_id` links.
   - Pretty-print as ASCII tree with `duration_ms` + `status`.
4. **For `stats <trace-id>`**: aggregate via Python one-liner (count, sum, p50/p95, top-5 slow ops).
5. **For `gc`**: delete trace files older than `--keep-days` (default 14d).

## Verification Commands

```bash
# 1. Bash sanity (no syntax errors)
bash -n hooks/trace-id-injector.sh
bash -n hooks/trace-id-finalizer.sh

# 2. Manual span emit (no Claude Code session required)
mkdir -p ~/.atlas/traces/test-session
export CLAUDE_SESSION_ID=test-session
export ATLAS_TRACE_ENABLED=1
export ATLAS_TRACE_ID=$(uuidgen)
echo '{"tool":"Bash","cwd":"/tmp"}' | HOOK_EVENT=PreToolUse bash hooks/trace-id-injector.sh
echo '{"tool":"Bash","exit_code":0}' | HOOK_EVENT=PostToolUse bash hooks/trace-id-finalizer.sh
test -s ~/.atlas/traces/test-session/$ATLAS_TRACE_ID.jsonl && echo "OK: trace file populated"
jq -c '.' ~/.atlas/traces/test-session/$ATLAS_TRACE_ID.jsonl   # validate JSONL

# 3. Overhead microbench (target <5ms P95)
for i in {1..100}; do
  /usr/bin/time -f "%e" -o /tmp/atlas-trace-bench.txt -a bash -c "
    echo '{\"tool\":\"Bash\"}' | HOOK_EVENT=PreToolUse bash hooks/trace-id-injector.sh
  "
done
sort -n /tmp/atlas-trace-bench.txt | awk 'NR==95{print "P95:", $1*1000, "ms"}'

# 4. Cleanup
rm -rf ~/.atlas/traces/test-session
```

## Forward-Compat Hooks (for W1.2 + W1.3)

- **W1.2 `skill-scorecard`** consumes `~/.atlas/traces/*/*.jsonl` to compute per-skill `latency_p50/p99`, `error_rate`, `cost_per_invocation`. Spans MUST have `service: "skill"` and `attributes.skill_name` set when emitted from a skill context.
- **W1.3 `trace-replay`** consumes the same JSONL files and renders an interactive timeline. Span tree MUST be reconstructable from `parent_span_id` chain alone (no external metadata needed).
- **W1.4 `cost-analytics --tree`** joins `~/.atlas/traces/*` with `~/.atlas/cost-log.jsonl` on `trace_id` (forward-compat: cost emitter will tag entries with current trace_id when `ATLAS_TRACE_ENABLED=1`).

## Constraints & Failure Modes

- **NEVER block the tool call**: hooks exit 0 on any internal error. Tracing is best-effort observability, not a gate.
- **NEVER write to traces dir if `ATLAS_TRACE_ENABLED != 1`**: zero overhead when disabled.
- **No external deps**: bash + python3 + uuidgen + flock only. `jq` is preferred for span close but optional (python3 fallback).
- **PII**: do NOT capture stdin/stdout content into spans. Only metadata (tool name, cwd, exit_code, file_path basename). Prompt content stays in Claude Code's own session log.
- **Concurrency**: parallel SubagentStart events from `atlas-team` create sibling spans under the same trace_id. Atomic append via `flock` ensures no JSONL corruption.

## Integration Points (across the plugin)

| Component | Touch point | Rationale |
|-----------|-------------|-----------|
| `hooks/trace-id-injector.sh` | PreToolUse + SubagentStart | Span open |
| `hooks/trace-id-finalizer.sh` | PostToolUse + SubagentStop | Span close |
| `skills/skill-scorecard` (W1.2) | Reads JSONL by skill_name attr | Rolling perf metrics |
| `skills/trace-replay` (W1.3) | Reads JSONL → ASCII timeline | Post-hoc debug |
| `skills/cost-analytics` (W1.4) | Joins on trace_id | $ per skill call-tree |
| `skills/atlas-eval` (W1.5) | Wraps invocation in trace span | Repro scoring |

## References

- Plan: `.blueprint/plans/ultrathink-regarde-ce-qui-abundant-petal.md` Section H W1.1
- SOTA: OpenTelemetry semantic conventions (span model adapted for shell-hook context)
- Reuse pattern: `hooks/auto-tail-agent` (subagent_id extraction, fast-fail JSON parse)
- Companion: `hooks/scorecard-emitter` (W1.2), `skills/trace-replay` (W1.3)
