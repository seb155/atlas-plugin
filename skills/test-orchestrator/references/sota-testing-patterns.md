# SOTA Testing Patterns — Anti-Patterns & 5-Level Maturity Model

> Authoritative reference for test architecture design & audit. Invoke when:
> - Reviewing a test suite and asking "does it actually catch bugs?"
> - Writing CI workflows for a new project
> - Auditing an existing codebase with thousands of tests but production incidents slipping through
> - Planning a test coverage sprint
>
> **Empirical source**: Synapse SP-TEST-SOTA (2026-04-14 audit — 674 backend files, 9,799 declared tests, only 7 running in CI).

---

## The Five Defects of "Test Theatre"

Test theatre = lots of tests exist but none act as a real quality gate. Symptoms:
- CI green on a commit that broke prod
- `git log --oneline tests/` shows constant growth but production incidents keep happening
- "We have 9,000 tests" but coverage metrics show 30%
- Local test runs take 10 min, CI runs take 30s

| # | Defect | Symptom | Detection | Fix |
|---|--------|---------|-----------|-----|
| **D1** | **Skeleton tests auto-generated** | Files with `pytest.skip("TODO: add assertions")` in every test body. Count inflated. | `grep -r "auto-generated skeleton" tests/ \| wc -l` | Delete the skeletons. Quantity without assertion = noise. |
| **D2** | **CI runs only smoke markers** | `pytest -m smoke` runs 7 tests while the suite has 9,000 | Read `.woodpecker/*.yml`, `.github/workflows/*.yml` — does the test step include `-m smoke` only? | Run `pytest -m "not external"` or equivalent broad filter. All markers that exist must run, only `external` / `slow` exempted. |
| **D3** | **`failure: ignore` / `continue-on-error: true`** on test steps | CI step goes red but pipeline continues to deploy | `grep -r "failure: ignore\|continue-on-error" .ci/ .woodpecker/ .github/` | Remove. Red = blocks merge. If the test is known-flaky, fix or quarantine it in a separate job. |
| **D4** | **Mocked DB in integration tests** | `test_user_creation.py` mocks SQLAlchemy instead of using real Postgres | Read a sample "integration" test — does it hit a real DB session? | Add postgres service in CI. Real SQL = catches RLS, triggers, migration regressions. |
| **D5** | **Coverage unenforced** | `fail_under=N` in `pyproject.toml` but CI doesn't invoke `--cov` | `grep -r "cov-fail-under\|coverageThresholds" .ci/` | Add `--cov --cov-fail-under=50` to CI test step. Coverage not enforced = coverage will decay. |

A test suite exhibiting D1+D2+D3 is effectively **zero safety net**. You have the illusion of quality without any of the substance.

---

## The 5-Level Test Maturity Model

Diagnose where a project is + plan the next step up.

| Level | Name | Characteristic | CI Outcome |
|-------|------|----------------|-----------|
| **L0** | Test theatre | Thousands of tests, 7 run in CI, everything `failure: ignore` | Green CI on broken prod |
| **L1** | Fail-loud | CI runs fast subset, red blocks merge. No skeletons. | Catches obvious regressions |
| **L2** | Real gate | Real DB in CI, integration + security tests run, coverage enforced | Catches schema/integration/auth bugs |
| **L3** | Gap closure | Pages/routes/hooks/stores covered systematically. Templates + auto-gen. | Catches UI/state-management regressions |
| **L4** | Advanced types | Property-based (Hypothesis), contract (OpenAPI diff), real-data fixtures | Catches edge cases + breaking changes |
| **L5** | Quality gates | Benchmarks, load tests, chaos tests, mutation testing | Catches perf regressions + weak assertions |

**Rule**: Don't skip levels. A team at L0 attempting L4 will produce fragile tests that get `failure: ignore`'d. Do L1→L2 first, earn the right to L3+.

---

## The SOTA Patterns by Level

### L1 — Fail-loud in CI (4-8h, any project)

```yaml
# .woodpecker/ci.yml — minimum viable gate
steps:
  lint:
    commands:
      - ruff check .
      # biome check frontend/
  types:
    commands:
      - mypy .              # backend
      # tsc --noEmit        # frontend
  tests:
    commands:
      - pytest -m "not external and not slow" -n auto --tb=short
      # bun test --run --coverage
    # failure: ignore       ← MUST NOT BE PRESENT
```

**Checklist to move to L1**:
- [ ] Delete all auto-generated skeleton tests
- [ ] `grep -r "failure: ignore\|continue-on-error"` returns zero hits on test steps
- [ ] CI test filter is `not external` / `not slow`, NOT `only smoke`
- [ ] Local `make test` runs the same filter

### L2 — Real gate with CI DB (8-16h)

```yaml
# Postgres-in-CI via service
services:
  postgres:
    image: postgres:17-alpine@sha256:<pinned>
    environment:
      POSTGRES_DB: app_test
      POSTGRES_USER: app
      POSTGRES_PASSWORD: test-only-not-a-real-secret

steps:
  migrate:
    commands:
      - alembic upgrade head
    environment:
      TEST_DATABASE_URL: postgresql+psycopg://app:test-only-not-a-real-secret@postgres:5432/app_test

  tests:
    commands:
      - pytest --cov --cov-fail-under=50 -m "not external" -n auto
    environment:
      TEST_DATABASE_URL: postgresql+psycopg://app:test-only-not-a-real-secret@postgres:5432/app_test
```

**Coverage enforcement** (`pyproject.toml`):

```toml
[tool.coverage.run]
branch = true
source = ["app"]

[tool.coverage.report]
fail_under = 50  # Start at realistic baseline, bump +5% per sprint
exclude_lines = [
  "pragma: no cover",
  "if TYPE_CHECKING:",
  "raise NotImplementedError",
]
```

**Frontend equivalent** (`vitest.config.ts`):

```typescript
coverage: {
  provider: "v8",
  reporter: ["text", "json", "html"],
  thresholds: {
    lines: 50,
    statements: 50,
    functions: 45,
    branches: 40,
  },
  autoUpdate: false,  // Don't silently lower thresholds
}
```

### L3 — Gap closure (systematic templates)

Write **one template**, apply everywhere.

**Backend template** — integration test for a CRUD endpoint:

```python
# tests/integration/test_foo_api.py
import pytest
from fastapi.testclient import TestClient

@pytest.fixture
def auth_headers(admin_token):
    return {"Authorization": f"Bearer {admin_token}"}

class TestFooCRUD:
    def test_create_requires_auth(self, client: TestClient):
        resp = client.post("/api/v1/foos", json={"name": "x"})
        assert resp.status_code == 401

    def test_create_happy_path(self, client: TestClient, auth_headers, db_session):
        resp = client.post("/api/v1/foos", json={"name": "x"}, headers=auth_headers)
        assert resp.status_code == 201
        assert db_session.query(Foo).count() == 1

    def test_create_project_scope_enforced(self, client: TestClient, auth_headers):
        # Create foo in project A, try to access from project B, expect 404
        ...

    def test_list_pagination(self, client: TestClient, auth_headers, db_session):
        ...
```

**Frontend template** — L2 MSW page integration:

```typescript
// src/__tests__/pages/foo-page.test.tsx
import { render, screen, waitFor } from "@testing-library/react";
import { setupServer } from "msw/node";
import { rest } from "msw";
import { FooPage } from "@/pages/foo-page";

const server = setupServer(
  rest.get("/api/v1/foos", (req, res, ctx) =>
    res(ctx.json([{ id: "1", name: "x" }]))
  )
);

beforeAll(() => server.listen());
afterAll(() => server.close());
afterEach(() => server.resetHandlers());

describe("FooPage", () => {
  it("renders list from API", async () => {
    render(<FooPage />);
    await waitFor(() => expect(screen.getByText("x")).toBeInTheDocument());
  });

  it("handles empty state", async () => {
    server.use(rest.get("/api/v1/foos", (_, res, ctx) => res(ctx.json([]))));
    render(<FooPage />);
    await waitFor(() => expect(screen.getByText(/no foos/i)).toBeInTheDocument());
  });

  it("handles API error", async () => {
    server.use(rest.get("/api/v1/foos", (_, res, ctx) => res(ctx.status(500))));
    render(<FooPage />);
    await waitFor(() => expect(screen.getByRole("alert")).toBeInTheDocument());
  });
});
```

**Hook test template**:

```typescript
// src/hooks/__tests__/use-foo.test.ts
import { renderHook, act } from "@testing-library/react";
import { useFoo } from "../use-foo";

describe("useFoo", () => {
  it("returns initial state", () => {
    const { result } = renderHook(() => useFoo());
    expect(result.current.value).toBe(null);
  });

  it("updates value on setter", () => {
    const { result } = renderHook(() => useFoo());
    act(() => result.current.setValue("x"));
    expect(result.current.value).toBe("x");
  });
});
```

**Auto-generation script**:

```typescript
// scripts/gen-l2-tests.ts
import { VIEW_REGISTRY } from "@/components/layout/workspace/ViewRegistry";
import { writeFileSync } from "fs";

for (const view of VIEW_REGISTRY) {
  const testPath = `src/__tests__/pages/${view.kebab}.test.tsx`;
  if (existsSync(testPath)) continue;
  writeFileSync(testPath, template(view));
}
```

Run once → 96 stub tests in minutes → human reviews + adds assertions.

### L4 — Advanced types

**Property-based** (Hypothesis, Python):

```python
from hypothesis import given, strategies as st

@given(
    flow=st.floats(min_value=0.1, max_value=1000),
    head=st.floats(min_value=1, max_value=200),
    efficiency=st.floats(min_value=0.3, max_value=0.95),
)
def test_pump_power_positive_and_bounded(flow, head, efficiency):
    power = calculate_pump_power(flow, head, efficiency)
    assert power > 0
    assert power < 10_000_000  # 10 MW cap for sanity
```

Catches inputs the human would never try. Essential for domain math.

**OpenAPI contract** (frontend↔backend):

```typescript
// src/__tests__/contract/openapi.test.ts
import { readFileSync } from "fs";

it("frontend types match backend schema", async () => {
  const live = await fetch("http://localhost:8001/api/openapi.json").then(r => r.json());
  const snapshot = JSON.parse(readFileSync("src/__tests__/contract/openapi.snapshot.json", "utf-8"));
  // Diff-compare — fail on breaking changes
  expect(diffBreakingChanges(snapshot, live)).toEqual([]);
});
```

**Real-data fixture**:

```sql
-- tests/fixtures/subset.sql
INSERT INTO projects (id, code, name) VALUES ('proj-1', 'DEMO', 'Demo Project');
INSERT INTO instruments (id, project_id, tag, type) VALUES
  ('i-001', 'proj-1', 'PT-101', 'pressure_transmitter'),
  ('i-002', 'proj-1', 'FT-201', 'flow_transmitter'),
  -- ... 50 instruments total representative of production structure
;
```

Loaded once per test session → tests run against realistic shape, not synthetic.

### L5 — Quality gates

**Benchmark** (`pytest-benchmark`):

```python
def test_search_bm25_performance(benchmark, db_session):
    result = benchmark(search_bm25, "centrifugal pump", limit=50)
    # pytest-benchmark auto-compares against baseline stored in .benchmarks/
    assert len(result) <= 50
```

**Load** (locust):

```python
from locust import HttpUser, task

class SearchUser(HttpUser):
    @task
    def search(self):
        self.client.get("/api/v1/search?q=valve&limit=20",
                        headers={"Authorization": f"Bearer {TOKEN}"})
```

CI runs: `locust --headless -u 50 -r 10 -t 1m --html report.html`
Assert: `p99 < 500ms`.

**Mutation testing** (`mutmut`):

```bash
mutmut run --paths-to-mutate app/services/rules/
mutmut results
# Kill score > 80% means tests catch most mutations.
```

Reveals weak assertions: if mutating `x > 10` to `x >= 10` doesn't fail any test, the assertion is too loose.

**Chaos testing**:

```python
@pytest.fixture
def slow_db(monkeypatch):
    # Inject 500ms latency into every db session commit
    ...

def test_circuit_breaker_engages_on_slow_db(slow_db, client):
    # After N slow requests, circuit opens
    ...
```

---

## The Five-Question Test Audit

Run before accepting a PR that touches `.ci/`, `.woodpecker/`, `.github/`:

1. **If I intentionally break code X, will CI go RED on this PR?** (Not "maybe eventually" — specifically on the failing metric.)
2. **Does the test filter in CI run MORE than `-m smoke`?**
3. **Are `failure: ignore` / `continue-on-error: true` removed from all test steps?**
4. **Is coverage enforced in CI (not just local) with a documented threshold?**
5. **Do "integration" tests touch a real DB/cache/queue, or are they just mocked?**

Any "no" = stop. Fix before merging more code.

---

## Anti-Patterns to Flag in Code Review

| Red flag | Example | Why | Correction |
|----------|---------|-----|-----------|
| Test body = `pass` + `pytest.skip` | `def test_foo(): pass; pytest.skip("TODO")` | Inflates count, tests nothing (D1) | Delete file |
| Assertion = `result is not None` | Tests that the function returned anything | Passes even with broken logic | Assert specific value |
| Assertion = range without bounds | `assert 0 <= x <= 999999` | Useless range | Assert exact expected |
| Sleep in test body | `time.sleep(0.5)` | Flaky under load | Use explicit sync primitives (events, futures) or mock time |
| `pytest.mark.xfail` without reason | Just marks as expected-to-fail | Hides real issues | Fix or delete; document reason if keeping |
| Unique test fixture per file | 20 files each defining `_make_user()` | DRY violation | Centralize in `tests/helpers.py` |
| `# type: ignore` in test code | Loose typing masks type errors | Tests lie about types they accept | Fix the type, or use `cast()` with justification |
| Mock matches implementation precisely | `mock.assert_called_once_with(<copied impl details>)` | Tautology — test always passes if impl unchanged | Assert behavior, not implementation |
| `describe.skip` / `test.skip` with no date | `describe.skip("TODO fix later")` | Rot | Add date + owner or delete |

---

## Rollout for an Existing L0 Project (Synapse 2026-04-14 playbook)

Order matters. Don't skip.

1. **Audit** — count skeletons, failures, markers. Record baseline. (1h)
2. **L1 Quick wins** — delete skeletons, toggle `failure: ignore`, shift `-m smoke` → broader filter. (4-6h)
3. **Expect test debt** — many tests will now run for the first time in CI. Fix or quarantine the failures. (variable, budget 1 sprint)
4. **L2 Real gate** — postgres in CI, migrations, coverage enforce. (8-12h)
5. **Measure coverage baseline** — don't set `fail_under` above current actual coverage; bump +5% per sprint.
6. **L3 Gap closure** — systematic templates + auto-gen for pages/hooks/stores. (variable by project size)
7. **L4 Advanced** — Hypothesis for domain math, OpenAPI contract diff. (16h)
8. **L5 Quality** — benchmarks, load, chaos, mutation. (10h)

Timeline per project: 2-4 sprints to go from L0 → L3. L4-L5 optional for most teams, essential for critical infra.

---

## Meta — When to invoke this skill

A project is ready for this review when:
- User says "our tests don't catch bugs"
- User says "we have X tests but production still breaks"
- User says "we need to enforce coverage"
- Before a major release / handoff / audit
- After any "why did the deploy pipeline pass?" incident
- When onboarding a new project to CI gates

Fetch this reference, run the 5-question audit, then propose a L0→L1→L2 rollout plan sized for the team.
