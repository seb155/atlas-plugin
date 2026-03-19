---
name: finishing-branch
description: "Complete development work: verify tests pass → intelligent commit (auto-detect type, conventional commits, exclude secrets) → present 4 options (merge/PR/keep/discard) → push → cleanup worktree → update INDEX."
effort: medium
---

# Finishing a Development Branch

## Process

### Step 1: Environment Health + Verify Tests Pass

**Pre-flight checks** (if workspace packages changed):
```bash
# If any frontend/packages/* files are staged, sync Docker workspace
if git diff --cached --name-only | grep -q "^frontend/packages/"; then
  docker exec synapse-frontend bun install
  docker restart synapse-frontend
  sleep 5
  curl -sf http://localhost:4000 > /dev/null || echo "⚠️ Frontend not responding"
fi
```

**Tests**:
```bash
docker exec synapse-backend bash -c "cd /app && python -m pytest tests/ -x -q --tb=short"
cd frontend && bunx vitest --run && bun run type-check
```

If tests FAIL → stop. Fix first.

### Step 2: Present 4 Options (AskUserQuestion)

| Option | Action |
|--------|--------|
| 1. Merge locally | `git checkout {base}` → `git merge --no-ff feature/{name}` → verify tests → delete branch → cleanup worktree |
| 2. Push + PR | `git push -u origin feature/{name}` → create Forgejo PR → keep worktree |
| 3. Keep as-is | No action, branch and worktree stay |
| 4. Discard | Require "discard" confirmation → delete branch + worktree |

### Step 3: Post-Integration

- Update `.blueprint/plans/INDEX.md` if tracked in plan → `plan({subsystem}): mark phase X complete`
- Add noticed improvements to `.blueprint/IMPROVEMENTS.md` (CRITICAL/IMPORTANT/NICE-TO-HAVE/SOTA)

## Forgejo PR Creation

> **CRITICAL**: ALWAYS use internal IP. External URL returns 302 (CF Access).

```bash
source ~/.env
FORGEJO_API="http://192.168.10.75:3000/api/v1"
# Create:  POST $FORGEJO_API/repos/{owner}/{repo}/pulls  {title, body, head, base}
# Merge:   POST $FORGEJO_API/repos/{owner}/{repo}/pulls/{N}/merge  {"do":"merge"}
# CI:      GET  $FORGEJO_API/repos/{owner}/{repo}/commits/{SHA}/status
```

| Gotcha | Detail |
|--------|--------|
| API URL | NEVER `https://forgejo.axoiq.com` — CF Access blocks |
| Token | `$FORGEJO_TOKEN` from `~/.env` — always source first |
| Merge field | lowercase `"do":"merge"` — uppercase returns 405 |
| Full ref | `.claude/references/forgejo-api.md` |

## Intelligent Commit (from /a-ship)

### Staging Rules

**NEVER `git add -A`.** Stage explicitly. **EXCLUDE**: `.env*`, `credentials*`, `secrets*`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `vaults/`, `node_modules/`, `__pycache__/`.

### Auto-Detect Commit Type

| Files Changed | Type | Scope |
|---------------|------|-------|
| New features/components | `feat` | Most common directory |
| Bug fixes | `fix` | Affected module |
| `*.md` in docs/.blueprint/ | `docs` | Subsystem |
| Config/deps | `chore` | Dependency name |
| Perf improvements | `perf` | Target area |
| Tests only | `test` | Module tested |
| Restructuring | `refactor` | Module |
| Build/CI | `build`/`ci` | Tool |
| Plans | `plan` | Subsystem |

Format: `<type>(<scope>): <summary>` + `Co-Authored-By: ATLAS AI <atlas@sgagnon.dev>`

### Push

`git push origin $(git branch --show-current)` — **NEVER force push**. If rejected: `git pull --rebase` then retry.

## HITL Gates

| When | Trigger | Options |
|------|---------|---------|
| Before commit | >20 files or mixed types | (a) Commit as proposed (b) Split (c) Edit msg (d) Abort |
| Before push | Always | Confirm branch + file count |
| After push | Always | (a) Monitor CI (b) Create PR (c) Deploy staging (d) Done |

## Safety Rules (NON-NEGOTIABLE)

1. Never force push
2. Never stage secrets
3. Warn on >50 files (AskUserQuestion)
4. Never skip pre-commit hooks
5. Never push to main directly (except HITL-approved hotfix)
