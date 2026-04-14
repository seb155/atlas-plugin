#!/usr/bin/env zsh
# ATLAS CLI Module: Interactive Menu, Tmux Split, Main Entry Point
# Sourced by atlas-cli.sh — do not execute directly

# ─── Interactive Menu (atlas with no args) ────────────────────
_atlas_interactive_menu() {
  _atlas_header

  if $ATLAS_HAS_GUM; then
    _atlas_gum_menu
  elif $ATLAS_HAS_FZF; then
    _atlas_fzf_menu
  else
    _atlas_basic_menu
  fi
}

_atlas_gum_menu() {
  # Build menu items: recent projects + actions
  local -a items=()
  local -a project_names=()

  # Recent projects
  local recents=$(_atlas_recent_projects 5)
  if [ -n "$recents" ]; then
    while IFS='|' read pname ago count; do
      items+=("▶ ${pname}  (${ago}, ${count}x)")
      project_names+=("$pname")
    done <<< "$recents"
  fi

  # All projects not in recents
  local all_projects=$(_atlas_known_projects)
  if [ -n "$all_projects" ]; then
    while read pname; do
      # Skip if already in recents
      local skip=false
      for r in "${project_names[@]}"; do
        [ "$r" = "$pname" ] && { skip=true; break; }
      done
      $skip && continue
      items+=("  ${pname}")
      project_names+=("$pname")
    done <<< "$all_projects"
  fi

  # Actions separator + items
  items+=("─────────────────────────")
  project_names+=("__separator__")
  items+=("📋 list --all       Scan all projects")
  project_names+=("__list_all__")
  items+=("🔄 resume           Resume last session")
  project_names+=("__resume__")
  items+=("📊 status           Active sessions")
  project_names+=("__status__")
  items+=("⚙️  setup            Configure ATLAS")
  project_names+=("__setup__")
  items+=("🩺 doctor           Health check")
  project_names+=("__doctor__")
  items+=("❓ help             Documentation")
  project_names+=("__help__")

  # Show gum choose menu
  local choice=$(printf '%s\n' "${items[@]}" | gum choose \
    --header "Select a project or action:" \
    --cursor "→ " \
    --cursor.foreground 214 \
    --selected.foreground 214 \
    --height 20)

  [ -z "$choice" ] && return 0

  # Find index of choice
  local idx=0
  for item in "${items[@]}"; do
    if [ "$item" = "$choice" ]; then
      local action="${project_names[$((idx + 1))]}"
      case "$action" in
        __separator__) _atlas_interactive_menu ;; # Re-show menu
        __list_all__) _atlas_list --all ;;
        __resume__) _atlas_resume ;;
        __status__) _atlas_status ;;
        __setup__) _atlas_setup ;;
        __doctor__) _atlas_doctor ;;
        __help__) _atlas_help ;;
        *) atlas "$action" ;; # Launch project
      esac
      return
    fi
    idx=$((idx + 1))
  done
}

_atlas_fzf_menu() {
  printf "  ${ATLAS_BOLD}Select project:${ATLAS_RESET}\n\n"

  local choice=$(_atlas_discover_projects | while IFS=: read pname ppath; do
    echo "$pname"
  done | fzf --header="ATLAS — Select project" --height=15 --reverse --border)

  [ -n "$choice" ] && atlas "$choice"
}

_atlas_basic_menu() {
  printf "  ${ATLAS_BOLD}Recent projects:${ATLAS_RESET}\n\n"
  local idx=1
  local -a names=()

  _atlas_recent_projects 5 | while IFS='|' read pname ago count; do
    printf "    ${ATLAS_CYAN}%d)${ATLAS_RESET} %-14s ${ATLAS_DIM}(%s)${ATLAS_RESET}\n" "$idx" "$pname" "$ago"
    names+=("$pname")
    idx=$((idx + 1))
  done

  echo ""
  printf "  ${ATLAS_BOLD}Actions:${ATLAS_RESET}\n"
  printf "    l) list all    r) resume    s) status    h) help    q) quit\n\n"
  printf "  Select: "
  read -r sel

  case "$sel" in
    [0-9]*) local name="${names[$sel]}"; [ -n "$name" ] && atlas "$name" ;;
    l) _atlas_list --all ;;
    r) _atlas_resume ;;
    s) _atlas_status ;;
    h) _atlas_help ;;
    q) return 0 ;;
  esac
}

# ─── Tmux Split Launcher ─────────────────────────────────────
_atlas_split_launch() {
  local project="$1" path="$2" session_name="$3"
  shift 3
  local cmd=("$@")

  if ! $ATLAS_HAS_TMUX; then
    echo "tmux required for split mode. Install: ${_pkg:-sudo apt install} tmux"
    echo "Falling back to inline mode..."
    (builtin cd "$path" && "${cmd[@]}")
    return
  fi

  # Collision handler: session already exists → ask user
  if /usr/bin/tmux has-session -t "$session_name" 2>/dev/null; then
    if $ATLAS_HAS_GUM; then
      local action
      action=$(gum choose --header "Session '${session_name}' exists:" \
        "📎 Attach (resume existing)" \
        "🔄 Kill & Replace" \
        "✏️  Rename" 2>/dev/null || echo "")
      case "$action" in
        *Attach*)
          if [ -n "$TMUX" ]; then
            /usr/bin/tmux switch-client -t "$session_name"
          else
            /usr/bin/tmux attach-session -t "$session_name"
          fi
          return ;;
        *Kill*)
          /usr/bin/tmux kill-session -t "$session_name" 2>/dev/null ;;
        *Rename*)
          local new_label
          new_label=$(gum input --header "New session name:" --width 40 2>/dev/null || echo "")
          [ -z "$new_label" ] && return 1
          session_name="cc-${project}-${new_label}" ;;
        *)
          return 0 ;;  # User cancelled
      esac
    else
      echo "Session '${session_name}' already exists. Kill it first or use a different name."
      return 1
    fi
  fi

  # Build the claude command string with full PATH export prefix
  # Append "; exit" so the tmux shell auto-closes when claude exits
  local path_export="export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:\${HOME}/.local/bin:\${HOME}/.bun/bin:\${HOME}/.cargo/bin:\${HOME}/.npm-global/bin:/usr/local/go/bin:\${HOME}/go/bin:\$PATH"
  local cmd_str="${cmd[*]}"
  local full_cmd="${path_export} && ${cmd_str}; exit"

  if [ -n "$TMUX" ]; then
    # Already inside tmux → create detached session, then switch to it
    /usr/bin/tmux new-session -d -s "$session_name" -n "${project}" -c "$path"
    /usr/bin/tmux send-keys -t "$session_name" "$full_cmd" C-m
    /usr/bin/tmux switch-client -t "$session_name"
  else
    # Outside tmux → create and attach directly
    /usr/bin/tmux new-session -s "$session_name" -n "${project}" -c "$path" \; \
      send-keys "$full_cmd" C-m
  fi
}


# ─── Main Entry Point ────────────────────────────────────────
atlas() {
  # Ensure standard system paths are in PATH and clear stale command cache
  export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${HOME}/.local/bin:${HOME}/.bun/bin:${HOME}/.cargo/bin:${HOME}/.npm-global/bin:/usr/local/go/bin:${HOME}/go/bin:$PATH"
  hash -r 2>/dev/null; rehash 2>/dev/null  # Reset both POSIX and zsh command hash tables

  # No args = interactive menu
  if [ $# -eq 0 ]; then
    _atlas_interactive_menu
    return
  fi

  # Subcommand dispatch
  case "$1" in
    list)    shift; _atlas_list "$@"; return ;;
    resume)  shift; _atlas_resume "$@"; return ;;
    status)  _atlas_status; return ;;
    setup)   shift; _atlas_setup "$@"; return ;;
    doctor)  shift; _atlas_doctor "$@"; return ;;
    hooks)   _atlas_hooks; return ;;
    topics)  _atlas_topics_list; return ;;
    update)  _atlas_update; return ;;
    ci) _atlas_ci; return ;;
    complexity) shift; _atlas_complexity "$@"; return ;;
    dispatch) shift; _atlas_dispatch "$@"; return ;;
    agents) shift; _atlas_agents_cmd "$@"; return ;;
    team) shift; _atlas_team_blueprint "$@"; return ;;
    manifest) shift; _atlas_manifest "$@"; return ;;
    repos) _atlas_repos; return ;;
    cost) shift; _atlas_cost "$@"; return ;;
    deps) _atlas_deps; return ;;
    init) shift; _atlas_init "$@"; return ;;
    plans) shift; _atlas_plans "$@"; return ;;
    sessions) _atlas_sessions; return ;;
    budget) _atlas_budget; return ;;
    import-handoff) shift; _atlas_import_handoff "$@"; return ;;
    replay) shift; _atlas_replay "$@"; return ;;
    ab) shift; _atlas_ab "$@"; return ;;
    worktrees|wt) _atlas_worktrees; return ;;
    cleanup) shift; _atlas_cleanup "$@"; return ;;
    feature|-f) shift; _atlas_feature "$@"; return ;;
    # v5.7.0+ Phase 3 — Semantic worktree subcommands (naming enforced)
    feat)     shift; _atlas_semantic_worktree feat "$@"; return ;;
    fix)      shift; _atlas_semantic_worktree fix "$@"; return ;;
    hotfix)   shift; _atlas_semantic_worktree hotfix "$@"; return ;;
    chore)    shift; _atlas_semantic_worktree chore "$@"; return ;;
    refactor) shift; _atlas_semantic_worktree refactor "$@"; return ;;
    promote) shift; _atlas_promote "$@"; return ;;
    review) shift; _atlas_review "$@"; return ;;
    blast) shift; _atlas_blast "$@"; return ;;
    --check) shift; _atlas_preflight "$@"; return ;;
    dashboard|dash|d) _atlas_dashboard; return ;;
    help|-h|--help) _atlas_help; return ;;
    --version|-v) echo "ATLAS CLI v${ATLAS_VERSION} | Plugin v$(_atlas_plugin_version) | CC v${ATLAS_CC_VERSION}"; return ;;
  esac

  # Daily topic cleanup (lightweight — runs once per day, no-op otherwise)
  _atlas_maybe_cleanup_topics

  # Parse project + flags
  local project="" topic=""
  local worktree=$ATLAS_DEFAULT_WORKTREE
  local split=$ATLAS_DEFAULT_SPLIT
  local effort=$ATLAS_DEFAULT_EFFORT
  local chrome=$ATLAS_DEFAULT_CHROME
  local yolo=false auto_mode=false plan_mode=false bare=false
  local cont=false resume_name="" session_name="" wt_name=""
  local -a extra_args=()
  local parsing_extra=false

  for arg in "$@"; do
    if $parsing_extra; then
      extra_args+=("$arg")
      continue
    fi

    case "$arg" in
      --) parsing_extra=true ;;
      -i|--inline) worktree=false; split=false ;;
      -y|--yolo) yolo=true ;;
      -a|--auto) auto_mode=true ;;
      -p|--plan) plan_mode=true ;;
      -b|--bare) bare=true ;;
      --no-split) split=false ;;
      --no-worktree) worktree=false ;;
      -c|--continue) cont=true ;;
      -e|--effort)
        # Next arg is the effort level (handled below)
        ;;
      -r|--resume)
        # Next arg is the session name (handled below)
        ;;
      -n|--name)
        # Next arg is the session name (handled below)
        ;;
      low|medium|high|max)
        # Effort level value (follows -e)
        effort="$arg"
        ;;
      -s|--split) split=true ;;
      -w|--worktree) worktree=true ;;
      -*)
        echo "Unknown flag: $arg. Run 'atlas help'."
        return 1
        ;;
      *)
        if [ -z "$project" ]; then
          project="$arg"
        elif [ -z "$topic" ]; then
          topic="$arg"
        elif [[ "$worktree" == "true" ]] && [ -z "$wt_name" ]; then
          wt_name="$arg"
        else
          extra_args+=("$arg")
        fi
        ;;
    esac
  done

  # Resolve project path
  local path=$(_atlas_resolve_project "$project")
  if [ -z "$path" ]; then
    echo "Project '${project}' not found. Run 'atlas list --all' to see available projects."
    return 1
  fi

  # Record usage
  _atlas_record_history "$project"

  # ─── Topic Detection (after project resolved, before CC launch) ───
  if [ -n "$topic" ]; then
    local topic_data
    topic_data=$(_atlas_topic_get "$topic" 2>/dev/null)

    if [ -n "$topic_data" ]; then
      # Existing topic — check for handoff
      local latest_handoff
      latest_handoff=$(python3 -c "
import json
t = json.loads('''$topic_data''')
handoffs = t.get('handoffs', [])
print(handoffs[-1] if handoffs else '')
" 2>/dev/null)

      if [ -n "$latest_handoff" ]; then
        export ATLAS_TOPIC="$topic"
        export ATLAS_TOPIC_HANDOFF="$latest_handoff"
      fi

      _atlas_topic_update_active "$topic"
    else
      # New topic — create entry
      local branch
      branch=$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
      _atlas_topic_create "$topic" "$project" "$branch"
      export ATLAS_TOPIC="$topic"
    fi

    _atlas_topic_add_session "$topic" "$name"
  fi

  # Auto-rebuild plugin if source is newer than cache (zero-friction dev)
  local _plugin_src="${HOME}/workspace_atlas/projects/atlas-dev-plugin"
  if [ -f "${_plugin_src}/VERSION" ]; then
    local _src_time _cache_time
    _src_time=$(stat -c %Y "${_plugin_src}/VERSION" 2>/dev/null || echo 0)
    _cache_time=$(stat -c %Y "${HOME}/.claude/plugins/cache/atlas-admin-marketplace/atlas-admin/"*/VERSION(N) 2>/dev/null | /usr/bin/head -1 || echo 0)
    if [ "${_src_time:-0}" -gt "${_cache_time:-0}" ]; then
      echo "🔄 Plugin source newer than cache, rebuilding..."
      (cd "${_plugin_src}" && make dev-admin 2>/dev/null) && echo "   ✅ Plugin rebuilt" || echo "   ⚠️  Plugin rebuild failed (non-blocking)"
    fi
  fi

  # Fix CC settings before launch (remove overly broad deny rules)
  [ -x "${HOME}/.atlas/scripts/fix-cc-settings.sh" ] && "${HOME}/.atlas/scripts/fix-cc-settings.sh" >/dev/null 2>&1

  # Load secrets (Vaultwarden unlock if needed — interactive mode for gum prompt)
  export ATLAS_INTERACTIVE=1
  [ -f "${HOME}/.atlas/scripts/load-secrets.sh" ] && source "${HOME}/.atlas/scripts/load-secrets.sh"
  unset ATLAS_INTERACTIVE

  # Resolve claude binary path (don't depend on PATH in subshell)
  local claude_bin="${HOME}/.local/bin/claude"
  [ ! -x "$claude_bin" ] && claude_bin=$(command -v claude 2>/dev/null || echo "claude")
  local -a cmd=("$claude_bin")

  # Worktree — always with a meaningful name (never random)
  if [[ "$worktree" == "true" ]]; then
    if [ -n "$wt_name" ]; then
      # Explicit name: atlas -w synapse pitch-demo
      cmd+=(-w "$wt_name")
    elif [ -n "$topic" ]; then
      # Topic provided: atlas synapse pitch-demo → use topic as worktree name
      cmd+=(-w "$topic")
    else
      # Fallback: project-MMDD (still meaningful, never random)
      local _wt_project
      _wt_project="${path:t}"
      cmd+=(-w "${_wt_project}-$(/usr/bin/date '+%m%d')")
    fi
  fi

  # Effort
  [ -n "$effort" ] && [ "$effort" != "auto" ] && cmd+=(--effort "$effort")

  # Permission modes (mutually exclusive, last wins)
  if $yolo; then
    cmd+=(--dangerously-skip-permissions)
  elif $auto_mode; then
    cmd+=(--enable-auto-mode --permission-mode auto)
  elif $plan_mode; then
    cmd+=(--permission-mode plan)
  fi

  # Bare mode
  $bare && cmd+=(--bare)

  # Chrome
  [[ "$chrome" == "true" ]] && ! $bare && cmd+=(--chrome)

  # Continue / Resume
  $cont && cmd+=(-c)
  [ -n "$resume_name" ] && cmd+=(-r "$resume_name")

  # Session name — interactive prompt for split mode, auto for inline
  local name="${session_name:-$(_cc_session_name "$path" "$topic")}"
  local tmux_session_name="cc-${project}${topic:+-$topic}"

  # Multi-session: prompt for name in split mode (skip if -n was passed)
  if [[ "$split" == "true" ]] && ! $bare && [ -z "$session_name" ] && $ATLAS_HAS_GUM && $ATLAS_HAS_TMUX; then
    local base_name="cc-${project}"
    local default_suffix=""
    local n=1
    # Auto-incremental: find next available number
    while /usr/bin/tmux has-session -t "${base_name}${default_suffix:+-$default_suffix}" 2>/dev/null; do
      default_suffix="$n"
      n=$((n + 1))
    done

    local user_label
    user_label=$(gum input --header "📋 Session name:" \
      --placeholder "${default_suffix:-"Enter=auto, or type a name"}" \
      --width 40 2>/dev/null || echo "")

    if [ -n "$user_label" ]; then
      tmux_session_name="${base_name}-${user_label}"
      name="${project}-${user_label}"
    elif [ -n "$default_suffix" ]; then
      tmux_session_name="${base_name}-${default_suffix}"
      name="${project}-${default_suffix}"
    fi
    # else: first session, use default cc-project
  fi

  cmd+=(-n "$name")

  # Extra passthrough args
  [ ${#extra_args[@]} -gt 0 ] && cmd+=("${extra_args[@]}")

  # Launch with full PATH guaranteed
  local _full_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${HOME}/.local/bin:${HOME}/.bun/bin:${HOME}/.cargo/bin:${HOME}/.npm-global/bin:/usr/local/go/bin:${HOME}/go/bin:$PATH"

  if [[ "$split" == "true" ]] && ! $bare; then
    _atlas_split_launch "$project" "$path" "$tmux_session_name" "${cmd[@]}"
  else
    # builtin cd bypasses zoxide wrapper; direnv export loads .envrc silently
    builtin cd "$path" \
      && { # shellcheck disable=SC2046
           # direnv output is trusted (it's OUR config), so eval is intentional here.
           eval "$(DIRENV_LOG_FORMAT= direnv export zsh 2>/dev/null)"; } \
      && export PATH="$_full_path" \
      && "${cmd[@]}"
  fi
}

