#!/usr/bin/env bash
# ATLAS Marketplace Migration — mono-plugin to multi-domain
# Usage: ./migrate-marketplace.sh [--dry-run] [--preset admin|dev|infra]
#
# Migrates from atlas-admin-marketplace (single monolithic plugin) to
# atlas-marketplace (6 domain plugins, user-selectable via presets).
#
# Presets:
#   admin  — all 6 domains (full install)
#   dev    — core + dev (default, lightweight)
#   infra  — core + infra
set -euo pipefail

# ── Constants ───────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
VERSION=$(cat "$PLUGIN_ROOT/VERSION" | tr -d '[:space:]')

OLD_MARKETPLACE="atlas-admin-marketplace"
NEW_MARKETPLACE="atlas-marketplace"
OLD_CACHE="$HOME/.claude/plugins/cache/$OLD_MARKETPLACE"
NEW_CACHE="$HOME/.claude/plugins/cache/$NEW_MARKETPLACE"
SETTINGS="$HOME/.claude/settings.json"

DRY_RUN=false
PRESET="dev"

# ── Colors ──────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ── Helpers ─────────────────────────────────────────────────────────
info()  { echo -e "${CYAN}ℹ${NC}  $*"; }
ok()    { echo -e "${GREEN}✅${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠️${NC}  $*"; }
err()   { echo -e "${RED}❌${NC} $*"; }
dry()   { echo -e "${DIM}[dry-run]${NC} $*"; }
header() {
  echo ""
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}  $*${NC}"
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ── Parse args ──────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run) DRY_RUN=true; shift ;;
    --preset)
      if [[ -z "${2:-}" ]]; then
        err "Missing value for --preset"; exit 1
      fi
      PRESET="$2"; shift 2
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--dry-run] [--preset admin|dev|infra]"
      echo ""
      echo "Options:"
      echo "  --dry-run          Show what would happen, don't modify anything"
      echo "  --preset <name>    Choose domain set (admin=all, dev=core+dev, infra=core+infra)"
      echo "  -h, --help         Show this help"
      exit 0
      ;;
    *) err "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Resolve preset → domain list ────────────────────────────────────
case "$PRESET" in
  admin) DOMAINS=(core dev frontend infra enterprise experiential) ;;
  dev)   DOMAINS=(core dev) ;;
  infra) DOMAINS=(core infra) ;;
  *)
    err "Unknown preset: $PRESET"
    echo "  Available presets: admin (all 6), dev (core+dev), infra (core+infra)"
    exit 1
    ;;
esac

# ── Banner ──────────────────────────────────────────────────────────
header "ATLAS Marketplace Migration v${VERSION}"
echo ""
echo -e "  Preset:    ${BOLD}${PRESET}${NC}"
echo -e "  Domains:   ${CYAN}${DOMAINS[*]}${NC}"
echo -e "  Dry-run:   ${DRY_RUN}"
echo -e "  Old cache: ${DIM}${OLD_CACHE}${NC}"
echo -e "  New cache: ${DIM}${NEW_CACHE}${NC}"

# ══════════════════════════════════════════════════════════════════════
# Step 1: Detection — check current state
# ══════════════════════════════════════════════════════════════════════
header "Step 1/6: Detection"

OLD_EXISTS=false
OLD_VERSIONS=()
if [ -d "$OLD_CACHE" ]; then
  OLD_EXISTS=true
  # List installed tiers and their versions
  for tier_dir in "$OLD_CACHE"/*/; do
    tier_name=$(basename "$tier_dir")
    for ver_dir in "$tier_dir"*/; do
      if [ -d "$ver_dir" ]; then
        ver=$(basename "$ver_dir")
        OLD_VERSIONS+=("${tier_name}@${ver}")
      fi
    done
  done
  ok "Old marketplace found: ${OLD_MARKETPLACE}"
  for v in "${OLD_VERSIONS[@]}"; do
    echo -e "     ${DIM}├─ ${v}${NC}"
  done
else
  info "No old marketplace found (fresh install)"
fi

NEW_EXISTS=false
if [ -d "$NEW_CACHE" ]; then
  NEW_EXISTS=true
  warn "New marketplace already exists at: ${NEW_CACHE}"
  for domain_dir in "$NEW_CACHE"/*/; do
    if [ -d "$domain_dir" ]; then
      echo -e "     ${DIM}├─ $(basename "$domain_dir")${NC}"
    fi
  done
fi

# ══════════════════════════════════════════════════════════════════════
# Step 2: Build domain plugins
# ══════════════════════════════════════════════════════════════════════
header "Step 2/6: Build"

if $DRY_RUN; then
  dry "Would run: cd $PLUGIN_ROOT && ./build.sh domains"
else
  info "Building all domain plugins..."
  if ! (cd "$PLUGIN_ROOT" && ./build.sh domains); then
    err "Build failed! Aborting migration."
    echo "  Fix build errors in $PLUGIN_ROOT and retry."
    exit 1
  fi
  ok "Build completed"
fi

# Verify dist outputs exist for requested domains
MISSING_DIST=()
for domain in "${DOMAINS[@]}"; do
  dist_dir="$PLUGIN_ROOT/dist/atlas-${domain}"
  if ! $DRY_RUN && [ ! -d "$dist_dir" ]; then
    MISSING_DIST+=("$domain")
  fi
done

if [ ${#MISSING_DIST[@]} -gt 0 ]; then
  err "Missing dist outputs: ${MISSING_DIST[*]}"
  exit 1
fi

# ══════════════════════════════════════════════════════════════════════
# Step 3: Install to new cache
# ══════════════════════════════════════════════════════════════════════
header "Step 3/6: Install"

# If new cache exists, ask about overwrite
if $NEW_EXISTS && ! $DRY_RUN; then
  echo ""
  warn "New marketplace cache already exists."
  read -r -p "  Overwrite existing domain plugins? [y/N] " overwrite
  if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
    info "Keeping existing cache. Only new domains will be added."
  fi
fi

INSTALLED_DOMAINS=()
TOTAL_SKILLS=0
TOTAL_AGENTS=0

for domain in "${DOMAINS[@]}"; do
  src="$PLUGIN_ROOT/dist/atlas-${domain}"
  dest="$NEW_CACHE/atlas-${domain}/${VERSION}"

  if $DRY_RUN; then
    dry "Would install: atlas-${domain} v${VERSION}"
    dry "  ${src}/ → ${dest}/"
    INSTALLED_DOMAINS+=("$domain")
    continue
  fi

  # Check if this specific version already installed
  if [ -d "$dest" ]; then
    if [[ "${overwrite:-n}" =~ ^[Yy]$ ]]; then
      rm -rf "$dest"
    else
      info "atlas-${domain}@${VERSION} already installed, skipping"
      INSTALLED_DOMAINS+=("$domain")
      continue
    fi
  fi

  mkdir -p "$dest"
  cp -r "$src"/* "$dest"/

  # Rewrite marketplace.json to use unified marketplace name
  python3 -c "
import json, os
mp = os.path.join('$dest', '.claude-plugin', 'marketplace.json')
if os.path.exists(mp):
    with open(mp) as f:
        data = json.load(f)
    data['name'] = '$NEW_MARKETPLACE'
    with open(mp, 'w') as f:
        json.dump(data, f, indent=2)
        f.write('\n')
"

  # Count skills and agents
  skill_count=$(find "$dest/skills" -maxdepth 2 -name "SKILL.md" 2>/dev/null | wc -l)
  agent_count=$(find "$dest/agents" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
  TOTAL_SKILLS=$((TOTAL_SKILLS + skill_count))
  TOTAL_AGENTS=$((TOTAL_AGENTS + agent_count))

  ok "Installed atlas-${domain} v${VERSION} (${skill_count} skills, ${agent_count} agents)"
  INSTALLED_DOMAINS+=("$domain")
done

# ══════════════════════════════════════════════════════════════════════
# Step 4: Update settings.json
# ══════════════════════════════════════════════════════════════════════
header "Step 4/6: Settings"

if $DRY_RUN; then
  dry "Would update ${SETTINGS}:"
  for domain in "${INSTALLED_DOMAINS[@]}"; do
    dry "  enabledPlugins[\"atlas-${domain}@${NEW_MARKETPLACE}\"] = true"
  done
  if $OLD_EXISTS; then
    dry "Would disable old plugin entries (atlas-*@${OLD_MARKETPLACE})"
  fi
else
  # Build the domain list as JSON for python
  DOMAIN_JSON="["
  for i in "${!INSTALLED_DOMAINS[@]}"; do
    [[ $i -gt 0 ]] && DOMAIN_JSON+=","
    DOMAIN_JSON+="\"${INSTALLED_DOMAINS[$i]}\""
  done
  DOMAIN_JSON+="]"

  python3 -c "
import json, os, sys

settings_path = '$SETTINGS'
new_marketplace = '$NEW_MARKETPLACE'
old_marketplace = '$OLD_MARKETPLACE'
domains = $DOMAIN_JSON

# Load or create settings
if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)
else:
    settings = {}
    print('  Created new settings.json')

# Ensure enabledPlugins exists
if 'enabledPlugins' not in settings:
    settings['enabledPlugins'] = {}

ep = settings['enabledPlugins']

# Add new domain plugin entries
for domain in domains:
    key = f'atlas-{domain}@{new_marketplace}'
    ep[key] = True

# Disable old marketplace entries (don't delete — user can clean up later)
old_keys = [k for k in ep if k.endswith(f'@{old_marketplace}')]
for k in old_keys:
    ep[k] = False

# Write back (preserving all other settings)
with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

# Report
for domain in domains:
    print(f'  + atlas-{domain}@{new_marketplace} = true')
for k in old_keys:
    print(f'  - {k} = false (disabled)')
"
  ok "Settings updated"
fi

# ══════════════════════════════════════════════════════════════════════
# Step 5: Verify
# ══════════════════════════════════════════════════════════════════════
header "Step 5/6: Verify"

if $DRY_RUN; then
  dry "Would verify SKILL.md files in ${NEW_CACHE}/"
else
  VERIFY_OK=true
  for domain in "${INSTALLED_DOMAINS[@]}"; do
    dest="$NEW_CACHE/atlas-${domain}/${VERSION}"

    if [ ! -d "$dest" ]; then
      err "Missing: atlas-${domain} at ${dest}"
      VERIFY_OK=false
      continue
    fi

    # Check plugin.json
    if [ ! -f "$dest/.claude-plugin/plugin.json" ]; then
      err "Missing plugin.json for atlas-${domain}"
      VERIFY_OK=false
    fi

    # List skills
    skill_files=$(find "$dest/skills" -maxdepth 2 -name "SKILL.md" 2>/dev/null | sort)
    skill_count=$(echo "$skill_files" | grep -c "SKILL.md" || true)

    if [ "$skill_count" -eq 0 ]; then
      warn "atlas-${domain}: no skills found"
    else
      ok "atlas-${domain}: ${skill_count} skills"
      echo "$skill_files" | while read -r sf; do
        skill_name=$(basename "$(dirname "$sf")")
        echo -e "     ${DIM}├─ ${skill_name}${NC}"
      done
    fi
  done

  if $VERIFY_OK; then
    ok "All domain plugins verified"
  else
    err "Verification found issues — check output above"
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# Step 6: Old marketplace cleanup (optional, interactive)
# ══════════════════════════════════════════════════════════════════════
header "Step 6/6: Cleanup"

if $DRY_RUN; then
  if $OLD_EXISTS; then
    dry "Would ask to remove old marketplace at ${OLD_CACHE}"
  else
    dry "No old marketplace to clean up"
  fi
elif $OLD_EXISTS; then
  echo ""
  info "Old marketplace still present at:"
  echo -e "  ${DIM}${OLD_CACHE}${NC}"
  du -sh "$OLD_CACHE" 2>/dev/null | awk '{print "  Size: "$1}'
  echo ""
  read -r -p "  Remove old atlas-admin-marketplace? [y/N] " cleanup
  if [[ "$cleanup" =~ ^[Yy]$ ]]; then
    rm -rf "$OLD_CACHE"
    ok "Old marketplace removed"
  else
    info "Old marketplace preserved (you can remove it later)"
    echo -e "  ${DIM}rm -rf ${OLD_CACHE}${NC}"
  fi
else
  info "No old marketplace to clean up"
fi

# ══════════════════════════════════════════════════════════════════════
# Summary
# ══════════════════════════════════════════════════════════════════════
header "Migration Summary"
echo ""

if $DRY_RUN; then
  echo -e "  ${YELLOW}DRY RUN — no changes were made${NC}"
  echo ""
fi

echo -e "  ${BOLD}Preset:${NC}     ${PRESET}"
echo -e "  ${BOLD}Version:${NC}    ${VERSION}"
echo -e "  ${BOLD}Installed:${NC}  ${INSTALLED_DOMAINS[*]}"

if ! $DRY_RUN; then
  echo -e "  ${BOLD}Skills:${NC}     ${TOTAL_SKILLS}"
  echo -e "  ${BOLD}Agents:${NC}    ${TOTAL_AGENTS}"
fi

echo -e "  ${BOLD}Cache:${NC}      ${NEW_CACHE}"
echo ""

echo -e "${BOLD}Next steps:${NC}"
echo "  1. Restart Claude Code to pick up new plugins"
echo "  2. Run /atlas doctor to verify plugin health"
echo "  3. Check skills are available: /skills or ask Claude to list skills"
echo ""

if $DRY_RUN; then
  echo -e "  Re-run without ${BOLD}--dry-run${NC} to apply changes."
fi

echo -e "${GREEN}Done.${NC}"
