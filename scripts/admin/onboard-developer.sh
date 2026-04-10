#!/usr/bin/env bash
# onboard-developer.sh — Add a new developer to all shared ATLAS repos
#
# Usage: ./onboard-developer.sh <github-username> <forgejo-username> <email>
# Requires: gh CLI authenticated, FORGEJO_TOKEN env var set
#
# What it does:
#   1. Invites GitHub user as collaborator (push access) on all shared repos
#   2. Adds Forgejo user to axoiq org with write access
#   3. Generates an onboarding message to send the new developer
set -euo pipefail

# --- Validate args ---
if [ $# -lt 3 ]; then
  echo "Usage: $0 <github-username> <forgejo-username> <email>"
  echo ""
  echo "Example: $0 jdoe jonathan.doe jdoe@[REDACTED]"
  exit 1
fi

USERNAME_GH="$1"
USERNAME_FJ="$2"
EMAIL="$3"

# --- Check prerequisites ---
if ! command -v gh &>/dev/null; then
  echo "❌ gh CLI not found. Install: https://cli.github.com"
  exit 1
fi

if [ -z "${FORGEJO_TOKEN:-}" ]; then
  echo "❌ FORGEJO_TOKEN not set. Run: source ~/.env"
  exit 1
fi

FORGEJO_URL="${FORGEJO_URL:-https://forgejo.axoiq.com}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏛️ ATLAS Developer Onboarding"
echo "  GitHub:  ${USERNAME_GH}"
echo "  Forgejo: ${USERNAME_FJ}"
echo "  Email:   ${EMAIL}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# --- GitHub: Invite collaborator on shared repos ---
echo ""
echo "📦 GitHub — Adding collaborator..."

GITHUB_REPOS=(
  "seb155/atlas-plugin"
  "seb155/gms-cowork-plugins"
  "seb155/genie-framework"
  # Add claude-deploy-scripts only for trusted devs:
  # "seb155/claude-deploy-scripts"
)

for repo in "${GITHUB_REPOS[@]}"; do
  if gh api "repos/${repo}/collaborators/${USERNAME_GH}" -X PUT -f permission=push --silent 2>/dev/null; then
    echo "  ✅ ${repo} — invited"
  else
    echo "  ⚠️  ${repo} — failed (check repo exists and gh is authenticated)"
  fi
done

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
FORGEJO_REPOS=(
  "atlas-plugin"
  "gms-cowork-plugins"
  "genie-framework"
  # Add claude-deploy-scripts only for trusted devs:
  # "claude-deploy-scripts"
)

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

# --- Generate onboarding message ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📧 Onboarding Message (send to ${EMAIL}):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Onboarding complete for ${USERNAME_GH} / ${USERNAME_FJ}"
