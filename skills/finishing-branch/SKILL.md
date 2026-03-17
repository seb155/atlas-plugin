---
name: finishing-branch
description: "Complete development work: verify tests pass → intelligent commit (auto-detect type, conventional commits, exclude secrets) → present 4 options (merge/PR/keep/discard) → push → cleanup worktree → update INDEX."
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

---

## Intelligent Commit & Push (from /a-ship)

Zero-friction git workflow with smart commit message generation and safety guards.

### Commit Workflow

#### 1. Check Status
```bash
git status --short
```
If no changes → inform user and stop.

#### 2. Stage Changes INTELLIGENTLY

**NEVER use `git add -A`.** Always stage explicitly:

1. Run `git status` to list changed files
2. **EXCLUDE** (never stage):
   - `.env*`, `credentials*`, `secrets*`
   - `*.pem`, `*.key`, `*.p12`, `*.pfx`
   - `vaults/`, `node_modules/`, `__pycache__/`
3. Stage remaining files by name: `git add <file1> <file2> ...`
4. If >20 files, group by directory for readability in the commit

#### 3. Auto-Detect Commit Type

| Files Changed | Type | Example |
|---------------|------|---------|
| New features, components, pages | `feat` | `feat(search): add BM25 omnisearch` |
| Bug fixes, error corrections | `fix` | `fix(import): handle empty CSV rows` |
| `*.md` in docs/ or .blueprint/ | `docs` | `docs(blueprint): update MODULES.md` |
| Config files, dependencies | `chore` | `chore(deps): bump AG Grid to v35` |
| Performance improvements | `perf` | `perf(query): add composite index` |
| Test files only | `test` | `test(api): add spec group coverage` |
| Code restructuring (no behavior change) | `refactor` | `refactor(hooks): extract useGridConfig` |
| Build/CI changes | `build` / `ci` | `ci(forgejo): add lint step` |
| Plan files | `plan` | `plan(rule-engine): add AI auto-tune` |

#### 4. Generate Conventional Commit Message

Format: `<type>(<scope>): <summary>`

- **type**: Auto-detected from changed files (see table above)
- **scope**: Auto-detected from directories (most common directory in changes)
- **summary**: Concise description of what changed (imperative mood)
- **Co-Author**: Append `Co-Authored-By: ATLAS AI <atlas@sgagnon.dev>`

```bash
git commit -m "<type>(<scope>): <summary>

Co-Authored-By: ATLAS AI <atlas@sgagnon.dev>"
```

#### 5. Push

```bash
git push origin $(git branch --show-current)
```

**NEVER force push.** If push fails due to remote changes:
```bash
git pull --rebase origin $(git branch --show-current)
# Then retry push
```

#### 6. Output Summary

```
┌─────────────────────────────────────────────────────────────────┐
│ SHIP COMPLETE                                                    │
├─────────────────────────────────────────────────────────────────┤
│ repo    │ N files │ type(scope): summary message       │ ✅     │
├─────────────────────────────────────────────────────────────────┤
│ CI will run. Use ci-feedback-loop to monitor.                    │
│ Before ending session: run session-retrospective                 │
└─────────────────────────────────────────────────────────────────┘
```

### Safety Rules (NON-NEGOTIABLE)

1. **Never force push** — `git push --force` is forbidden
2. **Never stage secrets** — `.env*`, `credentials*`, `secrets*`, `*.pem`, `*.key` are excluded
3. **Warn on large commits** — If >50 files, AskUserQuestion for confirmation before committing
4. **Pre-commit hooks respected** — Never skip with `--no-verify`
5. **Never push to main directly** — Must go through PR (except emergency hotfix with HITL approval)

### Dry Run Mode

`--dry` flag shows what would be shipped without committing:

```bash
# Show staged changes and proposed commit message
git status --short
# Display: "Would commit as: feat(search): add BM25 omnisearch"
# Display: "Would push to: origin/feature/omnisearch"
```

### HITL Gates

**Before commit** (if >20 files or mixed types):
```
AskUserQuestion: "I detected {N} changed files across {M} types. Proposed commit:
  {type}({scope}): {summary}
Options:
(a) Commit as proposed
(b) Split into multiple commits (suggest split)
(c) Edit the commit message
(d) Abort"
```

**Before push** (always):
```
AskUserQuestion: "Ready to push to {branch}. {N} files, commit: {hash}.
Proceed with push?"
```

**After push**:
```
AskUserQuestion: "Pushed to {branch}. CI will run.
(a) Monitor CI (ci-feedback-loop)
(b) Create PR to dev
(c) Deploy to staging (devops-deploy)
(d) Done for now"
```

If `.atlas/deploy.yaml` exists, also show deploy option with environment names.
