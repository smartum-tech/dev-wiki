---
title: Contract-First Mock Server
class: compiled
covers: []   # fill when adopting: the OpenAPI file, the mock's routes/data folders, the shared types package
last-verified: never
verified-by: boilerplate
sources: []
---

# Contract-First Mock Server

A mock of **your own** backend, used while the real one does not exist or as a hermetic stand for
frontend work and E2E. Doubles of third parties are a different problem with different failure
modes: [vendor-mocks.md](./vendor-mocks.md). Running the same app against the real thing:
[real-backend-testing.md](./real-backend-testing.md).

## Principle: the contract file is the single source of truth

`{{API_CONTRACT_FILE}}` (an OpenAPI document) describes the API. Every endpoint or schema change goes in
this order:

1. the OpenAPI file — edit the contract;
2. shared types (`{{TYPES_DIR}}`) — sync;
3. the handler in the mock — implement;
4. fixtures/store — add data;
5. the client code.

When a real backend appears it must match the same file. Anything that skips step 1 makes the contract
a story the mock tells about itself: **the mock agrees with your understanding by construction,
including wherever that understanding is wrong.** The contract file and a contract test against the
real stand (probe, don't read — a real stand's published schema can hide a version difference) are
what keep it honest.

Shared types live in one package imported by both sides; do not duplicate a type per package.

## Adding an endpoint

1. **Describe it** in the OpenAPI file: `summary`, `operationId`, `tags`, `requestBody` if any,
   `responses` referencing component schemas.
2. **Add types**: one file per domain area; requests are separate interfaces (`*Request`), responses
   separate (`*Response`, or a name plus `ListResponse`). Re-export from the package index.
3. **Implement the handler** in a route file named after the OpenAPI tag. Handlers are strictly typed
   through the framework's generics (request params, response body union with the error type, request
   body), so a hardcoded response without a shared type is a compile error. A new tag means a new
   route file, **registered in the bootstrap** — an unregistered file is silently never wired up.
4. **Scope by owner.** Look up the entity, and when the caller is not its owner answer 404 (not 403),
   so foreign ids do not leak.
5. **Verify**: the server restarts on save (watch mode); check the interactive docs UI shows the new
   endpoint and hit it with a direct HTTP call.
6. Record the change in the change log.

## Two kinds of data

- **Fixtures** — static, non-user data (price lists, reference data, demo templates): plain typed
  exports in a data folder, never inside a route file.
- **Store** — anything a user can mutate (users, balances, sessions): one store per entity, keyed by
  user id, persisted to JSON. **Always scope reads by the authenticated user's id.** An unscoped
  list is a cross-user leak waiting for the second test account. Wire types carry no user id; the
  internal stored shape adds it and a `toWire` helper strips it.
- **Seed versus runtime.** Committed seed (read-only; defines the demo account) is separate from
  mutable runtime state, which is gitignored so local runs never clobber a deployed instance's data.
  Reads prefer runtime and fall back to seed on first boot; all writes go to runtime. Persist the
  runtime folder via a volume (bind mount in dev, named volume on a shared stand).

## The mock must not carry test-only back doors that tests depend on

If E2E must also run against the real stand, the mock's test handles (reset, presets, clock
control) are **a convenience, not a dependency**: mount them only when an explicit enable flag and a
token are both set, keep them off by default, and write no test that needs them. See
[e2e-testing.md](./e2e-testing.md). A mock whose "dev" features differ from production (a
"top up without paying" button when the API is local) must hide them behind a check that is false on
the real stand and have no test rely on them.

Keep the **protocol-level** behaviour realistic where tests depend on it: token lifetimes that match
what the client's refresh logic assumes (or an env override for a long-lived test box), idempotency
keys, asynchronous commands (202 then polling), 429 anti-abuse throttles that the real server
enforces. A mock that is more forgiving than the real server hides exactly the bugs the E2E suite
exists to find.

## Anti-patterns

- Hardcoding a response without a type from the shared package — loses the link to the contract.
- Changing a handler without updating the contract file — contract and implementation drift.
- Putting fixtures inside a route file.
- `any` in request/response generics — loses type checking.
- Adding a route file without registering it.
- Reading a store without scoping by the authenticated user.

CORS on the mock may be wide open (it is a dev tool); if a whitelist is ever needed, configure it in
the bootstrap file. A real backend's allow-list is a different matter, see
[real-backend-testing.md](./real-backend-testing.md).
