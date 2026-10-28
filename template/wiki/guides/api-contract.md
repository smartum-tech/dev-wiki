---
title: API contract — contract-first workflow, shared types, mock parity
class: compiled
covers: []                 # fill when adopting: the contract file, the shared types lib, the mock routes
last-verified: never
verified-by: boilerplate
sources: []
---

# API contract — contract-first workflow, shared types, mock parity

The API is described once, in `{{API_CONTRACT_FILE}}` (OpenAPI). Clients, the mock server and — when
it exists — the real backend are all derived from, or checked against, that file. Migrating clients
to a *new* API version is [`api-version-migration.md`](./api-version-migration.md).

## The order is not negotiable

Any endpoint or schema change:

1. **Edit the contract file first.** `summary`, `operationId`, `tags`, `requestBody`, `responses`
   that reference schemas.
2. **Then the shared types** (`{{TYPES_DIR}}/<domain>.ts`, re-exported from the lib's index).
   Requests and responses are separate named types (`CancelOrderRequest`,
   `CancelOrderResponse`, `…ListResponse`).
3. **Then the handler** in the mock server (`{{MOCK_SERVER_DIR}}/src/routes/<tag>.ts`).
4. **Then the client** in the apps.

Why this order: the contract is the only artifact both sides can read. A handler changed before the
contract is documentation that lies; a client written before the type exists invents its own. When
a real backend appears it must match the same file — so a mock behaviour the contract does not
describe is a promise the backend never made.

**Shared types live in one lib, only.** A type reused across apps and the mock server goes in the
shared types lib and is imported from it — never duplicated per package. A duplicate drifts the
first time the contract changes, and neither compiler notices.

## Mock server: a stand-in with the contract's manners

The mock exists so clients can be built and tested before (and alongside) the real backend. Rules
that keep it honest:

- **Type every handler through the framework's generics** (`Request<Params, ResBody, ReqBody>`) with
  types from the shared lib. A hardcoded response without a shared type loses the link to the
  contract; `any` in the generics loses type checking.
- **One route file per contract tag**, each exporting a `register<Tag>Routes(app)` that the server
  entry point calls. A new file that is never registered is wired to nothing.
- **Fixtures vs the store.** Static, non-user data (price lists, reference catalogues, demo templates) is plain
  typed exports under `data/fixtures`. Anything a user can mutate lives in a per-entity store keyed
  by user id, persisted to JSON.
  - **Always scope reads by the authenticated user's id**, and answer a foreign id with **404**, not
    403, so ids do not leak. The wire types carry no `userId`; the internal `Stored*` shape adds it
    and a `toWire*()` helper strips it. A cross-user leak in a mock is a leak in every demo and test
    built on it.
  - **Seed vs runtime.** Committed seed (the demo account) is read-only; runtime state is written to
    a gitignored data directory, so local runs never clobber a deployed environment's data. Read
    prefers runtime and falls back to seed on first boot; all writes go to runtime.
- **Never put fixtures inside a route file** and never change a handler without changing the
  contract.
- **Verify:** the watcher restarts the server; confirm the new operation in the Swagger UI and with
  one `curl`.
- **Mock-only affordances are allowed but marked `MOCK ONLY`** in the contract and must not break its
  validity against any reference spec. A dev one-time code returned as a *response header* rather
  than a body field leaves the body schema identical to production's.
- **Don't be more permissive or more convenient than the real thing.** If the real gateway answers
  async with a request id, the mock answers async. An environment that is nicer than production
  trains the client to depend on the niceness.
- **When the real backend exists, run the suite against it.** The mock is a development aid, not
  the definition of correct. Provider-backed behaviour (payments, maps) uses the env-gated
  real/mock switch in [`payments-integration.md`](./payments-integration.md).

## Reading what a gateway sends: never trust the union

A real backend ships values its published spec does not name — a new history-row type live before
it reached any spec — and an exhaustive `switch` with no case for it white-screens the screen. If
the published spec describes only request bodies, nothing even lets you check responses against it.
Three rules:

1. **Filter at the client boundary.** A list whose items you branch on drops values you do not know,
   with a console warning, in the API client layer (`isKnownOperation`-style). Screens never see
   them.
2. **Every `switch` over a server value ends in `default: return unhandled(value, fallback)`.** The
   `never` parameter keeps the switch exhaustive at compile time; at run time it returns a neutral
   label instead of `undefined`. Equality checks (`status === 'paid'`) need nothing — an unknown
   value simply does not match.
3. **Render errors stop at the section.** An error boundary wraps each screen (and the keep-alive
   map, if any) with an outer ring around the tree. The fallback keeps the navigation, "Retry"
   re-reads every query *then* redraws, and a route change clears it.

## Transport conventions a modern backend may ask of the client

Worth building into the shared client once rather than per screen:

- **A trace header on every request, GET included** (W3C `traceparent`), generated client-side; pass
  one trace id through a whole user action (estimate → command → status poll) to keep it one trace.
- **An idempotency key (uuid) on every mutation**, generated **once per user intent** and reused
  across retries — never regenerated per attempt. It is the only way to recover a request id lost to
  a dropped response. Same key + same body returns the same request id; same key + different body
  is a 409.
- **Mutations may answer `202` with a request id, not a result.** The client polls the request
  endpoint until it completes or is rejected. Polling is mandatory: not every command changes the
  state document, and a failed command emits no push event at all.
- **Errors as `application/problem+json`** (`type`, `title`, `status`, `detail`, `instance` plus
  extension members). Keep an error-type registry in the shared types lib; until the backend
  publishes one, map unknown types to a neutral message rather than leaking `detail`.
- **A single state document** (`GET /state`) the screens select from, rather than per-entity
  endpoints, and **a push channel that only says "refetch"**
  ([`realtime-and-live-updates.md`](./realtime-and-live-updates.md)).
- **Server time and server prices.** When the server computes prices, the client has no pricing
  logic at all; when time matters (expiry, countdowns), use the gateway's clock, not the device's.

## Contract still in motion

When a spec drop is known to be unsettled — agreed in a meeting, not yet in the file — **do not
generate types from the current file and treat them as settled.** Write the list of agreed-but-
absent changes and the unanswered questions next to the migration notes, because they block the
screens that depend on them. When a new spec drop arrives: overwrite the reference file, then run an
OpenAPI diff tool against the previous git revision. The same tool answers the other direction —
whether the mock's contract still matches theirs.

## Anti-patterns

- Hardcoding a response without a type from the shared lib.
- Changing a handler without updating the contract file.
- A local interface for a server schema.
- Fixtures inside route files; `any` in request/response generics.
- Reading another user's row because the mock forgot to scope by id.
- A mock that returns a result where production returns a request id.
