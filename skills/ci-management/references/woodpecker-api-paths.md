# Woodpecker CI 3.x — API Paths Used by ATLAS

> Canonical endpoints extracted from the official Swagger spec at
> `https://ci.axoiq.com/swagger/doc.json` (Woodpecker 3.14.0-rc.0).
> Served with `Authorization: Bearer $WP_TOKEN` — no SSO bypass needed.

## Endpoints in active use

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/api/version` | Server version (diagnostic) |
| `GET` | `/api/user` | Current user — token-scope smoke test |
| `GET` | `/api/repos/{repo_id}/pipelines?per_page=N` | List recent pipelines |
| `GET` | `/api/repos/{repo_id}/pipelines/{number}` | Pipeline metadata + workflows + step tree |
| `GET` | `/api/repos/{repo_id}/pipelines/{number}/config` | Rendered workflow YAML |
| `GET` | **`/api/repos/{repo_id}/logs/{number}/{stepID}`** | **Step logs** (base64 `.data` per line) |
| `POST` | `/api/repos/{repo_id}/pipelines/{number}` | Retrigger pipeline |
| `GET` | `/api/repos/{repo_id}/agents` | Agent list (admin) |
| `GET` | `/swagger/doc.json` | OpenAPI spec (authoritative reference) |

`{repo_id}` for Synapse = `1` (set via env `WP_REPO_ID` if different).

## Log response shape

`GET /api/repos/1/logs/78/1718` returns:

```json
[
  {"id":13692785,"step_id":1718,"time":0,"line":0,"data":"KyBidW4gaW5zdGFsbCAtLWZyb3plbi1sb2NrZmlsZQ==","type":0},
  {"id":13692786,"step_id":1718,"time":0,"line":1,"data":"YnVuIGluc3RhbGwgdjEuMy4xMiAoNzAwZmMxMTcp","type":0}
]
```

| Field | Meaning |
|-------|---------|
| `id` | Log row DB id |
| `step_id` | Parent step (echoes the path) |
| `time` | Monotonic offset (ms) from step start |
| `line` | Absolute line number — sort on this before rendering |
| `data` | **base64** UTF-8 payload (one terminal line) |
| `type` | 0 = stdout, 1 = stderr, 2 = exit code line |

## Common pitfalls

### 1. `step_id` ≠ `pid`

Each step has **two numeric IDs**:

- `pid` — position in workflow (e.g. `12`). Small, visible in the Woodpecker UI.
- `step_id` (`id` in JSON) — global DB id (e.g. `1718`). Required by `/logs/` path.

Using `pid` where `step_id` is expected → HTTP 200 **with SPA HTML body** (see #2), not 404.

### 2. Wrong path = HTML 200, not 404

Woodpecker's reverse route falls back to `index.html` (SPA) for unmatched `/api/*` paths. Consequences:

- `curl -sf` succeeds (200 is success).
- `Content-Type: text/html; charset=UTF-8` instead of `application/json`.
- Looks like SSO blocked you — it did not.

**Always check `Content-Type` when diagnosing weird API responses.** If you see `text/html` on an `/api/*` endpoint, the path is wrong, not your auth.

### 3. `--frozen-lockfile` failures surface here

When CI runs `bun install --frozen-lockfile` and `bun.lock` drifts from `package.json`, the step fails with:

```
error: lockfile had changes, but lockfile is frozen
note: try re-running without --frozen-lockfile and commit the updated lockfile
```

Fix locally: `cd frontend && bun install && git add bun.lock && git commit -m "chore: refresh lockfile"`

### 4. Skipped steps return no logs

Steps with `state: skipped | pending | killed` have no log rows. The `/logs/` endpoint returns either `[]` or HTTP 404. The ATLAS CLI short-circuits these (see `_atlas_ci_logs_fetch`).

## Quick curl reference

```bash
# Load token from env
export WP_TOKEN=$(grep ^WP_TOKEN= ~/.env | cut -d= -f2-)

# Pipeline metadata
curl -sf -H "Authorization: Bearer $WP_TOKEN" \
  https://ci.axoiq.com/api/repos/1/pipelines/78 | jq .

# Step logs (note: step_id, not pid)
curl -sf -H "Authorization: Bearer $WP_TOKEN" \
  https://ci.axoiq.com/api/repos/1/logs/78/1718 \
  | jq -r '.[] | .data' | base64 -d
```

## Prefer the ATLAS CLI

For day-to-day debugging, use `atlas ci logs`:

```bash
atlas ci logs 78                              # step table
atlas ci logs 78 --step frontend-install      # decoded log by name
atlas ci logs 78 --step 12                    # by pid
atlas ci logs 78 --step 1718                  # by step_id
atlas ci logs 78 --all                        # every step, in order
```

The CLI handles: token loading, step resolution (name/pid/step_id), base64 decoding, and SPA-HTML detection.

## Known limitations

- `GET /api/stream/logs/{repo_id}/{pipeline}/{stepID}` (streaming SSE) not wired in ATLAS CLI yet — use `woodpecker-cli` directly if you need tail-follow.
- Deleting step logs (`DELETE /api/repos/.../logs/...`) not exposed by ATLAS CLI by design (destructive, admin op).

## Why this reference exists

Before this document existed, the `backlog_woodpecker_api_access_fix.md` memory note claimed "Caddy/Authentik SSO middleware intercepts log endpoints." That diagnosis was **wrong**. Evidence and the Swagger spec prove Bearer auth works cleanly — the issue was path+stepID mapping, captured in `lesson_woodpecker_api_path_mapping.md`.

Keep this doc in sync with `/swagger/doc.json` on Woodpecker upgrades.
