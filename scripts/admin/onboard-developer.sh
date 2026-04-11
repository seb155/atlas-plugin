#!/usr/bin/env bash
# onboard-developer.sh — Add a new developer to all shared ATLAS repos
#
# Usage:
#   Internal dev:  ./onboard-developer.sh <github-user> <forgejo-user> <email>
#   External collab: ./onboard-developer.sh <forgejo-user> <email> --external --tier admin --fork --require-nda --nda-confirmed
#   Forgejo-only:  ./onboard-developer.sh <forgejo-user> <email> --forgejo-only --tier dev
#
# Requires: FORGEJO_TOKEN env var set. gh CLI only needed without --forgejo-only.
#
# Flags:
#   --tier admin|dev|user   Access level (admin=4 repos, dev=3, user=2)
#   --external              External collaborator mode (adapted message, fork instructions)
#   --fork                  Create a Forgejo fork of atlas-plugin for the user
#   --require-nda           Refuse to run without --nda-confirmed
#   --nda-confirmed         Confirm NDA has been signed (required with --require-nda)
#   --forgejo-only          Skip GitHub invitations (default for --external)
set -euo pipefail

# --- Parse arguments ---
POSITIONAL=()
TIER="dev"
EXTERNAL=false
FORK=false
REQUIRE_NDA=false
NDA_CONFIRMED=false
FORGEJO_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tier)
      TIER="$2"
      shift 2
      ;;
    --external)
      EXTERNAL=true
      FORGEJO_ONLY=true  # External implies forgejo-only
      shift
      ;;
    --fork)
      FORK=true
      shift
      ;;
    --require-nda)
      REQUIRE_NDA=true
      shift
      ;;
    --nda-confirmed)
      NDA_CONFIRMED=true
      shift
      ;;
    --forgejo-only)
      FORGEJO_ONLY=true
      shift
      ;;
    -*)
      echo "❌ Unknown flag: $1"
      exit 1
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

# --- Determine mode and validate args ---
if [ "$FORGEJO_ONLY" = true ]; then
  # Forgejo-only: 2 positional args (forgejo-user, email)
  if [ ${#POSITIONAL[@]} -lt 2 ]; then
    echo "Usage: $0 <forgejo-username> <email> [flags]"
    echo ""
    echo "Flags:"
    echo "  --tier admin|dev|user   Access level (default: dev)"
    echo "  --external              External collaborator mode"
    echo "  --fork                  Create Forgejo fork of atlas-plugin"
    echo "  --require-nda           Require --nda-confirmed to proceed"
    echo "  --nda-confirmed         Confirm NDA signed"
    echo "  --forgejo-only          Skip GitHub (default with --external)"
    exit 1
  fi
  USERNAME_GH=""
  USERNAME_FJ="${POSITIONAL[0]}"
  EMAIL="${POSITIONAL[1]}"
else
  # Standard mode: 3 positional args (github-user, forgejo-user, email)
  if [ ${#POSITIONAL[@]} -lt 3 ]; then
    echo "Usage: $0 <github-username> <forgejo-username> <email> [flags]"
    echo ""
    echo "Flags:"
    echo "  --tier admin|dev|user   Access level (default: dev)"
    echo "  --external              External collaborator mode"
    echo "  --fork                  Create Forgejo fork of atlas-plugin"
    echo "  --require-nda           Require --nda-confirmed to proceed"
    echo "  --nda-confirmed         Confirm NDA signed"
    echo "  --forgejo-only          Skip GitHub"
    exit 1
  fi
  USERNAME_GH="${POSITIONAL[0]}"
  USERNAME_FJ="${POSITIONAL[1]}"
  EMAIL="${POSITIONAL[2]}"
fi

# --- Validate tier ---
case "$TIER" in
  admin|dev|user) ;;
  *)
    echo "❌ Invalid tier: $TIER (must be admin, dev, or user)"
    exit 1
    ;;
esac

# --- NDA gate ---
if [ "$REQUIRE_NDA" = true ] && [ "$NDA_CONFIRMED" = false ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🚫 NDA REQUIRED"
  echo ""
  echo "  This collaborator requires a signed NDA before access."
  echo "  The NDA template is at: docs/legal/NDA-EXTERNAL-COLLABORATOR.md"
  echo ""
  echo "  Once the NDA is signed, re-run with --nda-confirmed:"
  echo "  $0 ${POSITIONAL[*]} --require-nda --nda-confirmed [other flags]"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 1
fi

# --- Check prerequisites ---
if [ "$FORGEJO_ONLY" = false ] && ! command -v gh &>/dev/null; then
  echo "❌ gh CLI not found. Install: https://cli.github.com"
  echo "   Or use --forgejo-only to skip GitHub."
  exit 1
fi

if [ -z "${FORGEJO_TOKEN:-}" ]; then
  echo "❌ FORGEJO_TOKEN not set. Run: source ~/.env"
  exit 1
fi

FORGEJO_URL="${FORGEJO_URL:-https://forgejo.axoiq.com}"

# --- Build repo lists based on tier ---
declare -a GITHUB_REPOS FORGEJO_REPOS

case "$TIER" in
  admin)
    GITHUB_REPOS=(
      "seb155/atlas-plugin"
      "seb155/gms-cowork-plugins"
      "seb155/genie-framework"
      "seb155/claude-deploy-scripts"
    )
    FORGEJO_REPOS=(
      "atlas-plugin"
      "gms-cowork-plugins"
      "genie-framework"
      "claude-deploy-scripts"
    )
    ;;
  dev)
    GITHUB_REPOS=(
      "seb155/atlas-plugin"
      "seb155/gms-cowork-plugins"
      "seb155/genie-framework"
    )
    FORGEJO_REPOS=(
      "atlas-plugin"
      "gms-cowork-plugins"
      "genie-framework"
    )
    ;;
  user)
    GITHUB_REPOS=(
      "seb155/atlas-plugin"
      "seb155/gms-cowork-plugins"
    )
    FORGEJO_REPOS=(
      "atlas-plugin"
      "gms-cowork-plugins"
    )
    ;;
esac

# --- Header ---
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏛️ ATLAS Developer Onboarding"
if [ "$EXTERNAL" = true ]; then
  echo "  Mode:    EXTERNAL COLLABORATOR"
fi
echo "  Tier:    ${TIER}"
if [ -n "$USERNAME_GH" ]; then
  echo "  GitHub:  ${USERNAME_GH}"
fi
echo "  Forgejo: ${USERNAME_FJ}"
echo "  Email:   ${EMAIL}"
if [ "$FORK" = true ]; then
  echo "  Fork:    yes (charles/atlas-plugin)"
fi
if [ "$REQUIRE_NDA" = true ]; then
  echo "  NDA:     ✅ confirmed"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# --- GitHub: Invite collaborator (if not forgejo-only) ---
if [ "$FORGEJO_ONLY" = false ] && [ -n "$USERNAME_GH" ]; then
  echo ""
  echo "📦 GitHub — Adding collaborator..."

  for repo in "${GITHUB_REPOS[@]}"; do
    if gh api "repos/${repo}/collaborators/${USERNAME_GH}" -X PUT -f permission=push --silent 2>/dev/null; then
      echo "  ✅ ${repo} — invited"
    else
      echo "  ⚠️  ${repo} — failed (check repo exists and gh is authenticated)"
    fi
  done
else
  echo ""
  echo "📦 GitHub — Skipped (forgejo-only mode)"
fi

# --- Forgejo: Add to org + repos ---
echo ""
echo "🔧 Forgejo — Adding to org axoiq..."

# Add to org
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
  -H "Authorization: token ${FORGEJO_TOKEN}" \
  -H "Content-Type: application/json" \
  "${FORGEJO_URL}/api/v1/orgs/axoiq/members/${USERNAME_FJ}" \
  -d '{"role":"member"}')

if [ "$HTTP_CODE" = "204" ] || [ "$HTTP_CODE" = "200" ]; then
  echo "  ✅ Added to axoiq org"
else
  echo "  ⚠️  Org membership — HTTP ${HTTP_CODE} (user may already be a member)"
fi

# Grant write on repos
for repo in "${FORGEJO_REPOS[@]}"; do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
    -H "Authorization: token ${FORGEJO_TOKEN}" \
    -H "Content-Type: application/json" \
    "${FORGEJO_URL}/api/v1/repos/axoiq/${repo}/collaborators/${USERNAME_FJ}" \
    -d '{"permission":"write"}')

  if [ "$HTTP_CODE" = "204" ] || [ "$HTTP_CODE" = "200" ]; then
    echo "  ✅ axoiq/${repo} — write access granted"
  else
    echo "  ⚠️  axoiq/${repo} — HTTP ${HTTP_CODE}"
  fi
done

# --- Forgejo: Create fork (if --fork) ---
if [ "$FORK" = true ]; then
  echo ""
  echo "🍴 Forgejo — Creating fork ${USERNAME_FJ}/atlas-plugin..."

  # Note: This creates a fork under the user's namespace.
  # The Forgejo API requires the user's own token for fork creation,
  # so we use the admin token to create it via the API endpoint.
  FORK_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: token ${FORGEJO_TOKEN}" \
    -H "Content-Type: application/json" \
    "${FORGEJO_URL}/api/v1/repos/axoiq/atlas-plugin/forks" \
    -d "{\"name\": \"atlas-plugin\", \"organization\": \"\"}")

  FORK_HTTP_CODE=$(echo "$FORK_RESPONSE" | tail -n1)
  FORK_BODY=$(echo "$FORK_RESPONSE" | head -n -1)

  case "$FORK_HTTP_CODE" in
    200|201|202)
      echo "  ✅ Fork created: ${USERNAME_FJ}/atlas-plugin"
      ;;
    409)
      echo "  ⚠️  Fork already exists (HTTP 409)"
      ;;
    *)
      echo "  ❌ Fork creation failed — HTTP ${FORK_HTTP_CODE}"
      echo "     The user may need to create the fork manually via the Forgejo UI."
      echo "     URL: ${FORGEJO_URL}/axoiq/atlas-plugin → Fork button"
      ;;
  esac
fi

# --- Generate onboarding message ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📧 Onboarding Message (send to ${EMAIL}):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$EXTERNAL" = true ]; then
  cat << EOF

Bienvenue dans l'écosystème ATLAS! 🏛️

Voici les étapes pour configurer ton environnement sur ton homelab:

1. INSTALLER CLAUDE CODE
   Linux:    curl -fsSL https://claude.ai/install.sh | sh
   macOS:    curl -fsSL https://claude.ai/install.sh | sh
   Windows:  irm https://claude.ai/install.ps1 | iex

2. CONFIGURER TON GITHUB TOKEN (lecture du mirror public)
   - Va sur github.com/settings/tokens
   - Crée un Fine-grained token: Public Repositories, Contents: Read-only
   - Configure:
     echo 'export GITHUB_TOKEN="ghp_xxx"' >> ~/.zshrc && source ~/.zshrc

3. INSTALLER LE PLUGIN ATLAS (admin)
   claude
   /plugin marketplace add seb155/atlas-plugin
   /plugin install atlas-admin@atlas-admin-marketplace
   # Quitter et relancer Claude Code

4. VÉRIFIER
   # Banner attendu:
   🏛️ ATLAS v4.x.x online | <hostname>
   72 skills | 15 agents | Quality gate 16/20

   # Health check:
   /atlas doctor

5. TON FORK POUR CONTRIBUER
   URL: ${FORGEJO_URL}/${USERNAME_FJ}/atlas-plugin
   git clone ${FORGEJO_URL}/${USERNAME_FJ}/atlas-plugin.git
   cd atlas-plugin
   git remote add upstream ${FORGEJO_URL}/axoiq/atlas-plugin.git

6. GUIDE COMPLET
   Voir ONBOARDING-EXTERNAL.md dans le repo atlas-plugin pour les détails:
   - Installation CLI
   - Workflow de contribution (PR)
   - Créer des skills
   - Commandes essentielles

Questions? Contacte Seb sur Teams ou seb@axoiq.com.

EOF
else
  cat << EOF

Bienvenue dans l'équipe ATLAS! 🏛️

Voici les étapes pour configurer ton environnement Claude Code:

1. INSTALLER CLAUDE CODE
   Windows:  irm https://claude.ai/install.ps1 | iex
   Mac/Linux: curl -fsSL https://claude.ai/install.sh | sh

2. CONFIGURER TON GITHUB TOKEN
   - Va sur github.com/settings/tokens
   - Crée un Fine-grained token avec accès Read sur seb155/atlas-plugin
   - Configure-le:
     Windows:  [Environment]::SetEnvironmentVariable("GITHUB_TOKEN", "ghp_xxx", "User")
     Linux:    echo 'export GITHUB_TOKEN="ghp_xxx"' >> ~/.bashrc && source ~/.bashrc

3. INSTALLER LE PLUGIN ATLAS
   - Ouvre Claude Code: claude
   - Run: /plugin marketplace add seb155/atlas-plugin
   - Run: /plugin install atlas-admin@atlas-admin-marketplace
   - Redémarre Claude Code (exit + claude)
   - Tu devrais voir le banner: 🏛️ ATLAS v4.x.x online

4. CLONER LES REPOS POUR CONTRIBUER
   git clone https://github.com/seb155/atlas-plugin.git
   git clone https://github.com/seb155/gms-cowork-plugins.git
   git clone https://github.com/seb155/genie-framework.git

5. WORKFLOW DE CONTRIBUTION
   - Crée une branche: git checkout -b feature/mon-changement
   - Push: git push origin feature/mon-changement
   - Le mirror Forgejo se synchronise automatiquement

Questions? Contacte Seb sur Teams ou seb@axoiq.com.

EOF
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Onboarding complete for ${USERNAME_FJ} (tier: ${TIER})"
if [ "$EXTERNAL" = true ]; then
  echo ""
  echo "📋 Remaining manual steps:"
  echo "  1. Add ${EMAIL} to CF Access policy 'Allow AXOIQ Team'"
  echo "  2. Send the onboarding message above to ${EMAIL}"
  echo "  3. Set up branch protection on axoiq/atlas-plugin:main (if not done)"
fi
