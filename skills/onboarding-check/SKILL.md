---
name: onboarding-check
description: "Team readiness assessment (12 checks). This skill should be used when the user asks to '/atlas onboard', 'team readiness', 'onboarding check', 'new developer', 'discipline engineer onboard', or needs an A-F score across docs/dev/CI/Forgejo."
effort: medium
---

# Onboarding Check — Team Readiness Assessment

Validates whether the project is ready for a new team member to contribute.
Scores 12 dimensions across Documentation, Environment, Workflow, and Team Support.

## When to Use

- User says "onboard", "onboarding", "ready for new dev", "team ready"
- User says "contributing", "CONTRIBUTING.md", "dev setup", "first commit"
- Before a new developer joins the team
- After major infrastructure changes (CI, auth, env)
- Periodically (quarterly recommended)

## Subcommands

| Command | Mode | Output |
|---------|------|--------|
| `/atlas onboard` | **Full Check** | 12-dimension scorecard + grade |
| `/atlas onboard gaps` | **Gap List** | Actionable list of missing items to fix |
| `/atlas onboard fix` | **Auto-Fix** | Create missing docs/configs with HITL approval |
| `/atlas onboard simulate` | **Dry Run** | Simulate fresh clone → first commit path |

## Pipeline

```
SCAN → CHECK → SCORE → REPORT → FIX (optional)
```

---

## The 12 Checks

### Category 1: Documentation (4 checks, 35% weight)

#### Check 1.1: CONTRIBUTING.md (10%)

```bash
# Check existence
test -f CONTRIBUTING.md || test -f .github/CONTRIBUTING.md || test -f docs/CONTRIBUTING.md
```

**Score**:
- 100: Exists + has Quick Start + has PR workflow + has code conventions
- 70: Exists but incomplete (missing sections)
- 30: Exists but minimal (just a link)
- 0: Missing

**Content check** (if file exists, verify it contains):
- [ ] Quick Start section (clone → install → run)
- [ ] PR/branch workflow
- [ ] Code conventions (lint, format, naming)
- [ ] Testing instructions
- [ ] Link to detailed docs

#### Check 1.2: Per-Module READMEs (8%)

```bash
test -f frontend/README.md && test -f backend/README.md
```

**Score**:
- 100: Both exist with start/test/build commands
- 50: One exists
- 0: Neither exists

#### Check 1.3: Architecture Documentation (10%)

Check for architecture docs that help newcomers understand the system:

```bash
# Check for common architecture doc locations
test -f .blueprint/INDEX.md || test -f docs/ARCHITECTURE.md || test -f ARCHITECTURE.md
```

**Score**:
- 100: Index exists + links to module docs + entry points documented
- 70: Index exists but sparse
- 30: Some docs exist but no clear entry point
- 0: No architecture documentation

#### Check 1.4: Onboarding Runbook (7%)

```bash
test -f .blueprint/ONBOARDING-RUNBOOK.md || test -f docs/ONBOARDING.md
```

**Score**:
- 100: Step-by-step runbook with SSO + access + first task
- 50: Exists but outdated or incomplete
- 0: Missing

---

### Category 2: Development Environment (4 checks, 30% weight)

#### Check 2.1: One-Command Dev Setup (10%)

```bash
# Check for Makefile with dev target
grep -q "^dev:" Makefile 2>/dev/null || grep -q "^dev " Makefile 2>/dev/null
# OR docker-compose with dev profile
test -f docker-compose.yml
```

**Score**:
- 100: `make dev` or equivalent exists and is documented
- 70: Docker compose exists but no Makefile shortcut
- 30: Manual multi-step setup required
- 0: No documented dev setup

#### Check 2.2: Environment Variables (8%)

```bash
# Check for .env.example or .env.template
test -f .env.example || test -f .env.template || test -f .envrc.example
```

**Score**:
- 100: .env.example exists with all required vars documented
- 70: Exists but missing descriptions or has stale vars
- 30: Exists but incomplete
- 0: Missing (new dev must guess env vars)

**Validation** (if .env.example exists):
- Compare vars in .env.example vs. vars referenced in code (`os.environ`, `process.env`)
- Flag any referenced but undocumented vars

#### Check 2.3: Dependency Installation (7%)

```bash
# Check package managers
test -f bun.lockb || test -f package-lock.json || test -f yarn.lock  # Frontend
test -f requirements.txt || test -f pyproject.toml || test -f Pipfile  # Backend
```

**Score**:
- 100: Lock files exist + install command documented in README/Makefile
- 70: Lock files exist but install not documented
- 30: No lock files (version drift risk)
- 0: No dependency manifests

#### Check 2.4: Dev Tooling (5%)

```bash
# Check for helpful dev tools
test -f .editorconfig                          # Editor config
test -f .vscode/settings.json || test -f .idea  # IDE settings
grep -rq "pre-commit\|lefthook\|husky" . 2>/dev/null  # Git hooks
```

**Score**:
- 100: Editor config + IDE settings + Git hooks + lint config
- 70: Most present
- 30: Some present
- 0: No dev tooling

---

### Category 3: Workflow (2 checks, 20% weight)

#### Check 3.1: CI/CD Pipeline (12%)

```bash
# Check for CI config
test -f .forgejo/workflows/*.yml 2>/dev/null || \
test -f .github/workflows/*.yml 2>/dev/null || \
test -f .gitlab-ci.yml
```

**Score**:
- 100: CI exists + runs on PR + includes lint/test/build + currently green
- 70: CI exists but not all checks or currently failing
- 30: CI exists but minimal
- 0: No CI

**Live check** (if CI exists):
- Query CI status for latest run (Forgejo API, GitHub API)
- Report: last run date, status, duration

#### Check 3.2: Branch Protection & PR Template (8%)

```bash
# PR template
test -f .forgejo/PULL_REQUEST_TEMPLATE.md || test -f .github/PULL_REQUEST_TEMPLATE.md

# Branch protection (check via API if possible)
# Forgejo: GET /api/v1/repos/{owner}/{repo}/branch_protections
```

**Score**:
- 100: PR template exists + branch protection on main + review required
- 70: Some protection but no PR template
- 30: Minimal protection
- 0: No protection

---

### Category 4: Team Support (2 checks, 15% weight)

#### Check 4.1: Good First Issues (8%)

Query Forgejo/GitHub API for issues labeled `good-first-issue` or `help-wanted`:

```bash
# Forgejo
curl -s "http://localhost:3000/api/v1/repos/{owner}/{repo}/issues?labels=good-first-issue&state=open"

# GitHub
gh issue list --label "good first issue" --state open
```

**Score**:
- 100: 5+ open good-first-issues with clear descriptions
- 70: 2-4 issues available
- 30: 1 issue or issues without clear descriptions
- 0: No good-first-issues labeled

#### Check 4.2: Test Coverage & Safety Net (7%)

```bash
# Check test existence
find . -name "test_*.py" -o -name "*.test.ts" -o -name "*.spec.ts" | wc -l
```

**Score**:
- 100: >200 test files + CI runs tests + coverage > 50%
- 70: 100-200 test files + CI runs tests
- 30: Some tests exist but not in CI
- 0: <10 test files

---

## Scoring & Grading

### Weight Distribution

| Category | Weight | Checks |
|----------|--------|--------|
| Documentation | 35% | CONTRIBUTING, READMEs, Architecture, Runbook |
| Environment | 30% | Dev setup, Env vars, Dependencies, Tooling |
| Workflow | 20% | CI/CD, Branch protection |
| Team Support | 15% | Good first issues, Test safety net |

### Grade Scale

| Grade | Score | Meaning |
|-------|-------|---------|
| **A** | 90-100 | Ready for any developer, minimal friction |
| **B** | 75-89 | Ready with minor gaps, quick fixes needed |
| **C** | 60-74 | Passable but significant friction for newcomers |
| **D** | 40-59 | Major gaps — new dev will struggle |
| **F** | 0-39 | Not ready — invest before onboarding anyone |

---

## Output Format

```
🏛️ ATLAS │ Onboarding Check — Team Readiness — {date}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 Grade: {grade} ({score}/100) │ Time to first commit: ~{minutes} min

📚 Documentation (35%)                              {cat_score}/100
─────────────────────────────────────────────────────────────────
  {icon} CONTRIBUTING.md          {score}  {detail}
  {icon} Module READMEs           {score}  {detail}
  {icon} Architecture docs        {score}  {detail}
  {icon} Onboarding runbook       {score}  {detail}

🔧 Development Environment (30%)                    {cat_score}/100
─────────────────────────────────────────────────────────────────
  {icon} One-command dev setup    {score}  {detail}
  {icon} Environment variables    {score}  {detail}
  {icon} Dependency installation  {score}  {detail}
  {icon} Dev tooling              {score}  {detail}

🔄 Workflow (20%)                                    {cat_score}/100
─────────────────────────────────────────────────────────────────
  {icon} CI/CD pipeline           {score}  {detail}
  {icon} Branch protection + PR   {score}  {detail}

👥 Team Support (15%)                                {cat_score}/100
─────────────────────────────────────────────────────────────────
  {icon} Good first issues        {score}  {detail}
  {icon} Test safety net          {score}  {detail}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{If gaps exist:}
🔴 Gaps to Fix (priority order):
  1. {highest impact gap + estimated fix time}
  2. {next gap}
  3. {next gap}

💡 Quick Wins:
  - {item that takes < 30 min to fix}
  - {item that takes < 30 min to fix}

🎯 Recommendation: {overall recommendation}
```

Status icons: ✅ 90+, ⚠️ 50-89, ❌ <50

---

## Auto-Fix Mode (`/atlas onboard fix`)

When gaps are found, offer to create missing items with HITL approval:

### Fixable Items

| Gap | Auto-Fix Action | HITL Gate |
|-----|----------------|-----------|
| Missing CONTRIBUTING.md | Generate from project context (README + Makefile) | Review content before write |
| Missing frontend/README.md | Generate from package.json + Makefile targets | Review content before write |
| Missing backend/README.md | Generate from pyproject.toml + Makefile targets | Review content before write |
| Missing .env.example | Scan code for env var references, generate template | Review vars before write |
| Missing PR template | Generate standard template with checklist | Review content before write |
| No good-first-issues | Scan for TODO/FIXME, create 5 Forgejo issues | Review issues before create |
| Missing Forgejo labels | Create standard label set via API | Confirm label list |

### Fix Process

1. Show gap list via AskUserQuestion: "I found {N} gaps. Fix all, fix some, or skip?"
2. For each fixable gap:
   a. Generate content
   b. Show preview to user
   c. AskUserQuestion: "Create this file?" — Yes / Edit first / Skip
3. After all fixes, re-run scorecard to show improvement

### Safety Rules

- NEVER create files without HITL approval
- NEVER modify existing files (only create missing ones)
- NEVER push to remote (local changes only)
- Generated content uses project conventions detected during scan
- If Forgejo API unavailable, skip issue/label creation (report as manual action)

---

## Simulate Mode (`/atlas onboard simulate`)

Simulate what a new developer would experience:

1. **Check prerequisites**: git, docker, bun/node, python — are they documented?
2. **Simulate clone**: Would `git clone` + `make install` work?
3. **Simulate dev**: Would `make dev` start all services?
4. **Simulate test**: Would `make test` pass?
5. **Simulate first PR**: Is the branch/PR workflow documented?
6. **Time estimate**: Based on findings, estimate minutes to first commit

Output: Step-by-step walkthrough with pass/fail per step.

---

## Integration with Other Skills

| Skill | Integration |
|-------|------------|
| `product-health` | Onboard check references health grade for "is the app working?" |
| `feature-board` | Links to `/atlas board suggest` for first-task suggestions |
| `context-discovery` | Shares doc quality assessment |
| `atlas-doctor` | Shares tool/service health for env check |

---

## Personas

Different team members need different checks:

| Persona | Focus | Skip |
|---------|-------|------|
| **Full-stack dev** | All 12 checks | None |
| **Backend dev** | Docs, BE env, CI, tests | Frontend README, FE tooling |
| **Frontend dev** | Docs, FE env, CI, tests | Backend README, DB setup |
| **Discipline engineer** | Docs, feature request workflow, domain guides | Dev env, CI, tests |

Use AskUserQuestion at start: "Who are you onboarding?" to adapt check weights.
