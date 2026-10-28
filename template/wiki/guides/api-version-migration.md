---
title: Migrating the client to a new API version
class: compiled
covers: []                 # fill when adopting: the version switch, the lint boundary config, the api client lib
last-verified: never
verified-by: boilerplate
sources: []
---

# Migrating the client to a new API version

When a backend replaces its API with a **different contract, not an evolution of the old one** —
paths that do not overlap, identifiers that change shape (string codes → uuids), mutations that
become asynchronous commands, pricing that moves to the server, errors that change format — the
client cannot be migrated in place without a type that is sometimes one thing and sometimes the
other. This page is the pattern that avoids that. The day-to-day contract workflow is
[`api-contract.md`](./api-contract.md).

## The one rule: two trees that never meet

Migrate **screen by screen, inside the same repository, in a second screen tree beside the current
one** (`src/v2/` — named after the *API version it talks to*, not after an app version; the name
disappears when the migration completes and the tree moves up).

The mess everyone fears — a hook that sometimes returns a result and sometimes a request id — comes
from putting a shared abstraction **over** two contracts, not from having two contracts in the
repo. So: no adapter, no port with two implementations, no type spanning both. Code under the new
tree never imports app code from outside it; code outside never imports from it.

What the trees *do* share is everything that knows nothing about the API:

| Shared | Not shared |
|---|---|
| design-system lib, i18n setup and locale files | types, api client, hooks |
| third-party bridges (map, payment widgets) as far as they stay contract-free | pages, layouts, contexts |
| native shell, build, signing, distribution | routing |
| Tailwind config, base CSS, e2e infrastructure | client-side pricing, if the new API computes it server-side |

Do not try to keep the two versions of a screen visually identical; if they end up identical, the
component belongs in the design-system lib, not copied. Do not port the old page: the UX changes on
purpose (commands are asynchronous and the user has to see it; some surfaces do not exist in the new
contract; prices come from the server).

### Why the old tree may not simply be deleted

A new contract usually covers less than the old one at first (no corporate area, no leads, no
profile). The old contract and its mock routes stay alive for whatever surfaces still use them,
regardless of how far the main migration gets. Decide per surface, and write down what is *deliberately
weaker* on the new tree ("contract, not regression") so it is not reported as a bug.

## Layout

```
<libs-dir>/<new-api>-client/src/   # the new contract's client, shared by every app that migrates
├── client.ts, config.ts     # transport: trace header, idempotency key, problem+json,
│                            #   async commands, tokens, push hub
└── react/                   # hooks whose cache key or lifetime IS the contract's

{{MOBILE_DIR}}/src/
├── v2/                      # the new tree: talks to the new API only
├── pages/ hooks/ contexts/ … # the old tree, untouched
├── lib/api-version.ts       # which tree to mount
└── App.tsx                  # the switch — the only file allowed to see both
```

Folders appear as they are needed; an empty scaffold folder is not committed.

**Put the transport and contract-bound hooks in a workspace lib as soon as a second app needs them.**
The lib knows nothing about how an app picks its gateway or stores its tokens: both are handed in
once at startup (`configure…({ gatewayUrl, tokenStore })`). Rules for such a lib:

- **It must never import app code** — no `@/…` paths. Inside one app's build `@/` resolves to that
  app's `src`, so the import compiles there and breaks only for the *other* app.
- Third-party packages used by hooks (`react`, the query library, a realtime client) are **peer**
  dependencies, so there is one query library and one `QueryClient`.
- It compiles under each app's TypeScript `lib` setting, not its own — stay within the lowest target
  (no newer array methods).

## Switching between trees

**One lever:** a build/start-time env variable (`VITE_API_VERSION`, default the old one). A resolver
reads that variable and nothing else, falls back to the old tree on anything unrecognised, and the
app root calls it **once at mount** and mounts one tree or the other — never both, never a per-screen
`if`. In containers the service must be **recreated**, not restarted, because the bundler reads env
only from the compose block.

Do not document a second lever (a `localStorage` override) unless it exists. A guide that described
one that did not cost someone a debugging session; verify against the code each time.

The trees keep **different auth storage keys**, so a session in one does not carry into the other.
That is intentional. If a surface can hold only one session at a time (a person on the new API, a
company on the old), which token is held says who is signed in, and signing in as one ends the
other.

## The tenant is a gateway, not a parameter

If the new contract has no tenant anywhere (each customer runs its own backend), the client picks a
**base URL**, it does not tell one backend which tenant it means.

- Derive the address (`<base>/gw/<tenantId>`) rather than enumerating gateways in an env variable:
  `import.meta.env` is inlined at **build time**, so an enumerated roster freezes the set of
  reachable tenants into the binary and a tenant joining after a release cannot be reached without
  shipping a new app.
- The base-URL accessor is a **function read per request**, not a module-level constant — a
  constant is exactly why an app kept talking to the previous tenant after the user picked another.
- **Changing tenant ends the session**: tokens were issued by the gateway being left behind, and
  cached catalogues that are identical for everyone on *one* gateway differ between two.
- Locally the second deployment is a path prefix in the mock server, sharing accounts with the
  default one — two real deployments would share nothing.

## The boundary, enforced by lint

Two `no-restricted-imports` overrides: files under the new tree may not import the old tree's api
client, hooks, pages, components, contexts, layouts (or any pricing lib the new API makes obsolete);
every other file may not import the new tree. The app root is excluded — it is the switch. The rules
match the alias form the codebase uses; a determined relative import slips past, and that is
acceptable: the rule exists to catch the realistic mistake (pasting an import that already worked in
the other tree), not to be a sandbox. Add boundary rules per app that runs both trees.

## How a screen migrates

1. Add the operations to the mock's contract for the new API first — **copy schemas out of the
   reference drop rather than retyping** — then the route beside the old ones. Mock-only
   affordances are marked `MOCK ONLY` and must not break validity against the reference.
2. Add the hook under the new tree, reading the **single state document** and selecting from it
   when the new API has no per-entity endpoints.
3. Write the page; register the route in the new tree's app file; add the screen to the migration
   status checklist so test builds show progress honestly.

## When the new contract lacks a field you were using

Do not parse it out of a name. If a code a user reads off a physical label (a locker number, a bay
code) has to be extracted from a display name by regex, that is load-bearing and brittle: one
tenant naming its entities differently makes every entity report the wrong code and search finds
nothing. Record the
dependency as an **open question to the backend team** with the exact failure mode, fix the *fixture*
to the shape the parser expects, and keep the parser in one file with a comment saying so.

## Keep a list of open questions

Write down, next to the migration notes, every question whose answer the backend team owes, ordered
by how soon it will hurt: error-type registry, catalogue size and pagination, how a client learns
the outcome of a finished operation, what cancels a stuck one, push method names and envelope shape,
`id` vs `<entity>Id` ambiguities. Where the backend gave a written description that contradicts the
spec, implement the description, record the discrepancy in the shared type's comment, and tolerate
both shapes at the boundary until it is resolved.
