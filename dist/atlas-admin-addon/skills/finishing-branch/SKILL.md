---
name: finishing-branch
description: "Development branch finisher. This skill should be used when the user asks to 'finish the branch', 'ship this work', 'complete feature', '/finishing-branch', or when tests pass and the branch is ready to merge, PR, keep, or discard."
effort: medium
---

# Finishing a Development Branch

## Red Flags (rationalization check)

Before skipping finishing-branch or shortcutting its gates, ask yourself — are any of these thoughts running? If yes, STOP. Shipping broken branches is how you become the reason for an outage.

| Thought | Reality |
|---------|---------|
| "Just push and move on" | `git push` is not "done". DoD tier, enterprise audit, and CI must be green. |
| "Tests probably still pass since I only changed one file" | Run them. Workspace packages need `bun install` + restart on change. |
| "I'll force-push to fix history" | NEVER force-push. Rebase local, pull --rebase if behind. |
| "Merge to main bypasses the dev gate" | `dev` is the staging branch. Main only via PR with CI green. No exceptions. |
| "Skip the DoD check, it's a quick fix" | Tier 1 incomplete (<20%) BLOCKS merge. Even for one-line fixes. |
| "Enterprise audit is paranoid for this PR" | `toolkit.audit --fail-on critical` catches project_id/healthcheck gaps. Run it. |
| "I'll `git add -A` just this once" | NEVER. Explicit staging. Exclude .env*, credentials*, *.pem. Secrets leak irreversibly. |
| "Friday 15:00 EDT doesn't apply to this hotfix" | Check `.claude/rules/no-ship-friday.md`. Document exception in `decisions.jsonl`. |

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

### Step 2.5: Topic Memory Preservation (SP-ECO v4)

**Before** any worktree cleanup or branch deletion, preserve topic memory:

```bash
# Check if we're in a worktree with topic memory
TOPIC="${ATLAS_TOPIC:-}"
WORKTREE_TOPIC_DIR=".claude/topics/${TOPIC}"
MAIN_REPO=$(git worktree list --porcelain 2>/dev/null | head -1 | awk '{print $2}')

if [ -n "$TOPIC" ] && [ -d "$WORKTREE_TOPIC_DIR" ] && [ -n "$MAIN_REPO" ]; then
  MAIN_TOPIC_DIR="${MAIN_REPO}/.claude/topics/${TOPIC}"

  echo "Preserving topic memory: ${TOPIC}"
  mkdir -p "$MAIN_TOPIC_DIR"

  # Copy topic files to main repo (merge, don't overwrite)
  for f in decisions.md lessons.md context.md; do
    if [ -f "$WORKTREE_TOPIC_DIR/$f" ]; then
      if [ -f "$MAIN_TOPIC_DIR/$f" ]; then
        # Append new content (avoid duplication with header check)
        echo "" >> "$MAIN_TOPIC_DIR/$f"
        echo "---" >> "$MAIN_TOPIC_DIR/$f"
        echo "<!-- Merged from worktree $(date -Iseconds) -->" >> "$MAIN_TOPIC_DIR/$f"
        cat "$WORKTREE_TOPIC_DIR/$f" >> "$MAIN_TOPIC_DIR/$f"
      else
        cp "$WORKTREE_TOPIC_DIR/$f" "$MAIN_TOPIC_DIR/$f"
      fi
    fi
  done

  # Copy handoffs (additive)
  if [ -d "$WORKTREE_TOPIC_DIR/handoffs" ]; then
    mkdir -p "$MAIN_TOPIC_DIR/handoffs"
    cp -n "$WORKTREE_TOPIC_DIR/handoffs/"* "$MAIN_TOPIC_DIR/handoffs/" 2>/dev/null || true
  fi

  echo "Topic memory preserved to: $MAIN_TOPIC_DIR"
fi

# Update topics.json status
if [ -n "$TOPIC" ]; then
  python3 -c "
import json, os
from datetime import datetime
topics_file = os.path.expanduser('~/.atlas/topics.json')
if os.path.exists(topics_file):
    with open(topics_file) as f:
        topics = json.load(f)
    if '${TOPIC}' in topics:
        topics['${TOPIC}']['status'] = 'completed'
        topics['${TOPIC}']['completedAt'] = datetime.now().isoformat()
        with open(topics_file, 'w') as f:
            json.dump(topics, f, indent=2)
" 2>/dev/null
fi
```

**Rules**:
- ALWAYS preserve topic memory before worktree removal (Options 1 and 4)
- For Option 2 (PR): keep worktree, topic memory stays in place
- For Option 3 (keep): no action needed, topic memory stays
- Merge strategy: append to existing files (don't overwrite)

### Step 3: Post-Integration

- Update `.blueprint/plans/INDEX.md` if tracked in plan → `plan({subsystem}): mark phase X complete`
- Add noticed improvements to `.blueprint/IMPROVEMENTS.md` (CRITICAL/IMPORTANT/NICE-TO-HAVE/SOTA)

## Forgejo PR Creation

> **CRITICAL**: ALWAYS use internal IP. External URL returns 302 (CF Access).

```bash
source ~/.env
# Config helper — read from ~/.atlas/config.json with fallback
atlas_config() {
  local key="$1" fallback="${2:-}"
  python3 -c "
import json, os
try:
    with open(os.path.expanduser('~/.atlas/config.json')) as f:
        d = json.load(f)
    keys = '$key'.split('.')
    v = d
    for k in keys: v = v[k]
    if isinstance(v, list): print(' '.join(v))
    else: print(v)
except: print('$fallback')
" 2>/dev/null || echo "$fallback"
}

FORGEJO_URL=$(atlas_config "services.forgejo.local_url" "")
FORGEJO_API_PATH=$(atlas_config "services.forgejo.api_path" "/api/v1")
FORGEJO_API="${FORGEJO_URL}${FORGEJO_API_PATH}"
# Create:  POST $FORGEJO_API/repos/{owner}/{repo}/pulls  {title, body, head, base}
# Merge:   POST $FORGEJO_API/repos/{owner}/{repo}/pulls/{N}/merge  {"do":"merge"}
# CI:      GET  $FORGEJO_API/repos/{owner}/{repo}/commits/{SHA}/status
```

| Gotcha | Detail |
|--------|--------|
| API URL | Use local_url from config — external URL may be blocked by CF Access |
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

Format: `<type>(<scope>): <summary>` + `Co-Authored-By: $(atlas_config "identity.co_author_name" "ATLAS AI") <$(atlas_config "identity.co_author_email" "")>`

### Push

`git push origin $(git branch --show-current)` — **NEVER force push**. If rejected: `git pull --rebase` then retry.

## DoD Gate (Pre-merge)

Before merging, check DoD Tier 1 (CODED) is complete:

```bash
# Auth: X-Admin-Token (env: SYNAPSE_ADMIN_TOKEN, Vault-sourced in prod)
BACKEND="http://localhost:8001"
ADMIN_TOKEN="${SYNAPSE_ADMIN_TOKEN:-synapse-dev-admin-2026}"

# Verify DoD Tier 1 for the feature being merged
curl -s "$BACKEND/api/v1/admin/atlas-dev/features/{FEAT_ID}" \
  -H "X-Admin-Token: $ADMIN_TOKEN" | python3 -c "
import json, sys
f = json.load(sys.stdin)
score, tier = f.get('dod_score', 0), f.get('dod_tier', 'CODED')
print(f'DoD Score: {score}% → {tier}')
if score < 20:
    print('⚠️  Tier 1 (CODED) incomplete — block merge')
    sys.exit(1)
print('✅ Tier 1 complete — safe to merge')
"
```

| DoD Tier | Merge Policy |
|----------|-------------|
| < 20% (Tier 1 incomplete) | BLOCK — code layers must pass before merge |
| 20-80% (VALIDATING) | Allow merge to dev — validation continues on dev |
| 81-99% (VALIDATED) | Allow merge to main — ready for deploy |
| 100% (SHIPPED) | Auto-deploy candidate |

## Enterprise Gate (Pre-merge)

Before creating PR or merging, run quick enterprise audit:

```bash
python3 -m toolkit.audit --ci --fail-on critical --format json
```

| Result | Action |
|--------|--------|
| 0 CRITICAL | Proceed with merge/PR |
| 1+ CRITICAL | BLOCK — show findings via AskUserQuestion, fix before proceeding |
| WARN only | Show summary, proceed with acknowledgment |

This gate catches:
- Missing project_id on new endpoints (MT-002)
- Missing healthchecks on new Docker services (DEP-002)
- Hardcoded secrets or CORS wildcards (SEC-003, SEC-002)

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
