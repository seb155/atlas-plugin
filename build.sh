#!/usr/bin/env bash
# Build tier and domain plugins from atlas-core
# Usage: ./build.sh [admin|dev|user|worker|all]          — tier mode
#        ./build.sh domain <name>                         — single domain
#        ./build.sh domains                               — all 6 domains
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VERSION=$(cat VERSION | tr -d '[:space:]')
TIERS="${1:-all}"
METADATA_FILE="skills/_metadata.yaml"

# Propagate VERSION to source JSON files (keeps them in sync)
if command -v python3 &>/dev/null; then
  python3 -c "
import json, sys
v = '$VERSION'
for f in ['.claude-plugin/plugin.json', '.claude-plugin/marketplace.json']:
    try:
        with open(f) as fh: d = json.load(fh)
        if 'version' in d and d['version'] != v:
            d['version'] = v; open(f,'w').write(json.dumps(d, indent=2) + '\n')
        if 'plugins' in d:
            for p in d['plugins']:
                if 'version' in p and p['version'] != v:
                    p['version'] = v; open(f,'w').write(json.dumps(d, indent=2) + '\n')
    except: pass
" 2>/dev/null || true
fi

# Resolve profile inheritance and collect all items for a field
# Usage: resolve_field <tier> <field>
resolve_field() {
  local tier="$1"
  local field="$2"
  local profile="profiles/${tier}.yaml"
  local items=""

  # Check if this tier inherits from another
  local parent
  parent=$(yq -r '.inherits // ""' "$profile")

  # Recurse into parent first (base items come first)
  if [ -n "$parent" ] && [ -f "profiles/${parent}.yaml" ]; then
    items=$(resolve_field "$parent" "$field")
  fi

  # Add this tier's items
  local tier_items
  tier_items=$(yq -r ".${field} // [] | .[]" "$profile" 2>/dev/null || true)

  if [ -n "$items" ] && [ -n "$tier_items" ]; then
    echo -e "${items}\n${tier_items}" | awk '!seen[$0]++'
  elif [ -n "$items" ]; then
    echo "$items"
  else
    echo "$tier_items"
  fi
}

# ── Ownership functions (SP-DEDUP Phase 1) ──────────────────────
# Map tier build names to _metadata.yaml owner values
# (user tier → "core" owner — they merge in Phase 3)
tier_to_owner() {
  case "$1" in
    user) echo "core" ;;
    *) echo "$1" ;;
  esac
}

# Return skills OWNED by a given owner (from _metadata.yaml)
get_owned_skills() {
  local owner="$1"
  yq -r ".skills | to_entries[] | select(.value.owner == \"$owner\") | .key" "$METADATA_FILE"
}

# Return domain-EXCLUSIVE skills (owned by this domain but NOT a tier name)
# Tier owners (core/dev/admin) have their skills in tier plugins, not domain plugins
get_domain_exclusive_skills() {
  local domain="$1"
  case "$domain" in
    core|dev|admin) echo "" ;;  # These are tier names — no exclusive domain skills
    *) get_owned_skills "$domain" ;;  # infra, enterprise, etc.
  esac
}

build_tier() {
  local tier="$1"
  local profile="profiles/${tier}.yaml"
  local output="dist/atlas-${tier}"

  if [ ! -f "$profile" ]; then
    echo "❌ Profile not found: $profile"
    exit 1
  fi

  echo "🔨 Building atlas-${tier} v${VERSION}..."

  rm -rf "$output"
  mkdir -p "$output"/{.claude-plugin,skills,agents,hooks}

  # SP-DEDUP: Copy only OWNED skills (delta), not inherited
  # atlas-assist still gets the full list via resolve_field (line ~190)
  local owner
  owner=$(tier_to_owner "$tier")
  local owned_skills
  owned_skills=$(get_owned_skills "$owner")

  for skill in $owned_skills; do
    if [ -d "skills/$skill" ]; then
      cp -r "skills/$skill" "$output/skills/"
    else
      echo "  ⚠️  Skill not found: $skill (skipped)"
    fi
  done

  # Resolve inherited refs
  local refs
  refs=$(resolve_field "$tier" "refs")

  if [ -n "$refs" ]; then
    mkdir -p "$output/skills/refs"
    for ref in $refs; do
      if [ -d "skills/refs/$ref" ]; then
        cp -r "skills/refs/$ref" "$output/skills/refs/"
      else
        echo "  ⚠️  Ref not found: $ref (skipped)"
      fi
    done
  fi

  # Resolve inherited agents
  local agents
  agents=$(resolve_field "$tier" "agents")

  for agent in $agents; do
    if [ -d "agents/$agent" ]; then
      cp -r "agents/$agent" "$output/agents/"
    else
      echo "  ⚠️  Agent not found: $agent (skipped)"
    fi
  done

  # Copy hooks (profile-resolved — each tier gets only its declared hooks)
  local hooks
  hooks=$(resolve_field "$tier" "hooks")

  if [ -z "$hooks" ]; then
    # Empty hooks list (e.g., worker tier) → write empty hooks.json
    echo '{"hooks":{}}' > "$output/hooks/hooks.json"
  else
    # Filter master hooks.json to include only resolved hook scripts
    # shellcheck disable=SC2086
    python3 scripts/filter-hooks-json.py hooks/hooks.json $hooks > "$output/hooks/hooks.json"
    for hook_name in $hooks; do
      if [ -x "hooks/$hook_name" ]; then
        cp "hooks/$hook_name" "$output/hooks/"
      fi
    done
    # Copy hook shared libraries (sourced by multiple hooks)
    if [ -d "hooks/lib" ]; then
      mkdir -p "$output/hooks/lib"
      cp hooks/lib/*.sh "$output/hooks/lib/" 2>/dev/null || true
    fi
    # Copy TypeScript hook runner and hooks (if present)
    if [ -x "hooks/run-hook.sh" ]; then
      cp "hooks/run-hook.sh" "$output/hooks/"
    fi
    if [ -d "hooks/ts" ]; then
      cp -r "hooks/ts" "$output/hooks/"
    fi
  fi

  # Copy runtime scripts (exclude build-only scripts)
  local runtime_scripts=(parse-features.sh atlas-alert-module.sh atlas-context-size-module.sh detect-platform.sh detect-network.sh shell-aliases.sh setup-terminal.sh get-secret.sh bw-login.sh atlas-keyring.sh atlas-e2e-validate.sh require-secrets.sh statusline-command.sh atlas-cli.sh setup-wizard.sh load-secrets.sh fix-cc-settings.sh)
  mkdir -p "$output/scripts"
  for script in "${runtime_scripts[@]}"; do
    if [ -f "scripts/$script" ]; then
      cp "scripts/$script" "$output/scripts/"
      chmod +x "$output/scripts/$script"
    fi
  done

  # Copy VERSION file
  cp VERSION "$output/VERSION"

  # Copy plugin settings.json (CC v2.1.49+ — plugins ship default settings)
  if [ -f "settings.json" ]; then
    cp settings.json "$output/settings.json"
  fi

  # Copy config presets
  if [ -d "scripts/presets" ]; then
    mkdir -p "$output/scripts/presets"
    cp scripts/presets/*.json "$output/scripts/presets/" 2>/dev/null || true
  fi

  # Copy CShip config (statusline)
  [ -f "scripts/cship.toml" ] && cp "scripts/cship.toml" "$output/scripts/"

  # Generate tier-specific atlas-assist SKILL.md
  mkdir -p "$output/skills/atlas-assist"
  ./scripts/generate-master-skill.sh "$tier" "$output/skills/atlas-assist/SKILL.md"

  # Generate tier-specific plugin.json (with buildTimestamp for CC cache invalidation)
  local tier_upper build_ts
  tier_upper=$(echo "${tier}" | sed 's/./\U&/')
  build_ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  cat > "$output/.claude-plugin/plugin.json" <<EOF
{
  "name": "atlas-${tier}",
  "version": "${VERSION}",
  "description": "ATLAS ${tier_upper} — AXOIQ AI Engineering Assistant (${tier} tier)",
  "author": { "name": "AXOIQ", "email": "dev@axoiq.com" },
  "license": "UNLICENSED",
  "buildTimestamp": "${build_ts}"
}
EOF

  # Generate marketplace.json (valid marketplace manifest — no extra keys)
  cat > "$output/.claude-plugin/marketplace.json" <<EOF
{
  "name": "atlas-admin-marketplace",
  "owner": { "name": "AXOIQ", "email": "dev@axoiq.com" },
  "plugins": [
    {
      "name": "atlas-${tier}",
      "description": "ATLAS ${tier_upper} — AXOIQ AI Engineering Assistant (${tier} tier)",
      "version": "${VERSION}",
      "source": { "source": "url", "url": "https://forgejo.axoiq.com/atlas/atlas-plugin.git" },
      "author": { "name": "AXOIQ", "email": "dev@axoiq.com" }
    }
  ]
}
EOF

  # Count results
  local skill_count
  skill_count=$(find "$output/skills" -maxdepth 2 -name "SKILL.md" | wc -l)
  local agent_count
  agent_count=$(find "$output/agents" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)

  echo "✅ Built atlas-${tier} v${VERSION} → ${output}/"
  echo "   ${skill_count} skills | ${agent_count} agents"
}

# ── Domain build (standalone, no inheritance) ─────────────────────
DOMAIN_NAMES=(core dev frontend infra enterprise experiential)

build_domain() {
  local name="$1"
  local profile="profiles/domain-${name}.yaml"
  local output="dist/atlas-${name}"

  if [ ! -f "$profile" ]; then
    echo "❌ Domain profile not found: $profile"
    exit 1
  fi

  # SP-DEDUP: Skip domain build if a tier with same name was already built
  # (avoids dist/atlas-dev/ collision between tier "dev" and domain "dev")
  if [ -f "profiles/${name}.yaml" ] && [ -d "dist/atlas-${name}/skills" ]; then
    echo "⏭️  Skipping atlas-${name} domain — tier build already exists at dist/atlas-${name}/"
    return 0
  fi

  local desc
  desc=$(yq -r '.description // "ATLAS domain plugin"' "$profile")

  echo "🔨 Building atlas-${name} (domain) v${VERSION}..."

  rm -rf "$output"
  mkdir -p "$output"/{.claude-plugin,skills,agents,hooks}

  # SP-DEDUP: Copy only domain-EXCLUSIVE skills (not tier-owned)
  # atlas-assist still gets the full domain skill list for reference
  local owned_skills
  owned_skills=$(get_domain_exclusive_skills "$name")

  for skill in $owned_skills; do
    if [ -d "skills/$skill" ]; then
      cp -r "skills/$skill" "$output/skills/"
    else
      echo "  ⚠️  Skill not found: $skill (skipped)"
    fi
  done

  # Refs → copied into skills/refs/
  local refs
  refs=$(yq -r '.refs // [] | .[]' "$profile" 2>/dev/null || true)

  if [ -n "$refs" ]; then
    mkdir -p "$output/skills/refs"
    for ref in $refs; do
      if [ -d "skills/refs/$ref" ]; then
        cp -r "skills/refs/$ref" "$output/skills/refs/"
      else
        echo "  ⚠️  Ref not found: $ref (skipped)"
      fi
    done
  fi

  # Agents
  local agents
  agents=$(yq -r '.agents // [] | .[]' "$profile" 2>/dev/null || true)

  for agent in $agents; do
    if [ -d "agents/$agent" ]; then
      cp -r "agents/$agent" "$output/agents/"
    else
      echo "  ⚠️  Agent not found: $agent (skipped)"
    fi
  done

  # Hooks — filter master hooks.json via allowed list
  local hooks
  hooks=$(yq -r '.hooks // [] | .[]' "$profile" 2>/dev/null || true)

  if [ -z "$hooks" ]; then
    echo '{"hooks":{}}' > "$output/hooks/hooks.json"
  else
    # shellcheck disable=SC2086
    python3 scripts/filter-hooks-json.py hooks/hooks.json $hooks > "$output/hooks/hooks.json"
    for hook_name in $hooks; do
      if [ -x "hooks/$hook_name" ]; then
        cp "hooks/$hook_name" "$output/hooks/"
      fi
    done
    # Hook shared libraries
    if [ -d "hooks/lib" ]; then
      mkdir -p "$output/hooks/lib"
      cp hooks/lib/*.sh "$output/hooks/lib/" 2>/dev/null || true
    fi
    if [ -x "hooks/run-hook.sh" ]; then
      cp "hooks/run-hook.sh" "$output/hooks/"
    fi
    if [ -d "hooks/ts" ]; then
      cp -r "hooks/ts" "$output/hooks/"
    fi
  fi

  # Runtime scripts — only core domain gets scripts/
  if [ "$name" = "core" ]; then
    local runtime_scripts=(parse-features.sh atlas-alert-module.sh atlas-context-size-module.sh detect-platform.sh detect-network.sh shell-aliases.sh setup-terminal.sh get-secret.sh bw-login.sh atlas-keyring.sh atlas-e2e-validate.sh require-secrets.sh statusline-command.sh atlas-cli.sh setup-wizard.sh load-secrets.sh fix-cc-settings.sh)
    mkdir -p "$output/scripts"
    for script in "${runtime_scripts[@]}"; do
      if [ -f "scripts/$script" ]; then
        cp "scripts/$script" "$output/scripts/"
        chmod +x "$output/scripts/$script"
      fi
    done
    # Config presets
    if [ -d "scripts/presets" ]; then
      mkdir -p "$output/scripts/presets"
      cp scripts/presets/*.json "$output/scripts/presets/" 2>/dev/null || true
    fi
    # CShip config
    [ -f "scripts/cship.toml" ] && cp "scripts/cship.toml" "$output/scripts/"
  fi

  # VERSION file
  cp VERSION "$output/VERSION"

  # Plugin settings
  if [ -f "settings.json" ]; then
    cp settings.json "$output/settings.json"
  fi

  # Generate domain-specific atlas-assist SKILL.md
  mkdir -p "$output/skills/atlas-assist"
  ./scripts/generate-master-skill.sh "domain-${name}" "$output/skills/atlas-assist/SKILL.md"

  # Generate plugin.json (domain name = atlas-{name}, not atlas-domain-{name})
  local build_ts
  build_ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  cat > "$output/.claude-plugin/plugin.json" <<EOF
{
  "name": "atlas-${name}",
  "version": "${VERSION}",
  "description": "${desc}",
  "author": { "name": "AXOIQ", "email": "dev@axoiq.com" },
  "license": "UNLICENSED",
  "buildTimestamp": "${build_ts}"
}
EOF

  # Generate marketplace.json
  cat > "$output/.claude-plugin/marketplace.json" <<EOF
{
  "name": "atlas-${name}-marketplace",
  "owner": { "name": "AXOIQ", "email": "dev@axoiq.com" },
  "plugins": [
    {
      "name": "atlas-${name}",
      "description": "${desc}",
      "version": "${VERSION}",
      "source": { "source": "url", "url": "https://forgejo.axoiq.com/atlas/atlas-plugin.git" },
      "author": { "name": "AXOIQ", "email": "dev@axoiq.com" }
    }
  ]
}
EOF

  # Count results
  local skill_count
  skill_count=$(find "$output/skills" -maxdepth 2 -name "SKILL.md" | wc -l)
  local agent_count
  agent_count=$(find "$output/agents" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)

  echo "✅ Built atlas-${name} (domain) v${VERSION} → ${output}/"
  echo "   ${skill_count} skills | ${agent_count} agents"
}

# Main
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ATLAS Plugin Builder v${VERSION}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$TIERS" = "all" ]; then
  for t in admin dev user worker; do
    build_tier "$t"
    echo ""
  done
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  All 4 tiers built successfully!"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
elif [ "$TIERS" = "domains" ]; then
  for d in "${DOMAIN_NAMES[@]}"; do
    build_domain "$d"
    echo ""
  done
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  All ${#DOMAIN_NAMES[@]} domain plugins built successfully!"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
elif [ "$TIERS" = "domain" ]; then
  DOMAIN_NAME="${2:-}"
  if [ -z "$DOMAIN_NAME" ]; then
    echo "❌ Usage: ./build.sh domain <name>"
    echo "   Available: ${DOMAIN_NAMES[*]}"
    exit 1
  fi
  build_domain "$DOMAIN_NAME"
else
  build_tier "$TIERS"
fi
