---
name: sota-architecture-patterns
description: "Reference for 6 architecture patterns (Clean, Hexagonal, Onion, DDD, CQRS, Layered, Event-Driven) with tradeoffs + when to use."
effort: low
type: reference
---

# SOTA Architecture Patterns Reference

Practical reference for selecting architecture at the start of a project or major refactor.
No dogma — patterns are tools, not religions. Chose based on domain complexity + team size.

## Selection matrix

| Pattern | Best for | Avoid when |
|---------|----------|------------|
| **Layered / N-Tier** | Simple CRUD, startup MVP, bootstrap speed | Complex domain logic, >1 year lifespan |
| **Hexagonal (Ports & Adapters)** | Most backend apps, replaceable infra, testable | Frontend UI, trivial scripts |
| **Clean Architecture** | Long-lived domain-heavy apps, many IO sources | MVPs, small teams |
| **Onion** | Similar to Clean, concentric layers | Same as Clean |
| **DDD (Domain-Driven Design)** | Complex domains, bounded contexts, big team | Simple/stateless domains |
| **CQRS** | Read-heavy systems with different models, event sourcing fits | Simple CRUD (adds complexity without benefit) |
| **Event-Driven** | Microservices, async workflows, webhook chains | Synchronous CRUD |

Rule of thumb: **Default to Hexagonal.** It's the sweet spot between Layered (too simple for real apps)
and Clean/DDD (overkill for most). Adopt CQRS/Event-Driven only when you have the actual need.

---

## 1. Layered / N-Tier

### Structure
```
├── controllers/      (HTTP layer)
├── services/         (business logic)
├── repositories/     (data access)
└── models/           (entities)
```

### When
- CRUD apps with little business logic
- Bootstrap speed > architectural purity
- Small team / short lifespan
- Framework-driven (Rails, Django with default structure)

### Tradeoffs
| Pro | Con |
|-----|-----|
| Easy to learn | Tightly coupled to framework/ORM |
| Fast to bootstrap | Business logic leaks into controllers + ORM |
| Wide tooling support | Hard to evolve as domain grows |

---

## 2. Hexagonal (Ports & Adapters) — **RECOMMENDED DEFAULT**

### Structure
```
├── domain/                       (business entities, use cases, ports)
│   ├── entities/
│   ├── use_cases/                (one use case per file)
│   └── ports/                    (interfaces for outbound)
│       ├── user_repository.py    (port = interface)
│       └── email_service.py
├── adapters/                     (implementations of ports)
│   ├── inbound/                  (HTTP controllers, CLI, events)
│   │   ├── http/
│   │   └── cli/
│   └── outbound/                 (DB, email, external APIs)
│       ├── postgres_user_repo.py (adapter = implementation)
│       └── sendgrid_email.py
└── main.py                       (wire ports to adapters — DI)
```

### When
- Most backend apps (API, service, worker)
- You expect to swap infrastructure (e.g., Postgres → MongoDB, Sendgrid → SES)
- You want domain logic testable without spinning up DB
- Team is medium-sized and can invest 1-2 weeks in setup

### Tradeoffs
| Pro | Con |
|-----|-----|
| Domain testable in isolation | More boilerplate than Layered |
| Infrastructure pluggable | Requires DI framework (or manual wiring) |
| Clear dependency direction (adapter → domain) | Easy to over-abstract if domain is CRUD-simple |

### Golden rule
Dependencies point INWARD. Domain knows nothing about adapters. Adapters import domain.

---

## 3. Clean Architecture (Uncle Bob)

### Structure
```
├── entities/                     (innermost: enterprise business rules)
├── use_cases/                    (application-specific business rules)
├── interface_adapters/           (controllers, presenters, gateways)
└── frameworks_and_drivers/       (web, db, external tools)
```

### When
- Long-lived apps (> 3 years)
- Rich domain (not CRUD)
- Multiple entry points (HTTP, CLI, events, batch jobs)
- Separate team ownership per layer (entities team, use-cases team)

### Tradeoffs
| Pro | Con |
|-----|-----|
| Extreme testability | Steep learning curve |
| Swappable everything (DB, framework, UI) | Lots of mapping (entity → DTO → view) |
| Survives framework changes | Overkill for simple apps |

### Key difference from Hexagonal
Clean has 4 layers with strict dependency rule. Hexagonal has 2 (domain + adapters). Clean is
more prescriptive; Hexagonal is more pragmatic. Both follow the same DIP (dependency inversion).

---

## 4. Onion Architecture

### Structure
Concentric circles:
```
┌──────────────────────────────────┐
│  Infrastructure                   │
│  ┌───────────────────────────┐   │
│  │  Application Services      │   │
│  │  ┌─────────────────────┐   │   │
│  │  │  Domain Services     │   │   │
│  │  │  ┌──────────────┐   │   │   │
│  │  │  │  Domain Model │   │   │   │
│  │  │  └──────────────┘   │   │   │
│  │  └─────────────────────┘   │   │
│  └───────────────────────────┘   │
└──────────────────────────────────┘
```

### When
- Similar use cases as Clean Architecture
- Team prefers layered/concentric mental model over Clean's separate concerns

### Tradeoffs
Similar to Clean. Onion emphasizes domain model at the center. Often used interchangeably with
Clean, though Clean separates use cases from domain model more strictly.

---

## 5. DDD (Domain-Driven Design)

### Structure
Organized by **bounded context** (each context is a mini-project):
```
├── contexts/
│   ├── billing/
│   │   ├── domain/               (aggregates, entities, value objects, domain events)
│   │   ├── application/          (use cases, sagas)
│   │   └── infrastructure/       (adapters)
│   ├── user_management/
│   │   ├── domain/
│   │   ├── application/
│   │   └── infrastructure/
│   └── notifications/
└── shared_kernel/                (rare, shared concepts across contexts)
```

### When
- Complex domains (finance, healthcare, insurance, logistics)
- Multiple sub-domains with different models
- Team can invest in **ubiquitous language** (domain experts + engineers speak same terms)
- Long-lived system (>5 years expected lifetime)

### Tradeoffs
| Pro | Con |
|-----|-----|
| Domain clarity at scale | Requires domain expertise + modeling time |
| Bounded contexts enable team autonomy | Over-engineered for simple CRUD |
| Encodes business rules in code | Patterns (aggregate, event) take time to master |

### Key patterns
- **Aggregate** — consistency boundary (transaction scope)
- **Domain event** — something significant happened
- **Value object** — identity-less data (Money, Address)
- **Entity** — identity-bearing (User, Order)
- **Repository** — collection-like abstraction over persistence

---

## 6. CQRS (Command Query Responsibility Segregation)

### Structure
```
├── commands/                     (write model, task-oriented)
│   ├── create_order.py
│   └── cancel_order.py
├── queries/                      (read model, optimized for display)
│   ├── order_summary.py
│   └── customer_dashboard.py
└── projections/                  (read model builders from events)
```

### When
- Read/write ratios very different (heavy read, sparse write)
- Different data models for read vs. write (reporting vs. transactions)
- Event sourcing (writes as events, reads as projections)
- Scale requires separate read/write databases

### Tradeoffs
| Pro | Con |
|-----|-----|
| Optimize read + write independently | Complexity cost — NOT free |
| Event sourcing fits naturally | Eventual consistency between write + read |
| Scales beyond simple CRUD | Harder to reason about |

### Don't apply when
- Simple CRUD with same model for read and write
- Small app (premature optimization)

---

## 7. Event-Driven Architecture

### Structure
```
Services communicate via events (pub-sub):
  [User Service] --event: UserRegistered--> [Notification Service]
                                        \--> [Analytics Service]
                                        \--> [Billing Service]
```

### When
- Microservices / distributed systems
- Async workflows (long-running, retryable)
- Webhook integrations with external systems
- Event sourcing (state changes as events)

### Tradeoffs
| Pro | Con |
|-----|-----|
| Loose coupling between services | Eventual consistency |
| Retryable, resilient | Debugging across async chains is hard |
| Natural fit for async workflows | Need message broker + dead-letter handling |

### Tooling
- **Broker**: Kafka, RabbitMQ, AWS SNS/SQS, Temporal, NATS
- **Event schema**: CloudEvents, AsyncAPI

---

## Anti-pattern: "The Distributed Monolith"

Microservices that all call each other synchronously via HTTP = **worst of both worlds**:
coupling of a monolith + operational cost of distributed. Fix: move to event-driven OR merge back.

## Anti-pattern: "Architecture Astronaut"

Adopting Clean + DDD + CQRS + Event-Driven for a CRUD app. Starts with 5 layers, 15 classes per
feature. Team can't ship. Fix: start Layered or Hexagonal, evolve as complexity demands.

## Decision framework

```
Q: Is domain complexity high (many rules, variants, domain language)?
├── No → Layered (CRUD) or Hexagonal (default backend)
└── Yes → Hexagonal + DDD bounded contexts

Q: Read/write patterns very different?
├── No → Single model
└── Yes → CQRS (consider event sourcing)

Q: Distributed across services?
├── No → Monolith (modular)
└── Yes → Event-Driven (with care for consistency)
```

## References

- [Hexagonal vs Clean vs Onion — DEV.to 2026](https://dev.to/dev_tips/hexagonal-vs-clean-vs-onion-which-one-actually-survives-your-app-in-2026-273f)
- [Domain-Driven Hexagon](https://github.com/Sairyss/domain-driven-hexagon)
- [Awesome Software Architecture](https://github.com/mehdihadeli/awesome-software-architecture)
- Evans, *Domain-Driven Design* (2003)
- Martin, *Clean Architecture* (2017)
- `code-smells-catalog` — code-level anti-patterns
- `sota-code-patterns` — architecture selection skill
