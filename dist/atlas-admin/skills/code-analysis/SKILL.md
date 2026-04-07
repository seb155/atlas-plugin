---
name: code-analysis
description: "Codebase architecture analysis: dead code detection, dependency graphs, dataflow tracing, migration impact. Use for understanding what's alive vs dead, tracing data flows, or planning refactors."
effort: medium
model: opus
---

# Code Analysis

**Principle**: Understand before you change. Map before you refactor. Measure before you delete.

## Subcommands

| Command | What it does | When to use |
|---------|-------------|-------------|
| `/atlas analyze dead-code` | Find unused Python code (vulture + import counting) | Before writing tests for services |
| `/atlas analyze deps` | Generate dependency graph (pydeps + madge) | Architecture review, understanding coupling |
| `/atlas analyze dataflow <module>` | Trace who calls a module and what it calls | Before refactoring a service |
| `/atlas analyze migration <from> <to>` | Map migration path between two systems | D3 rules engine migration |
| `/atlas analyze coverage-map` | Map source files to test files, find gaps | Sprint planning for test coverage |
| `/atlas analyze circular` | Find circular imports/dependencies | Performance debugging |

---

## `/atlas analyze dead-code`

### Backend (Python)

```bash
# Step 1: Vulture — global unused code detection
# From the project's backend directory:
pip install vulture 2>/dev/null
vulture app/ --min-confidence 80 --exclude "alembic/,migrations/" 2>&1 | head -50

# Step 2: Import reference counting (custom — more accurate for services)
python3 -c "
from pathlib import Path
from collections import defaultdict

services = Path('app/services')
all_py = list(Path('app').rglob('*.py'))

for svc in sorted(services.rglob('*.py')):
    if svc.name == '__init__.py': continue
    module = str(svc).replace('/', '.').replace('.py', '')
    refs = sum(1 for f in all_py if f != svc and module.split('.')[-1] in f.read_text(errors='ignore'))
    if refs == 0:
        print(f'  DEAD: {svc} (0 references)')
    elif refs == 1:
        print(f'  LOW:  {svc} (1 reference)')
"

# Step 3: Ruff unused imports
# From the project's backend directory:
ruff check app/ --select F401 --output-format concise 2>&1 | head -30
```

### Frontend (TypeScript)

```bash
# Madge — circular dependency detection + unused
# From the project's frontend directory:
bunx madge --circular --extensions ts,tsx src/ 2>&1 | head -30

# dependency-cruiser — full validation
bunx depcruise --output-type err-long src/ 2>&1 | head -50
```

---

## `/atlas analyze deps`

### Backend dependency graph

```bash
# Requires: pip install pydeps graphviz
# From the project's backend directory:

# Service-level dependency graph (SVG output)
pydeps app/services --max-bacon=2 --cluster --no-show \
  -o /tmp/synapse-services-deps.svg 2>&1

# Specific module focus
pydeps app/services/rule_engine.py --max-bacon=3 --no-show \
  -o /tmp/rule-engine-deps.svg
```

### Frontend dependency graph

```bash
# From the project's frontend directory:

# Full dependency graph (dot format → SVG)
bunx madge --image /tmp/synapse-frontend-deps.svg src/App.tsx

# Specific module
bunx madge --image /tmp/stores-deps.svg src/store/
```

---

## `/atlas analyze dataflow <module>`

Trace the complete call chain for a specific module.

### Technique: Import-chain analysis

```bash
# Who imports this module? (downstream consumers)
grep -rl "from app.services.MODULENAME" backend/app/ | sort

# What does this module import? (upstream dependencies)
head -30 backend/app/services/MODULENAME.py | grep "^from\|^import"

# Which endpoints expose it? (API surface)
grep -rl "MODULENAME" backend/app/api/ | sort

# Which tests cover it?
grep -rl "MODULENAME" backend/tests/ | sort
```

### Technique: Runtime tracing (advanced)

```python
# Add to any service temporarily for runtime analysis
import sys
import functools

def trace_calls(func):
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        caller = sys._getframe(1)
        print(f"TRACE: {func.__module__}.{func.__name__} called by {caller.f_code.co_filename}:{caller.f_lineno}")
        return func(*args, **kwargs)
    return wrapper
```

---

## `/atlas analyze migration <from> <to>`

Map the migration path between two coexisting systems.

### Example: D3 Rules Engine Migration

Current state (Synapse 2026-03-20):

```
3 RULE ENGINES COEXIST:
┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────────┐
│ rule_engine.py       │  │ rule_evaluator.py     │  │ rule_engine_service  │
│ (D3 Standard)        │  │ (Legacy Enrichment)   │  │ (Unified 3-tier)     │
│                      │  │                       │  │                      │
│ Table:               │  │ Table:                │  │ Table:               │
│ rule_definitions     │  │ enrichment_rules      │  │ synapse_rules        │
│                      │  │                       │  │                      │
│ Format:              │  │ Format:               │  │ Format:              │
│ property_filters     │  │ field operators       │  │ JsonLogic            │
│ 8 operators          │  │ 5 operators           │  │ and/or/in/==         │
│                      │  │                       │  │                      │
│ Used by:             │  │ Used by:              │  │ Used by:             │
│ - Cable assignment   │  │ - backfill_package    │  │ - backfill_package   │
│ - /api/rules/*       │  │ - enrichment_rules EP │  │ - /proj/rules/*      │
│ - trace_classif.     │  │                       │  │                      │
└──────────────────────┘  └──────────────────────┘  └──────────────────────┘

MIGRATION TARGET:
┌─────────────────────────────────────────────────────────────┐
│ synapse_rules (Unified)                                      │
│ - 3-tier: global → company → project                        │
│ - JsonLogic conditions (superset of all 3 formats)          │
│ - Telemetry: match_count, override_count                    │
│ - Seed: migrate from enrichment_rules + rule_definitions    │
└─────────────────────────────────────────────────────────────┘
```

**Steps to analyze migration**:
1. Count rules in each table: `SELECT COUNT(*) FROM rule_definitions; SELECT COUNT(*) FROM enrichment_rules; SELECT COUNT(*) FROM synapse_rules;`
2. Map each rule_evaluator function to its synapse_rules equivalent
3. Identify rule_engine.py functions not yet in synapse_rules (trace_classification, conflict resolution)
4. Build migration script: enrichment_rules → synapse_rules with format conversion

---

## `/atlas analyze coverage-map`

Map source files to their test files and find gaps.

```bash
# Backend: service → test mapping
python3 -c "
from pathlib import Path

services = sorted(Path('backend/app/services').rglob('*.py'))
tests = {t.stem.replace('test_', ''): t for t in Path('backend/tests').rglob('test_*.py')}

covered = 0
for svc in services:
    if svc.name == '__init__.py': continue
    name = svc.stem
    has_test = name in tests or any(name in t for t in tests)
    status = 'COVERED' if has_test else 'GAP'
    if has_test: covered += 1
    print(f'  [{status:7s}] {svc.relative_to(\"backend\")}')
print(f'\nCoverage: {covered}/{len([s for s in services if s.name != \"__init__.py\"])}')
"

# Frontend: component → test mapping
find frontend/src/components -maxdepth 1 -type d | while read dir; do
  name=$(basename "$dir")
  if find "$dir" -name "*.test.*" 2>/dev/null | grep -q .; then
    echo "  [COVERED] $name"
  else
    echo "  [GAP    ] $name"
  fi
done
```

---

## Tools Reference

| Tool | Purpose | Install | Docs |
|------|---------|---------|------|
| vulture | Dead code (Python) | `pip install vulture` | github.com/jendrikseipp/vulture |
| deadcode | Dead code (Python, more flexible) | `pip install deadcode` | PyPI deadcode |
| ruff F401 | Unused imports | `pip install ruff` | astral.sh/ruff |
| pydeps | Dependency graph (Python) | `pip install pydeps` + Graphviz | github.com/thebjorn/pydeps |
| dependency-cruiser | Dependency graph (TS/JS) | `bun add -D dependency-cruiser` | github.com/sverweij/dependency-cruiser |
| madge | Circular deps + graph (TS/JS) | `bun add -D madge` | github.com/pahen/madge |

## Flags

| Flag | Meaning |
|------|---------|
| `--min-confidence 80` | Vulture: only report items 80%+ likely dead |
| `--max-bacon 2` | pydeps: show 2 levels of dependencies |
| `--circular` | madge: only show circular dependencies |
| `--cluster` | pydeps: group by package |
