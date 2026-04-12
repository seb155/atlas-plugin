---
name: plan-review
description: "Iterative plan review with simulation, consolidation, and HITL gates. Multi-pass quality improvement for sub-plans and mega plans. Use when reviewing, validating, or consolidating engineering plans."
effort: high
context: fork
agent: plan-reviewer
---

# Iterative Plan Review

Review, simulate, and consolidate engineering plans through multi-pass iterative improvement.

## When to Use

- Before implementation: validate plan quality and readiness (Gate G1)
- After major plan changes: re-score and re-validate
- When consolidating multiple sub-plans into a mega plan
- Periodically: every 2-3 sprints for active plans
- When user says: "review plan", "validate plan", "simulate plan", "consolidate plans"

## Workflow: Single Plan Review

### Pass 1 — Score & Identify Weaknesses

1. Read the plan file completely
2. Score against 15 criteria (A-O sections):

| # | Criterion | 1 pt if... |
|---|-----------|-----------|
| 1 | Vision explains WHY + chain impact |
| 2 | Inventory lists code + reusable hooks |
| 3 | Architecture has diagram + sourced decisions |
| 4 | DB schema with migrations |
| 5 | Backend services detailed |
| 6 | API endpoints table |
| 7 | Frontend UX mockups |
| 8 | Persona impact assessed |
| 9 | Security/RBAC defined |
| 10 | AI-native + observability |
| 11 | Infrastructure targets |
| 12 | Reusability/multi-tenant |
| 13 | Traceability/audit |
| 14 | Phases with effort + deps |
| 15 | Verification commands |

3. For each section scoring 0: flag as WEAK
4. Output: score table + list of weak sections + recommendations

### Pass 2 — Enrich Weak Sections

For each WEAK section (max 3 per pass):
1. Research via context-discovery or WebSearch if needed
2. Draft improved section content
3. Present to user via AskUserQuestion for HITL approval
4. Apply improvements

### Pass 3 — Cross-Section Consistency

Verify internal consistency:
- [ ] Phases (N) reference files from Inventory (B)?
- [ ] Architecture (C) decisions align with DB Schema (D)?
- [ ] API endpoints (F) match Backend services (E)?
- [ ] Frontend mockups (G) use hooks from Inventory (B)?
- [ ] Effort totals in Phases (N) sum correctly?
- [ ] Verification commands (O) match actual file paths?

### Pass 4 — Mental Simulation

Walk through each phase mentally:
1. **File touch order**: What files are created/modified in what sequence?
2. **Dependency chain**: Can phases execute in declared order?
3. **DB migration timing**: Migrations before service code?
4. **Test coverage**: Every deliverable has a test?
5. **Rollback plan**: If phase fails, what's the recovery?
6. **Effort realism**: No tasks > 12h (too vague) or < 1h (too granular)?

Output simulation report:
```
SIMULATION REPORT — SP-XX
Phase 1: ✅ Executable (DB migration → service → endpoint → test)
Phase 2: ⚠️ Risk — needs SP-06 P1 complete first (auth dep)
Phase 3: ✅ Executable (frontend only, no backend deps)
Overall: READY with 1 dependency to verify
```

### Stop Conditions

- Score >= 12/15 AND simulation PASS → APPROVE (Gate G1)
- Score < 12/15 after 3 passes → ESCALATE to user via AskUserQuestion
- Simulation FAIL (blocking dependency) → ESCALATE with options

## Workflow: Mega Plan Review

When reviewing a mega plan (M1-M16 format):

### Step 1 — Registry Validation
- All sub-plans listed in M3 exist as files?
- Effort totals sum correctly?
- Dependencies form a valid DAG (no cycles)?
- Bidirectional links present in each sub-plan?

### Step 2 — Cross-Plan Consistency
- Integration points (IP-1 to IP-9) addressed by responsible sub-plans?
- Shared DB tables defined consistently across sub-plans?
- API contracts compatible between sub-plans?
- Auth/RBAC model consistent?

### Step 3 — Timeline Simulation
- Critical path calculation: does timeline match effort?
- Phase gates achievable with single developer + AI co-dev?
- Parallel tracks don't exceed capacity?

### Step 4 — Gap Detection
- Any engineering chain steps not covered by any sub-plan?
- Any persona not served by any sub-plan?
- Any integration point without test strategy?

Output:
```
MEGA PLAN REVIEW — ticklish-tinkering-puppy.md
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Registry:     12/12 sub-plans exist          ✅
Links:        12/12 bidirectional links      ✅
DAG:          No cycles, critical path OK    ✅
Effort:       2,582h total (sums correct)    ✅
Integration:  9/9 IPs covered               ✅
Gaps:         SP-08 missing sub-plan file    ⚠️
Timeline:     Phase 0-6 feasible at 1 dev    ✅
OVERALL:      READY (1 minor gap)
```

## Workflow: Multi-Plan Consolidation

When consolidating N sub-plans:

1. Read all N sub-plans
2. Build dependency matrix (which plans share what)
3. Detect duplicate tasks across plans
4. Detect conflicting architecture decisions
5. Generate consolidation report
6. Present to user for HITL approval

## Output Files

- Review results: shown in conversation (not saved to file)
- If improvements applied: update the plan file directly
- If mega plan: update registry table in mega plan

## HITL Gates

- **Always ask** before modifying a plan section
- **Always present** simulation results before approving
- **Never auto-approve** plans — user must confirm Gate G1
- Use AskUserQuestion for all decisions

## Quality Gate

| Score | Action |
|-------|--------|
| 15/15 | EXEMPLARY — approve immediately |
| 12-14/15 | PASS — approve with notes |
| 9-11/15 | NEEDS WORK — 1 more pass, then escalate |
| < 9/15 | REJECT — major rewrite needed |

## Commands

- `/atlas review-plan {plan-file}` — review a single plan
- `/atlas review-plan --mega {mega-plan-file}` — review mega plan + all sub-plans
- `/atlas review-plan --simulate {plan-file}` — simulation only (no scoring)
- `/atlas review-plan --consolidate {plan1} {plan2} ...` — consolidate multiple plans
