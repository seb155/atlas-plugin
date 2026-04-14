---
name: code-smells-catalog
description: "Registry of 10+ anti-patterns with detection heuristics + refactor patterns. Referenced by sota-code-patterns, senior-review-checklist, code-review skills."
effort: low
type: reference
---

# Code Smells & Anti-Patterns Catalog

Reference registry for detecting and refactoring common code smells. Used by senior-review-checklist
and code-review skills. Based on Fowler's *Refactoring* (2nd ed.) + 2026 SOTA literature.

## How to use this catalog

1. **During code review**: grep this file for the pattern you see (e.g., "Long Method")
2. **During refactoring**: look up the smell → apply the recommended refactor
3. **During planning**: use the Detection column to write pre-commit checks

## Class/Module-level smells

### 1. God Class / Blob

| Aspect | Detail |
|--------|--------|
| **Detection** | File > 500 lines OR class > 300 lines OR > 20 methods on one class |
| **Symptom** | Class knows too much, does too much, hard to test in isolation |
| **Refactor** | Extract Class (split by responsibility), Move Method, Move Field |
| **Fowler ref** | Ch. 3, "Large Class" |
| **Example** | `UserService` with auth + profile + billing + notifications methods |

### 2. Long Parameter List

| Aspect | Detail |
|--------|--------|
| **Detection** | Function > 4 parameters |
| **Symptom** | Callers have to pass many args; easy to swap positions; signatures churn often |
| **Refactor** | Introduce Parameter Object, Replace Parameter with Query, Dependency Injection |
| **Example** | `create_user(name, email, age, role, tenant_id, created_by, metadata)` → `create_user(UserCreationRequest)` |

### 3. Data Clumps

| Aspect | Detail |
|--------|--------|
| **Detection** | Same 3+ parameters appear together in many function signatures |
| **Symptom** | Missing abstraction; domain object waiting to be extracted |
| **Refactor** | Extract Class, Preserve Whole Object |
| **Example** | `(street, city, postcode, country)` everywhere → `Address` value object |

### 4. Primitive Obsession

| Aspect | Detail |
|--------|--------|
| **Detection** | Many `str`/`int` parameters for domain concepts (user IDs, emails, amounts) |
| **Symptom** | Weak typing, easy to pass wrong string; validation scattered |
| **Refactor** | Replace Primitive with Object (Value Object), Introduce Parameter Object |
| **Example** | `amount: float` → `Money` value object with currency |

## Method-level smells

### 5. Long Method

| Aspect | Detail |
|--------|--------|
| **Detection** | Function > 50 lines OR cyclomatic complexity > 10 |
| **Symptom** | Hard to understand, hard to test, does too much |
| **Refactor** | Extract Method, Replace Temp with Query, Replace Conditional with Polymorphism |
| **Example** | 80-line `process_order()` → `validate()`, `apply_discounts()`, `calculate_total()`, `persist()` |

### 6. Feature Envy

| Aspect | Detail |
|--------|--------|
| **Detection** | Method uses more data from another class than its own (many foreign getters) |
| **Symptom** | Logic in wrong place; tight coupling |
| **Refactor** | Move Method to the class the data belongs to |
| **Example** | `Order.calculate_shipping()` reads all Customer fields → move to `Customer.get_shipping_rate()` |

### 7. Deep Nesting / Arrow Anti-Pattern

| Aspect | Detail |
|--------|--------|
| **Detection** | > 3 levels of nested `if`/`for`/`while` |
| **Symptom** | Hard to follow control flow, easy to miss edge cases |
| **Refactor** | Guard Clauses (early return), Replace Conditional with Polymorphism, Extract Method |
| **Example** | `if a: if b: if c: do()` → `if not a: return; if not b: return; if not c: return; do()` |

### 8. Magic Numbers / Strings

| Aspect | Detail |
|--------|--------|
| **Detection** | Hardcoded numeric/string constants in business logic |
| **Symptom** | Meaning unclear, duplicate usage, change-one-change-many |
| **Refactor** | Replace Magic Number with Named Constant |
| **Example** | `if age > 18` → `if age > LEGAL_ADULT_AGE` |

## Change-pattern smells

### 9. Shotgun Surgery

| Aspect | Detail |
|--------|--------|
| **Detection** | One logical change touches > 5 files |
| **Symptom** | Missing abstraction; coupling by duplication |
| **Refactor** | Move Method, Move Field, Consolidate (Extract Class to own the concern) |
| **Example** | Adding a new user field requires edits in 12 places |

### 10. Divergent Change

| Aspect | Detail |
|--------|--------|
| **Detection** | One class changes for many unrelated reasons |
| **Symptom** | Violates Single Responsibility Principle |
| **Refactor** | Extract Class (split by axis of change) |
| **Example** | `ReportService` changes for both layout (UI) AND data queries (backend) |

## Duplication smells

### 11. Copy-Paste Programming

| Aspect | Detail |
|--------|--------|
| **Detection** | 3+ duplicated blocks > 10 lines OR repeated logic across files |
| **Symptom** | Bug fixes must be applied N times; divergence over time |
| **Refactor** | Extract Method, Extract Class, Pull Up Method (for classes in hierarchy) |
| **Example** | Same auth token validation in 5 endpoints → `require_auth()` decorator |

### 12. Parallel Inheritance Hierarchies

| Aspect | Detail |
|--------|--------|
| **Detection** | When adding a subclass to hierarchy A requires adding one to hierarchy B |
| **Symptom** | Two hierarchies change together |
| **Refactor** | Move Method/Field, Folding one hierarchy into the other |

## Dead code

### 13. Dead Code

| Aspect | Detail |
|--------|--------|
| **Detection** | `findReferences` via LSP returns 0; Vulture/tools report unused |
| **Symptom** | Maintenance burden for unused paths |
| **Refactor** | Delete after verification (grep + LSP + git history) |
| **Caveat** | Reflective/dynamic usage may not appear in LSP — double-check before deletion |

### 14. Speculative Generality

| Aspect | Detail |
|--------|--------|
| **Detection** | Parameters/hooks never used, "just in case" abstractions, interfaces with 1 impl |
| **Symptom** | Complexity without value |
| **Refactor** | Remove Parameter, Collapse Hierarchy, Inline Class/Interface |

## Object-orientation smells

### 15. Refused Bequest

| Aspect | Detail |
|--------|--------|
| **Detection** | Subclass inherits methods it doesn't want; many `raise NotImplementedError` or empty overrides |
| **Symptom** | Inheritance misused — should be composition |
| **Refactor** | Replace Inheritance with Delegation (composition over inheritance) |

### 16. Temporary Field

| Aspect | Detail |
|--------|--------|
| **Detection** | Field only set/used by some methods, `None` most of the time |
| **Symptom** | Hidden state machine |
| **Refactor** | Extract Class (state object), Introduce Null Object |

## Summary metrics

Senior-review-checklist automates these using LSP + static analysis:

| Smell | Metric | Threshold |
|-------|--------|-----------|
| God Class | File LOC, class LOC, method count | > 500 file / > 300 class / > 20 methods |
| Long Method | Function LOC, cyclomatic complexity | > 50 LOC / > 10 complexity |
| Long Parameter List | Parameter count | > 4 |
| Deep Nesting | Max indent levels | > 3 |
| Copy-Paste | Duplicate block count | 3+ blocks of ≥10 lines |
| Dead Code | LSP findReferences count | 0 |
| Shotgun Surgery | Files changed per logical commit | > 5 unrelated files |

## References

- Fowler, *Refactoring: Improving the Design of Existing Code* (2nd ed., 2018)
- https://blog.codacy.com/code-smells-and-anti-patterns
- https://www.codeant.ai/blogs/what-is-code-smell-detection
- `sota-code-patterns` skill — architecture-level patterns
- `senior-review-checklist` skill — review process
