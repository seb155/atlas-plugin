#!/usr/bin/env bash
# ATLAS Status Line for Claude Code — Starship Style + SOTA v2.1.83
# Shipped via ATLAS plugin. Deployed by session-start hook.
# Shows: directory + git_branch + git_status + session + context% + rate% + effort + model

input=$(cat)

# Extract JSON data
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
model=$(echo "$input" | jq -r '.model.id')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
session_name=$(echo "$input" | jq -r '.session_name // empty')
rate_5h=$(echo "$input" | jq -r '.rate_limits["5h"].used_percentage // 0')
effort=$(echo "$input" | jq -r '.effort // "auto"')

# ANSI colors (bold to match Starship bold styles)
CYAN='\033[1;36m'
PURPLE='\033[1;35m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
RESET='\033[0m'

# Directory: truncate to last 4 components (matches truncation_length = 4)
dir_display=""
if [ -n "$cwd" ] && [ "$cwd" != "null" ]; then
    IFS='/' read -ra parts <<< "$cwd"
    total=${#parts[@]}
    if [ "$total" -le 4 ]; then
        dir_display="$cwd"
    else
        dir_display="${parts[$((total-4))]}/${parts[$((total-3))]}/${parts[$((total-2))]}/${parts[$((total-1))]}"
    fi
fi

# Git info (branch + status)
git_branch=""
git_status_str=""
if git -C "$cwd" rev-parse --git-dir &>/dev/null 2>&1; then
    branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        git_branch=" ${PURPLE}${branch}${RESET}"
    fi

    status_flags=""
    porcelain=$(git -C "$cwd" status --porcelain 2>/dev/null)
    ahead_behind=$(git -C "$cwd" rev-list --left-right --count "@{upstream}...HEAD" 2>/dev/null)

    if echo "$porcelain" | grep -q '^[MADRCU]'; then status_flags="${status_flags}!"; fi
    if echo "$porcelain" | grep -q '^ [MADRCU]'; then status_flags="${status_flags}+"; fi
    if echo "$porcelain" | grep -q '^??'; then status_flags="${status_flags}?"; fi
    if echo "$porcelain" | grep -q '^.D\|^D.'; then status_flags="${status_flags}x"; fi

    if [ -n "$ahead_behind" ]; then
        behind=$(echo "$ahead_behind" | awk '{print $1}')
        ahead=$(echo "$ahead_behind" | awk '{print $2}')
        [ "$ahead" -gt 0 ] 2>/dev/null && status_flags="${status_flags}^${ahead}"
        [ "$behind" -gt 0 ] 2>/dev/null && status_flags="${status_flags}v${behind}"
    fi

    if [ -n "$status_flags" ]; then
        git_status_str=" ${RED}[${status_flags}]${RESET}"
    fi
fi

# Model (short format: opus, sonnet, haiku)
model_short="${model#claude-}"
model_short="${model_short%%-*}"

# Context % with color (green <50, yellow 50-75, red >75)
used_int="${used_pct%.*}"
context_color=$GREEN
[ "${used_int:-0}" -gt 50 ] 2>/dev/null && context_color=$YELLOW
[ "${used_int:-0}" -gt 75 ] 2>/dev/null && context_color=$RED

# Session name
session_display=""
[ -n "$session_name" ] && session_display=" ${PURPLE}[${session_name}]${RESET}"

# Agents indicator (SP-AGENT-VIS Layer 2) — reads ~/.atlas/runtime/agents.json
# Format: " 🤖2▶ 1✓" — running / completed last 30min / failed
# Empty if no agents tracked. Python3 preferred for time-math filter, jq fallback.
agents_display=""
agents_file="${ATLAS_DIR:-$HOME/.atlas}/runtime/agents.json"
if [ -f "$agents_file" ]; then
    if command -v python3 &>/dev/null; then
        agents_display=$(python3 -c "
import json, sys
from datetime import datetime, timezone, timedelta
try:
    with open('${agents_file}') as f: data = json.load(f)
    cutoff = datetime.now(timezone.utc) - timedelta(minutes=30)
    running = sum(1 for a in data.values() if a.get('status') in ('running', 'spawning'))
    done = 0; failed = 0
    for a in data.values():
        finished = a.get('finished_at')
        if not finished: continue
        try: ts = datetime.fromisoformat(finished.replace('Z', '+00:00'))
        except: continue
        if ts < cutoff: continue
        if a.get('status') == 'completed': done += 1
        elif a.get('status') == 'failed': failed += 1
    parts = []
    if running > 0: parts.append(f'\033[1;33m{running}▶\033[0m')
    if done > 0: parts.append(f'\033[0;32m{done}✓\033[0m')
    if failed > 0: parts.append(f'\033[1;31m{failed}✗\033[0m')
    if parts: print(' 🤖' + ' '.join(parts))
except: pass
" 2>/dev/null)
    elif command -v jq &>/dev/null; then
        # jq fallback: running count only
        running=$(jq -r '[.[] | select(.status == "running" or .status == "spawning")] | length' "$agents_file" 2>/dev/null || echo 0)
        [ "$running" -gt 0 ] 2>/dev/null && agents_display=" 🤖${YELLOW}${running}▶${RESET}"
    fi
fi

# Rate limit % with color (v2.1.80)
rate_int="${rate_5h%.*}"
rate_color=$GREEN
[ "${rate_int:-0}" -gt 50 ] 2>/dev/null && rate_color=$YELLOW
[ "${rate_int:-0}" -gt 80 ] 2>/dev/null && rate_color=$RED
rate_display=""
[ "${rate_int:-0}" -gt 0 ] 2>/dev/null && rate_display=" ${rate_color}R${rate_int}%%${RESET}"

# Effort symbol (v2.1.72)
effort_sym="◐"
[ "$effort" = "low" ] && effort_sym="○"
[ "$effort" = "high" ] && effort_sym="●"

# Output: dir branch git-status session agents ctx% rate% effort model
printf "${CYAN}${dir_display}${RESET}${git_branch}${git_status_str}${session_display}${agents_display} ${context_color}${used_int}%%${RESET}${rate_display} ${effort_sym} ${YELLOW}${model_short}${RESET}"
