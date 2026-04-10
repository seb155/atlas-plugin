# Observability API Reference — LGTM Stack (VM 602)

> ATLAS reference for querying centralized logs, metrics, and traces.
> All APIs accessible from LAN without auth (except Grafana).
> Stack: Loki 3.4 + Prometheus 2.55 + Tempo 2.7 + Grafana 11.5
> Updated: 2026-04-10

## Endpoints

| Service | URL | Auth | Purpose |
|---------|-----|------|---------|
| **Loki** | `http://192.168.10.56:3100` | None | Log aggregation (LogQL) |
| **Prometheus** | `http://192.168.10.56:9090` | None | Metrics (PromQL) |
| **Tempo** | `http://192.168.10.56:3200` | None | Distributed traces (TraceQL) |
| **Grafana** | `http://192.168.10.56:3001` | API key | Dashboards, alerting |
| **OTel Collector** | `http://192.168.10.56:4317` | None | Ingestion hub (gRPC) |

## Loki — Log Queries

### Available labels
```bash
curl -s "http://192.168.10.56:3100/loki/api/v1/labels" | jq -r '.data[]'
# Key labels: container, deployment_environment, service_name, vm, vm_id
```

### List containers sending logs
```bash
curl -s "http://192.168.10.56:3100/loki/api/v1/label/container/values" | jq -r '.data[]'
# ~30 containers: synapse-prod-backend, synapse-prod-worker, temporal, etc.
```

### Recent errors (last N minutes, default 15)
```bash
MINUTES=${1:-15}
curl -sG "http://192.168.10.56:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={container=~"synapse.*"} |~ "(?i)error|critical|panic"' \
  --data-urlencode "start=$(date -d "${MINUTES} minutes ago" +%s)000000000" \
  --data-urlencode "end=$(date +%s)000000000" \
  --data-urlencode "limit=50" | jq -r '.data.result[].values[][1]'
```

### Errors by specific service
```bash
curl -sG "http://192.168.10.56:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={container="synapse-prod-backend"} |= "error"' \
  --data-urlencode "start=$(date -d '30 minutes ago' +%s)000000000" \
  --data-urlencode "end=$(date +%s)000000000" \
  --data-urlencode "limit=20" | jq -r '.data.result[].values[][1]'
```

### Error count per container (last hour)
```bash
curl -sG "http://192.168.10.56:3100/loki/api/v1/query" \
  --data-urlencode 'query=sum by(container)(count_over_time({container=~"synapse.*"} |~ "(?i)error" [1h]))' \
  | jq -r '.data.result[] | "\(.metric.container): \(.value[1])"'
```

### Trace ID correlation (logs for a specific request)
```bash
curl -sG "http://192.168.10.56:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={container=~"synapse.*"} |= "TRACE_ID_HERE"' \
  --data-urlencode "start=$(date -d '1 hour ago' +%s)000000000" \
  --data-urlencode "end=$(date +%s)000000000" | jq -r '.data.result[].values[][1]'
```

### Loki health
```bash
curl -s "http://192.168.10.56:3100/ready"
# Expected: "ready"
```

## Prometheus — Metric Queries

### All scrape targets up/down
```bash
curl -sG "http://192.168.10.56:9090/api/v1/query" \
  --data-urlencode 'query=up' \
  | jq -r '.data.result[] | "\(.metric.job) \(.metric.instance): \(if .value[1] == "1" then "UP" else "DOWN" end)"'
```

### Container memory (top 10)
```bash
curl -sG "http://192.168.10.56:9090/api/v1/query" \
  --data-urlencode 'query=topk(10, container_memory_usage_bytes{container=~"synapse.*"})' \
  | jq -r '.data.result[] | "\(.metric.container): \(.value[1] | tonumber / 1048576 | round)MB"'
```

### HTTP error rate (5xx in last 5m)
```bash
curl -sG "http://192.168.10.56:9090/api/v1/query" \
  --data-urlencode 'query=sum(rate(http_request_duration_seconds_count{status_code=~"5.."}[5m]))' \
  | jq -r '.data.result[].value[1] // "0"'
```

### Scrape target health detail
```bash
curl -s "http://192.168.10.56:9090/api/v1/targets" \
  | jq -r '.data.activeTargets[] | "\(.labels.job) → \(.health) (last: \(.lastScrape | split("T")[0]))"'
```

### Prometheus health
```bash
curl -s "http://192.168.10.56:9090/-/healthy"
# Expected: "Prometheus Server is Healthy."
```

## Quick Diagnostics

### Combined health check (one command)
```bash
echo "=== LOKI ERRORS (1h) ===" && \
curl -sG "http://192.168.10.56:3100/loki/api/v1/query" \
  --data-urlencode 'query=sum(count_over_time({container=~"synapse-prod.*"} |~ "(?i)error" [1h]))' \
  | jq -r '.data.result[0].value[1] // "0"' && \
echo "=== PROMETHEUS TARGETS ===" && \
curl -sG "http://192.168.10.56:9090/api/v1/query" \
  --data-urlencode 'query=up' \
  | jq -r '.data.result[] | "\(.metric.instance): \(if .value[1] == "1" then "UP" else "DOWN" end)"' && \
echo "=== DOCKER UNHEALTHY ===" && \
docker ps --filter 'health=unhealthy' --format '{{.Names}}' 2>/dev/null || \
ssh root@192.168.10.50 "docker ps --filter 'health=unhealthy' --format '{{.Names}}'"
```

## Response Format

Loki returns `{ status, data: { resultType: "streams", result: [{ stream: {labels}, values: [[ts_ns, line]] }] } }`
Prometheus returns `{ status, data: { resultType: "vector"|"matrix", result: [{ metric: {labels}, value|values }] } }`
Time: Loki uses nanoseconds, Prometheus uses Unix seconds.
