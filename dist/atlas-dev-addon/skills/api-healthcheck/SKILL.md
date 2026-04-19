---
name: api-healthcheck
description: "API endpoint health checker. This skill should be used when the user asks to 'healthcheck the API', 'check endpoints', 'ping all routes', 'api status', or needs a parallel curl sweep of .atlas/healthcheck.yaml."
triggers:
  - "/atlas healthcheck"
  - "/atlas health api"
  - "test all endpoints"
  - "api health"
  - "check all routes"
effort: low
---

# API Health Check — Batch Endpoint Testing

Test all API endpoints in parallel. Report status codes, response times, and errors.
Config-driven from `.atlas/healthcheck.yaml` or auto-discovered from the project.

## Commands

```bash
/atlas healthcheck                     # Test default profile
/atlas healthcheck devhub              # Test specific profile
/atlas healthcheck --url https://dev.axoiq.com/api/v1/devhub
/atlas healthcheck --local             # Test localhost
```

## Configuration

`.atlas/healthcheck.yaml`:

```yaml
profiles:
  devhub:
    base_url: https://dev.axoiq.com/api/v1/devhub
    local_url: http://localhost:8001/api/v1/devhub
    timeout: 10
    endpoints:
      - { path: /health, method: GET, expected: 200, check: "db_connected" }
      - { path: /features, method: GET, expected: 200 }
      - { path: /features/board, method: GET, expected: 200 }
      - { path: /features/matrix, method: GET, expected: 200 }
      - { path: /plans, method: GET, expected: 200 }
      - { path: /docs, method: GET, expected: 200 }
      - { path: /docs/search?q=synapse, method: GET, expected: 200 }
      - { path: /team, method: GET, expected: 200 }
      - { path: /team/matrix, method: GET, expected: 200 }
      - { path: /sprints, method: GET, expected: 200 }
      - { path: /sprints/active, method: GET, expected: 200 }
      - { path: /sessions, method: GET, expected: 200 }
      - { path: /hitl, method: GET, expected: 200 }
      - { path: /ci/status, method: GET, expected: 200 }
      - { path: /proxy/stack, method: GET, expected: 200 }
      - { path: /proxy/enterprise, method: GET, expected: 200 }
      - { path: /proxy/infra, method: GET, expected: 200 }

  synapse:
    base_url: https://synapse.axoiq.com/api/v1
    local_url: http://localhost:8001/api/v1
    timeout: 10
    endpoints:
      - { path: /health, method: GET, expected: 200 }
      - { path: /instruments, method: GET, expected: 200 }
      - { path: /packages, method: GET, expected: 200 }
```

## Process

### Step 1: Load Configuration

```bash
# Read profile from .atlas/healthcheck.yaml
PROFILE="${1:-devhub}"
CONFIG=".atlas/healthcheck.yaml"

if [ ! -f "$CONFIG" ]; then
  echo "No .atlas/healthcheck.yaml found. Create one or use --url flag."
  exit 1
fi

BASE_URL=$(yq ".profiles.${PROFILE}.base_url" "$CONFIG")
ENDPOINTS=$(yq ".profiles.${PROFILE}.endpoints[].path" "$CONFIG")
```

### Step 2: Run Batch Tests

Run ALL endpoints via a Bash loop. Display results as a table:

```bash
echo "Testing ${PROFILE} at ${BASE_URL}..."
echo ""
printf "%-35s %6s %8s %s\n" "Endpoint" "Status" "Time" "Result"
printf "%-35s %6s %8s %s\n" "---" "---" "---" "---"

PASS=0
FAIL=0

for EP in $ENDPOINTS; do
  START=$(date +%s%N)
  STATUS=$(curl -s -o /tmp/healthcheck_body -w "%{http_code}" \
    --connect-timeout 5 --max-time 10 \
    "${BASE_URL}${EP}" 2>/dev/null)
  END=$(date +%s%N)
  TIME_MS=$(( (END - START) / 1000000 ))

  if [ "$STATUS" = "200" ]; then
    RESULT="✅"
    PASS=$((PASS + 1))
  else
    RESULT="❌"
    FAIL=$((FAIL + 1))
  fi

  printf "%-35s %6s %6dms %s\n" "$EP" "$STATUS" "$TIME_MS" "$RESULT"
done

echo ""
echo "Results: ${PASS} pass, ${FAIL} fail ($(( PASS * 100 / (PASS + FAIL) ))%)"
```

### Step 3: Report

Output format:

```
Testing devhub at https://dev.axoiq.com/api/v1/devhub...

Endpoint                            Status     Time Result
---                                 ---        ---  ---
/health                             200        42ms ✅
/features                           200       128ms ✅
/features/board                     200       156ms ✅
/ci/status                          200       890ms ✅
/proxy/infra                        200      1200ms ✅
/proxy/activity                     500       340ms ❌

Results: 16 pass, 1 fail (94%)
```

### Step 4: Detailed Failure Report

For any failing endpoint, show response body:

```bash
if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "=== Failures ==="
  # Re-test failed endpoints with body output
  for EP in $FAILED_EPS; do
    echo "--- $EP ---"
    curl -s "${BASE_URL}${EP}" | head -5
  done
fi
```

## Auto-Discovery Mode

If no config exists, auto-discover from FastAPI:

```bash
# Try to get OpenAPI schema
curl -s "${BASE_URL}/../openapi.json" | python3 -c "
import sys,json
schema = json.load(sys.stdin)
for path, methods in schema.get('paths', {}).items():
    for method in methods:
        if method.upper() == 'GET':
            print(f'  - {{ path: {path}, method: GET, expected: 200 }}')
"
```

## Related

- `deploy-hotfix` — Run healthcheck after hotfix deploy
- `devops-deploy` — Run healthcheck as post-deploy step
- `verification` — Broader verification (includes tests, not just API)
