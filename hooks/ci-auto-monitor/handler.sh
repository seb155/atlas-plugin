#!/usr/bin/env bash
# ci-auto-monitor — PostToolUse hook for git push
# Detects git push in Bash output and suggests CI monitoring.
# This hook provides context to Claude, not direct automation.
set -euo pipefail

# Read tool result from stdin
TOOL_RESULT=$(cat)

# Only trigger on successful git push
if ! echo "$TOOL_RESULT" | grep -q "To ssh://\|To https://\|-> origin/"; then
  exit 0
fi

# Extract branch from push output
BRANCH=$(echo "$TOOL_RESULT" | grep -oP '\S+ -> \S+' | head -1 | awk '{print $NF}' | sed 's|origin/||')

if [ -z "$BRANCH" ]; then
  exit 0
fi

# Output context for Claude
cat <<EOF
📡 CI Auto-Monitor: Push detected to branch '${BRANCH}'.
To monitor CI status, use: /atlas ci status
Or run: source ~/.env && curl -s -H "Authorization: token \$FORGEJO_TOKEN" "http://192.168.10.75:3000/api/v1/repos/axoiq/synapse/actions/runs?limit=1" | python3 -c "import sys,json; d=json.load(sys.stdin); runs=d.get('workflow_runs',[]); print(f'CI: {runs[0][\"status\"]}' if runs else 'No runs')"
EOF
