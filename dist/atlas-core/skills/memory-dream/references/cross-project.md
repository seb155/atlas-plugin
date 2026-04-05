# Phase 5 — Cross-Project Consistency

> Multi-repo memory analysis. Read-only across other projects.
> Only runs with `--deep` or `--cross-project` flag.

**CRITICAL RULE**: NEVER write to memory directories of other projects. Read-only cross-project. Resolution only modifies the CURRENT project's memory files.

---

## C1 — Discovery

Find all memory directories across Claude projects.

### Step C1.1 — Discover memory dirs

```bash
find ~/.claude/projects -name "MEMORY.md" -printf "%h\n" 2>/dev/null
```

### Step C1.2 — Profile each directory

For each discovered memory directory:

```bash
# Read MEMORY.md headers
grep "^## " "$dir/MEMORY.md"

# Count files and total lines
file_count=$(ls "$dir"/*.md 2>/dev/null | wc -l)
line_count=$(wc -l "$dir"/*.md 2>/dev/null | tail -1 | awk '{print $1}')

# Extract ACTIVE WORK table entries
sed -n '/ACTIVE WORK/,/^$/p' "$dir/MEMORY.md" | grep "^|" | tail -n +3
```

### Step C1.3 — Extract infrastructure references

From each MEMORY.md, extract shared entities:
```bash
# VMs: VM NNN patterns
grep -oh 'VM [0-9]\{2,4\}' "$dir/MEMORY.md" | sort -u

# Services: port numbers
grep -oh ':[0-9]\{4,5\}' "$dir/MEMORY.md" | sort -u

# IPs: IPv4 patterns
grep -oh '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' "$dir/MEMORY.md" | sort -u

# Versions: vN.N.N patterns
grep -oh 'v[0-9]\+\.[0-9]\+\.[0-9]\+' "$dir/MEMORY.md" | sort -u
```

---

## C2 — Shared Entity Reconciliation

Build a map of entities that appear in multiple projects.

### Entity types to track

| Entity Type | Grep Pattern | Example |
|-------------|-------------|---------|
| VMs | `VM [0-9]+` | VM 550, VM 560, VM 602 |
| Hostnames | known list: `ATL-dev`, `sgagnon`, etc. | ATL-dev |
| Services | service names + ports | Forgejo :3000, Authentik :9443 |
| Repos | repo names | synapse, atlas-plugin |
| Plugin version | `v[0-9]+\.[0-9]+\.[0-9]+` | v3.23.3 |
| Stack versions | `Python [0-9.]+`, `bun [0-9.]+` | Python 3.13 |
| IPs | IPv4 addresses | 192.168.10.75 |
| DNS names | `*.axoiq.com` patterns | synapse.axoiq.com |

### Entity map output

```
C2 — Shared Entity Map
┌──────────────────┬──────────────────┬──────────────────┬──────────────────┐
│ Entity           │ synapse          │ atlas            │ dev-plugin       │
├──────────────────┼──────────────────┼──────────────────┼──────────────────┤
│ VM 550           │ decommissioned   │ —                │ —                │
│ VM 560           │ coding only      │ coding only      │ —                │
│ VM 602           │ observability    │ —                │ —                │
│ Forgejo IP       │ 192.168.10.75    │ 192.168.10.75    │ 192.168.10.75    │
│ Plugin version   │ v3.23.0          │ —                │ v3.23.3          │
│ Python           │ 3.13             │ 3.13             │ —                │
│ Authentik        │ SSO live         │ SSO live         │ —                │
│ NetBird          │ v0.67.0          │ v0.67.0          │ —                │
└──────────────────┴──────────────────┴──────────────────┴──────────────────┘
```

---

## C3 — Contradiction Detection

Identify cases where the same entity has different status or values across projects.

### Contradiction types

| Type | Example | Severity |
|------|---------|----------|
| Status mismatch | "VM 550 decommissioned" vs "VM 550 active" | HIGH |
| Version drift | Plugin v3.23.0 vs v3.23.3 | MEDIUM |
| Port/IP conflict | Same port claimed by different services | HIGH |
| Role conflict | "VM 560 = Docker host" vs "VM 560 = coding only" | MEDIUM |
| Count mismatch | "52 skills" vs "48 skills" | LOW |

### Detection logic

For each entity in the entity map:
1. Compare values across all projects where entity appears
2. If values differ, flag as contradiction
3. Determine which project is likely more current (by MEMORY.md modification date)
4. Suggest resolution direction

### Contradiction output

```
C3 — Contradictions Detected
┌──────────────────┬──────────────────────────┬──────────────────────────┬─────────────────────────┐
│ Entity           │ Project A (synapse)      │ Project B (dev-plugin)   │ Resolution              │
├──────────────────┼──────────────────────────┼──────────────────────────┼─────────────────────────┤
│ Plugin version   │ v3.23.0 (MEMORY.md)      │ v3.23.3 (MEMORY.md)     │ dev-plugin is SSoT →    │
│                  │                          │                          │ update synapse           │
│ Skills count     │ "52 skills"              │ "48 skills"              │ Count actual: 52 →      │
│                  │                          │                          │ update dev-plugin        │
│ VM 550 status    │ "decommissioned"         │ "running services"       │ Check: ping VM 550 →    │
│                  │                          │                          │ resolve by reality       │
└──────────────────┴──────────────────────────┴──────────────────────────┴─────────────────────────┘
```

---

## C4 — Output & Resolution

### Summary dashboard

```
📊 Cross-Project Memory Analysis
┌─────────────┬───────┬────────┬────────────────┐
│ Project     │ Files │ Lines  │ Contradictions │
├─────────────┼───────┼────────┼────────────────┤
│ synapse     │ 178   │ 149    │ 0              │
│ atlas       │ 45    │ 136    │ 2              │
│ dev-plugin  │ 12    │ 32     │ 0              │
└─────────────┴───────┴────────┴────────────────┘

Total entities tracked: 14
Shared across 2+ projects: 8
Contradictions found: 2
```

### HITL gate (H17)

For each contradiction, present resolution options:
```
Contradiction: Plugin version
  synapse/MEMORY.md says v3.23.0
  dev-plugin/MEMORY.md says v3.23.3

  [Update THIS project's memory] / [Skip] / [Note for manual fix]
```

### Resolution rules (NON-NEGOTIABLE)

1. **NEVER write to other projects' memory directories** — read-only cross-project
2. Resolution only modifies the **current** project's memory files
3. If the current project is wrong, update it
4. If another project is wrong, output a recommendation but do NOT modify it
5. User must manually fix other projects (or run dream in that project)

### Resolution actions (current project only)

| Action | What happens |
|--------|-------------|
| **Update** | Edit the memory file in THIS project to match reality |
| **Skip** | No change, contradiction noted in dream report |
| **Note** | Add `<!-- cross-project: value differs in {project}, last checked YYYY-MM-DD -->` |

---

## Execution Flow

```
Phase 5 — Cross-Project
├── C1: Discovery (find all MEMORY.md dirs)
│   └── Profile each: files, lines, entities
├── C2: Entity reconciliation (build shared entity map)
│   └── Output: entity map table
├── C3: Contradiction detection (diff values across projects)
│   └── Output: contradictions table
└── C4: Resolution
    └── HITL H17: per-contradiction decision (update/skip/note)
        └── Writes ONLY to current project's memory
```

**Model**: Opus (cross-repo reasoning, entity resolution)
**Time estimate**: ~5 min standalone (`--cross-project`), ~5 min as part of `--deep`
**Safety**: Read-only for all other projects. Write-capable only for current project after HITL approval.

---

*Reference: cross-project | Skill: memory-dream v2 | Phase: 5*
