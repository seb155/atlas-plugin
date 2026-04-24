---
name: infrastructure-ops
description: "Admin-tier infrastructure operations. This skill should be used when the user asks to 'manage VMs', 'LXC', 'proxmox ops', 'docker ops', 'backup DR', 'database admin', '/atlas infra ops', or needs Tailscale/DNS/Cloudflare/monitoring changes with HITL gates."
effort: high
---

# Infrastructure Ops

Manage homelab and production infrastructure safely.
Every destructive operation requires HITL approval and pre-action backup verification.

## Pipeline

```
AUDIT → PLAN → EXECUTE → VERIFY → (ROLLBACK if unhealthy)
```

## Scope

| Domain | Tools | Operations |
|--------|-------|-----------|
| Virtualization | Proxmox, LXC, QEMU | Create, resize, snapshot, migrate |
| Containers | Docker, Compose | Stack up/down, build, prune, volumes |
| Networking | Tailscale, Cloudflare, CoreDNS | ACL, DNS, tunnels, firewall |
| Monitoring | Grafana, Prometheus, Uptime Kuma | Dashboards, alerts, probes |
| Databases | PostgreSQL 17, Valkey 8 | Backup, vacuum, reindex, roles, slow queries |
| Backup & DR | pg_dump, rsync, Proxmox snapshots | Schedule, verify, restore test |
| Capacity | CPU/RAM/disk metrics | Trends, provisioning recommendations |

## Workflow

### Step 1: AUDIT — Establish ground truth
Run: `pvesh get /nodes`, `pct list && qm list`, `docker compose ls && docker ps`, `df -h`, `tailscale status`, DB health queries. Present summary table.

### Step 2: PLAN — Concrete change plan before touching anything
1. Goal (1 sentence), 2. Action steps + expected outcomes, 3. Dependencies/order, 4. Flag `⚠️ DESTRUCTIVE` steps, 5. Rollback per destructive step, 6. Success criteria.

**HITL Gate**: AskUserQuestion → Approve | Dry run | Modify | Abort

### Step 3: EXECUTE — Sequential, verify after each destructive step
Check exit code/logs, run health check, report status. **Retry cap: 2** → AskUserQuestion with error + 2-3 options.

### Step 4: VERIFY — Full health sweep
Check service endpoints, container restart counts, Prometheus targets, Uptime Kuma. If any fail → ROLLBACK.

## Subcommands

| Command | Description | HITL |
|---------|-------------|------|
| `infra status` | Full health sweep | No |
| `infra audit` | Resource inventory + capacity | No |
| `infra restart <svc>` | Restart with health check | Prod: yes |
| `infra snapshot <vm>` | Proxmox snapshot | No |
| `infra db backup [env]` | pg_dump + verify integrity | No |
| `infra db vacuum` | VACUUM ANALYZE + REINDEX | Prod: yes |
| `infra prune` | Docker prune (dry run first) | Yes |
| `infra capacity` | CPU/RAM/disk trends → recommendations | No |
| `infra network audit` | Tailscale ACL + CF DNS + firewall | No |
| `infra backup verify` | Restore-test latest backup | No |

## HITL Gates

| Operation | Dev/Staging | Production |
|-----------|:-----------:|:----------:|
| Service restart | Auto | ⚠️ HITL |
| DB backup | Auto | Auto |
| DB VACUUM / REINDEX | Auto | ⚠️ HITL |
| Docker prune | ⚠️ HITL | ⚠️ HITL |
| Volume delete | ⚠️ HITL | ⚠️ HITL |
| VM stop | Auto | ⚠️ HITL |
| VM snapshot | Auto | Auto |
| Firewall / DNS change | ⚠️ HITL | ⚠️ HITL |
| Valkey flush | ⚠️ HITL | ⚠️ HITL |

## Key Command Patterns

| Domain | Pattern |
|--------|---------|
| Docker restart | `docker compose -f <file> restart <service>` |
| Docker rebuild | `docker compose -f <file> up -d --build <service>` |
| Docker prune | `docker image prune -f --filter "until=720h" --dry-run` (dry-run FIRST) |
| Proxmox snapshot | `pvesh create /nodes/<node>/qemu/<vmid>/snapshot -snapname pre-change-$(date +%Y%m%d)` |
| PG backup | `docker exec <db> pg_dump -U postgres <dbname> \| gzip > backup_$(date +%Y%m%d).sql.gz` |
| PG slow queries | `SELECT query, calls, mean_exec_time FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 20` |
| Valkey health | `redis-cli -p 6379 info all \| grep -E "uptime\|memory\|clients\|keyspace"` |
| Tailscale status | `tailscale status && tailscale ping <peer>` |
| CF DNS | `curl -s "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" -H "Authorization: Bearer $CF_API_TOKEN" \| jq '.result[]'` |

## Safety Rules (NON-NEGOTIABLE)

1. **Backup before destructive ops** — pg_dump / snapshot ALWAYS
2. **Health check after every change** — never report success without proof
3. **Dry run before prune** — always `--dry-run` first
4. **HITL for prod** — restart, prune, schema change = explicit approval
5. **Max 2 retries** — then AskUserQuestion with alternatives
6. **Off-peak for REINDEX** — table-locking = maintenance windows only
7. **Never expose secrets** — no env vars/tokens/passwords in output
8. **Audit trail** — log every action with timestamp in session notes

## Error Recovery

| Scenario | Action |
|----------|--------|
| Container won't start | `docker logs --tail 100 <name>` → AskUserQuestion |
| DB connection refused | Check pg_hba.conf, max_connections, port |
| Tailscale unreachable | `tailscale ping`, check ACL, re-auth node |
| Health check fails post-deploy | Rollback compose → restore backup → AskUserQuestion |
| Disk full | `df -h` + `du -sh /opt/* /var/*` → prune Docker first |

## Capacity Planning

Collect 7-day trends (CPU/RAM/disk) → project 30/60/90 days → flag >80% within 30 days → recommend actions. Present as table: resource | current | projected | severity (CRITICAL/WARNING/OK).
