# TDD Cycle Example — Adding a new API endpoint

## Step 1: RED — Write a failing test

```python
# tests/api/test_project_settings.py
def test_get_project_settings(client, test_project):
    response = client.get(f"/api/v1/projects/{test_project.id}/settings")
    assert response.status_code == 200
    data = response.json()
    assert "timezone" in data
    assert "default_units" in data
```

Run: `pytest tests/api/test_project_settings.py -x -q --tb=short`
Expected: FAIL (endpoint doesn't exist yet)

## Step 2: GREEN — Minimal implementation

```python
# backend/app/api/v1/project_settings.py
@router.get("/projects/{project_id}/settings")
async def get_project_settings(project_id: str, db: AsyncSession = Depends(get_db)):
    settings = await db.execute(
        select(ProjectSettings).where(ProjectSettings.project_id == project_id)
    )
    return settings.scalar_one_or_none() or {"timezone": "UTC", "default_units": "metric"}
```

Run: `pytest tests/api/test_project_settings.py -x -q --tb=short`
Expected: PASS

## Step 3: REFACTOR — Clean up

- Extract default settings to a constant
- Add proper Pydantic response schema
- Add error handling for missing project

## Step 4: COMMIT

```bash
git add -A
git commit -m "feat(api): add project settings endpoint (TDD)"
```

## Cycle Rules

1. Never write implementation without a failing test first
2. Write the MINIMUM code to make the test pass
3. Refactor only after green
4. Commit after each green cycle
5. Max 2 fix attempts per failing test — escalate if stuck
