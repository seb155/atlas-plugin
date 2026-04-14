---
name: folder-structure-patterns
description: "Folder structure patterns: feature-based, test colocation, monorepo layouts. Used by code-hygiene-rules skill."
effort: low
type: reference
---

# Folder Structure Patterns

Two questions drive folder structure: **How do features group?** and **Where do tests live?**

## 1. Feature-based vs Layer-based

### Layer-based (traditional)

```
src/
├── controllers/           # all controllers from all features
├── services/              # all services
├── repositories/          # all repos
├── models/                # all models
└── utils/                 # shared helpers
```

**Pros**: Familiar, easy to teach, framework-friendly (Rails, Django default).
**Cons**: Feature changes touch every folder (shotgun surgery). Hard to know what belongs together.

**When to use**: Small apps (<50 files), framework-driven bootstrapping.

### Feature-based (SOTA for growing apps)

```
src/
├── users/                 # feature: user management
│   ├── user-list.tsx     # component
│   ├── user-service.ts   # logic
│   ├── user-api.ts       # HTTP
│   ├── user-types.ts     # types
│   └── user-list.test.tsx  # test colocated
├── orders/                # feature: order management
│   ├── order-detail.tsx
│   ├── order-service.ts
│   └── ...
└── shared/                # truly cross-feature only
    ├── ui/                # design system
    └── utils/
```

**Pros**: One feature = one folder = easy to find/move/delete. Teams own features cleanly.
**Cons**: "Where does this shared helper go?" debates. Needs discipline about cross-feature imports.

**When to use**: Apps > 50 files, teams owning distinct domains, expected long lifespan.

**ATLAS recommendation**: feature-based for new projects, migrate layer → feature when apps grow.

## 2. Test colocation vs test directory

### Colocated (SOTA)

```
src/
└── users/
    ├── user-service.ts
    └── user-service.test.ts   # RIGHT NEXT to source
```

**Pros**: Easy to find tests for a file. Delete file → delete test together. Encourages test updates.
**Cons**: Tests bloat feature folders. Build/ship must exclude tests from artifacts.

### Separate directory (traditional)

```
src/
└── users/
    └── user-service.ts
tests/
└── users/
    └── user-service.test.ts   # parallel tree
```

**Pros**: Clean separation, traditional in Python/Java. Artifacts exclusion trivial.
**Cons**: Refactor/rename → remember to update the test path. Tests get forgotten.

**ATLAS recommendation**: Colocate for TS/JS, traditional `tests/` for Python (PEP 8 convention).

## 3. Monorepo layouts

### `packages/` workspace (Turbo, Nx, Lerna)

```
repo/
├── packages/
│   ├── core/              # shared library
│   │   ├── src/
│   │   └── package.json
│   ├── web/               # frontend app
│   │   ├── src/
│   │   └── package.json
│   └── api/               # backend
│       ├── src/
│       └── package.json
├── turbo.json
└── package.json           # workspace root
```

**Pros**: Shared code versioned together, atomic refactors across packages.
**Cons**: Setup complexity, build orchestration (Turbo/Nx required).

### Apps + services (Synapse-style)

```
synapse/
├── backend/               # FastAPI Python app
├── frontend/              # React TS app
├── toolkit/               # Python CLI tools
├── data/                  # data files (inputs, config)
└── .blueprint/            # docs + plans
```

Separation by TECHNOLOGY + DEPLOYMENT UNIT. Good for mixed-stack projects.

## 4. Depth limits

```
# Good — shallow, discoverable
src/
└── users/
    ├── user-list.tsx
    └── user-service.ts

# Bad — too deep (3+ nested feature folders)
src/
└── features/
    └── user-management/
        └── components/
            └── lists/
                └── user-list.tsx    # 5 levels deep
```

**Rule**: max 3-4 levels deep from `src/`. If deeper, feature should split into sub-features.

## 5. Shared/utility rules

```
src/
├── users/                 # feature folder
├── orders/                # feature folder
└── shared/                # use SPARINGLY
    ├── ui/                # design-system components
    ├── utils/             # truly domain-agnostic helpers (date, currency)
    └── types/             # cross-feature types (rare)
```

**Shared folder discipline**:
- Put something in `shared/` ONLY if ≥ 2 features use it
- ASCII test: could this code live in a separate npm package? If yes, it's shared. If no, it belongs to the one feature using it.
- Review shared regularly: if only 1 feature uses a "shared" helper, move it back

## 6. Configuration files (standard locations)

| File | Location | Purpose |
|------|----------|---------|
| `README.md` | root | Project overview |
| `CLAUDE.md` | root + sub-dirs | AI maintenance context (ATLAS) |
| `CONTRIBUTING.md` | root | Contributor guide |
| `CHANGELOG.md` | root | Version history |
| `package.json` / `pyproject.toml` | root | Package metadata |
| `.gitignore` | root | Git exclusions |
| `.env.example` | root | Example env vars |
| `docs/` | root | Human documentation |
| `.blueprint/` | root (ATLAS) | Plans, patterns, AI-readable docs |
| `.atlas/` | root (ATLAS) | ATLAS config per project |

## 7. Anti-patterns

| Anti-pattern | Symptom | Fix |
|--------------|---------|-----|
| `components/` at root | Flat component dump, no feature context | Group by feature |
| `utils/` as dumping ground | Any random helper | Split: `date-utils.ts`, `currency-utils.ts`, or co-locate |
| Deep nesting (>4 levels) | `src/features/a/b/c/d/` | Flatten or split feature |
| `src/random-file.ts` at root | Unowned file | Put in a feature or `shared/` |
| Tests in `__tests__` vs `.test.ts` | Inconsistent | Pick one per project |
| `index.ts` barrel at every level | Over-barrelling, circular imports | Barrel only at feature boundary |

## Decision flowchart

```
Q: New file?
├── Is it for ONE feature? → put in that feature folder
├── Is it used by 2+ features? → shared/
└── Is it test? → colocate (TS/JS) or tests/ tree (Python)

Q: New feature folder?
├── Is it big enough (≥ 5 files)? → yes, create folder
└── Small (1-2 files)? → put in parent feature or shared/

Q: New import from another feature?
├── Going through well-defined public API? → OK
└── Reaching into implementation? → RED FLAG, extract to shared/ or public API
```

## References

- [Bulletproof React folder structure](https://github.com/alan2207/bulletproof-react)
- [Clean Architecture folder structure examples](https://github.com/mehdihadeli/awesome-software-architecture/blob/main/docs/clean-architecture.md)
- `naming-conventions/` — file naming rules
- `sota-architecture-patterns/` — architecture-level folder layouts
