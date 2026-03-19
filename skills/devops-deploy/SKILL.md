---
name: devops-deploy
description: "Unified deployment orchestration: pre-flight → CI monitor → deploy (staging/prod/sandbox) → health check → custom validators → data sync → report. Config-driven via .atlas/deploy.yaml."
effort: medium
---

# DevOps Deploy

Deploy code to any environment with safety gates, health checks, and rollback support.
Config-driven via `.atlas/deploy.yaml`. Works with Forgejo, GitHub, GitLab, bare SSH.

**Hard gate:** Production deployments ALWAYS require HITL approval via AskUserQuestion.

## Config

Reads `.atlas/deploy.yaml` at project root. Falls back to minimal mode (git push + CI watch) if absent.

Key fields: `project`, `platform` (forgejo|github|gitlab), `environments` (type, host, directory, compose_file, env_file, health_url, branch, auto_deploy, hitl_gate), `validators` (name, command), `data_sync` (type, script, commands).

## Forgejo API

> External URL behind CF Access → 302. ALWAYS use internal IP from config or default `http://192.168.10.75:3000/api/v1`.
> Full patterns: `.claude/references/forgejo-api.md`

```bash
source ~/.env  # loads $FORGEJO_TOKEN
FORGEJO_API="${config_forgejo_api_base:-http://192.168.10.75:3000/api/v1}"
```

## Process (10 Steps)

| Step | Action | HITL |
|------|--------|------|
| 1. Pre-flight | Read config, check `git status` clean, detect branch/env | No |
| 2. Local validation | Run tests if not already done (skip if recent) | No |
| 3. Push code | `git push origin <branch>` | No |
| 4. CI monitor | Poll CI status every 30s, max 10min. Fail → show logs, offer fix/abort | No |
| 5. HITL gate | Prod: AskUserQuestion (deploy/dry-run/abort) | **Prod: YES** |
| 6. Deploy | Execute per type (docker-compose, ssh-docker, ssh-bare, deploy_script) | No |
| 7. Health check | `curl -sf <health_url>`, retry 3x/10s. Fail → rollback | No |
| 8. Validators | Run custom checks from config (advisory, non-blocking) | No |
| 9. Data sync | Optional: AskUserQuestion for DB sync (prod=HITL) | **Prod: YES** |
| 10. Report | Show env/status/version/health summary table | No |

### Deploy Types

| Type | Command Pattern |
|------|----------------|
| `docker-compose` | `docker compose -f <file> up -d --build` + alembic |
| `ssh-docker` | `ssh <host> "cd <dir> && git pull && docker compose up -d --build"` |
| `ssh-bare` | `ssh <host> "cd <dir> && <deploy_commands>"` |
| `deploy_script` | `DEPLOY_SSH_HOST=<host> ./scripts/deploy.sh <env>` |

## Subcommands

| Command | Description | HITL |
|---------|-------------|------|
| `/atlas deploy [env]` | Deploy to env (or auto-detect) | Prod: yes |
| `/atlas deploy status` | Health check all environments | No |
| `/atlas deploy promote` | PR dev→main, wait CI, merge, deploy prod | Yes |
| `/atlas deploy sync [env]` | Data sync (golden dump) | Prod: yes |
| `/atlas deploy rollback <env>` | Rollback to previous commit | Always |
| `/atlas deploy dry-run [env]` | Show plan without executing | No |

## HITL Matrix

| Phase | Staging | Prod | Sandbox |
|-------|---------|------|---------|
| Deploy | Auto | ⚠️ HITL | Auto |
| Data sync | Auto | ⚠️ HITL | Auto |
| Rollback | ⚠️ HITL | ⚠️ HITL | Auto |

## Principles

- Prod = HITL always. Health check mandatory. Rollback ready.
- Config-driven (zero hardcode). Platform agnostic. Max 2 retries → escalate.
- Evidence before assertions — never claim "deployed" without health check proof.

## Error Recovery

| Scenario | Action |
|----------|--------|
| Health check fails | Retry 3x → rollback → AskUserQuestion |
| SSH/CI fails | Show error → offer fix/manual → AskUserQuestion |
| Data sync fails | Auto-rollback DB → AskUserQuestion |
