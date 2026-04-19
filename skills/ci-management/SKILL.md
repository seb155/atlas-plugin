---
name: ci-management
description: "Woodpecker CI/CD pipeline management. This skill should be used when the user asks to '/ci', 'CI status', 'check pipeline', 'rerun CI', 'agent status', or needs log viewing and agent fleet management."
effort: low
---

# CI Management — Woodpecker CI Pipeline

Manage the Woodpecker CI pipeline at `ci.axoiq.com`. Use the `forgejo-ci` subagent for detailed log analysis.

## When to Use

- User says "CI status", "check pipeline", "rerun CI", "agent status"
- After pushing code to check if CI passes
- When debugging CI failures
- Managing agent fleet capacity

## Sub-commands (v5.18.0+ — comprehensive Woodpecker CLI)

### Pipelines — read

| Command | Action |
|---------|--------|
| `atlas ci` or `atlas ci status` | Quick pipeline summary (legacy) |
| `atlas ci list [--limit N]` | Formatted table of recent pipelines (default 10) |
| `atlas ci pipeline <N>` | Detailed summary (status, event, author, workflows, errors) |

### Pipelines — actions

| Command | Action |
|---------|--------|
| `atlas ci rerun <N>` | Retrigger pipeline N (returns new pipeline number) |
| `atlas ci watch <N> [--interval S]` | Legacy: one line per state change (default 20s) |
| `atlas ci watch <N> --live [--tail N] [--freeze-threshold S]` | **Live TUI** — timeline + log tail + framework progress + freeze detection (3s poll). See `references/ci-watch-live.md`. |

### Logs

| Command | Action |
|---------|--------|
| `atlas ci logs <N>` | Step table (name, pid, step_id, state, error) |
| `atlas ci logs <N> --step <name\|pid\|step_id>` | Decoded plain-text logs |
| `atlas ci logs <N> --all` | Decoded logs for every step in order |

### Secrets (repo-level)

| Command | Action |
|---------|--------|
| `atlas ci secrets` or `atlas ci secrets list` | List secret names + events |
| `atlas ci secrets set <name> <value> [--events X,Y]` | Add or update secret |
| `atlas ci secrets rm <name>` | Delete secret |

Events: `push`, `pull_request`, `tag`, `deployment`, `cron`. Default: `push`.

### Agents (admin token required)

| Command | Action |
|---------|--------|
| `atlas ci agents` | Agent fleet table (id, name, platform, backend, last_seen) |

### Meta

| Command | Action |
|---------|--------|
| `atlas ci help` | Full usage + examples |
| `atlas ci version` | CI module version (not the server version) |

## Common workflows

**Diagnose a failing pipeline in one shot:**

```bash
atlas ci logs 88 --step backend-lint         # decoded ruff/mypy/bandit output
atlas ci logs 88 --all | grep -iE "error|fail"  # scan all steps
```

**Fix + retrigger:**

```bash
# After pushing a fix commit, retrigger the failed pipeline:
NEW=$(atlas ci rerun 88 | awk '/pipeline #[0-9]+/{print $NF}')
atlas ci watch $NEW                          # blocks until green/red
```

**Rotate a broken deploy SSH key (dogfood example):**

```bash
# 1. Generate a dedicated deploy keypair
ssh-keygen -t ed25519 -f /tmp/deploy_key -N "" -C "woodpecker-deploy-$(date -u +%Y%m%d)"

# 2. Add public key to target host authorized_keys (over any accessible path)
ssh -o ProxyJump=lxc105 sgagnon@<prod> "cat >> ~/.ssh/authorized_keys" < /tmp/deploy_key.pub

# 3. Upload private key to Woodpecker secret (use the new CLI!)
atlas ci secrets set ssh_key "$(cat /tmp/deploy_key)" --events push,deployment

# 4. Retrigger pipeline to validate
atlas ci rerun <failed_pipeline>
atlas ci watch <new_pipeline>
```

**Audit CI state:**

```bash
atlas ci list --limit 20                     # recent history
atlas ci pipeline 101                        # deep-dive one
atlas ci secrets                             # all secrets (metadata)
atlas ci agents                              # fleet capacity
```

No SSH needed for any read path. Uses Woodpecker 3.14 REST API via `$WP_TOKEN`
(Bearer). See `references/woodpecker-api-paths.md` for endpoint catalog + common
pitfalls (`step_id ≠ pid`, SPA-HTML fallback on wrong path, base64-encoded log data).

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
- `semgrep-sast` + `review-pass0` have `failure: ignore` (advisory only)
- Forgejo Actions REMOVED from Synapse 2026-04-11 (Woodpecker is sole CI for synapse repo)
- ATLAS plugin repo ALSO uses Woodpecker (per commit statuses `ci/woodpecker/pr/ci`, `ci/woodpecker/push/ci`)
- Use `ci-feedback-loop` skill for automated push → CI green workflow
- Secret requirements in PR pipelines: secrets referenced in `when: event: pull_request` steps MUST exist at parse-time, otherwise pipeline errors to `error` before any step runs (see: adding `forgejo_ci_bot_token` in 2026-04-14 session)

## Common failure signatures & fixes

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `bun install --frozen-lockfile` error | `bun.lock` drift from `package.json` | `cd frontend && bun install` + commit `bun.lock` |
| `RUF100 Unused noqa (non-enabled: XYZ)` | ruff suppresses rule XYZ which isn't in `pyproject.toml` | Remove the `# noqa: XYZ` directive |
| `D301 Use r""" if any backslashes` | Docstring has `\n`, `\t`, etc. | Prefix with `r"""` |
| `Permission denied (publickey,password)` on deploy | Woodpecker `ssh_key` secret value wrong / pubkey not in authorized_keys | See "Rotate broken deploy SSH key" workflow above |
| `secret "X" not found` error at parse time | Referenced secret doesn't exist | `atlas ci secrets set X <value> --events <matching>` |
| `BACKEND_IMAGE must be set by CI` compose error | compose.prod.yml requires BACKEND_IMAGE but CI deploy script doesn't set it | Manual: set in `.env` on prod; Long-term: add build+digest step to CI |
| API returns `Content-Type: text/html` on `/api/*` | Wrong path — SPA fallback, not SSO block | Check `https://ci.axoiq.com/swagger/doc.json` for canonical path |

## Delegation

- Detailed log analysis: invoke `forgejo-ci` subagent (or just `atlas ci logs`)
- Post-push monitoring: invoke `ci-feedback-loop` skill (or `atlas ci watch`)
- When secret needs rotation: follow the "Rotate broken deploy SSH key" workflow above
