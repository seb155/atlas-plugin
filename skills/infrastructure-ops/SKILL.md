---
name: infrastructure-ops
description: "Admin-tier infrastructure management: VM/container orchestration (Proxmox, Docker, LXC), networking (Tailscale, DNS, Cloudflare), monitoring (Grafana, Prometheus, Uptime Kuma), backup/DR, database administration (PostgreSQL, Valkey), and hardware capacity planning. HITL gates on all destructive operations."
---

# Infrastructure Ops

Manage homelab and production infrastructure safely. Every destructive operation
requires HITL approval and pre-action backup verification.

## Overview

```
AUDIT → PLAN → EXECUTE → VERIFY
  ↑                         |
  └── ROLLBACK (if unhealthy) ┘
```

**Hard gate:** Any operation that modifies, restarts, or deletes production resources
ALWAYS requires HITL approval via AskUserQuestion.

**Safety axiom:** Never delete without backup. Never change without health-check proof.

---

## Scope

| Domain | Tools | Scope |
|--------|-------|-------|
| Virtualization | Proxmox VE, LXC, QEMU | VM/container create, resize, snapshot, migrate |
| Containers | Docker, Docker Compose | Stack up/down, image prune, volume manage |
| Networking | Tailscale, Cloudflare, CoreDNS | ACL, DNS records, tunnel, firewall rules |
| Monitoring | Grafana, Prometheus, Uptime Kuma | Dashboards, alert rules, probe config |
| Databases | PostgreSQL 17, Valkey 8 | Backup, vacuum, reindex, user/role, slow query |
| Backup & DR | pg_dump, rsync, Proxmox snapshots | Schedule, verify, restore test |
| Capacity | CPU/RAM/disk metrics | Trend analysis, provisioning recommendations |

---

## Workflow

### Step 1: AUDIT

Before any action, establish ground truth:

```bash
# Proxmox node status
pvesh get /nodes --output-format json

# Container/VM inventory
pct list && qm list

# Docker stacks (per host)
docker compose ls && docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Disk usage
df -h && du -sh /var/lib/docker /opt/*

# Network reachability
tailscale status && ping -c2 <target>

# DB health
psql -U postgres -c "SELECT version(); SELECT pg_size_pretty(pg_database_size('synapse'));"

# Valkey health
redis-cli -p 6379 ping && redis-cli -p 6379 info server | grep -E "uptime|used_memory_human|connected_clients"
```

Present AUDIT summary table: resource | status | version | last-changed | health.

### Step 2: PLAN

Produce a concrete change plan before touching anything:

1. State the goal in one sentence
2. List each action step with expected outcome
3. Identify dependencies and order constraints
4. Flag irreversible steps (marked `⚠️ DESTRUCTIVE`)
5. Define rollback procedure for each destructive step
6. Define success criteria (health checks, metrics)

**HITL Gate:** Present plan via AskUserQuestion before executing any step.

```
AskUserQuestion:
  "Infrastructure change plan ready. Approve to execute?"
  - "Approve — execute plan" → proceed Step 3
  - "Dry run — show commands only" → print commands, stop
  - "Modify plan" → revise and re-present
  - "Abort" → cancel
```

### Step 3: EXECUTE

Execute each step sequentially. After each `⚠️ DESTRUCTIVE` step:

1. Verify the action completed (exit code, log line, or API response)
2. Run the defined health check for that resource
3. Report status before proceeding to the next step

**Retry cap:** Max 2 automatic retries per step. On third failure → AskUserQuestion
with (a) what failed (b) error output (c) 2-3 recovery options.

### Step 4: VERIFY

After all steps complete, run full health sweep:

```bash
# Service endpoints
for url in $(cat .atlas/deploy.yaml | grep health_url | awk '{print $2}'); do
  curl -sf --max-time 10 "$url" && echo "✅ $url" || echo "❌ $url"
done

# Container restarts (flag > 0)
docker ps --format "{{.Names}}\t{{.Status}}" | grep -v "Up"

# Prometheus targets (if available)
curl -sf http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health != "up")'

# Uptime Kuma (API)
curl -sf http://localhost:3001/api/status-page/heartbeat/main
```

Present VERIFY report. If any check fails → enter ROLLBACK path.

---

## Subcommands

| Command | Description | HITL |
|---------|-------------|------|
| `/atlas infra status` | Full health sweep of all infrastructure | No |
| `/atlas infra audit` | Detailed resource inventory + capacity report | No |
| `/atlas infra restart <service>` | Restart container/service with health check | Prod: yes |
| `/atlas infra snapshot <vm>` | Proxmox VM/CT snapshot before risky ops | No |
| `/atlas infra db backup [env]` | pg_dump + verify restore integrity | No |
| `/atlas infra db vacuum` | VACUUM ANALYZE + REINDEX on bloated tables | Staging: no, Prod: yes |
| `/atlas infra prune` | Docker image/volume/network prune (dry run first) | Yes |
| `/atlas infra capacity` | CPU/RAM/disk trend → provisioning recommendation | No |
| `/atlas infra network audit` | Tailscale ACL + Cloudflare DNS + firewall check | No |
| `/atlas infra backup verify` | Restore-test latest backup to scratch | No |

---

## Domain Procedures

### Docker — Container Management

```bash
# Restart single service (safe)
docker compose -f <file> restart <service>

# Full stack rebuild (use --no-deps to isolate)
docker compose -f <file> up -d --build <service>

# Image prune (ALWAYS dry-run first)
docker image prune -f --filter "until=720h" --dry-run
docker image prune -f --filter "until=720h"

# Volume inspection before removal
docker volume inspect <name>
docker volume rm <name>   # ⚠️ DESTRUCTIVE — requires HITL
```

### Proxmox — VM/LXC Operations

```bash
# Snapshot before any risky op
pvesh create /nodes/<node>/qemu/<vmid>/snapshot -snapname pre-change-$(date +%Y%m%d)
pvesh create /nodes/<node>/lxc/<vmid>/snapshot  -snapname pre-change-$(date +%Y%m%d)

# VM status
pvesh get /nodes/<node>/qemu/<vmid>/status/current

# LXC start/stop
pct start <vmid> && pct status <vmid>
pct stop  <vmid>   # ⚠️ DESTRUCTIVE — requires HITL if prod VM

# Resource resize (online, ZFS)
pvesh set /nodes/<node>/qemu/<vmid>/config --memory 8192 --cores 4
```

### PostgreSQL — Database Administration

```bash
# Health + size
psql -U postgres -c "\l+"
psql -U postgres -c "SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size FROM pg_tables ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC LIMIT 20;"

# Backup (ALWAYS via docker exec — never rely on host pg_dump version)
docker exec <db-container> pg_dump -U postgres <dbname> | gzip > backup_$(date +%Y%m%d_%H%M%S).sql.gz

# Restore test (scratch container)
docker run --rm postgres:17 psql -U postgres -c "SELECT 1" < backup.sql

# Slow queries
psql -U postgres -c "SELECT query, calls, mean_exec_time::int, total_exec_time::int FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 20;"

# VACUUM ANALYZE (non-blocking)
psql -U postgres -c "VACUUM ANALYZE VERBOSE <table>;"

# REINDEX (⚠️ locks table — off-peak only, HITL for prod)
psql -U postgres -c "REINDEX TABLE CONCURRENTLY <table>;"
```

### Valkey — Cache Administration

```bash
# Health
redis-cli -p 6379 info all | grep -E "uptime_in_seconds|used_memory_human|connected_clients|rejected_connections|keyspace_hits|keyspace_misses"

# Key space
redis-cli -p 6379 info keyspace
redis-cli -p 6379 dbsize

# Flush (⚠️ DESTRUCTIVE — requires HITL, causes cold cache)
redis-cli -p 6379 flushdb async   # flushdb, not flushall

# Config check
redis-cli -p 6379 config get maxmemory
redis-cli -p 6379 config get maxmemory-policy
```

### Networking — Tailscale + Cloudflare

```bash
# Tailscale status
tailscale status
tailscale ping <peer>

# Cloudflare DNS (via API — never via web UI for auditability)
source ~/.env
curl -s "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_API_TOKEN" | jq '.result[] | {name, type, content}'

# Firewall (UFW)
ufw status numbered
ufw allow from <tailscale-cidr> to any port 5432  # Example — never expose DB to internet
```

### Monitoring — Grafana + Prometheus + Uptime Kuma

```bash
# Prometheus targets health
curl -sf http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health, lastError}'

# Uptime Kuma — check all monitors
curl -sf http://localhost:3001/api/status-page/heartbeat/main | jq '.'

# Grafana API — alert states
curl -sf http://admin:admin@localhost:3001/api/alerts?state=alerting
```

---

## Safety Rules (NON-NEGOTIABLE)

1. **Backup before destructive ops** — pg_dump before any DB schema change or data migration
2. **Snapshot before VM changes** — Proxmox snapshot before resize, OS update, or config change
3. **Health check after every change** — never report success without endpoint proof
4. **Dry run before prune** — always `--dry-run` before `docker image prune` or `docker volume rm`
5. **HITL for prod** — any prod restart, prune, or schema change requires explicit user approval
6. **Max 2 retries** — if a step fails twice, stop and present alternatives via AskUserQuestion
7. **Off-peak for REINDEX** — table-locking operations only during maintenance windows
8. **Never expose secrets** — never print env vars, tokens, or passwords in output
9. **Audit trail** — log every infrastructure action with timestamp and actor in session notes

---

## HITL Gates Summary

| Operation | Dev/Staging | Production |
|-----------|:-----------:|:----------:|
| Service restart | Auto | ⚠️ HITL |
| DB backup | Auto | Auto |
| DB VACUUM | Auto | ⚠️ HITL |
| DB REINDEX | Auto | ⚠️ HITL |
| Docker prune | ⚠️ HITL | ⚠️ HITL |
| Volume delete | ⚠️ HITL | ⚠️ HITL |
| VM stop | Auto | ⚠️ HITL |
| VM snapshot | Auto | Auto |
| Firewall rule change | ⚠️ HITL | ⚠️ HITL |
| DNS record change | ⚠️ HITL | ⚠️ HITL |
| Valkey flush | ⚠️ HITL | ⚠️ HITL |

---

## Capacity Planning

When running `capacity` subcommand:

1. Collect 7-day resource trends (CPU, RAM, disk I/O) from Prometheus or `sar`
2. Project growth at current rate (linear extrapolation, 30/60/90 days)
3. Flag resources crossing 80% threshold within 30 days
4. Recommend specific actions (add disk, add RAM, migrate workload, prune images)
5. Present as a table with severity: CRITICAL / WARNING / OK

---

## Error Recovery

| Scenario | Action |
|----------|--------|
| Container won't start | Check logs → `docker logs --tail 100 <name>` → AskUserQuestion |
| DB connection refused | Check pg_hba.conf, max_connections, port → AskUserQuestion |
| Tailscale peer unreachable | `tailscale ping`, check ACL, re-auth node |
| Health check fails after deploy | Rollback compose → restore from backup → AskUserQuestion |
| Disk full | `df -h`, identify top dirs (`du -sh /opt/* /var/*`), prune Docker first |
| SSH connection refused | Check jump host, Tailscale ACL, sshd status on target |

---

## Integration with Other Skills

| Workflow | Chain |
|----------|-------|
| Before prod deploy | `infrastructure-ops audit` → `devops-deploy` |
| After deploy failure | `devops-deploy` rollback → `infrastructure-ops db backup verify` |
| Incident response | `infrastructure-ops status` → triage → `infrastructure-ops restart` |
| Capacity review | `infrastructure-ops capacity` → provision → `infrastructure-ops snapshot` |
