---
name: infra-inventory
description: "Infrastructure inventory scan and state management. Live scanning of PVE nodes, VMs, storage, GPUs. Drift detection and state file updates."
effort: high
---

# Infrastructure Inventory

## When to Use
- `/infra-inventory scan` — Full infrastructure scan and state update
- `/infra-inventory status` — Show current state from last scan
- Automatically at start of infra sessions (invoked by `infra-expert`)
- After any `infrastructure-change` or `proxmox-admin` operation

## Process

### 1. SCAN — Collect Live State
```bash
# Scan all PVE nodes
for node_ip in 192.168.1.21 192.168.1.22 192.168.1.23; do
  ssh root@$node_ip '
    echo "NODE:$(hostname)"
    echo "KERNEL:$(uname -r)"
    echo "CPU:$(nproc):$(cat /proc/cpuinfo | grep "model name" | head -1 | cut -d: -f2 | xargs)"
    echo "RAM:$(free -m | awk "/Mem:/{print \$2\":\" \$3\":\" \$7}")"
    echo "DISK:$(df -m / | tail -1 | awk "{print \$2\":\" \$3\":\" \$5}")"
    echo "VMS:"
    qm list 2>/dev/null | tail -n+2
    echo "LXCS:"
    pct list 2>/dev/null | tail -n+2
    echo "STORAGE:"
    pvesm status 2>/dev/null
    echo "GPU:"
    lspci | grep -i "nvidia\|vga" | grep -v virtio
    echo "NETS:"
    ip -br addr | grep -v "^lo"
  '
done

# Scan key VMs
for vm_ip in 192.168.10.50 192.168.10.55 192.168.10.65 192.168.10.70; do
  ssh -o ConnectTimeout=5 dev@$vm_ip "hostname && docker ps --format '{{.Names}}: {{.Status}}' 2>/dev/null && df -h / | tail -1" 2>/dev/null
done
```

### 2. COMPARE — Detect Drift
Compare scan results against previous state file. Flag:
- New VMs/LXCs not in previous state
- Missing VMs/LXCs (deleted or crashed)
- Disk usage > 80% (warning) or > 90% (critical)
- RAM usage > 90%
- GPU allocation changes
- Docker container count changes
- Kernel version changes

### 3. UPDATE — Write State File
Write structured state to memory file:
```
memory/homelab-topology.md
```

Format: Markdown tables (Nodes, VMs, Storage, Networks, GPUs, Changes)
Include timestamp: `Last scan: YYYY-MM-DD HH:MM TZ`

### 4. REPORT — Summary Output
```
🏗️ Infrastructure Inventory — {timestamp}
═══════════════════════════════════════════

Nodes:  3 PVE | {total_cpu} cores | {total_ram}GB RAM
VMs:    {vm_count} ({running} running, {stopped} stopped)
LXCs:   {lxc_count}
Storage: {pools} pools | {total_disk}GB ({used_pct}% used)
GPUs:   {gpu_count} ({allocated} allocated)

{drift_alerts if any}
```

## Safety Rules

- This skill is READ-ONLY (scan + report only)
- Never modify infrastructure — only observe and document
- SSH connections use existing authorized keys (no password prompts)
- Timeout: 5s per host (skip unreachable nodes gracefully)
- State file is append-only for "Changes Since Last Scan" section
