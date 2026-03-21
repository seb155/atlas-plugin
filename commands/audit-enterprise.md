Invoke the `enterprise-audit` skill with the following arguments: $ARGUMENTS

This is the ATLAS enterprise readiness audit command. It runs a 14-dimension audit covering
multi-tenancy, data integrity, deployment, security, testing, ops, code quality, documentation,
dependencies, API surface, i18n, accessibility, governance, and performance. Produces
A-F grades with weighted scoring and HITL gates for G Mining due diligence preparation.

Subcommands:
- `/atlas audit-enterprise` — Full 6-phase pipeline (all 14 dimensions, ~45 min, scope confirmation required)
- `/atlas audit-enterprise --quick` — Critical dimensions only: security, multi-tenancy, data, deployment (~15 min)
- `/atlas audit-enterprise --dimension <d1,d2>` — Specific dimensions by name (e.g. `security,data,testing`)
- `/atlas audit-enterprise report` — Regenerate report from last saved audit JSON (no re-scan)
- `/atlas audit-enterprise compare <file.json>` — Delta comparison vs a previous audit run JSON

If no subcommand given, run full audit pipeline with scope confirmation.

Workflow: SCOPE → CHECK → SCORE → REPORT → RECOMMEND → TRACK
Scoring: weighted 14-dimension model, Grade A-F. G Mining minimum: Grade B (≥80/100), zero open CRITICALs.
Delegates security dimension to `security-audit` skill. Delegates testing dimension to `verification` skill.
Exports to Excel or PPTX via `document-generator` skill on request.
Rubric: `skills/enterprise-audit/references/scoring-rubric.md`
G Mining checklist: `skills/enterprise-audit/references/gmining-checklist.md`
Read-only checks — never mutate DB, never auto-remediate without HITL approval.
