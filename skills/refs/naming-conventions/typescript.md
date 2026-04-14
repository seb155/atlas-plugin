# TypeScript Naming Conventions

Based on React/TS community norms (2026) + Airbnb/Google styleguides.

## Core rules

| Entity | Case | Example | Counter-example |
|--------|------|---------|-----------------|
| Variables | `camelCase` | `userProfile`, `orderCount` | `user_profile`, `UserProfile` |
| Functions | `camelCase` | `calculateTotal()`, `validateEmail()` | `calculate_total()`, `CalcTotal()` |
| React components | `PascalCase` | `UserList`, `OrderDetail` | `userList`, `order-detail` |
| Custom hooks | `camelCase` with `use` prefix | `useUserData()`, `useLocalStorage()` | `UseUserData()`, `useruserdata()` |
| Classes | `PascalCase` | `OrderService`, `UserRepository` | `orderService`, `user_repository` |
| Interfaces | `PascalCase` (NO `I` prefix) | `User`, `OrderRequest` | `IUser`, `I_Order` |
| Type aliases | `PascalCase` | `UserID`, `Status` | `user_id`, `status_t` |
| Enums | `PascalCase` for type, `PascalCase` or `UPPER_SNAKE` for values | `enum Status { Active, Inactive }` | `enum status { active }` |
| Constants | `UPPER_SNAKE_CASE` (if truly constant) or `camelCase` (config objects) | `MAX_RETRIES`, `apiConfig` | `max_retries` |
| Files (components) | `PascalCase.tsx` or `kebab-case.tsx` | `UserList.tsx` or `user-list.tsx` | `userList.tsx` |
| Files (utils/hooks) | `kebab-case.ts` or `camelCase.ts` | `use-auth.ts`, `date-utils.ts` | `DateUtils.ts` |
| Folders | `kebab-case` | `user-management/`, `order-detail/` | `UserManagement/`, `user_management/` |

## ATLAS/Synapse convention (from CLAUDE.md)

```
Files:       kebab-case      → user-profile.tsx, date-utils.ts
Components:  PascalCase      → <UserProfile />
Hooks:       use* prefix     → useWorkspaceNavigation()
```

File extension for files containing JSX: `.tsx` (uppercase variant preferred for React components).

## Boolean conventions

Same as other languages — prefix with `is`, `has`, `can`, `should`:
- `isAdmin`, `hasPermission`, `canEdit`, `shouldRetry`

## React-specific

| Concept | Convention |
|---------|-----------|
| Prop types | `interface ComponentNameProps` | `UserListProps` |
| Event handlers | `handle*` prefix | `handleClick`, `handleSubmit` |
| Handler props | `on*` prefix | `onClick={...}`, `onChange={...}` |
| Ref | `*Ref` suffix | `inputRef`, `scrollRef` |
| Context | `*Context` suffix | `AuthContext`, `ThemeContext` |

```tsx
// Good
interface UserProfileProps {
  user: User;
  onEdit: (user: User) => void;
}

function UserProfile({ user, onEdit }: UserProfileProps) {
  const handleEdit = () => onEdit(user);
  return <button onClick={handleEdit}>Edit</button>;
}

// Bad
interface IUserProfileProps { ... }            // 'I' prefix
function user_profile(props) { ... }            // snake_case
<button onClick={() => onEdit(user)}>           // inline — fine for trivial
```

## Type-level conventions

```typescript
// Good — no redundant suffix
type User = { id: string; name: string };

// Bad — "Type" suffix redundant
type UserType = { ... };

// Generic constraints
function identity<T>(arg: T): T { return arg; }
function map<T, R>(items: T[], fn: (t: T) => R): R[] { ... }

// Clear but not over-specified
function process<TInput, TOutput>(input: TInput): TOutput { ... }
```

## AVOID

- `I` prefix on interfaces (`IUser`) — TypeScript convention is no prefix
- `T` suffix on types (`UserT`) — redundant
- `_` prefix for private in classes — use `private` keyword
- `function Foo` without explicit return type for public API
- `any` — use `unknown` + type guards
- Hungarian notation (`strName`, `bIsActive`)
- Plural/singular mismatches: `users: User[]` (not `user: User[]`)

## React hook rules

- Must start with `use` (enforced by React linter)
- Must be called at top level (no conditional calls)
- Custom hooks: `useX` where X is a noun describing the value, not the action
  - `useUserData` (returns user data) ✅
  - `useFetchUser` (suggests verb) ❌ prefer `useUser` or `useUserQuery`

## Test naming

Consistent with Python:
```typescript
describe('UserService', () => {
  it('creates user when email is valid', () => { ... });
  it('throws when email is missing', () => { ... });
});
```

Or with Given-When-Then in description:
```typescript
it('Given a paid order, when refund issued, then marks as refunded', () => { ... });
```

## References

- [TypeScript ESLint naming convention rule](https://typescript-eslint.io/rules/naming-convention)
- [Airbnb JS/TS Style Guide](https://github.com/airbnb/javascript)
- Synapse CLAUDE.md — kebab-case files, PascalCase components, use* hooks
