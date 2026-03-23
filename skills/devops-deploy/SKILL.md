---
name: devops-deploy
description: "Unified deployment orchestration: pre-flight → CI monitor → deploy (staging/prod/sandbox) → health check → custom validators → data sync → report. Config-driven via .atlas/deploy.yaml. Supports deployment modes (auto/gated/manual) and types (full/quick/hotfix/promote)."
effort: medium
---

# DevOps Deploy

Deploy code to any environment with safety gates, health checks, and rollback support.
Config-driven via `.atlas/deploy.yaml`. Works with Forgejo, GitHub, GitLab, bare SSH.

## Deployment Types

Present these via AskUserQuestion when the user says `/atlas deploy` without specifying:

| Type | Description | When to Use |
|------|-------------|-------------|
| **full** | Push → CI wait → deploy all envs → DB migrate → health check → report | Release candidate, end of sprint |
| **quick** | Push → deploy target env → health check (skip CI wait) | Hotfix, urgent patch |
| **promote** | Merge dev→main (PR + approve + merge) → auto-deploy prod | Promotion to production |
| **staging** | Push → deploy staging only → health check | Integration testing |
| **status** | Health check all environments | Monitoring |
| **sync** | Data sync (golden dump) to target env | Data refresh |
| **rollback** | Revert to previous commit on target env | Recovery |

## Deployment Modes

| Mode | HITL Gates | When |
|------|-----------|------|
| **auto** | None — fully autonomous | Solo dev, all tests pass locally |
| **gated** | Prod only (AskUserQuestion) | Team environment, needs review |
| **manual** | Every step confirmed | Critical system, compliance |

Default: detect from `.atlas/deploy.yaml` field `mode:` or fall back to `auto` if solo dev.

## Config

Reads `.atlas/deploy.yaml` at project root. Falls back to minimal mode (git push + CI watch) if absent.

Key fields: `project`, `platform` (forgejo|github|gitlab), `mode` (auto|gated|manual), `environments` (type, host, directory, compose_file, env_file, health_url, branch, auto_deploy, hitl_gate), `validators` (name, command), `data_sync` (type, script, commands).

## Forgejo API

> External URL behind CF Access → 302. ALWAYS use resolved URL from detect-network.sh or config.json.
> Full patterns: `.claude/references/forgejo-api.md`

```bash
source ~/.env  # loads $FORGEJO_TOKEN + $FORGEJO_CI_BOT_TOKEN
FORGEJO_LOCAL=$(python3 -c "import json,os; d=json.load(open(os.path.expanduser('~/.atlas/config.json'))); print(d['services']['forgejo']['local_url'])" 2>/dev/null || echo "")
FORGEJO_API_PATH=$(python3 -c "import json,os; d=json.load(open(os.path.expanduser('~/.atlas/config.json'))); print(d['services']['forgejo']['api_path'])" 2>/dev/null || echo "/api/v1")
FORGEJO_API="${FORGEJO_LOCAL}${FORGEJO_API_PATH}"
```

### Promote Flow (Forgejo-specific)

The `promote` type uses `scripts/deploy.sh promote` which automates:
1. Create PR dev→main via Forgejo API
2. ci-bot approves (via `$FORGEJO_CI_BOT_TOKEN`)
3. Update branch (merge main into dev if behind)
4. Force-merge PR (`force_merge: true` — bypasses branch protection for admin)
5. Prod auto-deploy triggered by Forgejo Actions on main push

```bash
# One-liner promote:
source ~/.env && DEPLOY_SSH_HOST=docker01 ./scripts/deploy.sh promote
```

### Merge Gotchas (Forgejo v14.x)

- `"Do"` is PascalCase, not `"do"` (lowercase = ignored silently)
- `force_merge: true` bypasses all protections (needs admin token)
- `merge_whitelist_usernames` must NOT be empty if `enable_merge_whitelist: true`
- Always call `/pulls/{N}/update` before merge to avoid "head behind base" error
- ci-bot cannot approve own PR — use separate bot token

## Process (10 Steps)

| Step | Action | HITL |
|------|--------|------|
| 1. Pre-flight | Read config, check `git status` clean, detect branch/env | No |
| 2. Local validation | Run tests if not already done (skip if recent) | No |
| 3. Push code | `git push origin <branch>` | No |
| 4. CI monitor | Poll CI status every 30s, max 10min. Fail → show logs, offer fix/abort | No |
| 5. HITL gate | Only in `gated`/`manual` mode for prod. AskUserQuestion (deploy/dry-run/abort) | **Gated** |
| 6. Deploy | Execute per type (docker-compose, ssh-docker, ssh-bare, deploy_script) | No |
| 7. Health check | `curl -sf <health_url>`, retry 3x/10s. Fail → rollback | No |
| 8. Validators | Run custom checks from config (advisory, non-blocking) | No |
| 9. Data sync | Optional: AskUserQuestion for DB sync (prod=HITL in gated mode) | **Gated** |
| 10. Report | Show env/status/version/health summary table | No |

### Deploy Types

| Type | Command Pattern |
|------|----------------|
| `docker-compose` | `docker compose -f <file> up -d --build` + alembic |
| `ssh-docker` | `ssh <host> "cd <dir> && git pull && docker compose up -d --build"` |
| `ssh-bare` | `ssh <host> "cd <dir> && <deploy_commands>"` |
| `deploy_script` | `DEPLOY_SSH_HOST=<host> ./scripts/deploy.sh <env>` |

### Quick Deploy (skip CI)

For `quick` type, skip steps 2-4 (validation, push, CI wait) and go directly to deploy.
Use when: hotfix already tested locally, time-critical patch.

```bash
# Skip CI, deploy staging immediately:
DEPLOY_SSH_HOST=docker01 ./scripts/deploy.sh staging
```

## Subcommands

| Command | Description | Type | HITL |
|---------|-------------|------|------|
| `/atlas deploy` | Auto-detect type via AskUserQuestion | — | Depends |
| `/atlas deploy full` | Full pipeline: push → CI → all envs | full | Gated:prod |
| `/atlas deploy quick [env]` | Skip CI, deploy immediately | quick | No |
| `/atlas deploy promote` | PR dev→main, approve, merge, auto-deploy prod | promote | No (auto) |
| `/atlas deploy staging` | Deploy dev → staging only | staging | No |
| `/atlas deploy prod` | Deploy main → prod only | full | Gated |
| `/atlas deploy sandbox` | Deploy dev → sandbox only | quick | No |
| `/atlas deploy status` | Health check all environments | status | No |
| `/atlas deploy sync [env]` | Data sync (golden dump) | sync | Gated:prod |
| `/atlas deploy rollback <env>` | Rollback to previous commit | rollback | Always |
| `/atlas deploy dry-run [env]` | Show plan without executing | — | No |
| `/atlas deploy all` | Deploy all envs (staging+prod+sandbox) | full | Gated:prod |

## HITL Matrix (by mode)

### Auto Mode (solo dev)
| Phase | Staging | Prod | Sandbox |
|-------|---------|------|---------|
| Deploy | ✅ Auto | ✅ Auto | ✅ Auto |
| Data sync | ✅ Auto | ✅ Auto | ✅ Auto |
| Rollback | ✅ Auto | ⚠️ HITL | ✅ Auto |

### Gated Mode (team/production)
| Phase | Staging | Prod | Sandbox |
|-------|---------|------|---------|
| Deploy | ✅ Auto | ⚠️ HITL | ✅ Auto |
| Data sync | ✅ Auto | ⚠️ HITL | ✅ Auto |
| Rollback | ⚠️ HITL | ⚠️ HITL | ✅ Auto |

## Principles

- Config-driven (zero hardcode). Platform agnostic. Max 2 retries → escalate.
- Evidence before assertions — never claim "deployed" without health check proof.
- Solo dev (`mode: auto`) = no gates. Team (`mode: gated`) = prod gates only.
- `promote` always uses `force_merge` for reliability (admin token required).

## Error Recovery

| Scenario | Action |
|----------|--------|
| Health check fails | Retry 3x → rollback → AskUserQuestion |
| SSH/CI fails | Show error → offer fix/manual → AskUserQuestion |
| Data sync fails | Auto-rollback DB → AskUserQuestion |
| PR merge fails ("head behind base") | Auto-update branch → retry merge |
| PR merge fails ("not enough approvals") | ci-bot auto-approve → retry merge |
| Docker container conflict | `docker compose down --remove-orphans` → retry |

## Implementation Notes

### SSH Host Detection
```bash
# detect SSH host from deploy.yaml or fallback
SSH_HOST=$(grep -A2 "ssh:" .atlas/deploy.yaml | grep "target_host" | awk '{print $2}' | tr -d '"')
# Or use the ~/.ssh/config alias
SSH_HOST="${DEPLOY_SSH_HOST:-docker01}"
```

### deploy.sh Integration
The project's `scripts/deploy.sh` is the SSOT for deploy logic. This skill orchestrates it:
```bash
source ~/.env
DEPLOY_SSH_HOST=docker01 ./scripts/deploy.sh promote    # create PR + approve + merge
DEPLOY_SSH_HOST=docker01 ./scripts/deploy.sh staging     # deploy staging
DEPLOY_SSH_HOST=docker01 ./scripts/deploy.sh prod        # deploy prod
DEPLOY_SSH_HOST=docker01 ./scripts/deploy.sh all         # all envs
DEPLOY_SSH_HOST=docker01 ./scripts/deploy.sh status      # health checks
```
