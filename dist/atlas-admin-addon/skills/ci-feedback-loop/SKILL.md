---
name: ci-feedback-loop
description: "Post-push CI monitoring until terminal state. This skill should be used after every git push, when the user asks to 'check CI', '/a-ci', 'wait for CI', or whenever LAW-WORKFLOW-001 requires verification before further work."
effort: low
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [ci-management, finishing-branch, verification]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: quality
emoji: "🔄"
triggers: ["check CI", "wait for CI", "pipeline status", "post-push verify", "CI green?"]
---

<HARD-GATE>
NO SECOND PUSH TO THE SAME BRANCH WITHOUT CI VERIFY.
After git push, poll pipeline until terminal state (success/failure/error).
If red: triage + fix + re-push + re-verify. NEVER push through red CI silently.
Signature: sha256:LAW-WORKFLOW-001 (db7f6890b4e49ec020980a354a420ea142965d2725e48ef6227bab12adacc188)
</HARD-GATE>

**Iron Law**: `LAW-WORKFLOW-001` (no-push-without-ci-verify). Override requires HITL AskUserQuestion with "CI is red — push anyway? reason: ___".

<red-flags>
| Thought | Reality |
|---|---|
| "Tests passed locally, CI will be fine" | Different environment, different data, different concurrency. Local green ≠ CI green. Wait for the pipeline. |
| "I'll check CI tomorrow" | Tomorrow's you is dealing with a cascade of 8 broken commits. Now-you has 1 commit to triage. |
| "The pipeline usually takes 10 min, let me start the next thing" | Yes, AFTER green. Before green = context-switch penalty when CI red interrupts Phase 2 mid-sentence. |
| "Only l1-structural failed, unrelated to my change" | Prove it. Run the test locally. If truly unrelated, document + file issue. Don't guess. |
| "Push through red CI just this once" | "Just once" compounds. 27 red pushes in a row is the 2026-04-23 incident lesson. |
</red-flags>

# CI Feedback Loop

## Purpose

After every `git push`, poll the CI pipeline to terminal state BEFORE moving to the
next work item. Enforces LAW-WORKFLOW-001. Catches regressions in the shortest
possible feedback loop.

## The Loop (strict sequence)

```
1. git push                                  → CI triggers
2. Fetch pipeline ID for current branch      → via Woodpecker API
3. Poll every 20-30s until terminal state    → running → success | failure | error
4a. If SUCCESS                               → OK to continue next work
4b. If FAILURE                               → triage + fix + re-push + goto 1
```

## Commands (Woodpecker + Forgejo)

```bash
source ~/.env  # loads WP_TOKEN

# Get latest pipeline on current branch
BRANCH=$(git rev-parse --abbrev-ref HEAD)
PIPELINE_ID=$(curl -s -H "Authorization: Bearer ${WP_TOKEN}" \
  "https://ci.axoiq.com/api/repos/2/pipelines?branch=${BRANCH}&limit=1" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d[0]['number'])")

# Poll status
STATUS=$(curl -s -H "Authorization: Bearer ${WP_TOKEN}" \
  "https://ci.axoiq.com/api/repos/2/pipelines/${PIPELINE_ID}" \
  | python3 -c "import json,sys; print(json.load(sys.stdin).get('status'))")

# Terminal states: success | failure | error | killed | declined | blocked
```

For the Monitor tool (automated polling with notifications):

```bash
Monitor(
  command="source ~/.env; last=''; while true; do \
    pl=$(curl -s -H 'Authorization: Bearer ${WP_TOKEN}' \
      'https://ci.axoiq.com/api/repos/2/pipelines?branch=BRANCH&limit=1'); \
    num=$(echo \"$pl\" | python3 -c \"import json,sys;d=json.load(sys.stdin);p=d[0] if isinstance(d,list) and d else None;print(p.get('number','?') if p else '?')\"); \
    st=$(echo \"$pl\" | python3 -c \"import json,sys;d=json.load(sys.stdin);p=d[0] if isinstance(d,list) and d else None;print(p.get('status','?') if p else '?')\"); \
    if [[ \"$st\" != \"$last\" ]]; then echo \"[$(date +%H:%M:%S)] #${num}: ${st}\"; last=\"$st\"; fi; \
    case \"$st\" in success|failure|error|killed) echo \"[TERMINAL] #${num} => ${st}\"; break;; esac; \
    sleep 20; \
  done",
  timeout_ms=900000
)
```

## Failure Triage Checklist

On failure:
1. Identify failing step: `/api/repos/2/pipelines/{id}` → workflows[].children[] with state=failure
2. Fetch logs via web UI or `claude --print "pull log for step X"` (API returns HTML not JSON)
3. Reproduce locally before guessing: run the exact step's command
4. Fix root cause (not workaround)
5. Re-push → re-enter the loop

## When NOT to use this skill

- Dry-run / local-only work (no push happened)
- CI disabled for this branch (documented in CI yaml)
- Explicit HITL override with recorded reason in decision-log

## Integration with .claude/ci-audit.jsonl

This skill reads/writes `.claude/ci-audit.jsonl` (via `hooks/ci-audit-log`). Each
push gets one entry; this skill updates `resolved_at` + `failed_tests` on terminal.

## See also

- `ci-management` — broader CI admin (restart, cancel, secrets)
- `finishing-branch` — completes branch → implies final CI verify
- `verification` — code-level verification before push
- `LAW-WORKFLOW-001` in `iron-laws.yaml`
