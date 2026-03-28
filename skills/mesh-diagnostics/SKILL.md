---
name: mesh-diagnostics
description: "NetBird and Tailscale mesh network health diagnostics. Peer connectivity, latency, OIDC sync, route status. Use when 'mesh status', 'network health', 'netbird status', 'tailscale status', 'peer connectivity', 'vpn health', 'mesh diagnostics'."
effort: low
---

# Mesh Diagnostics — VPN/Mesh Network Health

> Check the health of NetBird and/or Tailscale mesh networks.
> Peer connectivity, latency, OIDC group sync, route advertisements.

## When to Use

- Troubleshooting SSH connectivity issues
- Verifying mesh health after infrastructure changes
- Checking if all peers are reachable before deploy
- Investigating latency between services

## Process

### Step 1: Detect Mesh Provider

```bash
MESH="none"
command -v netbird &>/dev/null && MESH="netbird"
command -v tailscale &>/dev/null && MESH="${MESH:+$MESH+}tailscale"
echo "Mesh provider: $MESH"
```

### Step 2: NetBird Status (if available)

```bash
if command -v netbird &>/dev/null; then
  echo "=== NetBird Status ==="
  sudo netbird status 2>/dev/null || netbird status 2>/dev/null

  echo ""
  echo "=== Peer Connectivity ==="
  sudo netbird status --detail 2>/dev/null | grep -E "Peer|Status|Latency|Routes"
fi
```

### Step 3: Tailscale Status (if available)

```bash
if command -v tailscale &>/dev/null; then
  echo "=== Tailscale Status ==="
  tailscale status 2>/dev/null

  echo ""
  echo "=== Tailscale Ping (all peers) ==="
  tailscale status --json 2>/dev/null | python3 -c "
import json, sys, subprocess
data = json.load(sys.stdin)
peers = data.get('Peer', {})
for key, peer in list(peers.items())[:10]:
    name = peer.get('HostName', 'unknown')
    ip = peer.get('TailscaleIPs', ['?'])[0]
    online = peer.get('Online', False)
    print(f'  {name:20s} {ip:18s} {\"ONLINE\" if online else \"OFFLINE\"}')"
fi
```

### Step 4: Output Summary

```
Mesh Health Summary
+-------------------+----------+---------+---------+
| Peer              | IP       | Latency | Status  |
+-------------------+----------+---------+---------+
| vm-550-prod       | 100.64.x | 2ms     | ONLINE  |
| vm-560-dev        | 100.64.x | 3ms     | ONLINE  |
| laptop-seb        | 100.64.x | 1ms     | ONLINE  |
+-------------------+----------+---------+---------+
Connected: {N}/{M} peers | Provider: {netbird|tailscale|both}
```

### Step 5: OIDC Group Sync Check (NetBird)

```bash
# Check if OIDC groups are synced (Authentik → NetBird)
if [ -f "$HOME/.env" ]; then
  source "$HOME/.env"
  if [ -n "${NETBIRD_API_KEY:-}" ]; then
    curl -sf "https://api.netbird.io/api/groups" \
      -H "Authorization: Token $NETBIRD_API_KEY" \
      -H "Accept: application/json" 2>/dev/null | \
      python3 -c "import json,sys; groups=json.load(sys.stdin); print(f'OIDC groups: {len(groups)}')" 2>/dev/null
  fi
fi
```
