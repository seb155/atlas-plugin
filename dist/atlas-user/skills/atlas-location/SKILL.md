---
name: atlas-location
description: "Manage location profiles and WiFi network trust levels. Auto-detects new networks via BSSID fingerprint. Adapts security behavior per trust level. Use when 'location', 'network', 'where am I', 'trust level', or 'new wifi'."
effort: low
---

# ATLAS Location Manager

Manages location-aware behavior by mapping WiFi networks (BSSIDs) to locations with trust levels. Adapts ATLAS security posture automatically per network.

## How It Works

1. **SessionStart** runs `detect-network.sh` which checks WiFi BSSID
2. **Known BSSID** → applies saved trust level (silent, no interruption)
3. **Unknown BSSID** → injects one context line: `📍 NEW NETWORK: {SSID}`
4. User can classify naturally ("c'est chez moi" → ATLAS saves as trusted)
5. If user ignores → defaults to "standard" (safe middle ground)

## Subcommands

| Command | Action |
|---------|--------|
| `/atlas location` | Show current location, network, trust level |
| `/atlas location add` | Register current network with HITL |
| `/atlas location list` | Show all known locations |
| `/atlas location trust [level]` | Change trust for current network |

## Trust Levels

| Level | Where | Behavior |
|-------|-------|----------|
| **trusted** | Home, personal office | Full vault access, all tokens, all skills |
| **standard** | Office, client site, VPN | API tokens OK, no vault secrets, no credentials display |
| **restricted** | Café, airport, hotel, public WiFi | Warn before token use, no vault, read-only preference |

Default for unknown networks: **standard** (safe, not paranoid).

## /atlas location add — Interactive

When user says "add this location" or responds to "📍 NEW NETWORK":

1. Auto-detect current WiFi:
```bash
SSID=$(nmcli -t -f active,ssid dev wifi | grep "^yes" | cut -d: -f2)
BSSID=$(nmcli -t -f active,bssid dev wifi | grep "^yes" | cut -d: -f2 | tr -d '\\')
```

2. AskUserQuestion — Trust level:
```
header: "Trust"
options:
  - "Home (trusted) — full access, vault, all tokens"
  - "Office (standard) — API tokens, no vault secrets"
  - "Public (restricted) — read-only, warn before token use"
```

3. AskUserQuestion — Location name and city:
```
header: "Name"
options:
  - "Home — {detected_city}" (if geo available)
  - "Office — {detected_city}"
  - "Other (I'll specify)"
```

4. Save to `~/.atlas/wifi-locations.json`:
```json
{
  "name": "Home — {city}",
  "bssids": ["{BSSID_1}", "{BSSID_2}"],
  "trust": "trusted",
  "city": "{city}",
  "region": "{region}",
  "country": "{country}"
}
```

Also capture ALL visible BSSIDs (not just connected one) — a location usually has multiple APs. This improves matching accuracy.

## Natural Language Classification

ATLAS-assist should detect when user responds to the "📍 NEW NETWORK" context line:
- "c'est chez moi" / "home" / "maison" → trusted
- "bureau" / "office" / "travail" → standard
- "café" / "public" / "hotel" / "aéroport" → restricted

No need for /atlas location add explicitly — natural conversation works.

## /atlas location — Show Current

```
🏛️ ATLAS │ 📍 LOCATION │ {city}, {region}, {country}
   └─ Network: {network} ({trust}) │ SSID: {ssid} │ IP: {local_ip}
   └─ Forgejo: {forgejo_url} │ Synapse: {synapse_url}
   └─ Geo source: {geo_source} ({geo_precision} precision)
```

## Storage

- `~/.atlas/wifi-locations.json` — BSSID→location database (machine-local)
- `~/.atlas/location.json` — user-configured default location (optional)
- Both are machine-local (Layer 1), NOT in vault
