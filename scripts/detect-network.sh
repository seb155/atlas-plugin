#!/usr/bin/env bash
# ATLAS Smart Network Detection
# Detects network, geolocation (3-tier), and returns correct service URLs.
# Used by: hooks, doctor, onboarding, finishing-branch
#
# Networks: local | external | offline
# Geolocation (3-tier precision):
#   1. User-configured (~/.atlas/location.json) — street-level (highest priority)
#   2. WiFi BSSID fingerprint (~/.atlas/wifi-locations.json) — building-level
#   3. IP-based (ip-api.com) — city-level (fallback)

set -euo pipefail

ATLAS_DIR="${HOME}/.atlas"

detect_network() {
  local network="offline"
  local forgejo_url="" synapse_url="" authentik_url=""

  # ─── Network Detection ────────────────────────────────────────
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

  # ─── Geolocation (3-tier) ─────────────────────────────────────
  local geo_source="none" geo_precision="none"
  local city="" region="" country="" lat="" lon="" address="" postal="" isp="" public_ip=""
  local vpn="false"

  # Tier 1: User-configured location (street-level, highest precision)
  # File: ~/.atlas/location.json — set once via /atlas setup or manually
  if [ -f "${ATLAS_DIR}/location.json" ]; then
    local loc_json
    loc_json=$(cat "${ATLAS_DIR}/location.json" 2>/dev/null || true)
    if [ -n "$loc_json" ]; then
      geo_source="user_config"
      geo_precision="street"
      city=$(echo "$loc_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('city',''))" 2>/dev/null || true)
      region=$(echo "$loc_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('region',''))" 2>/dev/null || true)
      country=$(echo "$loc_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('country',''))" 2>/dev/null || true)
      lat=$(echo "$loc_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('lat',''))" 2>/dev/null || true)
      lon=$(echo "$loc_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('lon',''))" 2>/dev/null || true)
      address=$(echo "$loc_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('address',''))" 2>/dev/null || true)
      postal=$(echo "$loc_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('postal',''))" 2>/dev/null || true)
    fi
  fi

  # Tier 2: WiFi BSSID fingerprint (building-level)
  # Map known WiFi networks to locations — detected via nmcli
  if [ "$geo_source" = "none" ] && [ -f "${ATLAS_DIR}/wifi-locations.json" ] && command -v nmcli &>/dev/null; then
    local current_bssid
    current_bssid=$(nmcli -t -f BSSID dev wifi list 2>/dev/null | head -1 | tr -d '\\' || true)
    if [ -n "$current_bssid" ]; then
      local wifi_match
      wifi_match=$(python3 -c "
import json, sys
try:
    with open('${ATLAS_DIR}/wifi-locations.json') as f:
        db = json.load(f)
    bssid = '${current_bssid}'.strip()
    for entry in db.get('locations', []):
        for known_bssid in entry.get('bssids', []):
            if known_bssid.upper() == bssid.upper():
                print(json.dumps(entry))
                sys.exit(0)
except: pass
" 2>/dev/null || true)
      if [ -n "$wifi_match" ]; then
        geo_source="wifi_fingerprint"
        geo_precision="building"
        city=$(echo "$wifi_match" | python3 -c "import sys,json; print(json.load(sys.stdin).get('city',''))" 2>/dev/null || true)
        region=$(echo "$wifi_match" | python3 -c "import sys,json; print(json.load(sys.stdin).get('region',''))" 2>/dev/null || true)
        country=$(echo "$wifi_match" | python3 -c "import sys,json; print(json.load(sys.stdin).get('country',''))" 2>/dev/null || true)
        lat=$(echo "$wifi_match" | python3 -c "import sys,json; print(json.load(sys.stdin).get('lat',''))" 2>/dev/null || true)
        lon=$(echo "$wifi_match" | python3 -c "import sys,json; print(json.load(sys.stdin).get('lon',''))" 2>/dev/null || true)
        address=$(echo "$wifi_match" | python3 -c "import sys,json; print(json.load(sys.stdin).get('address',''))" 2>/dev/null || true)
        postal=$(echo "$wifi_match" | python3 -c "import sys,json; print(json.load(sys.stdin).get('postal',''))" 2>/dev/null || true)
      fi
    fi
  fi

  # Tier 3: IP-based geolocation (city-level, fallback)
  if [ "$geo_source" = "none" ] && [ "$network" != "offline" ]; then
    local ip_json
    ip_json=$(curl -sf --max-time 3 "http://ip-api.com/json/?fields=query,city,regionName,country,lat,lon,zip,isp,proxy" 2>/dev/null || true)
    if [ -n "$ip_json" ]; then
      geo_source="ip_api"
      geo_precision="city"
      public_ip=$(echo "$ip_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('query',''))" 2>/dev/null || true)
      city=$(echo "$ip_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('city',''))" 2>/dev/null || true)
      region=$(echo "$ip_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('regionName',''))" 2>/dev/null || true)
      country=$(echo "$ip_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('country',''))" 2>/dev/null || true)
      lat=$(echo "$ip_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('lat',''))" 2>/dev/null || true)
      lon=$(echo "$ip_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('lon',''))" 2>/dev/null || true)
      postal=$(echo "$ip_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('zip',''))" 2>/dev/null || true)
      isp=$(echo "$ip_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('isp',''))" 2>/dev/null || true)
      vpn=$(echo "$ip_json" | python3 -c "import sys,json; print(str(json.load(sys.stdin).get('proxy',False)).lower())" 2>/dev/null || echo "false")
    fi
  fi

  # ─── Connectivity ─────────────────────────────────────────────
  local tailscale_status="disconnected"
  if command -v tailscale &>/dev/null; then
    tailscale status >/dev/null 2>&1 && tailscale_status="connected"
  fi
  local local_ip
  local_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "unknown")
  # Get public IP if not already fetched
  if [ -z "$public_ip" ] && [ "$network" != "offline" ]; then
    public_ip=$(curl -sf --max-time 2 "https://ifconfig.me" 2>/dev/null || echo "")
  fi

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
    "source": "${geo_source}",
    "precision": "${geo_precision}",
    "city": "${city}",
    "region": "${region}",
    "country": "${country}",
    "lat": "${lat}",
    "lon": "${lon}",
    "address": "${address}",
    "postal": "${postal}",
    "isp": "${isp}",
    "vpn": ${vpn}
  }
}
EOF
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  detect_network
fi
