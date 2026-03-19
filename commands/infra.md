Invoke the `infrastructure-ops` skill with the following arguments: $ARGUMENTS

This is the ATLAS infrastructure management command. It manages VM/container infrastructure,
networking, monitoring, backup/DR, and database administration with HITL gates on all
destructive operations.

Subcommands:
- `/atlas infra status` — Full health sweep of all infrastructure (containers, DBs, monitoring)
- `/atlas infra audit` — Detailed resource inventory + capacity report
- `/atlas infra restart <service>` — Restart container/service with health check (prod requires HITL)
- `/atlas infra snapshot <vm>` — Proxmox VM/CT snapshot before risky operations
- `/atlas infra db backup [env]` — pg_dump + verify restore integrity
- `/atlas infra db vacuum` — VACUUM ANALYZE + REINDEX on bloated tables
- `/atlas infra prune` — Docker image/volume/network prune (dry run shown first)
- `/atlas infra capacity` — CPU/RAM/disk trend → provisioning recommendation
- `/atlas infra network audit` — Tailscale ACL + Cloudflare DNS + firewall review
- `/atlas infra backup verify` — Restore-test latest backup to scratch container

If no subcommand given, run `status` (full health sweep).

Workflow: AUDIT → PLAN → (HITL approval) → EXECUTE → VERIFY
Safety rule: never delete without backup, never change without health-check proof.
