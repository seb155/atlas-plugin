# Phase 2.5 — Validate

> Intelligence layer that verifies memory content matches codebase reality.
> Only runs with `--deep` or `--validate` flag.

---

## V1 — Code Staleness Detection

Detect file paths, hooks, functions, and API endpoints referenced in memory that no longer exist in code.

### Step V1.1 — Extract file paths from memory

```bash
grep -roh 'backend/[^ )"]*\.py\|frontend/[^ )"]*\.\(ts\|tsx\)' "$MEMORY_DIR"/*.md | sort -u
```

### Step V1.2 — Check existence

For each extracted path:
```bash
[ -f "$path" ] && echo "LIVE" || echo "DEAD"
```

**Safety**: A missing file may exist on another branch. Always note git branch context:
```bash
git -C "$PROJECT_ROOT" branch --show-current
```

If file is DEAD on current branch, check if it exists on `dev` or `main`:
```bash
git -C "$PROJECT_ROOT" ls-tree --name-only dev -- "$path" 2>/dev/null
```

### Step V1.3 — Extract hook/function names

```bash
grep -roh 'use[A-Z][a-zA-Z]*\|def [a-z_]*' "$MEMORY_DIR"/*.md | sort -u
```

For each symbol, search codebase:
```bash
grep -rl "$symbol" "$PROJECT_ROOT/frontend/src/" "$PROJECT_ROOT/backend/" 2>/dev/null
```

### Step V1.4 — Extract API endpoints

```bash
grep -roh '/api/v1/[a-z/_-]*' "$MEMORY_DIR"/*.md | sort -u
```

Match against backend route definitions:
```bash
grep -rn "$endpoint" "$PROJECT_ROOT/backend/app/api/" 2>/dev/null
```

### V1 Output Template

```
V1 — Code Staleness Report
┌─────────────────────────────────┬────────┬──────────────────────┬─────────────────────────────────┐
│ Reference                       │ Status │ Memory File          │ Suggestion                      │
├─────────────────────────────────┼────────┼──────────────────────┼─────────────────────────────────┤
│ backend/app/services/foo.py     │ DEAD   │ import-pipeline.md   │ Renamed to bar.py? Check git    │
│ useWorkspaceNavigation          │ LIVE   │ MEMORY.md            │ OK                              │
│ def calculate_bom               │ MOVED  │ procurement.md       │ Now in bom_service.py           │
│ /api/v1/instruments/classify    │ LIVE   │ isa-classification.md│ OK                              │
│ frontend/src/hooks/useTree.ts   │ DEAD   │ sp14-unified-tree.md │ Branch-specific? (on dev only)  │
└─────────────────────────────────┴────────┴──────────────────────┴─────────────────────────────────┘

Summary: 12 refs checked — 9 LIVE, 2 DEAD, 1 MOVED
```

Status values:
- **LIVE** — File/symbol exists at expected location
- **DEAD** — Not found on current branch or `dev`/`main`
- **MOVED** — Found at different path (fuzzy match by filename)

---

## V2 — Status Claim Verification

Grep all status claims and verify each against its source of truth.

### Step V2.1 — Extract claims

```bash
grep -rn 'COMPLETE\|LIVE\|DONE\|SHIPPED\|DEPLOYED\|FIXED\|RESOLVED' "$MEMORY_DIR"/*.md | grep -v '^Binary'
```

### Step V2.2 — Verification methods by claim type

| Claim Pattern | Verification Method | Command |
|---------------|---------------------|---------|
| "COMPLETE" / "DONE" | Check FEATURES.md DoD tier | `grep -A2 "$feature" .blueprint/FEATURES.md` |
| "LIVE" / "DEPLOYED" | Health endpoint or docker status | `curl -s http://localhost:8001/health \| jq .status` or `docker compose ps --format json` |
| "N tests" (count) | Count test functions | `grep -c "def test_\|it(" "$test_dir"/**` |
| "vX.Y.Z" (version) | Check package manifest | `grep '"version"' package.json` or `grep 'version =' pyproject.toml` |
| "FIXED" | Search for residual TODO/FIXME | `grep -rn "TODO\|FIXME" "$PROJECT_ROOT" --include="*.py" --include="*.ts" \| grep -i "$topic"` |
| "SHIPPED" | Check main branch for merge | `git log main --oneline --grep="$feature" \| head -3` |
| "RESOLVED" | Verify no open issues | `grep -rn "$topic" "$PROJECT_ROOT" --include="*.md" \| grep -i "TODO\|BLOCKER\|WIP"` |
| "N containers" | Docker compose count | `docker compose ps --format json \| jq -s 'length'` |
| "port NNNN" | Check listening ports | `ss -tlnp \| grep ":$port"` |

### Step V2.3 — Batch verification

Run all verifications, collect results. Present stale claims as batch to user.

### V2 Output Template

```
V2 — Status Claim Verification
┌────────────────────────────────────┬──────────────────────┬──────────────────────────────┬────────┐
│ Claim                              │ File                 │ Verification                 │ Result │
├────────────────────────────────────┼──────────────────────┼──────────────────────────────┼────────┤
│ "SP-16 Test Coverage P0-P5 DONE"   │ test-coverage-sp16.md│ FEATURES.md tier = VALIDATING│ ✅     │
│ "171 BE test files"                │ test-coverage-sp16.md│ find: 183 files              │ ⚠️ stale│
│ "Plugin v3.23.0"                   │ MEMORY.md            │ plugin.json: v3.23.3         │ ⚠️ stale│
│ "SSO Validation 53/53 PASS"        │ sso-validation.md    │ test run: 53/53              │ ✅     │
│ "VM 550 decom"                     │ sso-activation.md    │ ping: unreachable            │ ✅     │
│ "BE 44.8% coverage"               │ test-coverage-sp16.md│ coverage run: 47.2%          │ ⚠️ stale│
└────────────────────────────────────┴──────────────────────┴──────────────────────────────┴────────┘

Summary: 14 claims checked — 10 ✅ current, 3 ⚠️ stale, 1 🔴 wrong
```

Result values:
- **✅** — Claim matches reality
- **⚠️ stale** — Claim was true but values have drifted (e.g., count changed)
- **🔴 wrong** — Claim is factually incorrect (e.g., feature marked DONE but still WIP)

### HITL Gate (H3)

Present all stale/wrong claims as a batch. User decides per-claim:
- **Update** — Modify the memory file with current value
- **Skip** — Leave as-is (user knows it's intentional)
- **Note** — Add "(as of YYYY-MM-DD)" qualifier

---

## V3 — External Reference Validation

Verify that file paths, plan references, and URLs referenced in memory actually exist.

### Step V3.1 — File path validation

```bash
grep -roh '/home/[^ )"]*\|\.blueprint/[^ )"]*\|\./[^ )"]*' "$MEMORY_DIR"/*.md | sort -u
```

For each path:
```bash
[ -f "$path" ] && echo "EXISTS" || ([ -d "$path" ] && echo "DIR" || echo "MISSING")
```

### Step V3.2 — Plan reference validation

```bash
grep -roh '[a-z-]*\-[a-z-]*\.md' "$MEMORY_DIR"/*.md | sort -u | while read plan; do
  [ -f ".blueprint/plans/$plan" ] && echo "EXISTS: $plan" || echo "MISSING: $plan"
done
```

### Step V3.3 — Blueprint reference validation

```bash
grep -roh '\.blueprint/[A-Z_-]*\.md' "$MEMORY_DIR"/*.md | sort -u | while read doc; do
  [ -f "$doc" ] && echo "EXISTS: $doc" || echo "MISSING: $doc"
done
```

### Step V3.4 — URL validation (--deep only)

Only runs with `--deep` flag. Rate-limited to avoid flooding:
```bash
grep -roh 'https\?://[^ )"]*' "$MEMORY_DIR"/*.md | sort -u | while read url; do
  status=$(curl -sI --max-time 5 "$url" 2>/dev/null | head -1 | awk '{print $2}')
  echo "$status $url"
done
```

Skip localhost/internal URLs — they depend on VPN/network context.

### V3 Output Template

```
V3 — External Reference Validation
┌────────────────────────────────────────────────┬────────┬─────────┬────────────┐
│ Reference                                      │ Type   │ Status  │ Age        │
├────────────────────────────────────────────────┼────────┼─────────┼────────────┤
│ .blueprint/plans/ticklish-tinkering-puppy.md   │ plan   │ EXISTS  │ 14d        │
│ .blueprint/DEFINITION-OF-DONE.md               │ doc    │ EXISTS  │ 7d         │
│ .blueprint/plans/old-removed-plan.md           │ plan   │ MISSING │ —          │
│ /home/sgagnon/Downloads/Synapse_Import/        │ dir    │ EXISTS  │ —          │
│ https://synapse.axoiq.com/api/v1/health        │ url    │ 200 OK  │ —          │
│ https://forgejo.axoiq.com/axoiq/synapse        │ url    │ 200 OK  │ —          │
└────────────────────────────────────────────────┴────────┴─────────┴────────────┘

Summary: 18 refs checked — 15 EXISTS, 2 MISSING, 1 TIMEOUT
```

---

## V4 — Context Failure Mode Detection (NEW — v3)

> Source: Anthropic Context Engineering Guide + LangChain failure taxonomy.
> Detects 4 failure modes that degrade AI context quality.

### Step V4.1 — Poisoning Detection

Status claims in memory that contradict current git/test reality.

```bash
# Find COMPLETE/DONE claims, cross-ref with git branches still open
for claim_file in $(grep -rl "COMPLETE\|ALL.*DONE" "$MEMORY_DIR"/*.md); do
  topic=$(grep -m1 "name:" "$claim_file" | sed 's/name: //')
  # Check if a feature branch still exists for this "done" topic
  git branch -a 2>/dev/null | grep -i "${topic// /-}" && echo "POISONED? $claim_file has DONE but branch exists"
done
```

### Step V4.2 — Distraction Detection

Files >50KB that inflate context without proportional value.

```bash
du -k "$MEMORY_DIR"/*.md | awk '$1 > 50 {print "DISTRACTION:", $1, "KB —", $2}'
```

Action: Flag for split (Phase 3.6 split wizard).

### Step V4.3 — Confusion Detection (Entity Duplication)

Same entity (IP, version, URL, port) described differently in 2+ files.

```bash
# Extract versioned claims: "vX.Y.Z" with surrounding context
grep -rn "v[0-9]\+\.[0-9]\+\.[0-9]\+" "$MEMORY_DIR"/*.md | \
  awk -F: '{print $3, "→", FILENAME}' | sort | \
  # Group by entity name, flag conflicts
  # Example: "NetBird v0.67.0" in file A but "v0.66.2" in file B
```

For IPs, ports, URLs — extract and compare across files:
```bash
# Build entity→value map from all files
for entity in "Authentik" "Forgejo" "NetBird" "Caddy" "Synapse"; do
  grep -rn "$entity" "$MEMORY_DIR"/*.md | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+" | sort -u
done
```

If same entity has >1 IP/version → flag as CONFUSION.

### Step V4.4 — Clash Detection (Contradictions)

Direct contradictions between memory files.

Patterns to detect:
- Same feature: `DONE` in file A, `BACKLOG` in file B
- Same service: `port 8001` in file A, `port 8002` in file B
- Same decision: "chose X over Y" in file A, "chose Y over X" in file B

```bash
# Extract status per topic across files
grep -rn "COMPLETE\|DONE\|BACKLOG\|PLANNING\|LIVE\|BLOCKED" "$MEMORY_DIR"/*.md | \
  awk -F: '{gsub(/.*\//, "", $1); print $1, $3}' | sort
# Manual review: same topic with conflicting status = CLASH
```

### V4 Output Template

```
V4 — Context Failure Modes
┌──────────────┬───────────────────────────┬─────────────────────────────────┬────────────────────────────────┐
│ Mode         │ Finding                   │ Files                           │ Suggestion                     │
├──────────────┼───────────────────────────┼─────────────────────────────────┼────────────────────────────────┤
│ POISONING    │ SP-XX marked DONE but     │ sp-xx.md, MEMORY.md             │ Verify: tests pass? branch     │
│              │ branch still open         │                                 │ merged?                        │
│ DISTRACTION  │ session-log.md = 60KB     │ session-log.md                  │ Archive entries >60d           │
│ CONFUSION    │ NetBird version: v0.67.0  │ netbird-mesh.md vs              │ Which is current? Update one   │
│              │ vs v0.66.2                │ netbird-migration.md            │                                │
│ CLASH        │ SP-AGENT-OPT: DONE in    │ agent-teams.md vs MEMORY.md     │ Reconcile status               │
│              │ one file, P0-P4 in other  │                                 │                                │
└──────────────┴───────────────────────────┴─────────────────────────────────┴────────────────────────────────┘

Summary: 2 POISONING, 1 DISTRACTION, 1 CONFUSION, 0 CLASH
```

### HITL Gate (H18 — NEW)

Present all detected failure modes as batch. User decides:
- **Fix** — Update the conflicting file(s)
- **Ignore** — Known intentional (e.g., version on different branch)
- **Defer** — Add to next dream cycle

---

## V5 — Temporal Window Audit (NEW — v3)

> Source: Zep/Graphiti temporal knowledge graphs.
> Checks `(since YYYY-MM-DD)` annotations in ACTIVE WORK.

### Step V5.1 — Extract temporal windows

```bash
grep -oP "\(since \d{4}-\d{2}-\d{2}\)" "$MEMORY_DIR/MEMORY.md"
```

### Step V5.2 — Flag aged items

Items with `(since ...)` older than 60 days → propose moving from ACTIVE WORK to COMPLETED WORK archive section.

### Step V5.3 — Missing temporal windows

COMPLETE/DONE items WITHOUT `(since ...)` → propose adding based on file modification date.

---

## Execution Flow

```
Phase 2.5 — Validate
├── V1: Code staleness (paths, hooks, endpoints)
│   └── Output: staleness table
├── V2: Status claims (DONE/LIVE/SHIPPED)
│   └── HITL H3: batch review stale claims
├── V3: External references (files, plans, URLs)
│   └── Output: reference table
├── V4: Context failure modes (poisoning, distraction, confusion, clash) [NEW v3]
│   └── HITL H18: batch review failure modes
└── V5: Temporal window audit (aged items, missing annotations) [NEW v3]
    └── Output: temporal audit table
```

**Model**: Opus (code understanding + semantic verification)
**Time estimate**: ~7 min standalone (`--validate`), ~5 min as part of `--deep`
**Safety**: Read-only analysis. No files modified during this phase. Modifications happen in Phase 3 after HITL approval.

---

*Reference: validate-phase | Skill: memory-dream v3 | Phase: 2.5*
