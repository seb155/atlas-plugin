#!/bin/bash
# Hook: PreToolUse(Bash) — Git Guardrails
# Cherry-picked from mattpocock/skills (misc/git-guardrails-claude-code), MIT.
# Adapted for ATLAS v7.0 PreToolUse contract.
#
# Blocks dangerous git operations BEFORE execution.
# Exit 0 = allow, Exit 2 = block (Claude Code PreToolUse convention).
#
# Bypass:
#   GIT_GUARDRAILS_BYPASS=1   one-shot bypass for THIS command
#   GIT_GUARDRAILS_DISABLE=1  permanent disable for the session
#
# Pain patterns this prevents (memory references):
#   - feedback_merge_before_delete.md  (worktree force removal w/ unmerged commits)
#   - lesson_strategy_theirs_old_commits.md  (theirs strategy on old refs)
#   - 380-skeleton-deletion (commit ecbd2bce0): rm -rf inside repo
set -euo pipefail

# --- Hook aggregation log (best-effort, never fails the hook) ---
_hook_log() {
  local result="${1:-pass}"
  local elapsed="${2:-0}"
  printf '{"ts":"%s","event":"%s","handler":"%s","result":"%s","ms":%s}\n' \
    "$(date -Iseconds)" "${HOOK_EVENT:-PreToolUse}" "$(basename "$0")" "$result" "$elapsed" \
    >> "${HOME}/.claude/hook-log.jsonl" 2>/dev/null || true
}

# --- Permanent session disable (escape valve) ---
if [ "${GIT_GUARDRAILS_DISABLE:-0}" = "1" ]; then
  _hook_log disabled
  exit 0
fi

# --- Read tool invocation from Claude Code ---
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

# Pass-through for non-Bash tools or empty commands
if [ "$TOOL_NAME" != "Bash" ] || [ -z "$COMMAND" ]; then
  _hook_log pass
  exit 0
fi

# --- One-shot bypass via env var on the wrapper invocation ---
if [ "${GIT_GUARDRAILS_BYPASS:-0}" = "1" ]; then
  _hook_log bypass
  exit 0
fi

# --- Helper: emit standardized block message and exit 2 ---
_block() {
  local reason="$1"
  local suggestion="$2"
  cat >&2 <<EOF
GIT GUARDRAILS — Operation blocked

Command: $COMMAND
Reason: $reason

Suggestion: $suggestion

To bypass once: GIT_GUARDRAILS_BYPASS=1 <your command>
To disable for session: export GIT_GUARDRAILS_DISABLE=1
EOF
  _hook_log block
  exit 2
}

# --- Pattern 1: force-push WITHOUT --force-with-lease ---
# Match `git push ... --force` or `git push ... -f` only when no lease present.
if echo "$COMMAND" | grep -qE 'git[[:space:]]+push([[:space:]]|$)'; then
  if echo "$COMMAND" | grep -qE '(--force([[:space:]]|$)|[[:space:]]-f([[:space:]]|$))'; then
    if ! echo "$COMMAND" | grep -qE -- '--force-with-lease'; then
      _block \
        "Force-push WITHOUT --force-with-lease (loses peer history without consent check)." \
        "Use --force-with-lease (safer): git push --force-with-lease origin <branch>, or open a PR."
    fi
  fi

  # --- Pattern 7: pushing directly to origin main/master (use PR) ---
  if echo "$COMMAND" | grep -qE 'git[[:space:]]+push[[:space:]].*origin[[:space:]]+(HEAD:)?(main|master)([[:space:]]|$)'; then
    _block \
      "Direct push to origin main/master (CI gate + branch protection bypassed)." \
      "Push your feature branch and open a PR: git push -u origin <feature-branch>"
  fi
fi

# --- Pattern 2: git reset --hard with explicit commit ref (HEAD safe) ---
# Allow: `git reset --hard`, `git reset --hard HEAD`, `git reset --hard HEAD~0`
# Block: `git reset --hard <sha>`, `git reset --hard origin/main`, `git reset --hard HEAD~5`
if echo "$COMMAND" | grep -qE 'git[[:space:]]+reset[[:space:]]+--hard([[:space:]]|$)'; then
  # Extract the arg after --hard (if any)
  TARGET=$(echo "$COMMAND" | sed -E 's/.*git[[:space:]]+reset[[:space:]]+--hard[[:space:]]*([^[:space:]&|;]*).*/\1/')
  case "$TARGET" in
    ""|"HEAD"|"HEAD~0"|"@")
      : # allow
      ;;
    *)
      _block \
        "git reset --hard with non-HEAD target ($TARGET) — destroys uncommitted work AND moves branch ref." \
        "Prefer: git stash + git reset (soft), or git reset --keep <ref>, or backup branch first."
      ;;
  esac
fi

# --- Pattern 3: rm -rf touching .git directory (irreversible repo destruction) ---
if echo "$COMMAND" | grep -qE 'rm[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*|-[a-zA-Z]*f[a-zA-Z]*r[a-zA-Z]*|-rf|-fr)([[:space:]]|$)'; then
  if echo "$COMMAND" | grep -qE '(^|[[:space:]/])\.git([[:space:]/]|$)'; then
    _block \
      "rm -rf targeting .git directory — destroys repository history irreversibly." \
      "If you want a clean slate, clone fresh into a new directory."
  fi
fi

# --- Pattern 4: git branch -D on local (unmerged delete) ---
# -D = force delete unmerged. -d = safe (rejects unmerged). Block -D unless --remotes/-r is also set.
if echo "$COMMAND" | grep -qE 'git[[:space:]]+branch[[:space:]]+(-[a-zA-Z]*D[a-zA-Z]*|-D)([[:space:]]|$)'; then
  if ! echo "$COMMAND" | grep -qE '(--remotes|[[:space:]]-r([[:space:]]|$))'; then
    _block \
      "git branch -D force-deletes a local branch even if unmerged (irreversible loss of commits)." \
      "Use git branch -d (safe — rejects if unmerged), or merge first, or create a backup tag: git tag archived/<branch> <branch>."
  fi
fi

# --- Pattern 5: git filter-branch / filter-repo --force (history rewrite) ---
if echo "$COMMAND" | grep -qE 'git[[:space:]]+filter-(branch|repo)'; then
  if echo "$COMMAND" | grep -qE -- '--force'; then
    _block \
      "git filter-branch/filter-repo --force rewrites history irreversibly across the repo." \
      "Confirm a backup mirror exists, then run via GIT_GUARDRAILS_BYPASS=1. Coordinate with team before push."
  fi
fi

# --- Default: allow ---
_hook_log pass
exit 0
