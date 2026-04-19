---
name: forgejo-pr
description: "Forgejo PR lifecycle manager. This skill should be used when the user asks to 'create a PR', 'merge PR', 'promote dev to main', 'rebase PR', '/forgejo-pr', or needs Forgejo-specific PR orchestration."
triggers:
  - "/atlas pr"
  - "/atlas promote"
  - "create PR"
  - "merge PR"
  - "promote dev to main"
  - "merge to main"
effort: low
---

# Forgejo PR Lifecycle

Automate the full PR workflow: create branch → push → create PR → rebase if behind → merge → cleanup.

## Commands

```bash
/atlas pr promote dev main              # Create + merge in one step
/atlas pr promote dev main --title "feat: my feature"
/atlas pr create "title" --head dev --base main
/atlas pr merge 150                     # Merge existing PR by number
/atlas pr status                        # Show open PRs
```

## Process

### Step 1: Read Configuration

```bash
# Source Forgejo credentials
source ~/.env 2>/dev/null
FORGEJO_API="${FORGEJO_INTERNAL_URL:-http://192.168.10.75:3000/api/v1}"
TOKEN="${FORGEJO_TOKEN}"

# Detect repo org/name from git remote
REMOTE_URL=$(git remote get-url origin)
# Extract org/repo from SSH or HTTP URL
ORG=$(echo "$REMOTE_URL" | grep -oP '(?<=/)[^/]+(?=/[^/]+\.git)' | tail -1)
REPO=$(echo "$REMOTE_URL" | grep -oP '[^/]+(?=\.git$)')
```

### Step 2: Promote Flow (create + merge)

When user runs `/atlas pr promote {head} {base}`:

1. **Create temporary promote branch** from head:
   ```bash
   git checkout {head}
   git pull origin {head}
   PROMOTE_BRANCH="promote/{head}-to-{base}-$(date +%Y-%m-%d)"
   git checkout -b $PROMOTE_BRANCH
   ```

2. **Rebase on base** to ensure up-to-date:
   ```bash
   git fetch origin {base}
   git rebase origin/{base}
   # If conflict → HITL gate: ask user to resolve
   git push --force-with-lease origin $PROMOTE_BRANCH
   ```

3. **Create PR via API**:
   ```bash
   PR_NUM=$(curl -s -X POST "${FORGEJO_API}/repos/${ORG}/${REPO}/pulls" \
     -H "Authorization: token ${TOKEN}" \
     -H "Content-Type: application/json" \
     -d "{\"title\":\"${TITLE}\",\"head\":\"${PROMOTE_BRANCH}\",\"base\":\"${BASE}\"}" \
     | python3 -c "import sys,json; print(json.load(sys.stdin).get('number',''))")
   ```

4. **Merge PR**:
   ```bash
   # Try merge, fallback to rebase
   RESULT=$(curl -s -X POST "${FORGEJO_API}/repos/${ORG}/${REPO}/pulls/${PR_NUM}/merge" \
     -H "Authorization: token ${TOKEN}" \
     -H "Content-Type: application/json" \
     -d '{"Do":"merge"}')

   # If "behind base branch" → rebase on base + force push + retry
   if echo "$RESULT" | grep -q "behind"; then
     git fetch origin {base} && git rebase origin/{base}
     git push --force-with-lease origin $PROMOTE_BRANCH
     # Retry merge with rebase strategy
     curl -s -X POST "${FORGEJO_API}/repos/${ORG}/${REPO}/pulls/${PR_NUM}/merge" \
       -H "Authorization: token ${TOKEN}" \
       -H "Content-Type: application/json" \
       -d '{"Do":"rebase"}'
   fi
   ```

5. **Cleanup**:
   ```bash
   git checkout {head}
   git branch -D $PROMOTE_BRANCH
   git push origin --delete $PROMOTE_BRANCH
   ```

### Step 3: Merge Existing PR

When user runs `/atlas pr merge {number}`:

```bash
# Check PR status
PR=$(curl -s "${FORGEJO_API}/repos/${ORG}/${REPO}/pulls/${NUMBER}" \
  -H "Authorization: token ${TOKEN}")
STATE=$(echo "$PR" | python3 -c "import sys,json; print(json.load(sys.stdin).get('state',''))")

if [ "$STATE" != "open" ]; then
  echo "PR #${NUMBER} is ${STATE}, not open"
  exit 1
fi

# Merge
curl -s -X POST "${FORGEJO_API}/repos/${ORG}/${REPO}/pulls/${NUMBER}/merge" \
  -H "Authorization: token ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"Do":"merge"}'
```

### Step 4: Status Check

When user runs `/atlas pr status`:

```bash
curl -s "${FORGEJO_API}/repos/${ORG}/${REPO}/pulls?state=open&limit=10" \
  -H "Authorization: token ${TOKEN}" | python3 -c "
import sys,json
prs=json.load(sys.stdin)
print(f'{len(prs)} open PRs:')
for p in prs:
    print(f'  #{p[\"number\"]:4d} {p[\"title\"][:60]}  ({p[\"head\"][\"ref\"]}→{p[\"base\"][\"ref\"]})')
"
```

## Error Handling

| Error | Action |
|-------|--------|
| "PR already exists" | Find existing PR, merge it instead |
| "behind base branch" | Auto-rebase + force push + retry merge |
| Merge conflict | HITL gate: show conflicts, ask user to resolve |
| Token missing | Error: "Set FORGEJO_TOKEN in ~/.env" |
| API unreachable | Error: "Forgejo at {URL} not responding" |

## HITL Gates

- **Merge conflicts**: Always ask user before resolving
- **Force push**: Show what will be overwritten
- **Merge to main**: Confirm PR title and commit count

## Related

- `finishing-branch` — Uses this skill for the PR step
- `ci-management` — Check CI before merging
- `.claude/references/forgejo-api.md` — API documentation
