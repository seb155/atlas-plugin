---
name: deploy-hotfix
description: "Deploy file hotfix to running container without CI rebuild. SCP → docker cp → clear pycache → restart → health check. Supports SSH jump hosts."
triggers:
  - "/atlas hotfix"
  - "hotfix to prod"
  - "deploy file to container"
  - "docker cp"
  - "hotfix deploy"
effort: low
---

# Deploy Hotfix to Running Container

Deploy a local file to a running Docker container on a remote host without rebuilding the image.
Supports SSH jump hosts, pycache cleanup, and health verification.

## Commands

```bash
/atlas hotfix backend/app/services/forgejo_client.py
/atlas hotfix backend/app/api/endpoints/atlas_dev.py --container synapse-prod-backend
/atlas hotfix frontend-devhub/ --container synapse-prod-devhub --rebuild
```

## Configuration

Read from `.atlas/deploy.yaml` in the project root:

```yaml
environments:
  prod:
    ssh_host: root@192.168.10.50
    ssh_jump: root@192.168.10.20   # Optional jump host
    containers:
      backend:
        name: synapse-prod-backend
        app_root: /app
        health_url: http://localhost:8002/api/v1/health
        health_timeout: 30
      frontend:
        name: synapse-prod-devhub
        app_root: /usr/share/nginx/html
        health_url: http://localhost:4010/
        health_timeout: 10
        rebuild: true  # Frontend needs docker build, not cp
```

## Process

### Step 1: Detect Target Container

```bash
# Infer container from file path
FILE_PATH="$1"
if [[ "$FILE_PATH" == backend/* ]]; then
  CONTAINER="synapse-prod-backend"
  APP_ROOT="/app"
elif [[ "$FILE_PATH" == frontend-devhub/* ]]; then
  CONTAINER="synapse-prod-devhub"
  REBUILD=true
fi
# Override with --container flag if provided
```

### Step 2: Build SSH Command

```bash
# Read deploy config
SSH_HOST=$(yq '.environments.prod.ssh_host' .atlas/deploy.yaml 2>/dev/null || echo "root@192.168.10.50")
SSH_JUMP=$(yq '.environments.prod.ssh_jump' .atlas/deploy.yaml 2>/dev/null || echo "")

SSH_CMD="ssh"
SCP_CMD="scp"
if [ -n "$SSH_JUMP" ]; then
  SSH_CMD="ssh -J $SSH_JUMP"
  SCP_CMD="scp -o ProxyJump=$SSH_JUMP"
fi
```

### Step 3: Transfer File

```bash
# For single file hotfix (backend)
$SCP_CMD "$FILE_PATH" "${SSH_HOST}:/tmp/$(basename $FILE_PATH)"
$SSH_CMD "$SSH_HOST" "docker cp /tmp/$(basename $FILE_PATH) ${CONTAINER}:${APP_ROOT}/${FILE_PATH}"

# For directory rebuild (frontend)
if [ "$REBUILD" = true ]; then
  $SSH_CMD "$SSH_HOST" "cd /opt/synapse && git fetch origin dev && git checkout origin/dev -- ${FILE_PATH}"
  $SSH_CMD "$SSH_HOST" "docker build --network=host -t ${CONTAINER}:latest ./${FILE_PATH}/"
  $SSH_CMD "$SSH_HOST" "docker rm -f ${CONTAINER} && docker run -d --name ${CONTAINER} ... ${CONTAINER}:latest"
fi
```

### Step 4: Clear Cache + Restart

```bash
# Python: clear __pycache__ for the modified module
MODULE_DIR=$(dirname "$FILE_PATH")
$SSH_CMD "$SSH_HOST" "docker exec $CONTAINER find ${APP_ROOT}/${MODULE_DIR} -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null"

# Restart
$SSH_CMD "$SSH_HOST" "docker restart $CONTAINER"
```

### Step 5: Health Check

```bash
HEALTH_URL=$(yq ".environments.prod.containers.backend.health_url" .atlas/deploy.yaml 2>/dev/null)
TIMEOUT=30

echo "Waiting for health..."
for i in $(seq 1 $TIMEOUT); do
  STATUS=$($SSH_CMD "$SSH_HOST" "curl -s -o /dev/null -w '%{http_code}' $HEALTH_URL" 2>/dev/null)
  if [ "$STATUS" = "200" ]; then
    echo "✅ Healthy after ${i}s"
    break
  fi
  sleep 1
done

if [ "$STATUS" != "200" ]; then
  echo "❌ Health check failed after ${TIMEOUT}s (HTTP $STATUS)"
  # HITL gate: ask user if they want to rollback
fi
```

### Step 6: Quick Sanity Test

```bash
# If api-healthcheck skill exists, run it
# Otherwise, test the specific endpoint related to the changed file
$SSH_CMD "$SSH_HOST" "curl -s $HEALTH_URL | python3 -c 'import sys,json; d=json.load(sys.stdin); print(json.dumps(d, indent=2)[:200])'"
```

## HITL Gates

- **Before restart**: "About to restart {container} on {host}. Proceed?"
- **Health check failure**: "Container unhealthy after {timeout}s. Rollback or investigate?"
- **Frontend rebuild**: "About to rebuild + replace container. This will cause ~10s downtime."

## Error Handling

| Error | Action |
|-------|--------|
| SSH timeout | Check VPN/network, suggest `ping {host}` |
| Docker cp fails | Container may be stopped, check `docker ps` |
| Health timeout | Show container logs: `docker logs --tail 20 {container}` |
| File not found locally | Error with correct relative path suggestion |

## Related

- `devops-deploy` — Full deployment (CI + compose up)
- `api-healthcheck` — Post-deploy verification
- `infrastructure-ops` — SSH + Docker management
