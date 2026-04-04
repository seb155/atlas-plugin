---
name: hardware-capacity
description: "Hardware inventory and capacity planning. CPU/RAM/disk/GPU audit, resource allocation, growth projections, thermal monitoring."
---

# Hardware Capacity Planning

## When to Use
- Auditing current hardware utilization across PVE nodes
- Planning for new VMs/workloads (will it fit?)
- GPU allocation decisions (which GPU for which workload)
- Disk capacity projections (when will we run out?)
- RAM/CPU right-sizing for existing VMs

## Hardware Inventory

| Node | Hostname | CPU | Cores | RAM | Disk | GPU | VRAM |
|------|----------|-----|-------|-----|------|-----|------|
| PVE1 | srv-ctrl | i5-12600H | 12T | 32GB | ~100GB SSD | none | — |
| PVE2 | srv-comp | Ryzen 7950X3D | 32T | 94GB | ~960GB NVMe | RTX 3080 Ti | 12GB |
| PVE3 | srv-stor | i5-9600KF | 6C | 32GB | ~960GB NVMe + NAS | GTX 1070 Ti | 8GB |

## Process

### 1. Live Audit (per node)
```bash
for node in 192.168.1.21 192.168.1.22 192.168.1.23; do
  echo "=== $(ssh root@$node hostname) ==="
  ssh root@$node '
    echo "CPU: $(nproc) cores, $(cat /proc/cpuinfo | grep "model name" | head -1 | cut -d: -f2)"
    echo "RAM: $(free -h | awk "/Mem:/{print \$2\" total, \"\$3\" used, \"\$7\" available\"}")"
    echo "Disk: $(df -h / | tail -1 | awk "{print \$2\" total, \"\$3\" used, \"\$5\" usage\"}")"
    echo "VMs: $(qm list 2>/dev/null | tail -n+2 | wc -l) running"
    echo "LXCs: $(pct list 2>/dev/null | tail -n+2 | wc -l) running"
    lspci | grep -i "nvidia\|vga" | grep -v "virtio"
  '
done
```

### 2. Capacity Calculation
```
Available = Total - Reserved(host) - Allocated(VMs)
Overcommit ratio: CPU 2:1 OK, RAM 1:1 strict, Disk 1:1 strict
```

### 3. GPU Allocation Matrix

| GPU | Node | Allocated To | VRAM Used | Available |
|-----|------|-------------|-----------|-----------|
| RTX 3080 Ti | PVE2 | VM 551 (AI/LLM) | ~10GB | ~2GB |
| GTX 1070 Ti | PVE3 | VM 570 (GPU-dev) | 0 (passthrough) | 8GB |

### 4. Growth Projection
```
Current: X GB used / Y GB total (Z%)
30-day trend: +N GB/month
Projected full: in M months
Action threshold: 80% → alert, 90% → expand
```

## Output Format

Present results as:
1. **Node Summary Table** — CPU/RAM/Disk per node
2. **VM Allocation Table** — Per-VM resource usage
3. **Capacity Forecast** — 30/60/90 day projections
4. **Recommendations** — Resize, migrate, or expand decisions
