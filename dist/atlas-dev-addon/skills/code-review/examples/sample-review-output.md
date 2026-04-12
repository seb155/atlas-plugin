# Sample Code Review Output

## Code Review — feature/add-project-settings

### Summary
Adds a new project settings API endpoint with CRUD operations and Zustand store integration.

### Issues Found

| # | Severity | File | Line | Issue |
|---|----------|------|------|-------|
| 1 | 🔴 CRITICAL | backend/app/api/v1/settings.py | 42 | SQL injection via f-string in filter |
| 2 | 🟡 WARNING | frontend/src/hooks/useSettings.ts | 15 | Missing error state in TanStack Query |
| 3 | 🟡 WARNING | backend/app/services/settings.py | 28 | No `project_id` filter — Synapse Principle #2 |
| 4 | 🔵 SUGGESTION | frontend/src/components/SettingsPanel.tsx | 90 | Could reuse existing `FormField` component |

### Details

#### 🔴 #1 — SQL injection via f-string
**File**: `backend/app/api/v1/settings.py:42`
**Current**: `db.execute(f"SELECT * FROM settings WHERE key = '{key}'")`
**Fix**: Use parameterized query: `db.execute(select(Settings).where(Settings.key == key))`
**Why**: OWASP A03:2021 — Injection

#### 🟡 #2 — Missing error state
**File**: `frontend/src/hooks/useSettings.ts:15`
**Current**: Only handles `data` and `isLoading`
**Fix**: Add `error` and `isError` handling with user-visible feedback
**Why**: UX rules require loading + error + empty states on every view

#### 🟡 #3 — No project_id filter
**File**: `backend/app/services/settings.py:28`
**Current**: `select(Settings)` without project scope
**Fix**: `select(Settings).where(Settings.project_id == project_id)`
**Why**: Synapse Principle #2 — DB-First SSoT, project_id on every query

#### 🔵 #4 — Reusable component
**File**: `frontend/src/components/SettingsPanel.tsx:90`
**Suggestion**: Use `FormField` from `@/components/ui/form-field` instead of inline implementation

### Verdict
❌ **REQUEST CHANGES** — 1 critical issue (SQL injection) must be fixed before merge.
