---
name: code-review
description: "Unified code review and PR review. This skill should be used when the user asks to 'review code', 'review this PR', 'code review', 'check for bugs', 'audit changes', 'review pull request', or mentions reviewing diffs, CLAUDE.md compliance, or checking code quality. Two modes: local (working tree diff) and PR (remote pull request)."
---

# Code Review

Unified code review combining local diff analysis and PR review into a single workflow.
Two modes: **local** (uncommitted/unpushed changes) and **PR** (remote pull request).

## Mode Detection

- If user provides a PR number/URL → **PR mode**
- If user says "review my changes" / "review this code" without PR → **Local mode**
- If ambiguous → ask via AskUserQuestion

## Local Mode (Working Tree Review)

### 1. Gather Changes
```bash
git diff --stat                    # Unstaged changes
git diff --cached --stat           # Staged changes
git log --oneline origin/dev..HEAD # Unpushed commits
```

### 2. Load Context
- Read CLAUDE.md files in affected directories
- Read .claude/rules/ files relevant to changes
- Identify project conventions (linting, naming, patterns)

### 3. Parallel Review (launch subagents)
Launch 3-4 parallel Sonnet agents:

**Agent 1 — CLAUDE.md Compliance**: Audit changes against CLAUDE.md rules in scope. Only flag violations of explicit rules.

**Agent 2 — Bug Scanner**: Scan diff for obvious bugs. Focus on significant issues only. Ignore style, formatting, linter-catchable issues.

**Agent 3 — Logic & Security**: Look for incorrect logic, security issues, unhandled edge cases. Only flag issues within changed code.

**Agent 4 — Pattern Consistency** (if project has PATTERNS.md): Check changes follow established project patterns.

### 4. Confidence Scoring
For each issue found, score confidence 0-100:
- **0-25**: Likely false positive or pre-existing
- **25-50**: Might be real, can't fully verify
- **50-75**: Real issue but minor / nitpick
- **75-100**: Confirmed real, impactful issue

**Filter threshold: 75+** — only report high-confidence issues.

### 5. Present Results
Show findings grouped by severity. For each issue:
- File and line reference
- Brief description
- Why it matters (cite CLAUDE.md rule if applicable)
- Suggested fix (if straightforward)

If no issues: "No issues found. Checked for bugs, CLAUDE.md compliance, and pattern consistency."

## PR Mode (Pull Request Review)

### Prerequisites
- Git remote accessible (Forgejo or GitHub)
- `gh` CLI or Forgejo API available

### 1. Eligibility Check
Verify PR is:
- Not closed or draft
- Not already reviewed by this agent
- Not trivially simple (auto-generated, version bump)

### 2. Gather PR Context
```bash
gh pr view <PR> --json title,body,files
gh pr diff <PR>
```

### 3. Parallel Review (same as local, plus):

**Additional Agent — Historical Context**: Check git blame and previous PRs on affected files for recurring issues.

### 4. Validation Pass
For each issue from review agents, launch a validation subagent to confirm:
- The issue is real and not a false positive
- The issue is within changed code (not pre-existing)
- Any cited CLAUDE.md rule is actually in scope for the file

### 5. Post Results
- If `--comment` flag: post inline comments on PR
- Otherwise: display results in terminal

### Output Format (PR comments)
```markdown
## Code Review

Found N issues:

1. **{description}** (CLAUDE.md: "{rule}")
   {file link with full SHA}

2. **{description}** (bug: {evidence})
   {file link with full SHA}
```

## False Positive Checklist (DO NOT flag)

- Pre-existing issues not introduced by this change
- Style/formatting (linter catches these)
- General code quality (unless CLAUDE.md requires it)
- Intentional functional changes related to the PR purpose
- Issues on unmodified lines
- Speculative issues that depend on unknown runtime state

## HITL Gates

- Before posting PR comments → confirm with user via AskUserQuestion
- If review finds 0 issues → report that (don't invent issues)
- If unsure about severity → ask user to validate
