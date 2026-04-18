---
name: smoke-gate
description: "Post-deploy G3 gate. Run scripts/smoke.sh against dev/staging/prod, emit structured JSON, create Forgejo issue on red (alert-only policy)."
triggers:
  - "/atlas smoke-gate"
  - "/atlas smoke"
  - "smoke test after deploy"
  - "verify deploy"
  - "post-deploy smoke"
effort: low
---

# Smoke-Gate — Post-Deploy Integration Gate

Runs the curl-based smoke harness against a deployed environment. Catches
the **contract-drift bug class** (e.g. attribute name renames, SSE shape
changes) that mock-based unit tests miss.

> **Persona bug class**: on 2026-04-16, 49 unit tests passed green while
> a real curl detected `persona.persona_id` vs `.name` drift in <10s.
> This skill is the automation of that curl.

## Commands

```bash
/atlas smoke-gate                         # --env dev by default
/atlas smoke-gate --env staging
/atlas smoke-gate --env prod              # careful — hits production
/atlas smoke-gate --only health,auth      # subset
/atlas smoke-gate --json-out report.json  # machine-readable
/atlas smoke-gate --create-issue          # on red: post Forgejo issue
```

## What it tests

Reads `scripts/smoke-endpoints.yml` from the current repo. Typical checks:

- **Liveness**: `/health`, `/api/v1/knowledge/brain/health`
- **Auth**: login + token capture (downstream endpoints need the token)
- **Canonical streams**: `/api/v1/chat/stream` — asserts `event: status/sources/done`
  arrive within timing budget. Catches persona-bug class.
- **RBAC**: admin routes return 403 for non-admin token
- **DB read paths**: conversations list, projects list, instruments list

## Output

```json
{
  "env": "dev",
  "base_url": "https://synapse-dev.axoiq.com",
  "run": 10, "failed": 0, "passed": 10,
  "generated_at": "2026-04-17T02:37:00Z",
  "results": [
    {"name":"health","status":200,"duration_ms":13,"pass":true,"reasons":[]},
    ...
  ]
}
```

## Rollback policy (ALERT-ONLY)

- Smoke red → `scripts/smoke-report.py` creates Forgejo issue tagged
  `smoke-fail` with reproducible curl for each failure
- NO automatic rollback — human or AI-session reviews issue and decides
- Rationale: **predictable state > silent revert** for AI-assisted dev
- Flip to auto-rollback: after 2 weeks zero false-positives, see
  `memory/smoke-reports/policy-eval-*.md`

## Files

- Implementation wrapper: `${CLAUDE_PLUGIN_ROOT}/skills/smoke-gate/smoke-gate.sh`
- Synapse harness (source of truth): `scripts/smoke.sh`, `scripts/smoke-endpoints.yml`
- Issue builder: `scripts/smoke-report.py`
- CI trigger: `.woodpecker/post-deploy-smoke.yml`

## Monitor Pattern (v6.0 SOTA)

Stream smoke test runs in real-time:

```bash
Monitor({
  description: "smoke gate failures or completion",
  command: "scripts/smoke.sh --watch | grep --line-buffered -E 'FAIL|PASS|exit'",
  persistent: false,
  timeout_ms: 120000  # 2 min smoke tests are quick
})
```

Match BOTH FAIL et PASS et exit signatures. If silent → smoke crashed, investigate.

## References

- `.blueprint/plans/hazy-mapping-stallman.md` Section E + Phase 2 T2.1-T2.4
- `.claude/rules/testing-mock-budget.md` — enforcement rule that mandates
  a smoke-endpoints.yml entry for every new POST endpoint
