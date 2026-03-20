# /update — Platform Update & SOTA Audit

Audit Claude Code environment + ATLAS plugin against latest best practices.
Detects current state, researches SOTA, proposes fixes, auto-updates plugin.

**Usage**: `/atlas update`

Invoke Skill 'platform-update'.

ARGUMENTS: $ARGUMENTS

Modes:
- `/atlas update` — Full audit + fix proposals (default)
- `/atlas update check` — Audit only, no changes
- `/atlas update apply` — Apply all recommended fixes (after prior audit)
- `/atlas update plugin` — Self-update plugin from Forgejo main branch
