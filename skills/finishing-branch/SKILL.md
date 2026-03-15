---
name: finishing-branch
description: "Complete development work: verify tests pass → present 4 options (merge/PR/keep/discard) → execute choice → cleanup worktree → update INDEX."
---

# Finishing a Development Branch

## Overview

After all implementation tasks are complete, guide the user through finishing the work: verify, choose integration strategy, execute, cleanup.

## Process

### Step 1: Verify Tests Pass
```bash
# Backend
docker exec synapse-backend bash -c "cd /app && python -m pytest tests/ -x -q --tb=short"

# Frontend
cd frontend && bunx vitest --run && bun run type-check
```

If tests FAIL → cannot proceed. Show failures. Fix first.

### Step 2: Present 4 Options

Use AskUserQuestion:

```
How do you want to integrate this work?

1. Merge back to {base-branch} locally
   → Merge + verify tests + delete branch + cleanup worktree

2. Push and create Pull Request
   → Push branch + create PR on Forgejo + keep worktree

3. Keep the branch as-is
   → Don't merge, don't push. Keep for later.

4. Discard this work
   → Delete branch + cleanup worktree (requires confirmation)
```

### Step 3: Execute Choice

**Option 1 — Local Merge:**
```bash
git checkout {base-branch}
git merge --no-ff feature/{name}
# Run tests again to verify
git branch -d feature/{name}
# Cleanup worktree
```

**Option 2 — Push + PR:**
```bash
git push -u origin feature/{name}
# Create PR on Forgejo via API or manual
# Keep worktree alive for iteration
```

**Option 3 — Keep:**
- No action. Branch and worktree stay.

**Option 4 — Discard:**
- Require user to type "discard" to confirm
- Delete branch and cleanup worktree

### Step 4: Update Plans Index
If the work was tracked in a plan:
- Update `.blueprint/plans/INDEX.md` → status change
- Commit: `plan({subsystem}): mark phase X complete`

### Step 5: Note Improvements
If any improvements/tech debt was noticed during implementation:
- Add to `.blueprint/IMPROVEMENTS.md`
- Categorize: CRITICAL / IMPORTANT / NICE-TO-HAVE / SOTA

## Forgejo PR Creation

```bash
# Via Forgejo API (if available)
curl -X POST "https://forgejo.axoiq.com/api/v1/repos/{owner}/{repo}/pulls" \
  -H "Authorization: token $FORGEJO_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "feat({subsystem}): {description}",
    "body": "## Summary\n{plan reference}\n\n## Changes\n{file list}",
    "head": "feature/{name}",
    "base": "dev"
  }'
```
