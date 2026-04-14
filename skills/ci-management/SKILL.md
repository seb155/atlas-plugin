---
name: ci-management
description: "CI/CD pipeline management for Woodpecker CI. Check status, view logs, rerun pipelines, manage agent fleet. Triggers on: /ci, 'CI status', 'check pipeline', 'rerun CI', 'agent status'."
effort: low
---

# CI Management — Woodpecker CI Pipeline

Manage the Woodpecker CI pipeline at `ci.axoiq.com`. Use the `forgejo-ci` subagent for detailed log analysis.

## When to Use

- User says "CI status", "check pipeline", "rerun CI", "agent status"
- After pushing code to check if CI passes
- When debugging CI failures
- Managing agent fleet capacity

## Sub-commands

| Command | Action |
|---------|--------|
| `atlas ci` or `atlas ci status` | List recent pipelines with status |
| `atlas ci logs <pipeline>` | Step table for a pipeline (name, pid, step_id, state) |
| `atlas ci logs <pipeline> --step <X>` | Decoded plain-text logs for step (X = name, pid, or step_id) |
| `atlas ci logs <pipeline> --all` | Decoded logs for every step in order |
| `atlas ci help` | Full usage + env vars |

**Reading logs programmatically — one-liner:**

```bash
atlas ci logs 78 --step frontend-install   # decoded bun/tsc/ruff output
```

No SSH needed. Uses Woodpecker 3.14 REST API via `$WP_TOKEN` (Bearer). See
`references/woodpecker-api-paths.md` for endpoint catalog + common pitfalls
(step_id ≠ pid, SPA-HTML fallback on wrong path).

## Architecture

| Component | Host | Details |
|-----------|------|---------|
| WP Server | 192.168.10.76 (LXC 107) | Docker, SQLite, Caddy → `ci.axoiq.com` |
| Agent PVE1 | 192.168.10.75 (LXC 105) | capacity=2, Docker |
| Agent PVE2 | 192.168.10.70 (VM 700) | capacity=2, Docker |
| **Total** | | **4 concurrent jobs** |

## Pipeline Files

| File | Triggers | Steps |
|------|----------|-------|
| `.woodpecker/ci.yml` | push dev/main/feature/* | lint, security, tests, typecheck, test, build, docs |
| `.woodpecker/security.yml` | push dev/main | pip-audit, frontend-audit, secret-scan (gitleaks) |
| `.woodpecker/deploy-dev.yml` | push dev | staging + sandbox deploy, health-check, telegram |
| `.woodpecker/deploy-prod.yml` | push main | production deploy, health-check, telegram |

## API Access

- **UI**: `https://ci.axoiq.com` (Forgejo OAuth SSO)
- **API (public)**: `https://ci.axoiq.com/api/*` — Bearer auth via `$WP_TOKEN` (works, no SSO bypass needed)
- **API (internal)**: `http://192.168.10.76:8000/api` (on-LAN direct, same payload)
- **Swagger spec**: `https://ci.axoiq.com/swagger/doc.json` — authoritative path reference
- **DB Direct**: `ssh root@192.168.10.76` → SQLite at Docker volume (fallback for admin ops only)
- **Env var**: `WP_TOKEN` in `~/.env` (generate at ci.axoiq.com/user/tokens)

> **Pitfall**: When `/api/*` returns `Content-Type: text/html` (SPA fallback HTML), the **path is wrong**, not the auth. Always verify Content-Type when diagnosing API issues. See `references/woodpecker-api-paths.md`.

## Quick Queries (SSH + SQLite)

```bash
# Recent pipelines
ssh root@192.168.10.76 'sqlite3 /var/lib/docker/volumes/woodpecker_woodpecker-data/_data/woodpecker.sqlite \
  "SELECT number, status FROM pipelines WHERE repo_id=1 ORDER BY number DESC LIMIT 5;"'

# Step details for pipeline N
ssh root@192.168.10.76 'sqlite3 /var/lib/docker/volumes/woodpecker_woodpecker-data/_data/woodpecker.sqlite \
  "SELECT s.name, s.state, s.exit_code FROM steps s WHERE s.pipeline_id=(SELECT id FROM pipelines WHERE number=N AND repo_id=1) ORDER BY s.pid;"'
```

## Notes

- Woodpecker v3 breaking changes: no `:latest` tag, `from_secret:` syntax, no `mem_limit`
- Frontend typecheck/test use `failure: ignore` (pre-existing TS debt)
- Deploy steps have `failure: ignore` (infra-dependent, shouldn't block CI)
- Forgejo Actions REMOVED from Synapse 2026-04-11 (Woodpecker is sole CI for synapse repo)
- ATLAS plugin repo still uses Forgejo Actions (separate CI)
- Use `ci-feedback-loop` skill for automated push → CI green workflow

## Delegation

- Detailed log analysis: invoke `forgejo-ci` subagent
- Post-push monitoring: invoke `ci-feedback-loop` skill
