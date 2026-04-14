---
name: naming-conventions
description: "Per-language naming conventions reference. Python, TypeScript, Bash, YAML. Used by code-hygiene-rules and senior-discipline-checklist skills."
effort: low
type: reference
---

# Naming Conventions Reference

Authoritative naming conventions per language. Senior-review-checklist and naming-enforcer hook
consult this reference when scoring the "Naming" dimension (10% weight).

## Universal principles (language-agnostic)

1. **Precision over brevity** — `customer_id` beats `cid`; `parsed_order` beats `data`.
2. **WHAT not HOW** — `calculate_total()` not `sum_and_apply_tax()`.
3. **Booleans as questions** — `is_valid`, `has_permission`, `can_edit`.
4. **Domain consistency** — match ubiquitous language; use terms domain experts use.
5. **Avoid type suffixes** — `user_list`, `users_arr`, `order_dict` — let the type system express the type.
6. **No Hungarian notation** — `strName`, `iCount` — let static types do the work.
7. **No generic names** — `data`, `obj`, `info`, `item`, `handle`, `process`, `do`.

## Abbreviations policy

Accepted without team vote (widely understood):
- `id`, `url`, `api`, `db`, `ui`, `uuid`, `iso`, `utc`, `json`, `xml`, `html`, `css`, `sql`, `jwt`

Everything else requires explicit team agreement in `.atlas/hygiene-config.yaml`:
```yaml
naming:
  allow_abbreviations: [id, url, api, db, ui, mgr, cfg]
```

Reject: `usr`, `mgmt`, `ctrl` (unless MVC), `qty`, `idx` (in non-tight loops), `str` as variable name.

## Per-language files

- `python.md` — PEP 8 + domain conventions
- `typescript.md` — React/TS community norms
- `bash.md` — shell script conventions (ATLAS-specific)
- `yaml.md` — YAML key conventions

See each file for language-specific rules and examples.
