---
name: onboarding-check
description: "Team readiness assessment. 12 checks across docs, dev environment, CI, and Forgejo. Scores A-F. /atlas onboard for full check, /atlas onboard gaps for actionable fix list. Use before onboarding new developers or discipline engineers."
effort: medium
---

# Onboarding Check — Team Readiness Assessment

Validates project readiness for new team members. Scores 12 dimensions across Documentation, Environment, Workflow, Team Support.

## When to Use

- "onboard", "onboarding", "ready for new dev", "team ready"
- "contributing", "CONTRIBUTING.md", "dev setup", "first commit"
- Before new dev joins
- After major infra changes (CI, auth, env)
- Periodically (quarterly)

## Subcommands

| Command | Mode | Output |
|---------|------|--------|
| `/atlas onboard` | **Full Check** | 12-dim scorecard + grade |
| `/atlas onboard gaps` | **Gap List** | Actionable missing items |
| `/atlas onboard fix` | **Auto-Fix** | Create missing docs/configs (HITL) |
| `/atlas onboard simulate` | **Dry Run** | Simulate fresh clone → first commit |

## Pipeline

```
SCAN → CHECK → SCORE → REPORT → FIX (optional)
```

## The 12 Checks

### Category 1: Documentation (4 checks, 35% weight)

#### 1.1 CONTRIBUTING.md (10%)

```bash
test -f CONTRIBUTING.md || test -f .github/CONTRIBUTING.md || test -f docs/CONTRIBUTING.md
```

**Score**: 100 = exists + Quick Start + PR workflow + conventions | 70 = incomplete | 30 = minimal | 0 = missing

**Content check** (if exists, verify): Quick Start (clone→install→run) | PR/branch workflow | Code conventions (lint/format/naming) | Testing instructions | Link to detailed docs

#### 1.2 Per-Module READMEs (8%)

```bash
test -f frontend/README.md && test -f backend/README.md
```

**Score**: 100 = both with start/test/build | 50 = one exists | 0 = neither

#### 1.3 Architecture Documentation (10%)

```bash
test -f .blueprint/INDEX.md || test -f docs/ARCHITECTURE.md || test -f ARCHITECTURE.md
```

**Score**: 100 = index + module links + entry points | 70 = sparse | 30 = no clear entry | 0 = missing

#### 1.4 Onboarding Runbook (7%)

```bash
test -f .blueprint/ONBOARDING-RUNBOOK.md || test -f docs/ONBOARDING.md
```

**Score**: 100 = step-by-step + SSO + access + first task | 50 = outdated/incomplete | 0 = missing

### Category 2: Development Environment (4 checks, 30% weight)

#### 2.1 One-Command Dev Setup (10%)

```bash
grep -q "^dev:" Makefile 2>/dev/null || grep -q "^dev " Makefile 2>/dev/null
test -f docker-compose.yml
```

**Score**: 100 = `make dev` documented | 70 = compose only, no Makefile | 30 = manual multi-step | 0 = no dev setup

#### 2.2 Environment Variables (8%)

```bash
test -f .env.example || test -f .env.template || test -f .envrc.example
```

**Score**: 100 = `.env.example` complete + documented | 70 = missing descriptions/stale | 30 = incomplete | 0 = missing

**Validation**: compare `.env.example` vars vs code references (`os.environ`, `process.env`); flag undocumented refs.

#### 2.3 Dependency Installation (7%)

```bash
test -f bun.lockb || test -f package-lock.json || test -f yarn.lock          # FE
test -f requirements.txt || test -f pyproject.toml || test -f Pipfile        # BE
```

**Score**: 100 = lock files + install documented | 70 = lock files only | 30 = no lock (drift risk) | 0 = no manifests

#### 2.4 Dev Tooling (5%)

```bash
test -f .editorconfig                                   # Editor
test -f .vscode/settings.json || test -f .idea          # IDE
grep -rq "pre-commit\|lefthook\|husky" . 2>/dev/null    # Git hooks
```

**Score**: 100 = editor + IDE + hooks + lint | 70 = most | 30 = some | 0 = none

### Category 3: Workflow (2 checks, 20% weight)

#### 3.1 CI/CD Pipeline (12%)

```bash
test -f .forgejo/workflows/*.yml 2>/dev/null || \
test -f .github/workflows/*.yml 2>/dev/null || \
test -f .gitlab-ci.yml
```

**Score**: 100 = CI on PR + lint/test/build + green | 70 = exists not all checks or red | 30 = minimal | 0 = none

**Live check** (if CI exists): query CI status (Forgejo/GitHub API) → report last run date, status, duration.

#### 3.2 Branch Protection & PR Template (8%)

```bash
test -f .forgejo/PULL_REQUEST_TEMPLATE.md || test -f .github/PULL_REQUEST_TEMPLATE.md
# Branch protection: GET /api/v1/repos/{owner}/{repo}/branch_protections (Forgejo)
```

**Score**: 100 = PR template + protection on main + review required | 70 = some protection no template | 30 = minimal | 0 = none

### Category 4: Team Support (2 checks, 15% weight)

#### 4.1 Good First Issues (8%)

```bash
# Forgejo
curl -s "http://localhost:3000/api/v1/repos/{owner}/{repo}/issues?labels=good-first-issue&state=open"
# GitHub
gh issue list --label "good first issue" --state open
```

**Score**: 100 = 5+ open with clear desc | 70 = 2-4 | 30 = 1 or unclear | 0 = none

#### 4.2 Test Coverage & Safety Net (7%)

```bash
find . -name "test_*.py" -o -name "*.test.ts" -o -name "*.spec.ts" | wc -l
```

**Score**: 100 = >200 tests + CI runs + coverage >50% | 70 = 100-200 + CI | 30 = some not in CI | 0 = <10

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
| **C** | 60-74 | Passable but significant friction |
| **D** | 40-59 | Major gaps — new dev will struggle |
| **F** | 0-39 | Not ready — invest before onboarding |

## Output Format

```
🏛️ ATLAS │ Onboarding Check — Team Readiness — {date}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{If gaps:}
🔴 Gaps to Fix (priority order):
  1. {highest impact + estimated fix time}
  2. ...

💡 Quick Wins (<30 min each):
  - {item}

🎯 Recommendation: {overall}
```

Status icons: ✅ 90+ | ⚠️ 50-89 | ❌ <50

## Auto-Fix Mode (`/atlas onboard fix`)

When gaps found, create missing items with HITL approval.

### Fixable Items

| Gap | Auto-Fix Action | HITL Gate |
|-----|----------------|-----------|
| Missing CONTRIBUTING.md | Generate from project context (README+Makefile) | Review before write |
| Missing frontend/README.md | Generate from package.json + Makefile targets | Review before write |
| Missing backend/README.md | Generate from pyproject.toml + Makefile targets | Review before write |
| Missing .env.example | Scan code for env refs, generate template | Review vars before write |
| Missing PR template | Generate standard template + checklist | Review before write |
| No good-first-issues | Scan TODO/FIXME, create 5 Forgejo issues | Review issues before create |
| Missing Forgejo labels | Create standard label set via API | Confirm label list |

### Process

1. AskUserQuestion: "{N} gaps found. Fix all / fix some / skip?"
2. Per fixable gap: generate content → preview → AskUserQuestion: "Create?" (Yes / Edit first / Skip)
3. After all fixes: re-run scorecard to show improvement

### Safety Rules

- NEVER create files without HITL approval
- NEVER modify existing files (only create missing)
- NEVER push to remote (local only)
- Generated content uses project conventions from scan
- Forgejo API unavailable → skip issue/label creation (report as manual)

## Simulate Mode (`/atlas onboard simulate`)

Simulate new developer experience:

1. Check prerequisites: git, docker, bun/node, python — documented?
2. Simulate clone: `git clone` + `make install` work?
3. Simulate dev: `make dev` starts all services?
4. Simulate test: `make test` passes?
5. Simulate first PR: workflow documented?
6. Time estimate: minutes to first commit

Output: Step-by-step walkthrough with pass/fail per step.

## Integration with Other Skills

| Skill | Integration |
|-------|------------|
| `product-health` | References health grade ("is app working?") |
| `feature-board` | Links to `/atlas board suggest` for first-task suggestions |
| `context-discovery` | Shares doc quality assessment |
| `atlas-doctor` | Shares tool/service health for env check |

## Personas

Different roles need different checks:

| Persona | Focus | Skip |
|---------|-------|------|
| **Full-stack dev** | All 12 | None |
| **Backend dev** | Docs, BE env, CI, tests | FE README, FE tooling |
| **Frontend dev** | Docs, FE env, CI, tests | BE README, DB setup |
| **Discipline engineer** | Docs, feature workflow, domain guides | Dev env, CI, tests |

AskUserQuestion at start: "Who are you onboarding?" to adapt check weights.
