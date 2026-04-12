# Sample Verification Report — L1-L6

## Verification Report — feature/project-settings

### Environment Health
| Check | Status | Detail |
|-------|--------|--------|
| Docker | ✅ | 6/6 containers running |
| DB | ✅ | PostgreSQL 17 responding |
| Backend | ✅ | Health endpoint 200 OK |
| Frontend | ✅ | Vite dev server on :4000 |

### L1 — Backend Unit Tests
```
pytest tests/unit/ -x -q --tb=short
42 passed in 3.2s
```
**Result**: ✅ PASS

### L2 — Frontend Unit Tests
```
bunx vitest --run
137 tests passed (2 suites)
```
**Result**: ✅ PASS

### L3 — Type Check
```
bun run type-check
No errors found
```
**Result**: ✅ PASS

### L4 — Integration Tests
```
pytest tests/integration/ -x -q --tb=short
18 passed in 8.1s
```
**Result**: ✅ PASS

### L5 — E2E Workflow
```
bunx playwright test e2e/qa-settings.spec.ts
3 tests passed
```
**Result**: ✅ PASS

### L6 — Security Scan
```
gitleaks detect --source . --no-git
No leaks found
```
**Result**: ✅ PASS

### DoD Score
| Layer | Weight | Status | Score |
|-------|--------|--------|-------|
| BE Unit | 5% | ✅ | 5 |
| BE Integration | 3% | ✅ | 3 |
| FE Unit | 5% | ✅ | 5 |
| FE Visual | 2% | ⏳ | 0 |
| Type Check | 5% | ✅ | 5 |
| E2E Workflow | 10% | ✅ | 10 |
| HITL Review | 15% | ⏳ | 0 |
| Security | 8% | ✅ | 8 |
| Performance | 7% | ⏳ | 0 |
| Real Data | 10% | ⏳ | 0 |
| Enterprise | 10% | ✅ | 10 |
| Demo Ready | 10% | ⏳ | 0 |
| Deploy Prod | 10% | ⏳ | 0 |

**Total: 46/100** — Tier: VALIDATING
