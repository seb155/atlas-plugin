# /review-plan — Iterative plan review, simulation, and consolidation

Invoke the `plan-review` skill with the following arguments: $ARGUMENTS

Review engineering plans through multi-pass iterative improvement:
- **Single plan**: `/review-plan {plan-file}` — score 15 criteria + enrich weak sections + simulate
- **Mega plan**: `/review-plan --mega {mega-plan}` — validate registry + cross-plan consistency + timeline
- **Simulate only**: `/review-plan --simulate {plan}` — mental execution without scoring
- **Consolidate**: `/review-plan --consolidate {plan1} {plan2}` — merge + deduplicate + align

Workflow: Score → Identify Weaknesses → Enrich → Cross-Check → Simulate → HITL Approve
Max 3 iterative passes. Gate: 12/15 minimum.
