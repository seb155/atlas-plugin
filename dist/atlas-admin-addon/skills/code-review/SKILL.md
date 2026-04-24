---
name: code-review
description: "Unified code review and PR review, two-stage: spec → /ultrareview. This skill should be used when the user asks to 'review code', 'review this PR', 'code review', 'check for bugs', 'audit changes', 'review pull request', or mentions reviewing diffs, CLAUDE.md compliance, or checking code quality. Two modes: local (working tree diff) and PR (remote pull request). Stage 1 handles spec compliance; Stage 2 dispatches /ultrareview (CC 2.1.111+) for code quality."
effort: high
context: fork
agent: code-reviewer
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [senior-review-checklist, verification-before-completion, systematic-debugging]
thinking_mode: adaptive
---

# Code Review

<HARD-GATE>
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE.
If you have not run the verification command in this message, you cannot claim it passes.
Evidence before assertions, always.
</HARD-GATE>

<red-flags>
| Thought | Reality |
|---------|---------|
| "Tests should pass now, committing" | "Should pass" is a wish, not evidence. Confidence is not verification. Until the command runs and the output is read, you do not know — you hope. Run the exact verification command. Read the full output. Confirm exit 0 + 0 failures. Quote the evidence in your response BEFORE claiming success. |
| "Good enough, we can refactor later" | "Later" is the cemetery where good intentions go. Code merged ships to production. Every refactor-later is a mortgage with compound interest paid in incident reviews. If it is not refactor-ready today, it is not merge-ready today. |
| "The agent reported success, task is done" | Agent reports are NOT evidence. Agents can claim success while leaving an empty diff, broken tests, or uncommitted files. Trust but verify — always check the VCS diff independently. Run `git diff` or `git status`. Confirm actual file changes match the agent's report. |
| "Trust me, I've done this pattern 20 times" | Experience speeds recognition, not verification. The 20 previous times had 20 different contexts. This one has its own gotcha you have not met yet. Treat familiarity as a hypothesis, not a conclusion. Run the verification step anyway. |
</red-flags>

Unified code review combining local diff analysis and PR review into a single workflow.
Two modes: **local** (uncommitted/unpushed changes) and **PR** (remote pull request).

## Red Flags (rationalization check)

Before shortcutting code-review, ask yourself — are any of these thoughts running? If yes, STOP. "LGTM" without parallel agents produces false-confidence reviews that let bugs through.

| Thought | Reality |
|---------|---------|
| "LGTM, just a small diff" | Small diffs hide off-by-one, null deref, race conditions. Run the parallel agents. |
| "I already read the code once" | Reading ≠ reviewing. Review checks against CLAUDE.md rules + enterprise compliance. |
| "senior-review-checklist is overkill for this PR" | Only skip for trivial PRs (style-only, single-line). 50+ lines triggers full checklist. |
| "I'll skip the LSP blast-radius check" | Rename without findReferences = 30 silent call sites broken. |
| "Confidence 50 is fine to report" | Threshold is 75+. Below that = noise that buries real issues. |
| "Pattern compliance is a nit" | PATTERNS.md exists to PREVENT duplication. Flag it. |
| "Enterprise compliance is for production" | Multi-tenant project_id filter + RBAC gate MUST be on new endpoints from day 1. |
| "Posting PR comments doesn't need confirmation" | HITL: confirm via AskUserQuestion before posting. Delete is possible; un-publish is not. |
| "AI wrote this PR, the patterns must be fine" | AI clears `it works`, not `it respects the machine`. For diffs > 50 LoC with AI-generated portions, the AI-Perf Patterns dim (8th) of senior-review-checklist is **mandatory** — see step 2.25 below. |

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

### 2.25 Senior Review Checklist (mandatory for non-trivial PRs)

For PRs > 50 lines OR touching > 3 files, invoke the `senior-review-checklist`
skill as a mandatory step. It scores **8 dimensions** (correctness, design, SOLID,
naming, cohesion/coupling, testability, observability, **AI-Perf patterns**) and
produces a structured review output that informs the parallel agents below.

**AI-Perf Patterns dim (8th)** is especially load-bearing for AI-assisted PRs.
Detection heuristics for "AI-generated":
- Branch name suggests automation (`copilot/*`, `ai/*`, `claude-*`, `cursor-*`, `bot/*`)
- Commit author is an AI tool / matches AI-bot pattern
- PR description mentions AI assistance ("written with Claude", "Copilot suggested")
- Code style suggests AI verbosity (high comment-to-code ratio, defensive over-validation, generic naming)

When any of those signals match, **score dim 8 explicitly** (not just sample-checked).
Reference: `skills/performance-discipline/references/anti-patterns-from-plummer.md`
for the 8 anti-patterns + grep heuristics.

Skipped for trivial PRs (style-only, typo, single-line fix) — those go through
lint + quick sanity check only.

Senior-review-checklist reads:
- `skills/refs/code-smells-catalog/` for design smell detection
- `skills/refs/sota-architecture-patterns/` for architecture alignment
- `skills/performance-discipline/references/anti-patterns-from-plummer.md` for AI-Perf dim 8

### 2.5 Semantic Impact (LSP) — if available

If `ENABLE_LSP_TOOL=1` and relevant LSP installed, use LSP to scope
the BLAST RADIUS of changes before reviewing. Cheaper than grep + more accurate:

```
# For each renamed/modified identifier, check its callers:
LSP(operation: "findReferences", filePath: "{changed_file}", line: {identifier_line})

# For unfamiliar types/signatures in the diff:
LSP(operation: "hover", filePath: "{file}", line: {line})

# For "what does this function do" before reviewing its callers:
LSP(operation: "goToDefinition", filePath: "{file}", line: {line})
```

Use LSP output to inform reviewers on:
- Whether refactor touches 3 files or 30
- Type contract changes that break callers
- Missed call sites that should've been updated

LSP skipped when not installed — fall back to grep + pattern analysis.

### 3. Parallel Review (launch subagents)

For comprehensive reviews, launch 3 review agents **simultaneously** — one Agent tool
call per agent, all issued in the **same message**. Each agent gets a single focused
responsibility to avoid overlap and reduce false positives.

**Agent 1 — Bug & Logic Review**
```
subagent_type: general-purpose
model: sonnet
prompt: "Review this diff for correctness only. Focus on:
  - Logic errors and off-by-one bugs
  - Unhandled edge cases and null dereferences
  - Race conditions or async issues
  Ignore style, formatting, and patterns.
  Diff: {diff_content}"
```

**Agent 2 — Convention & Style Review**
```
subagent_type: general-purpose
model: sonnet
prompt: "Review this diff for convention compliance only. Focus on:
  - CLAUDE.md rule violations (rules provided below)
  - Naming conventions (kebab-case files, PascalCase components, use* hooks)
  - File size limits (hooks < 50 lines, components < 300 lines)
  - Import organization and barrel exports
  CLAUDE.md rules in scope: {claude_md_rules}
  Diff: {diff_content}"
```

**Agent 3 — Simplification Review**
```
subagent_type: general-purpose
model: sonnet
prompt: "Review this diff for complexity and DRY violations only. Focus on:
  - Duplicated logic that could be extracted to a shared hook/util
  - Overly complex conditionals that could be simplified
  - Dead code or unused variables introduced by this change
  - Opportunities to reuse existing patterns from PATTERNS.md
  Diff: {diff_content}"
```

**Agent 4 — Enterprise Compliance Review**
```
subagent_type: general-purpose
model: sonnet
prompt: "Review this diff for enterprise compliance only. Check:
  - Multi-tenancy: new endpoints filter by project_id?
  - Security: new endpoints have RBAC gate (Depends(verify_project_access))? Input validated with Pydantic schema?
  - Audit trail: mutations call log_audit()?
  - Data: new tables have project_id FK? Indexes on filtered columns?
  - Ops: new Docker services have healthcheck? Non-root user?
  - Frontend: no hardcoded strings? Error boundaries? ARIA labels?
  Reference: .claude/rules/enterprise-*.md
  Diff: {diff_content}"
```

**Agent 5 — Pattern Consistency** (if project has PATTERNS.md): Check changes follow established project patterns.

### 4. Consolidate Parallel Results

After all agents complete:
1. Deduplicate findings (same issue reported by 2 agents = 1 finding)
2. Apply confidence scoring below
3. Merge into a single structured report

### 5. Confidence Scoring
For each issue found, score confidence 0-100:
- **0-25**: Likely false positive or pre-existing
- **25-50**: Might be real, can't fully verify
- **50-75**: Real issue but minor / nitpick
- **75-100**: Confirmed real, impactful issue

**Filter threshold: 75+** — only report high-confidence issues.

### 6. Present Results
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

## Two-Stage Review Flow (v6.0)

Code review in ATLAS v6.0 is **two-stage mandatory** (Philosophy Engine):

### Stage 1 — Spec Compliance (this skill)
Verify the change aligns with requirements:
- All acceptance criteria met?
- All edge cases handled?
- API contract respected?
- Existing behavior preserved?

If Stage 1 fails → STOP, fix, retry. Do NOT proceed to Stage 2.

### Stage 2 — Code Quality (/ultrareview)
Once Stage 1 passes, invoke Claude Code native `/ultrareview` slash command:

```bash
# From within CC session, after spec-compliance stage passed:
/ultrareview
```

`/ultrareview` dispatches a senior reviewer (Opus max effort) who checks:
- Architecture & design patterns
- Performance & security
- Maintainability & readability
- Convention adherence

Use `/ultrareview` findings alongside `senior-review-checklist` skill for structured quality audit.

**Why two stages?**
Mixing spec-compliance and code-quality in one pass leads to spec violations slipping through when reviewer focuses on style. Separating ensures both dimensions get dedicated attention.

## HITL Gates

- Before posting PR comments → confirm with user via AskUserQuestion
- If review finds 0 issues → report that (don't invent issues)
- If unsure about severity → ask user to validate
