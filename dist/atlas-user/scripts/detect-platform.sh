#!/usr/bin/env bash
# ATLAS Platform Detection Helper
# Returns JSON with OS, shell, terminal, architecture, capabilities
# Used by: session-start hook, atlas-onboarding, atlas-doctor

detect_platform() {
  local os="unknown" os_version="" arch="" shell_name="" terminal="" wsl=false
  local has_docker=false has_bun=false has_yq=false has_starship=false has_cship=false has_jq=false has_winget=false

  # OS Detection
  case "$(uname -s)" in
    Linux)
      os="linux"
      os_version=$(uname -r)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        os="wsl"
        os_version="$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2) (WSL)"
        wsl=true
      elif [ -f /etc/os-release ]; then
        os_version=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
      fi
      ;;
    Darwin)
      os="macos"
      os_version=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
      ;;
    MINGW*|MSYS*|CYGWIN*)
      os="windows"
      os_version="$(uname -r)"
      ;;
  esac

  # Architecture
  arch=$(uname -m)

  # Shell
  shell_name=$(basename "${SHELL:-unknown}")

  # Terminal Detection
  if [ -n "${TERM_PROGRAM:-}" ]; then
    terminal="$TERM_PROGRAM"
  elif [ -n "${WT_SESSION:-}" ]; then
    terminal="windows-terminal"
  elif [ -n "${PTYXIS_VERSION:-}" ] || pgrep -x ptyxis >/dev/null 2>&1; then
    terminal="ptyxis"
  elif [ -n "${KITTY_WINDOW_ID:-}" ]; then
    terminal="kitty"
  elif [ -n "${ALACRITTY_SOCKET:-}" ]; then
    terminal="alacritty"
  elif [ -n "${TMUX:-}" ]; then
    terminal="tmux"
  else
    terminal="${TERM:-unknown}"
  fi

  # Tool capabilities
  command -v docker &>/dev/null && has_docker=true
  command -v bun &>/dev/null && has_bun=true
  command -v yq &>/dev/null && has_yq=true
  command -v starship &>/dev/null && has_starship=true
  command -v cship &>/dev/null && has_cship=true
  command -v jq &>/dev/null && has_jq=true
  command -v winget &>/dev/null && has_winget=true

  local hostname
  hostname=$(hostname -s 2>/dev/null || echo "unknown")

  cat <<EOF
{
  "os": "${os}",
  "os_version": "${os_version}",
  "arch": "${arch}",
  "shell": "${shell_name}",
  "terminal": "${terminal}",
  "hostname": "${hostname}",
  "wsl": ${wsl},
  "home": "${HOME}",
  "capabilities": {
    "docker": ${has_docker},
    "bun": ${has_bun},
    "yq": ${has_yq},
    "starship": ${has_starship},
    "cship": ${has_cship},
    "jq": ${has_jq},
    "winget": ${has_winget}
  }
}
EOF
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  detect_platform
fi
