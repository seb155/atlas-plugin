---
name: proxmox-admin
description: "Proxmox VE administration. VM/LXC lifecycle, storage pools, GPU passthrough, clustering, backup/restore, resource quotas."
effort: high
---

# Proxmox Administration

## When to Use
- Creating, configuring, or managing VMs and LXC containers
- Storage pool management (add, resize, migrate)
- GPU passthrough configuration (IOMMU, vfio-pci, hook scripts)
- Cluster operations (node status, HA groups, migrations)
- Backup and restore (PBS, vzdump, snapshots)
- Resource quota management (CPU, RAM, disk limits)

## Infrastructure

| Node | Hostname | IP (mgmt) | CPU | RAM | GPU | Role |
|------|----------|-----------|-----|-----|-----|------|
| PVE1 | srv-ctrl | 192.168.1.21 | i5-12600H | 32GB | none | Ingress, Traefik |
| PVE2 | srv-comp | 192.168.1.22 | Ryzen 7950X3D | 94GB | RTX 3080 Ti | Compute, AI |
| PVE3 | srv-stor | 192.168.1.23 | i5-9600KF | 32GB | GTX 1070 Ti | Storage |

## Process

### 1. Pre-flight
```bash
# Connect to PVE node
ssh root@192.168.1.{21,22,23}
# Check cluster status
pvecm status 2>/dev/null || echo "Standalone node"
# List resources
qm list && pct list && pvesm status && free -h && df -h /
```

### 2. VM Operations
```bash
qm create <vmid> --name <name> --ostype l26 --cores <n> --memory <mb> --net0 virtio,bridge=vmbr1,tag=10
qm set <vmid> --scsi0 <storage>:<size>,ssd=1,iothread=1
qm set <vmid> --ide2 <storage>:cloudinit --ciuser <user> --cipassword <pass>
qm set <vmid> --ipconfig0 ip=<ip>/24,gw=<gw>
qm resize <vmid> scsi0 +<size>G
qm start|stop|restart|destroy <vmid>
qm migrate <vmid> <target-node>
```

### 3. LXC Operations
```bash
pct create <ctid> <template> --hostname <name> --cores <n> --memory <mb> --rootfs <storage>:<size>
pct set <ctid> --net0 name=eth0,bridge=vmbr1,ip=<ip>/24,gw=<gw>,tag=10
pct start|stop|destroy <ctid>
```

### 4. Storage
```bash
pvesm status                          # List all pools
pvesm add dir <name> --path <path>    # Add directory storage
pvesm scan nfs <server>               # Scan NFS exports
zpool status                          # ZFS pool health
```

### 5. GPU Passthrough
```bash
# Check IOMMU
dmesg | grep -i "DMAR\|iommu"
# Find GPU
lspci -nnk | grep -A3 nvidia
# Verify VFIO binding
lspci -nnk -s <bus>:00 | grep "driver in use"
# Hook script for dynamic bind
cat /var/lib/vz/snippets/gpu-passthrough.sh
# VM config
qm set <vmid> --hostpci0 <bus>:00,pcie=1,rombar=0 --vga none
qm set <vmid> --hookscript local:snippets/gpu-passthrough.sh
```

### 6. Backup & Restore
```bash
vzdump <vmid> --storage <pbs> --mode snapshot --compress zstd
qmrestore <backup-file> <vmid> --storage <target>
```

## Safety Rules (NON-NEGOTIABLE)

- **HITL gate** before: VM destroy, storage remove, cluster join/leave, GPU reassign
- **Snapshot first** before resize, migrate, or config changes
- **Verify after** every change: `qm status`, `pvesm status`, `ping <vm-ip>`
- **Never** resize down (only grow)
- **Never** destroy a VM without confirming it has no active users
- Max 2 retries per operation → escalate to human
