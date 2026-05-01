---
name: git-guardrails
description: "Git safety guardrails companion skill. Use when the user says 'check git safety', 'why was my push blocked', 'git guardrails status', 'bypass guardrails', or when investigating a PreToolUse block on a git/rm command. Explains what is blocked, why, and how to bypass safely."
effort: low
version: 1.0.0
tier: [admin]
attribution: "Cherry-picked from mattpocock/skills (misc/git-guardrails-claude-code, MIT). See CREDITS.md."
---

# Git Guardrails

PreToolUse hook that blocks dangerous git operations before they execute.
Lives at `hooks/git-guardrails.sh` and runs on every Bash tool invocation.

## What gets blocked

| # | Pattern | Reason |
|---|---------|--------|
| 1 | `git push --force` (no `--force-with-lease`) | Stomps peer history without consent check |
| 2 | `git push origin main` / `master` (direct) | Bypasses CI gate + branch protection |
| 3 | `git reset --hard <sha\|ref>` (non-HEAD) | Destroys uncommitted work AND moves branch ref |
| 4 | `rm -rf .git` (any path) | Irreversible repo destruction |
| 5 | `git branch -D` (without `-r/--remotes`) | Force-deletes unmerged local commits |
| 6 | `git filter-branch \| filter-repo --force` | History rewrite across the repo |

Safe variants pass through unchanged: `--force-with-lease`, `git reset --hard HEAD`,
`git branch -d` (lower-d), `git push -u origin feat/...`.

## What is NOT blocked (deliberately)

- `git push -u origin <feature-branch>` — your normal workflow
- `git reset --hard HEAD` / `git reset --hard` (no target = HEAD)
- `git checkout -- <file>` — local-only discard
- `git rebase -i` — interactive only, no force
- `git commit --amend` — local commit, push gate catches dangerous re-push

## How to bypass

Two escape valves, ordered by safety:

```bash
# One-shot: bypass for THIS command only
GIT_GUARDRAILS_BYPASS=1 git push --force origin main

# Session-wide: disable until shell exits (use sparingly)
export GIT_GUARDRAILS_DISABLE=1
```

The hook logs every block / bypass / disable to `~/.claude/hook-log.jsonl`
so you can audit your own escapes.

## Why these specific patterns

Every blocked pattern matches a real Synapse incident:

- **feedback_merge_before_delete.md** — worktree force-removal w/ unmerged commits → branch -D guard
- **lesson_strategy_theirs_old_commits.md** — old commits as targets → reset --hard guard
- **commit ecbd2bce0** (380-skeleton deletion) — wide rm in repo → rm -rf .git guard
- **lesson_oauth_refresh_token_race.md** — direct main pushes during CI fragility → main-push guard

## Companion files

- Hook: `hooks/git-guardrails.sh` (Bash, ShellCheck-clean)
- Hook registration: `hooks/hooks.json` PreToolUse(Bash) chain
- This SKILL: `skills/git-guardrails/SKILL.md`
- Source pattern: https://github.com/mattpocock/skills (misc/git-guardrails-claude-code, MIT)

## Troubleshooting

**Q: Hook blocks something safe.**
A: Bypass once with `GIT_GUARDRAILS_BYPASS=1`, file an issue with the exact command,
and reference this SKILL. Pattern can be tightened in next iteration.

**Q: I want to disable it permanently.**
A: Don't. Set `GIT_GUARDRAILS_DISABLE=1` in a long-lived shell only when
intentionally rewriting history (e.g., scrubbing a leaked secret with filter-repo).
Re-enable as soon as the operation completes.

**Q: Does it block in CI?**
A: No. CI runs hooks only if Claude Code itself is invoking them. CI scripts
calling git directly are unaffected. Use Forgejo branch protection for CI.

## Exit codes

- `0` = allow (pass-through OR bypass active OR pattern not matched)
- `2` = block (Claude Code PreToolUse blocking convention)

The hook never exits non-zero for non-Bash tools — it's a strict Bash-only guard.
