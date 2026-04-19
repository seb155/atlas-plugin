---
name: ship-all
description: "Full-repository ship orchestrator. This skill should be used when the user asks to 'ship all', 'grand menage', 'nettoyer le repo', 'clean repo', 'deploy everything', 'sync all envs', 'merge and deploy', or 'cleanup branches'."
argument-hint: "[--dry-run] [--skip-deploy] [--aggressive]"
effort: medium
---

# Ship All — Full Repository Ship & Deploy Pipeline

## Overview

Ship All is the "grand menage" skill. It audits the entire repository state, presents a cleanup plan, executes it with safety gates, deploys to all environments, and verifies health. Think of it as `finishing-branch` but for the ENTIRE repo — not just one branch.

**5-Phase Pipeline:**
```
SAFETY → AUDIT → PLAN → EXECUTE → DEPLOY → VERIFY
```

**When to use:**
- End of sprint / milestone — ship everything clean
- Multiple stale branches / worktrees accumulated
- dev and main are out of sync
- PRs need merging and deploying
- "I want everything clean and deployed"

**Modes:**
- `--dry-run`: Show what WOULD be done without executing
- `--skip-deploy`: Clean repo only, don't deploy to environments
- `--aggressive`: Auto-decide (discard dirty files, delete all merged branches, clear stashes)

## Phase 0: Safety Checkpoint

Before ANY destructive operation:

```bash
# Create recovery tags
git tag safety/pre-ship-dev dev
git tag safety/pre-ship-main main
git push origin safety/pre-ship-dev safety/pre-ship-main
```

**Rollback:** `git reset --hard safety/pre-ship-dev` at any point to restore.

Document the rollback point in the task list. Safety tags survive `git gc` because they're named refs.

## Phase 1: Audit

Run a comprehensive scan and present findings in a structured table.

### Git State Scan

```bash
# Branches (local + remote, sorted by date)
git branch -a --sort=-committerdate

# Worktrees
git worktree list

# Stashes
git stash list

# Dirty files
git status --short

# Branch divergence
git log main..dev --oneline | wc -l    # dev ahead of main
git log dev..main --oneline | wc -l    # main ahead of dev

# Tags
git tag --sort=-creatordate | head -10
```

### Forgejo API Scan

```bash
source ~/.env 2>/dev/null
# Open PRs
curl -sf "${FORGEJO_URL}/api/v1/repos/${FORGEJO_ORG}/${REPO}/pulls?state=open" \
  -H "Authorization: token ${FORGEJO_TOKEN}"

# CI status (recent runs)
curl -sf "${FORGEJO_URL}/api/v1/repos/${FORGEJO_ORG}/${REPO}/actions/tasks?limit=10" \
  -H "Authorization: token ${FORGEJO_TOKEN}"
```

### Identify Stale Refs

A branch is "stale" if:
- Fully merged into main AND dev (`git branch --merged main`)
- Is a worktree branch (`worktree-*`) with no corresponding worktree
- Has no commits in >30 days and is merged

A worktree is "stale" if:
- Its branch no longer exists
- It has no uncommitted changes AND its branch is merged
- It's a CC session worktree (`.claude/worktrees/*`) from a past session

### Present Audit Results

Use a compact table via AskUserQuestion:

```
| Category        | Count | Action Needed |
|-----------------|-------|---------------|
| Local branches  | N     | M stale       |
| Remote branches | N     | M stale       |
| Worktrees       | N     | M removable   |
| Stashes         | N     | M orphaned    |
| Dirty files     | N     | commit/discard|
| Open PRs        | N     | M mergeable   |
| dev↔main sync   | N ahead, M behind | sync needed |
```

## Phase 2: Plan (HITL Gate)

Present cleanup decisions via AskUserQuestion. Group by category:

### Dirty Files Decision
For each dirty file, recommend: commit (meaningful change), discard (noise/cache), or skip (other session's work).

**Auto-discard candidates:** `*.pyc`, `test-results.json`, `*.lock` (if not committed), `dist/` build artifacts.

### Branch Decisions
Show each stale branch with its last commit date and merge status. Recommend: delete (merged), keep (active work), or HITL (unclear).

**Safety:** Always use `git branch -d` (lowercase). Never `-D` unless user explicitly confirms unmerged deletion.

### Worktree Decisions
For each removable worktree: remove (clean + merged), keep (locked/active), or evaluate (dirty).

**Safety:** Never delete locked worktrees. Check for uncommitted changes before removal.

### PR Decisions
For each open PR: merge (mergeable + CI green), close (conflicts + obsolete), or keep (active work).

**Safety:** Always AskUserQuestion before merging to main (triggers prod deploy).

### Stash Decisions
Show each stash with its source branch. If the source branch no longer exists → orphaned → recommend drop.

## Phase 3: Execute

Execute in strict order (dependencies matter):

### 3.1 Sync Branches
```bash
git fetch --all --prune
git fetch origin main:main          # ff main without checkout
git stash push -m "pre-ship"        # stash dirty files if needed
git pull --ff-only origin dev       # ff dev
git stash pop                       # restore dirty files
```

### 3.2 Handle Dirty Files
Per Phase 2 decisions: `git checkout -- <file>` (discard) or `git add + commit` (commit).

### 3.3 Clean Worktrees
```bash
git worktree remove <path> [--force]    # force only if user confirmed dirty discard
git branch -d <worktree-branch>          # delete associated branch
```

### 3.4 Clean Branches (local + remote)
```bash
git branch -d <branch>                         # local (safe: refuses unmerged)
git push origin --delete <branch>               # remote
```

### 3.5 Clean Stashes
```bash
git stash clear          # if user confirmed clear-all
# OR
git stash drop stash@{N} # selective
```

### 3.6 Git Housekeeping
```bash
git gc --prune=now
```

## Phase 4: Deploy (skip with --skip-deploy)

### 4.1 Push dev → staging + sandbox
```bash
git push origin dev
# CI auto-deploys to staging (VM 801) + sandbox (VM 802)
```

### 4.2 Wait for CI
Monitor Forgejo Actions or Telegram notifications. Max wait: 20 min.

### 4.3 Verify staging healthy
```bash
curl -sf http://<staging-host>:<port>/api/v1/health
```

### 4.4 Merge dev → main (HITL GATE)
**ALWAYS AskUserQuestion before this step.** This triggers production deploy.

```bash
# Sync dev with main first (prevent "head behind base" error)
git merge main && git push origin dev

# Create + merge PR via Forgejo API
curl -X POST "${FORGEJO_URL}/api/v1/repos/${ORG}/${REPO}/pulls" ...
curl -X POST "${FORGEJO_URL}/api/v1/repos/${ORG}/${REPO}/pulls/${PR}/merge" ...

# Sync local main
git fetch origin main:main
git merge main && git push origin dev    # keep in sync
```

### 4.5 Verify production healthy
```bash
curl -sf https://<prod-url>/api/v1/health
```

**If prod fails:** Check deploy script issues (branch mismatch, stale containers). Use SSH jump host if direct access fails:
```bash
ssh -J root@<pve-host> root@<prod-vm> "docker compose -f <compose> --env-file <env> ps"
```

## Phase 5: Verify

### Final State Report

```
╔══════════════════════════════════════════════════════════════╗
║  SHIP-ALL COMPLETE — YYYY-MM-DD HH:MM TZ                    ║
╠══════════════════════════════════════════════════════════════╣
║                    BEFORE         →         AFTER             ║
║  Branches:    N                  →   M                       ║
║  Worktrees:   N                  →   M                       ║
║  Stashes:     N                  →   M                       ║
║  Dirty files: N                  →   M                       ║
║  PRs open:    N                  →   M                       ║
║  dev↔main:    X ahead/Y behind  →   0/0 (synced)            ║
╠══════════════════════════════════════════════════════════════╣
║  ENVIRONMENTS                                                ║
║  Local:     ✅/❌                                             ║
║  Staging:   ✅/❌                                             ║
║  Sandbox:   ✅/❌                                             ║
║  Production:✅/❌                                             ║
╚══════════════════════════════════════════════════════════════╝
```

### Cleanup Safety Tags (remind user)
After 1 week, remove safety tags:
```bash
git tag -d safety/pre-ship-dev safety/pre-ship-main
git push origin --delete safety/pre-ship-dev safety/pre-ship-main
```

## Safety Rules (NON-NEGOTIABLE)

1. **ALWAYS** create safety tags before destructive operations
2. **ALWAYS** use `git branch -d` (lowercase) — refuses to delete unmerged branches
3. **ALWAYS** `--force-recreate --remove-orphans` on docker compose up
4. **ALWAYS** validate branch before `git reset --hard` (check current != expected → switch)
5. **ALWAYS** AskUserQuestion before merging to main (prod deploy)
6. **NEVER** delete locked worktrees
7. **NEVER** delete branches with open PRs (unless user explicitly closes the PR)
8. **NEVER** force-push to shared branches (main, dev)
9. **`--dry-run`**: Show the full plan without executing. Exit after Phase 2.

## Deploy Script Requirements

The deploy script (`scripts/deploy.sh`) MUST:
- Validate branch before `git reset --hard` (switch if mismatched)
- Use `--force-recreate --remove-orphans` on all `docker compose up`
- Check staging health before deploying to prod
- Auto-rollback on health check failure

If these safeguards are missing, warn the user and offer to fix the deploy script first.

## Integration with Other Skills

- **finishing-branch**: Ships ONE branch. Ship-all ships the ENTIRE repo.
- **devops-deploy**: Handles deployment mechanics. Ship-all orchestrates the full pipeline including cleanup.
- **git-worktrees**: Creates worktrees. Ship-all removes stale ones.
- **ci-management**: Monitors CI. Ship-all uses health checks as deploy gates.
