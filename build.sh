#!/usr/bin/env bash
# Build 3 tier plugins from atlas-core
# Usage: ./build.sh [admin|dev|user|all]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VERSION=$(cat VERSION | tr -d '[:space:]')
TIERS="${1:-all}"

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
    echo -e "${items}\n${tier_items}" | sort -u
  elif [ -n "$items" ]; then
    echo "$items"
  else
    echo "$tier_items"
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
  mkdir -p "$output"/{.claude-plugin,commands,skills,agents,hooks}

  # Resolve inherited skills
  local skills
  skills=$(resolve_field "$tier" "skills")

  for skill in $skills; do
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

  # Resolve inherited commands
  local commands
  commands=$(resolve_field "$tier" "commands")

  for cmd in $commands; do
    if [ -f "commands/${cmd}.md" ]; then
      cp "commands/${cmd}.md" "$output/commands/"
    else
      echo "  ⚠️  Command not found: ${cmd}.md (skipped)"
    fi
  done

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

  # Copy hooks (all tiers get all hooks)
  cp hooks/hooks.json "$output/hooks/"
  for hook in session-start session-end-memory-cleanup post-compact permission-request; do
    cp "hooks/$hook" "$output/hooks/" 2>/dev/null || true
  done

  # Copy VERSION file
  cp VERSION "$output/VERSION"

  # Generate tier-specific using-atlas SKILL.md
  mkdir -p "$output/skills/using-atlas"
  ./scripts/generate-master-skill.sh "$tier" "$output/skills/using-atlas/SKILL.md"

  # Generate tier-specific plugin.json
  local tier_upper
  tier_upper=$(echo "${tier}" | sed 's/./\U&/')
  cat > "$output/.claude-plugin/plugin.json" <<EOF
{
  "name": "atlas-${tier}",
  "version": "${VERSION}",
  "description": "ATLAS ${tier_upper} — AXOIQ AI Engineering Assistant (${tier} tier)",
  "author": { "name": "AXOIQ", "email": "dev@axoiq.com" },
  "license": "UNLICENSED"
}
EOF

  # Generate marketplace.json
  cat > "$output/.claude-plugin/marketplace.json" <<EOF
{
  "source": "./",
  "url": "https://forgejo.axoiq.com/atlas/atlas-plugin.git",
  "tier": "${tier}"
}
EOF

  # Count results
  local skill_count
  skill_count=$(find "$output/skills" -maxdepth 2 -name "SKILL.md" | wc -l)
  local cmd_count
  cmd_count=$(find "$output/commands" -name "*.md" | wc -l)
  local agent_count
  agent_count=$(find "$output/agents" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)

  echo "✅ Built atlas-${tier} v${VERSION} → ${output}/"
  echo "   ${skill_count} skills | ${cmd_count} commands | ${agent_count} agents"
}

# Main
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ATLAS Plugin Builder v${VERSION}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$TIERS" = "all" ]; then
  for t in admin dev user; do
    build_tier "$t"
    echo ""
  done
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  All 3 tiers built successfully!"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
  build_tier "$TIERS"
fi
