#!/usr/bin/env bash
# shellcheck shell=bash
# NOTE: Sourced by scripts/atlas-cli.sh (no set -euo pipefail at file level).
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
  local recents
  recents=$(_atlas_recent_projects 5)
  if [ -n "$recents" ]; then
    while IFS='|' read pname ago count; do
      items+=("▶ ${pname}  (${ago}, ${count}x)")
      project_names+=("$pname")
    done <<< "$recents"
  fi

  # All projects not in recents
  local all_projects
  all_projects=$(_atlas_known_projects)
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
  local choice
  choice=$(printf '%s\n' "${items[@]}" | gum choose \
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

  local choice
  choice=$(_atlas_discover_projects | while IFS=: read pname ppath; do
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
    ci) shift; _atlas_ci_cmd "$@"; return ;;
    plugin) shift; _atlas_plugin "$@"; return ;;
    profile) shift; _atlas_profile_cmd "$@"; return ;;
    mcp) shift; _atlas_mcp_cmd "$@"; return ;;
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
    version) _atlas_version; return ;;
    upgrade) shift; _atlas_upgrade "$@"; return ;;
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

  # ─── P2.4 + P3.1/2/6: Launch Profile pre-parse (v5.28.0+) ─────
  # Detect --profile <name> and apply profile defaults BEFORE main arg parse.
  # Explicit flags (-p, -a, -e, etc.) still override profile values (parse later).
  local lp_name="" detect_only=false no_profile=false
  local -a _atlas_args=("$@")
  local _i
  for ((_i=0; _i<${#_atlas_args[@]}; _i++)); do
    case "${_atlas_args[_i]}" in
      --profile)      lp_name="${_atlas_args[_i+1]:-}" ;;
      --detect-only)  detect_only=true ;;
      --no-profile)   no_profile=true ;;
    esac
  done

  # P3.1 + P3.2: Auto-detect profile if no explicit --profile AND auto-detect enabled
  # Feature flag: ATLAS_AUTO_DETECT_PROFILE=true (default false for safe rollout)
  if [ -z "$lp_name" ] && ! $no_profile; then
    local auto_detect="${ATLAS_AUTO_DETECT_PROFILE:-false}"
    if [ "$auto_detect" = "true" ] || $detect_only; then
      local _detected
      _detected=$(_atlas_detect_profile 2>/dev/null)
      if [ -n "$_detected" ]; then
        lp_name="$_detected"
        echo "🎯 [atlas] Auto-detected profile: '$lp_name' (cwd: $PWD)" >&2
      fi
    fi
  fi

  if [ -n "$lp_name" ] && ! $no_profile; then
    if _atlas_load_profile "$lp_name"; then
      # P3.3 + P3.4 + P3.5: Apply environment overlays (WiFi trust, git branch, time)
      # These modify ATLAS_LP_* based on current environment context.
      _atlas_apply_all_overlays

      # Apply profile values as new defaults (explicit flags below will override)
      [ -n "$ATLAS_LP_WORKTREE" ] && [ "$ATLAS_LP_WORKTREE" != "null" ] && worktree="$ATLAS_LP_WORKTREE"
      [ -n "$ATLAS_LP_EFFORT" ] && [ "$ATLAS_LP_EFFORT" != "null" ] && effort="$ATLAS_LP_EFFORT"
      case "${ATLAS_LP_PERMISSION_MODE:-}" in
        plan)    plan_mode=true ;;
        auto)    auto_mode=true ;;
        dontAsk) yolo=true ;;  # yolo now → --permission-mode dontAsk (post-P1.4)
      esac
      [ "${ATLAS_LP_BARE:-}" = "true" ] && bare=true
      echo "📋 [atlas] Profile '$lp_name' loaded (chain: $ATLAS_LP_CHAIN)" >&2
    else
      echo "❌ [atlas] Profile load failed — using defaults" >&2
      return 1
    fi
  fi

  # ─── P2.5: --override key=value (applied after profile, before explicit flags) ───
  # Example: atlas --profile dev-synapse --override effort=max --override worktree=false
  for ((_i=0; _i<${#_atlas_args[@]}; _i++)); do
    if [ "${_atlas_args[_i]}" = "--override" ]; then
      local _kv="${_atlas_args[_i+1]:-}"
      local _k="${_kv%%=*}" _v="${_kv#*=}"
      if [ -z "$_kv" ] || [ "$_k" = "$_kv" ]; then
        echo "⚠️  [atlas] Invalid --override syntax: '$_kv' (expected key=value)" >&2
        continue
      fi
      case "$_k" in
        tier)            export "ATLAS_LP_TIER=$_v" ;;
        permission_mode|permission-mode|mode)
          case "$_v" in
            plan)    plan_mode=true;  auto_mode=false; yolo=false ;;
            auto)    auto_mode=true; plan_mode=false; yolo=false ;;
            dontAsk) yolo=true;      plan_mode=false; auto_mode=false ;;
            default) plan_mode=false; auto_mode=false; yolo=false ;;
            *)       echo "⚠️  [atlas] Unknown permission_mode: '$_v'" >&2 ;;
          esac
          export "ATLAS_LP_PERMISSION_MODE=$_v"
          ;;
        effort)          effort="$_v" ;;
        worktree)        worktree="$_v" ;;
        fork_session|fork-session) export "ATLAS_LP_FORK_SESSION=$_v" ;;
        bare)            [ "$_v" = "true" ] && bare=true ;;
        mcp_profile|mcp-profile) export "ATLAS_LP_MCP_PROFILE=$_v" ;;
        *)               echo "⚠️  [atlas] Unknown override field: '$_k'" >&2 ;;
      esac
    fi
  done

  # ─── P3.6: --detect-only dry-run (exits after printing resolved state) ─────
  if $detect_only; then
    echo ""
    if [ -n "$lp_name" ]; then
      echo "📋 Profile Resolution (post profile + override)"
      echo "   Name:     $lp_name"
      echo "   Chain:    ${ATLAS_LP_CHAIN:-—}"
      echo "   Tier:     ${ATLAS_LP_TIER:-—}"
      echo "   Mode:     ${ATLAS_LP_PERMISSION_MODE:-—}"
      echo "   Effort:   $effort"
      echo "   Worktree: $worktree"
      echo "   Fork:     ${ATLAS_LP_FORK_SESSION:-—}"
      echo "   Bare:     $bare"
      echo "   MCP:      ${ATLAS_LP_MCP_PROFILE:-—}"
      echo "   WiFi Req: ${ATLAS_LP_WIFI_TRUST_REQUIRED:-—}"
    else
      echo "ℹ️  [atlas] No profile detected or specified"
      echo "   Current cwd: $PWD"
      echo "   To enable auto-detect:  export ATLAS_AUTO_DETECT_PROFILE=true"
      echo "   To use explicit:        atlas --profile <name> --detect-only"
      echo "   To list available:      atlas profile list"
    fi
    echo ""
    return 0
  fi

  # P2.4 + P2.5: skip_next flag — consumes value arg after --profile or --override
  local _atlas_skip_next=false

  for arg in "$@"; do
    if $parsing_extra; then
      extra_args+=("$arg")
      continue
    fi
    if $_atlas_skip_next; then
      _atlas_skip_next=false
      continue
    fi

    case "$arg" in
      --) parsing_extra=true ;;
      --profile) _atlas_skip_next=true ;;  # Profile name is next arg (pre-parsed above)
      --override) _atlas_skip_next=true ;;  # key=value is next arg (pre-parsed above)
      --detect-only|--no-profile) ;;        # P3: handled in pre-parse, no-op here
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
  local path
  path=$(_atlas_resolve_project "$project")
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
    # Find the first VERSION file in any atlas-admin version dir (cross-shell safe).
    _cache_time=$(find "${HOME}/.claude/plugins/cache/atlas-admin-marketplace/atlas-admin/" -mindepth 2 -maxdepth 2 -name VERSION -type f 2>/dev/null | /usr/bin/head -1 | xargs -I{} stat -c %Y {} 2>/dev/null || echo 0)
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
      # Fallback: {abbrev}-MMDD (semantic, short, never random)
      # Multi-segment (atlas-dev-plugin) → initials (adp)
      # Mono-word (synapse) → first 5 chars (synap)
      local _wt_project="${path%/}"
      _wt_project="${_wt_project##*/}"
      cmd+=(-w "$(_atlas_abbrev_project "$_wt_project")-$(/usr/bin/date '+%m%d')")
    fi
  fi

  # Effort
  [ -n "$effort" ] && [ "$effort" != "auto" ] && cmd+=(--effort "$effort")

  # Permission modes (mutually exclusive, last wins)
  if $yolo; then
    # DEPRECATED in v5.28.0: -y/--yolo now maps to --permission-mode dontAsk (was --dangerously-skip-permissions).
    # Scheduled removal: v5.30.0. Migrate to `atlas <proj> --mode dontAsk` (see P2 profiles + P5 override syntax).
    echo "⚠️  [atlas] -y/--yolo deprecated → now uses --permission-mode dontAsk (safer). Will be removed in v5.30.0. Use 'atlas <proj> --mode dontAsk' or profile field 'permission_mode: dontAsk'." >&2
    cmd+=(--permission-mode dontAsk)
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

