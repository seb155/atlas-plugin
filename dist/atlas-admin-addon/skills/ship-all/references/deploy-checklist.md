# Deploy Checklist — Ship All Reference

## Pre-Deploy Verification

- [ ] All tests pass locally (`bun run test:smoke` or `pytest -x --tb=short`)
- [ ] No uncommitted changes (`git status` clean)
- [ ] dev and main are synced (`git log main..dev` = 0)
- [ ] Staging is healthy before prod deploy
- [ ] PR exists and is mergeable

## Deploy Script Safety Checks

The deploy script MUST have these safeguards. If missing, fix before deploying:

| Check | Script Location | Fix |
|-------|----------------|-----|
| Branch validation | `git rev-parse --abbrev-ref HEAD` before reset | Add `git checkout -B $branch origin/$branch` |
| Force recreate | `docker compose up -d` | Add `--force-recreate --remove-orphans` |
| Staging gate | `deploy-prod.yml` staging check | Ensure it runs on ALL triggers, not just manual |
| Health endpoint | `curl /api/v1/health` | Verify correct URL for each environment |
| Rollback | `git reset --hard $prev_commit` | Ensure rollback also uses `--force-recreate` |

## Environment Health Check URLs

| Environment | Internal URL | Public URL |
|-------------|-------------|------------|
| Local | `http://localhost:8001/api/v1/health` | N/A |
| Staging | `http://<staging-ip>:<port>/api/v1/health` | Check `.atlas/deploy.yaml` |
| Sandbox | `http://<sandbox-ip>:<port>/api/v1/health` | Check `.atlas/deploy.yaml` |
| Production | `http://localhost:8002/api/v1/health` (from VM) | `https://<domain>/api/v1/health` |

## Troubleshooting

### "head branch is behind base branch" on PR merge
Dev is missing commits from main (merge commits). Fix:
```bash
git merge main -m "Merge origin/main into dev"
git push origin dev
# Then retry PR merge
```

### Container name conflict on deploy
Stale containers block new ones. Fix in deploy script:
```bash
docker compose -f <compose> --env-file <env> up -d --build --force-recreate --remove-orphans
```

### Backend not starting (BACKEND_IMAGE missing)
The prod compose expects `BACKEND_IMAGE` env var. Check `.env.prod`:
```bash
grep BACKEND_IMAGE .env.prod    # Should have synapse-backend:local or registry path
```

### VM on wrong branch
Deploy script should auto-detect and fix:
```bash
CURRENT=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT" != "$EXPECTED" ]; then
    git checkout -B $EXPECTED origin/$EXPECTED
fi
```

### SSH to prod fails
Use PVE jump host:
```bash
ssh -J root@<pve-host> root@<prod-vm> "docker ps | grep synapse"
```
