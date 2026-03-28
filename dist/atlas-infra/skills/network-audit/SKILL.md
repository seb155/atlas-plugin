---
name: network-audit
description: "Network infrastructure audit: DNS resolution, port scanning, VLAN verification, SSL certificates, firewall rules. Use when 'network audit', 'check dns', 'port scan', 'check ssl', 'vlan check', 'firewall status', 'network check'."
effort: low
---

# Network Audit — Infrastructure Network Health

> Comprehensive network health check: DNS, ports, VLANs, SSL, firewall.
> For homelab and production environments.

## When to Use

- After network infrastructure changes (VLAN, DNS, firewall rules)
- Debugging service connectivity issues
- Pre-deploy verification
- Periodic security audit

## Process

### Step 1: DNS Resolution Check

```bash
echo "=== DNS Resolution ==="
DOMAINS=(
  "synapse.axoiq.com"
  "forgejo.axoiq.com"
  "auth.axoiq.com"
)
for domain in "${DOMAINS[@]}"; do
  ip=$(dig +short "$domain" 2>/dev/null | head -1)
  echo "  $domain → ${ip:-FAIL}"
done

# Internal DNS (Technitium)
echo ""
echo "=== Internal DNS ==="
for host in synapse-db synapse-backend synapse-frontend; do
  ip=$(getent hosts "$host" 2>/dev/null | awk '{print $1}')
  echo "  $host → ${ip:-NOT RESOLVED}"
done
```

### Step 2: Service Port Check

```bash
echo ""
echo "=== Service Ports ==="
SERVICES=(
  "localhost:5433:PostgreSQL"
  "localhost:8001:Backend"
  "localhost:4000:Frontend"
  "localhost:3000:Forgejo"
  "localhost:9005:Authentik"
  "localhost:6380:Valkey"
)
for svc in "${SERVICES[@]}"; do
  IFS=: read -r host port name <<< "$svc"
  if timeout 2 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
    echo "  ✅ $name ($host:$port)"
  else
    echo "  ❌ $name ($host:$port) — NOT REACHABLE"
  fi
done
```

### Step 3: SSL/TLS Certificate Check

```bash
echo ""
echo "=== SSL Certificates ==="
for domain in synapse.axoiq.com forgejo.axoiq.com auth.axoiq.com; do
  expiry=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | \
    openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
  if [ -n "$expiry" ]; then
    days_left=$(( ($(date -d "$expiry" +%s) - $(date +%s)) / 86400 ))
    status=$([ $days_left -gt 30 ] && echo "✅" || echo "⚠️")
    echo "  $status $domain — expires in ${days_left}d ($expiry)"
  else
    echo "  ❌ $domain — SSL check failed"
  fi
done
```

### Step 4: Output Summary

```
Network Audit Summary
+-------------------+--------+
| Check             | Status |
+-------------------+--------+
| DNS (external)    | 3/3 OK |
| DNS (internal)    | 2/3 OK |
| Service ports     | 5/6 OK |
| SSL certificates  | 3/3 OK |
| Mesh connectivity | 9/10   |
+-------------------+--------+
Overall: HEALTHY / DEGRADED / CRITICAL
```
