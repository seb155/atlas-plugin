# Woodpecker CI 3.x — API Paths Used by ATLAS

> Canonical endpoints extracted from the official Swagger spec at
> `https://ci.axoiq.com/swagger/doc.json` (Woodpecker 3.14.0-rc.0).
> Served with `Authorization: Bearer $WP_TOKEN` — no SSO bypass needed.

## Endpoints used by atlas-plugin (v5.14.1+)

### Meta (read)

| Method | Path | CLI command | Purpose |
|--------|------|-------------|---------|
| `GET` | `/api/version` | — | Server version (diagnostic) |
| `GET` | `/api/user` | — | Current user (token-scope smoke test) |
| `GET` | `/swagger/doc.json` | — | OpenAPI spec — authoritative reference |

### Pipelines (read)

| Method | Path | CLI command |
|--------|------|-------------|
| `GET` | `/api/repos/{repo_id}/pipelines?per_page=N` | `atlas ci list [--limit N]` |
| `GET` | `/api/repos/{repo_id}/pipelines/{number}` | `atlas ci pipeline N`, `atlas ci watch N`, `atlas ci logs N` |
| `GET` | `/api/repos/{repo_id}/pipelines/{number}/config` | — (rendered YAML — not wired yet) |
| `GET` | **`/api/repos/{repo_id}/logs/{number}/{stepID}`** | `atlas ci logs N --step X` (base64 `.data` per line) |

### Pipelines (actions)

| Method | Path | CLI command |
|--------|------|-------------|
| `POST` | `/api/repos/{repo_id}/pipelines/{number}` | `atlas ci rerun N` |

### Secrets (repo-level)

| Method | Path | CLI command |
|--------|------|-------------|
| `GET` | `/api/repos/{repo_id}/secrets` | `atlas ci secrets list` |
| `POST` | `/api/repos/{repo_id}/secrets` | `atlas ci secrets set` (create path) |
| `PATCH` | `/api/repos/{repo_id}/secrets/{name}` | `atlas ci secrets set` (update path; fallback on 409/500) |
| `DELETE` | `/api/repos/{repo_id}/secrets/{name}` | `atlas ci secrets rm` |

**Secret request body schema** (POST/PATCH):

```json
{
  "name": "ssh_key",
  "value": "<secret value>",
  "events": ["push", "deployment"],
  "images": []
}
```

### Agents (admin token)

| Method | Path | CLI command |
|--------|------|-------------|
| `GET` | `/api/agents?per_page=50` | `atlas ci agents` |

`{repo_id}` for Synapse = `1` (override via env `WP_REPO_ID`).

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

### 5. Log entries with `data: null` (fixed v5.14.1)

Some log rows are tracing/metadata markers with `data: null` instead of base64 payload:

```json
{"id":13692812,"step_id":1718,"time":0,"line":11,"data":null,"type":0}
```

Previously crashed with `'NoneType' object has no attribute 'rstrip'`. The CLI now silently skips these rows.

### 6. Secrets missing at parse time → pipeline errors to `error`

If a `when: event: pull_request` step references a secret that doesn't exist,
the PR pipeline **ERRORS at parse time** (no workflows start). Push pipelines
for the same step are fine because Woodpecker resolves the secret only for
the matching event. Error message example:

```
secret "forgejo_ci_bot_token" not found
```

Fix:

```bash
atlas ci secrets set forgejo_ci_bot_token "$TOKEN" --events pull_request,push
```

### 7. Secret update: POST→PATCH fallback

Some Woodpecker 3.x builds return `409`/`500` from `POST /secrets` when the
name already exists instead of treating it as an update. The CLI handles this
by first attempting `POST` (create), then falling back to `PATCH` on the
`/secrets/{name}` endpoint for update. Net effect: a single
`atlas ci secrets set` invocation works for both create and update cases.

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
