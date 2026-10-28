---
title: Frontend how-to — building a feature
class: compiled
covers: []                 # fill when adopting: the query client defaults, the api fetch wrapper, the router
last-verified: never
verified-by: boilerplate
sources: []
---

# Frontend how-to — building a feature

Scope: the React apps in `{{FRONTEND_DIR}}` (plain web SPA) and `{{MOBILE_DIR}}` (Capacitor shell).
Both are TanStack Query + React Router + i18n clients over one API contract, and both draw with the
shared design system ([`design-system.md`](./design-system.md)). The conventions below apply to
both unless a rule names one. A third surface with no query layer (a static marketing site) is
outside this page — see "Copy that lives outside the bundle" for the one rule that still reaches it.

The order is API first, UI last. Skipping ahead is how a screen ends up built against a response
shape that exists only in someone's head ([`api-contract.md`](./api-contract.md)).

## The steps

1. **Is the endpoint in the contract?** Open `{{API_CONTRACT_FILE}}`. If the operation exists, go
   on. If not, add it to the contract, then the shared type, then the mock handler, and only then
   come back — in that order ([`api-contract.md`](./api-contract.md)).
2. **Import types from the shared types lib** (`{{TYPES_DIR}}`). Never declare a local interface
   for a server schema: a second copy drifts the first time the contract changes, and nothing fails
   until a user hits the difference.
3. **Write the hook** — `use-<entity>.ts`, one file per entity. Queries and mutations live here and
   nowhere else:
   - the query key is an array marked `as const`; request parameters are further elements of it;
   - the base key is **one constant** at the top of the file, shared by every hook of the entity,
     and every mutation's `onSuccess` invalidates it (plus any aggregate it feeds, e.g. a combined
     status). That is what lets a realtime handler and a manual refresh drive the *same* cache
     instead of two competing answers to "is this list stale";
   - data access goes through the app's fetch wrapper, which reads the API base URL from env —
     never a hardcoded host, never a bare `fetch()` in a component.
4. **Write the page** — it composes design-system primitives and the hook, and holds only local UI
   state. Errors go to local state and an inline banner ([`frontend-ui-patterns.md`](./frontend-ui-patterns.md)).
   One `<h1>` per page. Do not mix query logic into presentation: pull data in the hook, render
   in the page.
5. **Register the route**, then **translations in every shipped locale** — a key present in one
   bundle and missing in another renders as the raw key in production, and no type check sees it.
6. **Verify in the running dev stack** (`{{DEV_URL}}`): confirm the hot-reload line in the dev
   server log, then load the page and read the browser console. Do not start a second dev server
   next to a running container on the same port.
7. **Record the change** wherever the project keeps its change record.

## Two things that are easy to get subtly wrong

**Partial-update payloads.** An edit form diffs against the loaded entity and sends only the
changed fields (`if (name !== entity.name) patch.name = name`), not the whole form state. Sending
everything overwrites a field another client changed in the meantime, and on APIs that treat a
present field as "set it" it also trips server-side guards on columns the user never touched. If
the diff is empty, send nothing: an empty `PATCH` is a no-op write that still bumps `updated_at`.

**Invalidate before you close.** Relying on a mutation's `onSuccess` alone to refresh a table is
not reliable: it can lose the race with the drawer or dialog unmounting. In the submit handler,
`await queryClient.invalidateQueries(...)` explicitly, *then* call `onClose()`.

## Drawer and dialog gotchas

- **Stale data on open.** A drawer that receives the entity as a prop shows whatever the parent's
  list query held at its last render. Edit drawers therefore take an **id** and fetch fresh inside
  through the entity's own query hook. This is for *edit* drawers; a read-only or action drawer that
  shows a snapshot of something not being edited concurrently may take the row object.
- **Buttons live inside the `<form>`, immediately after the fields** — never in a fixed or sticky
  footer. A footer decouples the buttons from the fields they act on and breaks down once the
  form's length varies (a "Delete" that appears only in edit mode).
- ⚠️ **A drawer that stays mounted across entity changes carries the previous entity's local state
  for one commit, and a reset `useEffect` keyed on the id is one commit too late.** Passive effects
  run *after* the commit in which the prop changed, so on a **direct** A → B move — no `null` in
  between, which a URL edit or the back button produces and close-and-reopen never does — B's
  first frame renders whatever A left behind (an "action recorded" acknowledgement on an entity
  nobody acted on). Scope the state itself to the entity — store `{entityId, value}` and require
  the id to match — instead of trusting effect order; keep the reset effect for the
  session-scoped half. A test that asserts after `rerender` returns cannot see this; it needs the
  intermediate frame (see [`frontend-testing.md`](./frontend-testing.md)).

## Hard invariants

- **No `window.alert()` / `confirm()` / `prompt()`.** They block the main thread, cannot be
  styled or tested reliably, and in a WebView look like a system error. Use an inline error banner,
  a toast, or the confirm dialog. Worth stating as an invariant because it is the rare convention
  that actually holds when it is a lint rule instead of an aspiration — make it one.
- **Every interactive element an end-to-end test must find carries a `data-testid`; every form
  `<input>` carries a `name`.** Skipping either breaks test authoring downstream, usually not
  until someone else tries to write the test.

## Copy that lives outside the bundle

A surface that does not load the locale bundles (a static site, a server-rendered invite page)
hardcodes its strings, so correcting a label in the app's bundle leaves the same sentence on that
surface unchanged — and nothing in either workspace fails. Where a literal duplicates a bundle
string, put a comment on it naming its twin; that comment is the only thing that makes the pair
greppable from the side that has no key.

## Live data

Subscriptions, reconnect healing and push events have their own page —
[`realtime-and-live-updates.md`](./realtime-and-live-updates.md). The short version for this page:
**a subscription is an accelerator over a query, never a replacement for it**, and exactly one
component owns each channel.

## Anti-patterns

- A bare `fetch()` in a component instead of the fetch wrapper or a query hook.
- An inline type for something the shared types lib already exports.
- A hardcoded `localhost:<port>` in client code — read it from env.
- A reusable visual component (card, button, row) under the app's own `components/` — it belongs in
  the design-system lib ([`design-system.md`](./design-system.md)).
- A page that both fetches and lays out: split it into hook + presentation.
- Passing the whole entity to an edit drawer "to save a request".
