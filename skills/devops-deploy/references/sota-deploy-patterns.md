# SOTA Deploy Patterns — Anti-Patterns & Their Fixes

> Authoritative reference for CI/CD deploy pipelines. Invoke when:
> - Writing or reviewing `.woodpecker/deploy-*.yml`, `.github/workflows/deploy-*.yml`, or equivalent
> - Auditing an existing deploy script that "reports success but prod seems stale"
> - User says "the deploy worked but nothing changed" / "CI green but prod is old"
>
> Empirical source: Synapse SP-DEPLOY-SOTA (2026-04-14 EVE incident — Pillow/docling hotfix deploy silently failed 3× before root cause found).

---

## The Five Compounding Defects That Silently Break Deploys

Most broken deploy pipelines are green-on-CI but don't actually ship. They exhibit some combination of:

| # | Defect | Symptom | Fix |
|---|--------|---------|-----|
| **D1** | `\| tail -N` on deploy commands | CI step green, no error surfaced, but target host unchanged | Never pipe the deploy command. Use explicit log capture. `set -Eeuo pipefail` on every shell step. |
| **D2** | `--build` on target host | Rebuild uses stale dependency resolution; may fail on transitive pins; uses local tags | Build + push in CI only. Target host only `docker compose pull` + `up -d --no-build`. |
| **D3** | Local image tags (no registry) | `synapse-backend:prod-<sha>` exists only on the host that built it; no rollback history; no digest | Push to container registry (`forgejo.axoiq.com`, `ghcr.io`, `registry.k8s.io`). Reference images by digest in `.env`. |
| **D4** | SSH user ≠ docker group | `docker compose` fails with `permission denied while trying to connect to the docker daemon socket` | Either add user to `docker` group OR wrap in `sudo -n` and verify passwordless sudo configured. **Align `.atlas/deploy.yaml` `ssh_user` with actual CI secret.** |
| **D5** | `curl localhost:PORT` as health gate | Tests internal port, misses Caddy/HAProxy routing failures | Gate on **external** probe (`https://yourdomain.com/api/v1/health`) or pull from Gatus/Uptime-Kuma status feed. |

A deploy script suffering **any combination of D1+D2+D3** will report green while the running image is whatever it was before. This is the most common "zombie deploy" failure mode.

---

## The SOTA Pattern — Build-Push-Pull-Pin

```
┌─ CI Runner (LAN) ────────────────────────────────────────────────┐
│                                                                  │
│  ON push to main (or merged PR):                                 │
│    1. docker buildx build -t registry/org/service:prod-<sha> .   │
│    2. docker push registry/org/service:prod-<sha>                │
│    3. DIGEST=$(docker buildx imagetools inspect … --format '{{.Manifest.Digest}}') │
│    4. ssh root@prod-host "bash -Eeuo pipefail <<EOF              │
│         cd /opt/service                                          │
│         git fetch --prune && git reset --hard origin/main        │
│         sed -i 's|^IMAGE_DIGEST=.*|IMAGE_DIGEST=${DIGEST}|' .env │
│         docker compose -f compose.yml -f compose.prod.yml pull   │
│         docker compose -f compose.yml -f compose.prod.yml up -d --no-build │
│       EOF"                                                       │
│    5. Poll external health until 3 consecutive 200s in 30 s      │
│    6. On fail → sed to previous DIGEST + up -d + alert           │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### Compose file contract

```yaml
# compose.prod.yml (override)
services:
  backend:
    image: ${IMAGE_REPO:?required}:${IMAGE_TAG:-latest-main}@${IMAGE_DIGEST:?required}
```

- `IMAGE_REPO` = `forgejo.axoiq.com/axoiq/synapse-backend` (resolvable over LAN)
- `IMAGE_TAG` = `prod-<sha>` (human-readable for rollback picking)
- `IMAGE_DIGEST` = `sha256:…` (CI writes this line into `.env`; compose pulls exact bytes)

### `.env` on prod

```
IMAGE_REPO=forgejo.axoiq.com/axoiq/synapse-backend
IMAGE_TAG=prod-f73e1182
IMAGE_DIGEST=sha256:3f8a…    ← CI updates this line on every deploy
```

---

## Required Shell Patterns for Deploy Scripts

### Always `set -Eeuo pipefail`

```bash
# top of every deploy step:
set -Eeuo pipefail

# why each flag:
#   -E  ERR trap inherited by functions (so traps work inside helpers)
#   -e  exit on any non-zero (catches silent failures)
#   -u  error on undefined variables (catches typos)
#   -o pipefail  pipeline exit = rightmost non-zero (catches `cmd | tail` masks)
```

### Never `| tail` on deploy output

```bash
# WRONG — tail masks failure
ssh host "docker compose up -d --build 2>&1 | tail -10"

# RIGHT — capture full log, fail loud
ssh host "set -Eeuo pipefail; docker compose up -d --build"
# (output is streamed; CI captures it. If build fails, step exits non-zero.)
```

### Never rebuild on target

```bash
# WRONG — target rebuilds → local-tag hell, no audit trail
ssh prod "docker compose up -d --build"

# RIGHT — CI pushes; prod pulls
docker buildx build --push -t $REGISTRY/$IMAGE:$TAG .
ssh prod "docker compose pull && docker compose up -d --no-build"
```

### Health gate must be external

```bash
# WRONG — tests localhost, misses proxy config bugs
ssh prod "curl -sf http://localhost:8002/health"

# RIGHT — external probe through real user path
for i in 1 2 3; do
  curl -sf --max-time 10 "https://$PUBLIC_URL/api/v1/health" && exit 0
  sleep 10
done
echo "external health failed"; exit 1
```

---

## Anti-Patterns to Reject in Code Review

| Red flag | Example | Why it's wrong | Correction |
|----------|---------|----------------|-----------|
| `2>&1 \| tail -N` | `"… cmd 2>&1 \| tail -10"` | Tail always exits 0 → step green on failure (D1) | Drop the pipe; stream output |
| `docker compose up --build` on prod | deploy step SSHs and builds | Slow, stale deps, no audit (D2) | Build in CI, pull on prod |
| Image as `service:latest` | `image: synapse-backend:latest` | No digest pinning; race with registry mutation | `image: $REPO:$TAG@$DIGEST` |
| Bare `echo "✅ Deployed"` after shell pipe | `… \|\| echo fail; echo ok` | Unconditional success message; lies on failure | Only echo success after `&&` chain |
| Health check on `localhost` | `curl localhost:8002` | Misses reverse-proxy bugs (D5) | `curl https://public.domain/...` |
| SSH user isn't in docker group | `sgagnon@host "docker ps"` fails silent | `permission denied` swallowed (D4) | Use root OR `sudo -n` OR add user to group |
| No `set -Eeuo pipefail` | plain shell block | Silent failures everywhere | Always set strict flags |
| Secret in log | `echo "using token: $TOKEN"` | Leaks to CI logs | Use `--secret` flag or `::add-mask::` |
| `ssh -o StrictHostKeyChecking=no` without known_hosts | MITM risk | Accepts any host key | Pre-seed `~/.ssh/known_hosts` with pinned keys |

---

## The Five-Question Deploy Audit

Before merging any PR that touches `.woodpecker/`, `.github/workflows/`, `.gitlab-ci.yml`, or equivalent, answer:

1. **If the build on the target host failed, would this CI step fail RED?** (If you can only say "maybe", fix the script.)
2. **Where does the image live after the deploy — local-tag or registry with digest?**
3. **If I revert `.env`'s IMAGE_DIGEST to the previous value and run `up -d`, does prod roll back in under 30 s?**
4. **Is the health check probing the real public URL or just localhost?**
5. **Does the declared SSH user actually have docker permissions on the target?** (ssh + `docker ps` must succeed without `sudo` OR `sudo -n` must be passwordless.)

A "no" or "not sure" on any of these means the deploy can silently rot.

---

## Verification Checklist (for new/changed deploy pipelines)

```bash
# Simulate build failure — CI must go RED, not green-with-masked-success
echo "RAISE" >> Dockerfile   # invalid directive
git push
# → expect CI step to fail-loud at build stage, no "deployed" message downstream

# Simulate deploy-host-fail — CI must capture error
ssh target "sudo systemctl stop docker"   # break docker
git push
# → expect CI step fail at "docker compose pull" with clear permission/connect error

# Simulate rollback
ssh prod "sed -i 's|IMAGE_DIGEST=.*|IMAGE_DIGEST=$PREV_DIGEST|' /opt/service/.env \\
          && docker compose up -d --no-build"
curl -sf https://public.domain/api/v1/health
# → expect prod health green with git_sha matching $PREV_DIGEST

# Verify registry push actually happened
docker manifest inspect $REPO:$TAG
# → expect JSON manifest with config digest

# Verify no NetBird / mesh IPs leaked into deploy code
git grep -E '10\.(64|88|100)\.' .woodpecker/ .atlas/ scripts/
# → expect empty (all infra traffic should use LAN 192.168.x.x + DNS *.axoiq.com for AXOIQ setups)
```

---

## Mapping to `.atlas/deploy.yaml`

When this pattern is integrated with the `devops-deploy` skill, expected shape:

```yaml
# .atlas/deploy.yaml
registry:
  url: forgejo.axoiq.com                  # private container registry
  image_repo: axoiq/synapse-backend       # path under registry
  ci_user: axoiq-ci                        # service account
  ci_token_secret: forgejo_registry_token  # Woodpecker secret name

environments:
  prod:
    host: prod-docker.axoiq.com           # LAN DNS, not NetBird IP
    ip_fallback: 192.168.10.50             # in case DNS drifts
    ssh_user: root
    ssh_key_secret: prod_ssh_key
    compose_files: [compose.yml, docker-compose.prod.yml]
    env_file: /opt/synapse/.env            # digest injection target
    health_gate:
      type: gatus                           # or: external_curl, uptime_kuma
      endpoint_id: synapse
      required_consecutive_green: 3
      timeout_s: 60
    rollback:
      keep_previous_digests: 3              # registry-gc policy
    url: https://synapse.axoiq.com          # public URL for external health check
```

The `devops-deploy` skill should consume this shape directly and produce the CI workflow + deploy script without per-project boilerplate.

---

## Rollout for an Existing Misconfigured Project

Order matters. Apply in this sequence to avoid a deploy gap:

1. **Stand up registry** + create CI service user with `write:packages` scope (zero impact on running prod).
2. **Add DNS** for LAN hostname (zero impact).
3. **Update `.woodpecker/deploy-*.yml`** to new build-push-pull flow — **keep old deploy step disabled, don't delete yet**.
4. **First run**: manually invoke new pipeline. Confirm registry has the digest, prod pulls it, health gate passes.
5. **Verify rollback**: revert digest line manually, `up -d`, confirm older version comes back.
6. **Delete old deploy step**, land commit on main, mark ship complete.
7. **Document**: add to `.blueprint/DEPLOY.md` (project-local) and reference this file for patterns.

Never delete the old deploy before the new one has been exercised end-to-end at least once. A regression in deploy pipelines is indistinguishable from an outage.
