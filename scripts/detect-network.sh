#!/usr/bin/env bash
# ATLAS Smart Network Detection
# Detects network, geolocation, and returns correct service URLs.
# Used by: hooks, doctor, onboarding, finishing-branch
#
# Networks:
#   local    — home LAN (*.home.axoiq.com reachable)
#   external — internet only (*.axoiq.com via Cloudflare)
#   offline  — no network

set -euo pipefail

detect_network() {
  local network="offline"
  local forgejo_url="" synapse_url="" authentik_url=""
  local public_ip="" city="" region="" country="" isp="" vpn="false"

  # Priority 1: Local network (home LAN — *.home.axoiq.com)
  if curl -sf --max-time 2 https://forgejo.home.axoiq.com/api/v1/version >/dev/null 2>&1; then
    network="local"
    forgejo_url="https://forgejo.home.axoiq.com"
    synapse_url="https://synapse.home.axoiq.com"
    authentik_url="https://auth.home.axoiq.com"
  # Priority 2: External (Cloudflare — *.axoiq.com)
  elif curl -sf --max-time 3 https://forgejo.axoiq.com/api/v1/version >/dev/null 2>&1; then
    network="external"
    forgejo_url="https://forgejo.axoiq.com"
    synapse_url="https://synapse.axoiq.com"
    authentik_url="https://auth.axoiq.com"
  fi

  # Synapse localhost always takes priority if available
  if curl -sf --max-time 2 http://localhost:8001/health >/dev/null 2>&1; then
    synapse_url="http://localhost:8001"
  fi

  # Geolocation via ip-api.com (free, no key, 45 req/min)
  # Only if we have network
  if [ "$network" != "offline" ]; then
    local geo_json
    geo_json=$(curl -sf --max-time 3 "http://ip-api.com/json/?fields=query,city,regionName,country,isp,proxy" 2>/dev/null || true)
    if [ -n "$geo_json" ]; then
      public_ip=$(echo "$geo_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('query',''))" 2>/dev/null || true)
      city=$(echo "$geo_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('city',''))" 2>/dev/null || true)
      region=$(echo "$geo_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('regionName',''))" 2>/dev/null || true)
      country=$(echo "$geo_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('country',''))" 2>/dev/null || true)
      isp=$(echo "$geo_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('isp',''))" 2>/dev/null || true)
      vpn=$(echo "$geo_json" | python3 -c "import sys,json; print(str(json.load(sys.stdin).get('proxy',False)).lower())" 2>/dev/null || echo "false")
    fi
  fi

  # Tailscale/Headscale VPN detection
  local tailscale_status="disconnected"
  if command -v tailscale &>/dev/null; then
    tailscale status >/dev/null 2>&1 && tailscale_status="connected"
  fi

  # Local IP
  local local_ip
  local_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "unknown")

  cat <<EOF
{
  "network": "${network}",
  "forgejo_url": "${forgejo_url}",
  "synapse_url": "${synapse_url}",
  "authentik_url": "${authentik_url}",
  "connectivity": {
    "local_ip": "${local_ip}",
    "public_ip": "${public_ip}",
    "tailscale": "${tailscale_status}"
  },
  "geo": {
    "city": "${city}",
    "region": "${region}",
    "country": "${country}",
    "isp": "${isp}",
    "vpn": ${vpn}
  }
}
EOF
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  detect_network
fi
