# Python Naming Conventions

Based on PEP 8 + Python community norms (2026).

## Core rules

| Entity | Case | Example | Counter-example |
|--------|------|---------|-----------------|
| Variables | `snake_case` | `user_profile`, `order_count` | `userProfile`, `OrderCount` |
| Functions | `snake_case` | `calculate_total()`, `validate_email()` | `calculateTotal()`, `CalcTotal()` |
| Methods (instance) | `snake_case` | `self.send_email()` | `self.sendEmail()` |
| Methods (private) | `_snake_case` | `self._compute_hash()` | `self.__computeHash()` (too specific) |
| Classes | `PascalCase` | `OrderService`, `UserRepository` | `orderservice`, `Order_Service` |
| Constants | `UPPER_SNAKE_CASE` | `MAX_RETRIES`, `DEFAULT_TIMEOUT` | `max_retries`, `MaxRetries` |
| Modules (files) | `snake_case.py` | `user_service.py`, `order_repo.py` | `UserService.py`, `order-repo.py` |
| Packages (dirs) | `snake_case` | `user_management/`, `billing/` | `UserManagement/`, `user-management/` |
| Type aliases | `PascalCase` | `UserID = int` | `user_id_type` |
| TypeVars | `PascalCase` with optional suffix | `T`, `K_T`, `ResultT` | `t`, `type_var` |
| Magic/dunder | `__snake_case__` | `__init__`, `__str__` | custom `__mything__` |

## Boolean conventions

Prefix with `is_`, `has_`, `can_`, `should_`:
- `is_admin`, `has_permission`, `can_edit`, `should_retry`

AVOID: `admin` (unclear — attribute or bool?), `flag`, `status_ok`.

## Domain-specific

| Concept | Convention |
|---------|-----------|
| Primary key | `id` (when class context is clear) or `{entity}_id` (FK) |
| Timestamps | `created_at`, `updated_at`, `deleted_at` (ISO 8601 UTC) |
| Count/total | `count` (N items), `total` (sum value), `len_{field}` (explicit) |
| Collection | plural noun: `users`, `orders` — not `user_list` |

## File-level

```python
# Good
user_service.py
order_repository.py
payment_gateway.py

# Bad
UserService.py          # PascalCase reserved for classes
order-repo.py           # dashes illegal as module name
user_services.py        # plural for module inconsistent w/ class inside
```

## Private / public

- Module-level private: `_helper_func()` (single underscore — convention, not enforced)
- Name mangling (class-only): `self.__really_private` (double underscore — enforced, avoid in normal code)
- Module `__all__ = [...]` declares public API

## Avoid

- Single-letter names outside of list comprehensions or tight loops
  ```python
  # OK in comprehension:
  [x * 2 for x in numbers]
  # Bad as function parameter:
  def process(x, y, z):  # what are x, y, z?
  ```
- Type suffixes (`user_dict`, `items_list`): the type system handles it
- Abbreviations (unless in allowlist): `usr`, `mgr`, `ctrl`
- Double negatives: `is_not_enabled` → use `is_disabled`
- Method/attribute shadowing Python builtins: `list`, `dict`, `id`, `type`, `str`

## Test naming

```python
# Descriptive test names
def test_user_creation_with_valid_email_succeeds():
    ...

def test_order_total_applies_tax_when_region_is_us():
    ...

# NOT:
def test_1():
def test_user():
```

Use Given-When-Then in docstring for non-obvious cases:
```python
def test_refund_partial():
    """Given a fully-paid order, when 50% refund issued, then order.refunded = True and customer credited."""
    ...
```

## References

- [PEP 8 — Style Guide for Python Code](https://peps.python.org/pep-0008/)
- [PEP 257 — Docstring Conventions](https://peps.python.org/pep-0257/)
- `naming-enforcer` hook — regex-based live validation
