---
name: devops-deploy
description: "Unified deployment orchestration: pre-flight → CI monitor → deploy (staging/prod/sandbox) → health check → custom validators → data sync → report. Config-driven via .atlas/deploy.yaml."
---

# DevOps Deploy

Deploy code to any environment with safety gates, health checks, and rollback support.
Works with any platform (Forgejo, GitHub, GitLab, bare SSH) via project-level config.

## Overview

Extends the ATLAS pipeline beyond SHIP:

```
DISCOVER → PLAN → IMPLEMENT → VERIFY → SHIP → DEPLOY → VALIDATE
                                                ^^^^^^^^^^^^^^
                                                this skill
```

**Hard gate:** Production deployments ALWAYS require HITL approval via AskUserQuestion.

## Configuration

The skill reads `.atlas/deploy.yaml` at project root. If absent, falls back to minimal mode
(git push + watch CI). See examples at the end of this skill.

### Config Schema

```yaml
project: <name>                    # Project identifier
platform: forgejo|github|gitlab    # Git platform for PR/CI
deploy_script: ./scripts/deploy.sh # Optional: custom deploy script

environments:
  <env-name>:
    type: docker-compose|ssh-docker|ssh-bare|vercel-preview|vercel-production
    host: <ssh-host>               # SSH config alias or IP
    directory: <remote-path>       # Remote project directory
    compose_file: <file>           # Docker compose file
    env_file: <file>               # Environment file
    health_url: <url>              # Health check endpoint
    branch: <branch>               # Git branch to deploy
    auto_deploy: true|false        # CI triggers deploy automatically
    hitl_gate: true|false          # Require human approval (always true for prod)

validators:                        # Optional: custom post-deploy checks
  - name: <check-name>
    command: <bash-command>
    description: <what-it-checks>

data_sync:                         # Optional: DB/file sync
  type: script|command|none
  script: <path-to-sync-script>
  commands:                        # Named sync commands
    export: <cmd>
    push: <cmd>
    push_staging: <cmd>
    push_prod: <cmd>
    status: <cmd>
```

## Process

### Step 1: Pre-Flight

1. Read `.atlas/deploy.yaml` (or detect minimal mode)
2. Check `git status` — must be clean
3. Detect current branch and environment
4. Verify target env exists in config
5. Show deployment summary via AskUserQuestion (for prod) or auto-proceed (staging/sandbox)

### Step 2: Validate Local (Optional)

If not already done by `verification` skill:

```bash
# Backend
docker exec <backend-container> bash -c "cd /app && python -m pytest tests/ -x -q --tb=short"

# Frontend
cd frontend && bunx vitest --run && bun run type-check && bunx vite build
```

Skip if tests were already run in current session.

### Step 3: Push Code

**If `auto_deploy: true`:** Just push to the target branch. CI handles deploy.

```bash
git push origin <branch>
```

**If `auto_deploy: false`:** Execute deploy manually.

### Step 4: CI Monitor

Invoke `ci-feedback-loop` skill pattern:

1. Check CI status via platform API (Forgejo/GitHub)
2. Wait for CI green (poll every 30s, max 10 min)
3. If CI fails → show logs, offer fix-and-retry or abort

### Step 5: HITL Gate (Production Only)

For environments with `hitl_gate: true`:

```
AskUserQuestion:
  "Deploy to PROD confirmed?"
  - "Yes, deploy now" — proceed
  - "Dry run first" — show what would happen
  - "Abort" — cancel
```

### Step 6: Deploy

Execute deployment based on `type`:

**docker-compose (local):**
```bash
docker compose -f <compose_file> up -d --build
docker compose -f <compose_file> exec -T backend alembic upgrade head
```

**ssh-docker (remote):**
```bash
ssh <host> "cd <directory> && git pull origin <branch> && \
  docker compose -f <compose_file> --env-file <env_file> up -d --build && \
  docker compose -f <compose_file> exec -T backend alembic upgrade head"
```

**ssh-bare (remote without Docker):**
```bash
ssh <host> "cd <directory> && <deploy_commands>"
```

**deploy_script (custom):**
```bash
DEPLOY_SSH_HOST=<host> ./scripts/deploy.sh <env-name>
```

### Step 7: Health Check

```bash
curl -sf --max-time 30 <health_url>
```

Retry 3 times with 10s interval. If all fail → rollback or escalate.

### Step 8: Custom Validators

Run each validator from config:

```bash
for validator in validators:
  result = run(validator.command)
  if fail: report but don't block (advisory)
```

### Step 9: Data Sync (Optional)

If `data_sync` configured and user requests it:

```
AskUserQuestion:
  "Sync database to <env>?"
  - "Yes, sync now" — run sync command
  - "Skip" — code only, no data sync
```

### Step 10: Report

Show deployment summary:

```
╔════════════════════════════════════════════╗
║  DEPLOYMENT REPORT — 2026-03-17 05:40 EDT ║
╠════════════════════════════════════════════╣
║ Env        Status    Version    Health     ║
║ ─────────  ────────  ─────────  ──────── ║
║ staging    ✅ OK     fcdc18e4   healthy    ║
║ prod       ✅ OK     fcdc18e4   healthy    ║
║ sandbox    ✅ OK     fcdc18e4   healthy    ║
╠════════════════════════════════════════════╣
║ Validators                                ║
║ ─────────                                 ║
║ gpu-health    ✅ YOLO service OK           ║
║ ollama        ✅ 27 models available       ║
║ copilot       ✅ qwen3:8b, standard        ║
╚════════════════════════════════════════════╝
```

## Subcommands

| Command | Description | HITL |
|---------|-------------|------|
| `/atlas deploy [env]` | Deploy to specific env (or all) | Prod: yes |
| `/atlas deploy status` | Health check all environments | No |
| `/atlas deploy promote` | Merge dev→main (PR or direct) | Yes |
| `/atlas deploy sync [env]` | Data sync (golden dump, etc.) | Prod: yes |
| `/atlas deploy rollback <env>` | Rollback to previous version | Always |
| `/atlas deploy dry-run [env]` | Show what would happen | No |

### deploy status

Quick health check of all configured environments:

```bash
for env in config.environments:
  curl -sf <health_url> → status
  show: env | status | version | health
```

### deploy promote

Merge dev→main and trigger prod deploy:

1. Check dev is ahead of main
2. Create PR via Forgejo/GitHub API
3. Wait for CI green
4. Merge PR (HITL gate)
5. Watch prod deploy

### deploy rollback

```bash
ssh <host> "cd <directory> && git log --oneline -5"
# Show last 5 commits, let user pick rollback target
ssh <host> "cd <directory> && git checkout <commit> && docker compose up -d --build"
```

## Key Principles

- **Prod = HITL always** — never auto-deploy to production without confirmation
- **Health check mandatory** — every deploy must pass health check before reporting success
- **Rollback ready** — know how to undo before you do
- **Config-driven** — zero hardcoded environments, all from `.atlas/deploy.yaml`
- **Platform agnostic** — Forgejo, GitHub, GitLab, bare SSH all supported
- **Max 2 retries** — if deploy fails twice, escalate via AskUserQuestion
- **Evidence before assertions** — never claim "deployed" without health check proof
- **Minimal mode** — works without config (just git push + CI watch)

## HITL Gates

| Phase | Staging | Prod | Sandbox |
|-------|---------|------|---------|
| Deploy approval | Auto | ⚠️ HITL | Auto |
| Data sync | Auto | ⚠️ HITL | Auto |
| Rollback | ⚠️ HITL | ⚠️ HITL | Auto |

## Integration with Other Skills

| Workflow | Chain |
|----------|-------|
| After shipping code | `finishing-branch` → offers "Deploy to staging?" → `devops-deploy` |
| Full pipeline | `plan-builder` → `tdd` → `verification` → `finishing-branch` → `devops-deploy` |
| CI monitoring | `devops-deploy` uses `ci-feedback-loop` pattern internally |
| Pre-deploy validation | `verification` → `devops-deploy` |
| Environment audit | `devops-deploy status` (standalone health check) |

## Error Recovery

| Scenario | Action |
|----------|--------|
| Health check fails | Retry 3x → rollback if persistent → AskUserQuestion |
| SSH connection fails | Show error → suggest manual SSH → AskUserQuestion |
| CI fails | Show logs → offer fix-and-retry or abort |
| Deploy script fails | Show stderr → offer manual intervention |
| Data sync fails | Auto-rollback DB from backup → AskUserQuestion |

## Config Examples

### Synapse (Forgejo + Docker + SSH + GPU)

```yaml
project: synapse
platform: forgejo
deploy_script: ./scripts/deploy.sh

environments:
  local:
    type: docker-compose
    compose_file: compose.yml
    health_url: http://localhost:8001/health
    branch: dev

  staging:
    type: ssh-docker
    host: target
    directory: /opt/synapse-dev
    compose_file: docker-compose.dev-remote.yml
    env_file: .env.dev
    health_url: https://synapse-dev.home.axoiq.com/api/v1/health
    branch: dev
    auto_deploy: true

  prod:
    type: ssh-docker
    host: target
    directory: /opt/synapse
    compose_file: docker-compose.prod.yml
    env_file: .env.prod
    health_url: https://synapse.home.axoiq.com/api/v1/health
    branch: main
    auto_deploy: true
    hitl_gate: true

  sandbox:
    type: ssh-docker
    host: target
    directory: /opt/synapse-sandbox
    compose_file: docker-compose.sandbox.yml
    env_file: .env.sandbox
    health_url: http://192.168.10.50:8004/health
    branch: dev
    auto_deploy: true

validators:
  - name: gpu-health
    command: "curl -sf http://192.168.10.55:8090/api/v1/health"
    description: "YOLO GPU service"
  - name: ollama-health
    command: "curl -sf http://192.168.10.55:11434/api/tags"
    description: "Ollama LLM models"
  - name: copilot-health
    command: "curl -sf {health_url_base}/api/v1/copilot/health"
    description: "Copilot RAG service"
  - name: observability
    command: "curl -sf http://192.168.10.56:3001/api/health"
    description: "Grafana observability"

data_sync:
  type: script
  script: ./scripts/sync-db.sh
  commands:
    export: "export"
    push: "push"
    push_staging: "push-staging"
    push_prod: "push-prod"
    status: "status"
```

### Simple SaaS (GitHub + Vercel)

```yaml
project: my-app
platform: github

environments:
  staging:
    type: vercel-preview
    health_url: https://staging.my-app.com/api/health
    branch: dev
    auto_deploy: true

  prod:
    type: vercel-production
    health_url: https://my-app.com/api/health
    branch: main
    hitl_gate: true
```

### Bare-Metal SSH

```yaml
project: internal-tool
platform: forgejo

environments:
  prod:
    type: ssh-bare
    host: prod-server
    directory: /opt/app
    deploy_commands:
      - "git pull origin main"
      - "pip install -r requirements.txt"
      - "systemctl restart app"
    health_url: http://prod-server:8000/health
    branch: main
    hitl_gate: true
```
