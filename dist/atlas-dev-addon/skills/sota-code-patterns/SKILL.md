---
name: sota-code-patterns
description: "Architecture pattern selection guide. Use when starting a new service/module, planning a refactor, or when the user asks to 'choose architecture', 'pattern selection', 'clean vs hexagonal', 'CQRS', 'DDD', 'event-driven vs layered'."
effort: medium
refs:
  - sota-architecture-patterns
  - code-smells-catalog
---

# SOTA Code Patterns — Architecture Selection Skill

Use this skill when:
- Starting a new service, module, or bounded context
- Planning a major refactor (> 20 files affected)
- Reviewing an architecture proposal
- Debating "how should we structure this" in design review

**DO NOT** use this skill for:
- Small bug fixes, single-file changes, style tweaks
- Adding a feature within an existing architecture (just follow it)
- Writing tests (see `test-driven-development` skill)

## Process

### Step 1 — Assess the problem

Ask 4 questions (AskUserQuestion encouraged):

1. **Domain complexity**: Is this a CRUD app, or is there rich business logic?
2. **Lifespan**: Quick MVP or long-lived (>3 years)?
3. **Team**: Single developer, small team (2-5), or larger?
4. **Infra volatility**: Will we swap DB/framework/queue in foreseeable future?

### Step 2 — Apply the decision framework

```
Q: Domain complexity high?
├── No (simple CRUD, few rules) → Layered OR Hexagonal
└── Yes (rich rules, many edge cases) → Hexagonal + consider DDD

Q: Will infrastructure change?
├── No (locked to framework/DB) → Layered OK
└── Yes → Hexagonal (ports & adapters enable swap)

Q: Read/write patterns very different?
├── No → Single model
└── Yes → CQRS (with care — complexity cost is real)

Q: Distributed (multiple services)?
├── No → Monolith (modular, boring, fast to ship)
└── Yes → Event-Driven (expect eventual consistency)
```

### Step 3 — Present 2-3 options to the user

Always use AskUserQuestion with comparison:

```
Q: "Which architecture for this new billing service?"

Options:
  1. Hexagonal (Recommended — default)
     - Domain testable standalone, DB-swappable
     - ~2 weeks boilerplate investment
     - Medium learning curve
  2. DDD + Hexagonal
     - Bounded contexts, ubiquitous language
     - +1 week modeling, +domain expert involvement
     - Steep learning curve
  3. Layered
     - Fastest to ship, lowest complexity
     - Tightly coupled — hard to evolve
     - Shallow learning curve
```

**Default recommendation: Hexagonal.** It's the sweet spot.

### Step 4 — Document the decision

After user picks:
- Write the decision to `.claude/decisions.jsonl` via decision-log skill
- Create a `docs/architecture.md` (or update existing) with the chosen pattern
- Reference `skills/refs/sota-architecture-patterns/` for the pattern details

### Step 5 — Link to refactor if applicable

If this is a refactor (not greenfield):
- Identify code smells via `skills/refs/code-smells-catalog/`
- Sequence refactors: smallest first (Extract Method), biggest last (Extract Class / Context Split)
- Keep tests green after each step (run them, don't assume)

## Architecture patterns (cheat sheet)

| Pattern | Complexity | Best for |
|---------|-----------|----------|
| Layered | Low | CRUD MVPs, framework-driven |
| **Hexagonal** | Medium | **Default backend** — most services |
| Clean | High | Long-lived rich domain, many I/O |
| Onion | High | Same as Clean, concentric mental model |
| DDD | High | Complex domains, bounded contexts |
| CQRS | High | Read-heavy + different read/write models |
| Event-Driven | High | Microservices, async workflows |

Details + file structures in `skills/refs/sota-architecture-patterns/`.

## Code-level patterns (what to emit within the architecture)

| Situation | Pattern |
|-----------|---------|
| 3+ duplicated blocks | Extract Method / Function |
| Many primitives for a domain concept | Value Object / Replace Primitive with Object |
| Function > 50 lines | Extract Method, Replace Conditional with Polymorphism |
| Class > 300 lines | Extract Class (split by responsibility) |
| > 4 parameters | Introduce Parameter Object / DTO |
| Deep nesting | Guard Clauses (early return), Extract Method |
| Magic numbers | Replace Magic Number with Named Constant |
| Feature envy (method reads foreign data) | Move Method |

Full catalog in `skills/refs/code-smells-catalog/`.

## SOLID quick reference

- **S**ingle Responsibility — class changes for one reason
- **O**pen/Closed — open for extension, closed for modification
- **L**iskov Substitution — subclasses usable where parent is expected
- **I**nterface Segregation — many small interfaces > one big
- **D**ependency Inversion — depend on abstractions, not concretions

Hexagonal/Clean both enforce DIP naturally (domain depends on ports, not adapters).

## Anti-patterns to avoid

1. **Architecture Astronaut**: adopting Clean+DDD+CQRS for a CRUD app. Start Hexagonal, evolve.
2. **Distributed Monolith**: microservices calling each other sync over HTTP. Go event-driven or merge.
3. **Premature abstraction**: designing for hypothetical needs. YAGNI applies.
4. **Framework coupling**: business logic in controllers/ORM. Extract to domain/use cases.

## Output format

```
🏛️ Architecture Recommendation

Problem: {1-line summary of what user is building}

Analysis:
  - Domain complexity: {low/medium/high}
  - Lifespan: {short/long}
  - Team: {size}
  - Infra volatility: {yes/no}

Recommended: {Pattern}

Why: {1-2 sentence justification}

File structure: {point to refs/sota-architecture-patterns/ section}

Tradeoffs to accept:
  + {pro 1}
  + {pro 2}
  - {con to be aware of}

Next steps:
  1. {concrete action}
  2. Log decision via decision-log skill
```

## References

- Detail: `skills/refs/sota-architecture-patterns/SKILL.md`
- Smells: `skills/refs/code-smells-catalog/SKILL.md`
- Complement: `senior-review-checklist` skill (review process)
- Complement: `code-review` skill (local/PR review with LSP + pattern awareness)
