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
CMD_METADATA_FILE="commands/_metadata.yaml"

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

# Return skills listed in a domain profile (reads profile YAML directly)
# Domain plugins are functional bundles — they bundle ALL skills in their profile,
# regardless of tier ownership in _metadata.yaml.
# SP-DEDUP Phase 2: domains bundle by profile, tiers bundle by ownership.
get_domain_profile_skills() {
  local domain="$1"
  local profile="profiles/domain-${domain}.yaml"
  if [ -f "$profile" ]; then
    yq -r '.skills // [] | .[]' "$profile" 2>/dev/null | grep -v '^atlas-assist$' || true
  fi
}

# Return commands OWNED by a given owner (from commands/_metadata.yaml)
get_owned_commands() {
  local owner="$1"
  if [ -f "$CMD_METADATA_FILE" ]; then
    yq -r ".commands | to_entries[] | select(.value.owner == \"$owner\") | .key" "$CMD_METADATA_FILE" 2>/dev/null || true
  fi
}

# Return commands listed in a domain profile
get_domain_profile_commands() {
  local domain="$1"
  local profile="profiles/domain-${domain}.yaml"
  if [ -f "$profile" ]; then
    yq -r '.commands // [] | .[]' "$profile" 2>/dev/null || true
  fi
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
  mkdir -p "$output"/{.claude-plugin,skills,agents,hooks,commands}

  # v5.1+: Copy capability discovery manifest (declarative metadata for scanner)
  # Source: manifests/atlas-{tier}.yaml → dist/atlas-{tier}/_addon-manifest.yaml
  if [ -f "manifests/atlas-${tier}.yaml" ]; then
    cp "manifests/atlas-${tier}.yaml" "$output/_addon-manifest.yaml"
  fi

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

  # Copy owned commands (delta, like skills)
  local owned_cmds
  owned_cmds=$(get_owned_commands "$owner")

  for cmd in $owned_cmds; do
    if [ -f "commands/$cmd.md" ]; then
      cp "commands/$cmd.md" "$output/commands/"
    else
      echo "  ⚠️  Command not found: $cmd (skipped)"
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

  # Copy hooks — SP-HOOK-DEDUP: use delta hooks for child tiers
  # Base tier (user) gets full resolved hooks. Child tiers (dev, admin)
  # get ONLY hooks declared in their OWN profile, not inherited ones.
  # This prevents SessionStart duplication when multiple tiers are installed.
  local hooks
  local parent
  parent=$(yq -r '.inherits // ""' "$profile")
  if [ -z "$parent" ]; then
    # Base tier (user, worker) — gets full resolved hooks
    hooks=$(resolve_field "$tier" "hooks")
  else
    # Child tier (dev, admin) — delta only (own hooks, not parent's)
    hooks=$(yq -r '.hooks // [] | .[]' "$profile" 2>/dev/null || true)
  fi

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
  # v5.1+: atlas-discover-addons.sh added (capability scanner for adaptive master)
  local runtime_scripts=(parse-features.sh atlas-alert-module.sh atlas-context-size-module.sh atlas-agents-module.sh atlas-effort-module.sh atlas-cost-usd-module.sh atlas-200k-badge-module.sh atlas-agent-tail.sh atlas-jsonl-format.sh detect-platform.sh detect-network.sh shell-aliases.sh setup-terminal.sh get-secret.sh bw-login.sh atlas-keyring.sh atlas-e2e-validate.sh require-secrets.sh statusline-command.sh atlas-cli.sh setup-wizard.sh load-secrets.sh fix-cc-settings.sh mega-status-manager.sh atlas-discover-addons.sh atlas-resolve-version.sh)
  mkdir -p "$output/scripts"
  for script in "${runtime_scripts[@]}"; do
    if [ -f "scripts/$script" ]; then
      cp "scripts/$script" "$output/scripts/"
      chmod +x "$output/scripts/$script"
    fi
  done

  # v5.5+: Copy scripts/lib/ (SP-AGENT-VIS Layer 3 helpers: detect-visibility-env.sh, show-hint.sh)
  if [ -d "scripts/lib" ]; then
    cp -r "scripts/lib" "$output/scripts/"
    find "$output/scripts/lib" -name "*.sh" -exec chmod +x {} \;
  fi

  # Inject VERSION into atlas-cli.sh (fix version drift)
  if [ -f "$output/scripts/atlas-cli.sh" ]; then
    sed -i "s/^ATLAS_VERSION=.*/ATLAS_VERSION=\"${VERSION}\"/" "$output/scripts/atlas-cli.sh"
  fi

  # Copy atlas-modules/ (modularized CLI)
  if [ -d "scripts/atlas-modules" ]; then
    mkdir -p "$output/scripts/atlas-modules"
    cp scripts/atlas-modules/*.sh "$output/scripts/atlas-modules/"
    chmod +x "$output/scripts/atlas-modules/"*.sh
  fi

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

  # v5.1+: atlas-assist is UNIFIED (single master in atlas-core).
  # Source of truth: scripts/atlas-assist-master.md (hand-crafted, adaptive).
  # The master reads ~/.atlas/runtime/capabilities.json at runtime to adapt
  # persona/pipeline based on installed addons. dev/admin addons NO LONGER
  # ship their own atlas-assist (avoids namespace conflicts + duplication).
  if [ "$tier" = "core" ]; then
    mkdir -p "$output/skills/atlas-assist"
    cp scripts/atlas-assist-master.md "$output/skills/atlas-assist/SKILL.md"
  fi

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
      "source": { "source": "url", "url": "https://github.com/seb155/atlas-plugin.git" },
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
  local cmd_count
  cmd_count=$(find "$output/commands" -name "*.md" 2>/dev/null | wc -l)

  echo "✅ Built atlas-${tier} v${VERSION} → ${output}/"
  echo "   ${skill_count} skills | ${agent_count} agents | ${cmd_count} commands"
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
  mkdir -p "$output"/{.claude-plugin,skills,agents,hooks,commands}

  # SP-DEDUP Phase 2: Domain plugins are functional bundles — copy ALL skills
  # from domain profile. Domains group by function, not by tier ownership.
  local domain_skills
  domain_skills=$(get_domain_profile_skills "$name")

  for skill in $domain_skills; do
    if [ -d "skills/$skill" ]; then
      cp -r "skills/$skill" "$output/skills/"
    else
      echo "  ⚠️  Skill not found: $skill (skipped)"
    fi
  done

  # Copy domain commands from profile
  local domain_cmds
  domain_cmds=$(get_domain_profile_commands "$name")

  for cmd in $domain_cmds; do
    if [ -f "commands/$cmd.md" ]; then
      cp "commands/$cmd.md" "$output/commands/"
    else
      echo "  ⚠️  Command not found: $cmd (skipped)"
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
    local runtime_scripts=(parse-features.sh atlas-alert-module.sh atlas-context-size-module.sh atlas-agents-module.sh atlas-effort-module.sh atlas-cost-usd-module.sh atlas-200k-badge-module.sh atlas-agent-tail.sh atlas-jsonl-format.sh detect-platform.sh detect-network.sh shell-aliases.sh setup-terminal.sh get-secret.sh bw-login.sh atlas-keyring.sh atlas-e2e-validate.sh require-secrets.sh statusline-command.sh atlas-cli.sh setup-wizard.sh load-secrets.sh fix-cc-settings.sh mega-status-manager.sh)
    mkdir -p "$output/scripts"
    for script in "${runtime_scripts[@]}"; do
      if [ -f "scripts/$script" ]; then
        cp "scripts/$script" "$output/scripts/"
        chmod +x "$output/scripts/$script"
      fi
    done
    # Copy atlas-modules/ (modularized CLI)
    if [ -d "scripts/atlas-modules" ]; then
      mkdir -p "$output/scripts/atlas-modules"
      cp scripts/atlas-modules/*.sh "$output/scripts/atlas-modules/"
      chmod +x "$output/scripts/atlas-modules/"*.sh
    fi
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
      "source": { "source": "url", "url": "https://github.com/seb155/atlas-plugin.git" },
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

  local cmd_count
  cmd_count=$(find "$output/commands" -name "*.md" 2>/dev/null | wc -l)

  echo "✅ Built atlas-${name} (domain) v${VERSION} → ${output}/"
  echo "   ${skill_count} skills | ${agent_count} agents | ${cmd_count} commands"
}

# ── Modular Plugin build (core + addons, zero duplication) ─────────
# This is the v5+ default architecture. Each plugin is self-contained.
# Reads skills directly from profile YAML (like domain builds).
# Profile path: profiles/{name}.yaml or profiles/{name}-addon.yaml
MODULAR_PLUGINS=(core dev-addon admin-addon)
# Backward-compat alias (deprecated; use MODULAR_PLUGINS)
V5_PLUGINS=("${MODULAR_PLUGINS[@]}")

build_modular_plugin() {
  local name="$1"
  local profile=""
  local output_name=""

  # Resolve profile path and output name
  if [ -f "profiles/${name}.yaml" ]; then
    profile="profiles/${name}.yaml"
    output_name="$name"
  elif [ -f "profiles/${name}-addon.yaml" ]; then
    profile="profiles/${name}-addon.yaml"
    output_name="${name%-addon}"  # dev-addon → dev
  else
    echo "❌ modular profile not found for: $name"
    exit 1
  fi

  local output="dist/atlas-${output_name}"
  local desc
  desc=$(yq -r '.description // "ATLAS modular plugin"' "$profile")

  echo "🔨 Building atlas-${output_name} (modular) v${VERSION}..."

  rm -rf "$output"
  mkdir -p "$output"/{.claude-plugin,skills,agents,hooks,commands}

  # v5.1+: Copy capability discovery manifest (declarative metadata for scanner)
  # Source: manifests/atlas-{name}.yaml → dist/atlas-{output_name}/_addon-manifest.yaml
  if [ -f "manifests/atlas-${name}.yaml" ]; then
    cp "manifests/atlas-${name}.yaml" "$output/_addon-manifest.yaml"
  fi

  # Skills: read directly from profile YAML
  local skills
  skills=$(yq -r '.skills // [] | .[]' "$profile" 2>/dev/null || true)

  for skill in $skills; do
    if [ -d "skills/$skill" ]; then
      cp -r "skills/$skill" "$output/skills/"
    else
      echo "  ⚠️  Skill not found: $skill (skipped)"
    fi
  done

  # Refs
  local refs
  refs=$(yq -r '.refs // [] | .[]' "$profile" 2>/dev/null || true)
  if [ -n "$refs" ]; then
    mkdir -p "$output/skills/refs"
    for ref in $refs; do
      [ -d "skills/refs/$ref" ] && cp -r "skills/refs/$ref" "$output/skills/refs/"
    done
  fi

  # Agents
  local agents
  agents=$(yq -r '.agents // [] | .[]' "$profile" 2>/dev/null || true)
  for agent in $agents; do
    [ -d "agents/$agent" ] && cp -r "agents/$agent" "$output/agents/"
  done

  # Hooks
  local hooks
  hooks=$(yq -r '.hooks // [] | .[]' "$profile" 2>/dev/null || true)
  if [ -z "$hooks" ]; then
    echo '{"hooks":{}}' > "$output/hooks/hooks.json"
  else
    # shellcheck disable=SC2086
    python3 scripts/filter-hooks-json.py hooks/hooks.json $hooks > "$output/hooks/hooks.json"
    for hook_name in $hooks; do
      if [ -d "hooks/$hook_name" ]; then
        cp -r "hooks/$hook_name" "$output/hooks/"
      elif [ -x "hooks/$hook_name" ]; then
        cp "hooks/$hook_name" "$output/hooks/"
      fi
    done
    [ -d "hooks/lib" ] && mkdir -p "$output/hooks/lib" && cp hooks/lib/*.sh "$output/hooks/lib/" 2>/dev/null || true
    [ -x "hooks/run-hook.sh" ] && cp "hooks/run-hook.sh" "$output/hooks/"
    [ -d "hooks/ts" ] && cp -r "hooks/ts" "$output/hooks/"
  fi

  # Runtime scripts: core plugin gets scripts/, addons don't
  # v5.1+: atlas-discover-addons.sh (capability scanner) + atlas-resolve-version.sh (statusline)
  if [ "$output_name" = "core" ]; then
    local runtime_scripts=(parse-features.sh atlas-alert-module.sh atlas-context-size-module.sh atlas-agents-module.sh atlas-effort-module.sh atlas-cost-usd-module.sh atlas-200k-badge-module.sh atlas-agent-tail.sh atlas-jsonl-format.sh detect-platform.sh detect-network.sh shell-aliases.sh setup-terminal.sh get-secret.sh bw-login.sh atlas-keyring.sh atlas-e2e-validate.sh require-secrets.sh statusline-command.sh atlas-cli.sh setup-wizard.sh load-secrets.sh fix-cc-settings.sh mega-status-manager.sh atlas-discover-addons.sh atlas-resolve-version.sh)
    mkdir -p "$output/scripts"
    for script in "${runtime_scripts[@]}"; do
      [ -f "scripts/$script" ] && cp "scripts/$script" "$output/scripts/" && chmod +x "$output/scripts/$script"
    done
    [ -d "scripts/atlas-modules" ] && mkdir -p "$output/scripts/atlas-modules" && cp scripts/atlas-modules/*.sh "$output/scripts/atlas-modules/" && chmod +x "$output/scripts/atlas-modules/"*.sh
    [ -d "scripts/presets" ] && mkdir -p "$output/scripts/presets" && cp scripts/presets/*.json "$output/scripts/presets/" 2>/dev/null || true
    [ -d "scripts/lib" ] && mkdir -p "$output/scripts/lib" && cp scripts/lib/*.sh "$output/scripts/lib/" && chmod +x "$output/scripts/lib/"*.sh   # v5.5+ SP-AGENT-VIS Layer 3 helpers
    [ -f "scripts/cship.toml" ] && cp "scripts/cship.toml" "$output/scripts/"
    [ -f "$output/scripts/atlas-cli.sh" ] && sed -i "s/^ATLAS_VERSION=.*/ATLAS_VERSION=\"${VERSION}\"/" "$output/scripts/atlas-cli.sh"
  fi

  # VERSION + settings
  cp VERSION "$output/VERSION"
  [ -f "settings.json" ] && cp settings.json "$output/settings.json"

  # v5.1+: atlas-assist is UNIFIED in atlas-core (see scripts/atlas-assist-master.md).
  # Only the core plugin ships the master skill; addons rely on it via discovery.
  local tier_label
  tier_label=$(yq -r '.tier // "core"' "$profile")
  if [ "$tier_label" = "core" ]; then
    mkdir -p "$output/skills/atlas-assist"
    cp scripts/atlas-assist-master.md "$output/skills/atlas-assist/SKILL.md"
  fi

  # v5.1+: Copy commands owned by this plugin (commands/_metadata.yaml owner field)
  # Reads owner from metadata; only copies commands matching this plugin's name.
  if [ -f "commands/_metadata.yaml" ]; then
    local owned_cmds
    owned_cmds=$(yq -r ".commands | to_entries[] | select(.value.owner == \"${output_name}\") | .key" commands/_metadata.yaml 2>/dev/null || true)
    for cmd in $owned_cmds; do
      if [ -f "commands/${cmd}.md" ]; then
        cp "commands/${cmd}.md" "$output/commands/"
      fi
    done
  fi

  # plugin.json
  local build_ts
  build_ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  cat > "$output/.claude-plugin/plugin.json" <<EOF
{
  "name": "atlas-${output_name}",
  "version": "${VERSION}",
  "description": "${desc}",
  "author": { "name": "AXOIQ", "email": "dev@axoiq.com" },
  "license": "UNLICENSED",
  "buildTimestamp": "${build_ts}"
}
EOF

  # marketplace.json — single marketplace for modular plugins
  cat > "$output/.claude-plugin/marketplace.json" <<EOF
{
  "name": "atlas-marketplace",
  "owner": { "name": "AXOIQ", "email": "dev@axoiq.com" },
  "plugins": [
    {
      "name": "atlas-${output_name}",
      "description": "${desc}",
      "version": "${VERSION}",
      "source": { "source": "git", "url": "https://plugins.axoiq.com" },
      "author": { "name": "AXOIQ", "email": "dev@axoiq.com" }
    }
  ]
}
EOF

  local skill_count agent_count
  skill_count=$(find "$output/skills" -maxdepth 2 -name "SKILL.md" | wc -l)
  agent_count=$(find "$output/agents" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)

  echo "✅ Built atlas-${output_name} (modular) v${VERSION} → ${output}/"
  echo "   ${skill_count} skills | ${agent_count} agents"
}

# Main
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ATLAS Plugin Builder v${VERSION}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 2026-04-19: "all" aliased to "modular" (v5+ SP-DEDUP architecture).
# Legacy tiers (admin/dev/user → profiles/admin.yaml etc) superseded by
# modular plugins (admin-addon/dev-addon/core). "build.sh all" now identical to "modular".
if [ "$TIERS" = "all" ]; then
  TIERS="modular"
fi

if [ "$TIERS" = "domains" ]; then
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
elif [ "$TIERS" = "modular" ] || [ "$TIERS" = "v5" ]; then
  # 'modular' = canonical name (v5+ architecture). 'v5' kept as alias for backward-compat.
  for p in "${V5_PLUGINS[@]}"; do
    build_modular_plugin "$p"
    echo ""
  done
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  All modular plugins built successfully!"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
elif [ "$TIERS" = "modular-core" ] || [ "$TIERS" = "v5-core" ]; then
  build_modular_plugin "core"
elif [ "$TIERS" = "modular-dev" ] || [ "$TIERS" = "v5-dev" ]; then
  build_modular_plugin "dev-addon"
elif [ "$TIERS" = "modular-admin" ] || [ "$TIERS" = "v5-admin" ]; then
  build_modular_plugin "admin-addon"
else
  build_tier "$TIERS"
fi
