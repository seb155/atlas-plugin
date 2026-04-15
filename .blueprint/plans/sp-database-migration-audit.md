# SP-DATABASE-MIGRATION-AUDIT — Atlas DB Audit Skill + CLI Command

**Plan ID**: `sp-database-migration-audit`
**Effort**: 2-3h
**Sprint**: Next available
**Parent**: Discovered during SP-TEST-SOTA N2 session (synapse repo, 2026-04-14)
**Status**: STUB — to be expanded pre-implementation

## Context

Session SP-TEST-SOTA N2 uncovered 6+ layers of migration debt in synapse (10 alembic heads, 4-13 orphan tables, forward-refs on non-existent tables, circular FK). Detection was ad-hoc: scripts written mid-session, regex missed typed revision form, oracle via `alembic heads` CLI.

This skill formalizes migration audit as a reusable atlas tool, so future projects (or recurrent audits on synapse) can detect debt systematically before it blocks CI.

## Scope

Cross-project migration audit for alembic-based codebases. Callable as:

```bash
atlas db audit [--backend PATH] [--format json|markdown|terminal]
```

## Strategy

Use alembic's own introspection APIs (`ScriptDirectory`), not regex. Use SQLAlchemy's Base.metadata vs alembic migration DAG to detect orphans. Write report in selected format.

## Phases

| Phase | Task | Effort |
|-------|------|--------|
| P1 | CLI skeleton: `atlas db audit` in new module `scripts/atlas-modules/db.sh` | 30min |
| P2 | Audit #1: head count (via `alembic heads`) — single head = pass | 30min |
| P3 | Audit #2: orphan table detection (models with `__tablename__` but no `op.create_table`) | 45min |
| P4 | Audit #3: forward-ref detection (`ALTER TABLE X`/`CREATE TRIGGER ON X` where X has no CREATE) | 45min |
| P5 | Output formatter (terminal colored, JSON for CI, markdown for docs) | 30min |
| P6 | Skill MD (`skills/database-migration-audit/SKILL.md`) | 15min |
| P7 | Tests (bats for CLI, mock alembic dirs for audit) | 30min |

## Audit checks

1. **Head count**: `alembic heads | wc -l`. Expected: 1. Any more = divergent branches not merged.
2. **Orphan tables**: Models declare `__tablename__ = "X"`, but no migration does `op.create_table("X", ...)` or raw `CREATE TABLE X`.
3. **Forward-refs**: Migration does `op.execute("ALTER TABLE X ...")` or creates a trigger/index/FK on X, but no migration creates X first (topological).
4. **Typed revision detection** (bonus): warn if any migration uses `revision: str = "..."` form — some tools miss it.
5. **Merge migrations validity**: every merge migration must reference existing revisions (no typos in down_revision tuple).

## Verification

```bash
# Run on synapse (which has known debt)
atlas db audit --backend ~/workspace_atlas/projects/atlas/synapse/backend
# Expected output: 4 audits run, drift detected, actionable fix hints

# Run on clean project
atlas db audit --backend ~/path/to/clean
# Expected: all audits pass
```

## Integration with systematic-debugging skill

When a migration-related failure occurs during debugging, the skill should recommend `atlas db audit` as the pre-check before hypothesizing.

## Cross-references

- Lesson: `memory/lesson_alembic_cli_over_regex.md`
- Session: `memory/handoff-2026-04-14-sp-test-sota-n2-migration-archaeology.md`
- Shipped PR #189 (synapse) — cherry-picked manual fixes that this skill would have surfaced
- Sibling plan: `.blueprint/plans/sp-atlas-ci-live-monitor.md` (rich CI monitoring)
