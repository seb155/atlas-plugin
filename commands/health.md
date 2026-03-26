# /health — Application Reality Audit

Live validation of the running application. Tests what ACTUALLY works via API, browser, and test suite.
Produces `APPLICATION-REALITY-MATRIX.md` with evidence (screenshots, test output, API responses).

**Usage**: `/atlas health [subcommand]`

Invoke Skill 'product-health'.

ARGUMENTS: $ARGUMENTS

Subcommands:
- `/atlas health` — Full scan: Docker + API + Browser + Tests + DB
- `/atlas health api` — Backend API endpoint health only (curl-based)
- `/atlas health ui` — Frontend browser audit with screenshots + console errors
- `/atlas health tests` — Run BE + FE test suites, report pass/fail
- `/atlas health matrix` — Generate/refresh APPLICATION-REALITY-MATRIX.md
- `/atlas health quick` — Docker + API + test counts (no browser, fast)
