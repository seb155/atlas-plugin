# /ship - Quick Commit & Push

Ship changes to remote. Zero-friction git workflow.

## Usage

```
/ship              # Ship current repo (auto-detect from cwd)
/ship --dry        # Show what would be shipped (no commit)
```

## Workflow

When `/ship` is invoked:

### 1. Check Status
```bash
git status --short
```

If no changes, inform user and stop.

### 2. Stage & Commit
```bash
# Stage changes INTELLIGENTLY (never git add -A)
# 1. Run git status to list changed files
# 2. EXCLUDE: .env*, credentials*, secrets*, *.pem, *.key, vaults/
# 3. Stage remaining files by name: git add <file1> <file2> ...
# 4. If >20 files, group by directory for readability

# Commit with auto-generated message
git commit -m "<type>(<scope>): <summary>

Co-Authored-By: ATLAS AI <atlas@sgagnon.dev>"
```

### 3. Push
```bash
git push origin $(git branch --show-current)
```

### 4. Output Summary
```
┌─────────────────────────────────────────────────────────────────┐
│ 🚀 SHIP COMPLETE                                                │
├─────────────────────────────────────────────────────────────────┤
│ repo    │ N files │ type: summary message            │ ✅       │
├─────────────────────────────────────────────────────────────────┤
│ 📡 CI will run. Use ci-feedback-loop to monitor.                │
│ 📝 Before ending session: run session-retrospective             │
└─────────────────────────────────────────────────────────────────┘
```

## Commit Type Detection

| Files Changed | Type |
|---------------|------|
| New features, components | `feat:` |
| Bug fixes | `fix:` |
| `*.md` in docs/ | `docs:` |
| Config files, mixed | `chore:` |
| Performance improvements | `perf:` |
| Tests | `test:` |
| Refactoring | `refactor:` |

## Safety Rules

1. **Never force push**
2. **Skip sensitive files** — `.env*`, `credentials*`, `secrets*`
3. **Warn on large commits** — If >50 files, ask confirmation
4. **Pre-commit hooks respected**

ARGUMENTS: $ARGUMENTS
