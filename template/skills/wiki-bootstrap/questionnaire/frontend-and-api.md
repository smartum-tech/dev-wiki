# Questionnaire: frontend-and-api

Covers: frontend-howto, frontend-ui-patterns, design-system, client-state-races, realtime-and-live-updates,
native-webview-pitfalls, third-party-sdk-bridge, api-contract, api-version-migration, payments-integration.
Prune together: native-webview-pitfalls + third-party-sdk-bridge (no webview and no iframe bridge);
api-contract + api-version-migration (no HTTP API at all); realtime + the realtime parts of client-state-races.

## guides/frontend-howto.md — Building a frontend feature

**Applies when:** the repo has a React frontend: `git grep -l '"react"' -- '*package.json'` returns a
workspace under `{{FRONTEND_DIR}}` or `{{MOBILE_DIR}}`.
**Otherwise:** prune — other UI stacks need their own page; offer to keep it as a template to rewrite.

**Detect, don't ask** (show as "your code does X in N of M"):
- Server-state library — `git grep -hE '"(@tanstack/react-query|swr|@reduxjs/toolkit|@apollo/client|urql)"' -- '*package.json'`; if it is not TanStack Query, rewrite the query-key/invalidate wording to the detected library without asking.
- Router and i18n library — `git grep -hE '"(react-router(-dom)?|@tanstack/react-router|next|i18next|react-intl|@lingui/core)"' -- '*package.json'`
- Hook-per-entity layout — `git ls-files '{{FRONTEND_DIR}}/src/**/use-*.ts*' '{{FRONTEND_DIR}}/src/**/use*.ts*'`
- Bare `fetch(` outside the api wrapper — `git grep -n 'fetch(' -- '{{FRONTEND_DIR}}/src' '{{MOBILE_DIR}}/src'`
- Blocking dialogs — `git grep -nE '\b(window\.)?(alert|confirm|prompt)\(' -- '{{FRONTEND_DIR}}/src' '{{MOBILE_DIR}}/src'`; and whether a lint rule bans them: `git grep -nE 'no-alert' -- '*eslint*' '*.json'`
- Test hooks — count `data-testid` vs `<input` in `{{FRONTEND_DIR}}/src`; the attribute name actually used (`data-testid`, `data-test`, `data-cy`).
- Shipped locales and key parity — `git ls-files '**/locales/**' '**/i18n/**'`; compare key counts per locale file.
- Hardcoded dev hosts — `git grep -nE 'localhost:[0-9]+' -- '{{FRONTEND_DIR}}/src' '{{MOBILE_DIR}}/src'`

**Decide** (ask only these; one at a time):
1. **What is the i18n policy?** — decides whether a missing key is a build failure or a runtime fallback.
   - Ours: every key in every shipped locale, same change — a key missing in one bundle renders raw in production and no type check sees it.
   - Also common: one source locale + fallback to it, others filled by a translation pass (fast-moving product); single locale, no i18n library (prune the i18n wording).
   - Evidence: locales listing and key-parity counts.
   - Lands in: step 5 of "The steps"; the "Copy that lives outside the bundle" section.
2. **Do edit forms send only changed fields?** — decides the PATCH-vs-PUT rule.
   - Ours: diff against the loaded entity, send only changed fields, send nothing when the diff is empty — avoids overwriting concurrent edits and tripping server guards.
   - Also common: full-object PUT (API is PUT-only); autosave per field (settings screens).
   - Evidence: how existing edit forms build their mutation payload (read two).
   - Lands in: "Partial-update payloads".
3. **Which invariants are enforced by tooling, and which attribute marks test hooks?** — a rule that is not a lint rule decays.
   - Ours: no `window.alert/confirm/prompt` (make it a lint rule); `data-testid` on every element a test must find, `name` on every input.
   - Also common: role/label-based locators only (no test ids); `data-cy`/`data-test` attribute.
   - Evidence: the dialog and test-hook detect items; the e2e suite's locator style.
   - Lands in: "Hard invariants"; anti-patterns.
4. **Do edit drawers take an id and fetch fresh?** — decides the stale-data rule.
   - Ours: yes for edit drawers (parent's list data is stale at open); read-only drawers may take the row.
   - Also common: pass the row and refetch in the background (small, rarely edited lists).
   - Evidence: how existing drawers/dialogs receive their entity.
   - Lands in: "Drawer and dialog gotchas".

**Web, on request:** known issues of the detected query library's version (invalidation vs unmount, `onSuccess` removed or changed in mutations, StrictMode double-mount); the detected i18n library's missing-key behaviour.

## guides/frontend-ui-patterns.md — Frontend UI patterns

**Applies when:** the repo has a React UI with forms or dialogs (same check as frontend-howto).
**Otherwise:** prune — offer to keep it as reference only if a UI is planned.

**Detect, don't ask:**
- Surface components — `git ls-files '*drawer*' '*modal*' '*dialog*' '*banner*' '*toast*' '*bottom-sheet*'`
- Accessible-primitive library — `git grep -hE '"(@headlessui/react|@radix-ui/[a-z-]+|react-aria|@ariakit/react)"' -- '*package.json'`
- Toast library or global provider — `git grep -nE '(sonner|react-hot-toast|react-toastify|ToastProvider)' -- '*package.json' '{{FRONTEND_DIR}}/src' '{{MOBILE_DIR}}/src'`
- Back navigation — hand-rolled vs shared: `git grep -nE "navigate\\((-1|'/)" -- '{{FRONTEND_DIR}}/src' '{{MOBILE_DIR}}/src'` and `git ls-files '*back-button*'`
- Fixed bottom navigation — `git grep -niE 'bottom-?nav' -- '{{MOBILE_DIR}}/src' '{{UI_LIB_DIR}}'`
- Tailwind with bare CSS-variable colours — `test -f tailwind.config.*`; `git grep -nE ':\s*.var\(--' -- 'tailwind.config.*'`
- `role="radio"` / `role="radiogroup"` hand-rolled — `git grep -n 'role="radio"' -- '*.tsx'`
- Native `<select>` use — `git grep -c '<select' -- '*.tsx'`

**Decide:**
1. **Which surface carries which interaction?** — the largest source of per-feature rework.
   - Ours: multi-field create/edit → drawer; yes/no, single field, alert → centred modal; multi-step/many fields/tabs → page; non-blocking feedback → banner. A component outgrowing its surface is promoted, not stretched.
   - Also common: modals for everything (small apps); pages only (no overlays, mobile-first).
   - Evidence: the surface components listing and what existing create/edit flows use.
   - Lands in: "Which surface: the decision rule" table.
2. **Feedback: page-scoped banner or app-level toast queue?**
   - Ours: field validation inline under the input; action results in a page-scoped in-flow banner (one hook, one slot), cross-page handoff via router state, no auto-dismiss.
   - Also common: global toast provider with auto-dismiss (many routes, background events); inline only.
   - Evidence: toast detect item and how existing pages report a saved/failed action.
   - Lands in: "Feedback: two channels, one per event".
3. **Where do confirmations live?**
   - Ours: always a centred modal over whatever opened it, never inline in a drawer footer or table row; own dialog registration, own scrim.
   - Also common: inline confirm in dense admin tables (accepted reflow cost); native bottom-sheet confirm on mobile shells.
   - Evidence: grep for "Delete?"/"Are you sure" patterns in drawers and rows.
   - Lands in: "Confirmations".
4. **Back navigation: one shared component that pops history?**
   - Ours: a single back component doing `navigate(-1)` with a `fallback` for first entries; returns to an origin pop or replace, never push.
   - Also common: explicit parent routes per screen (breadcrumb-style apps, desktop admin); the browser back button only.
   - Evidence: back-navigation detect item (hand-rolled count vs shared).
   - Lands in: "Navigation".
5. **Hand-rolled vs library primitives for dialog/menu/listbox?** — pick the accessible library when one is present.
   - Ours: prefer an unstyled accessible library; hand-rolled radio groups must implement roving tabindex and arrows.
   - Also common: a full component kit (MUI, Mantine, shadcn-style copies) where the rule becomes "use the kit's".
   - Evidence: accessible-primitive library detect item.
   - Lands in: "Hand-rolled interactive primitives".

If no Tailwind: delete the "Tailwind: an `/alpha` modifier" section. If no fixed bottom nav: delete "Layout: reserve space".

**Web, on request:** the detected dialog library's focus-trap/portal issues; React Router version notes on `navigate(-1)` and `location.state`.

## guides/design-system.md — Design system (one shared lib)

**Applies when:** a shared UI workspace lib exists, or two or more apps (`{{FRONTEND_DIR}}`, `{{MOBILE_DIR}}`) each have their own `components/`.
**Otherwise:** keep-as-reference — a single app with no shared lib: ask whether to adopt the rule with the app's own `components/ui/` as the "lib"; if not, prune.

**Detect, don't ask:**
- Shared lib and import name — `git ls-files '**/package.json'` filtered to workspaces named `*ui*`/`*design*`; read its `name`. Fills `{{UI_LIB_DIR}}` and `{{UI_LIB_IMPORT}}`.
- Apps consuming it — `git grep -l '{{UI_LIB_IMPORT}}' -- '*package.json'`
- Layout of the lib — `git ls-files '{{UI_LIB_DIR}}/src' | head -50` against the tree on the page (styles/, components/, web/, icons/).
- Tokens and class prefix — `git grep -nE '^\s*--[a-z]+-' -- '{{UI_LIB_DIR}}/**/tokens*.css'`; most common class prefix in `components/*.css`.
- Domain leakage into the lib — `git grep -nE "from '(react-router|@tanstack/react-query|i18next|react-i18next|{{TYPES_DIR}})" -- '{{UI_LIB_DIR}}/src'` (any hit is a decision-test violation).
- Duplicates in apps — `git ls-files '{{FRONTEND_DIR}}/src/components' '{{MOBILE_DIR}}/src/components'` and compare names with the lib's.
- Web-only layer present — `test -d {{UI_LIB_DIR}}/src/web`; a web root class — `git grep -nE "className=.*(app-web|[a-z]+-web)" -- '{{FRONTEND_DIR}}/src'`
- Hardcoded colours in apps — `git grep -cE '#[0-9a-fA-F]{6}' -- '{{FRONTEND_DIR}}/src' '{{MOBILE_DIR}}/src'`

**Decide:**
1. **Must every reusable visual primitive live in the shared lib?** — ownership; decides where review blocks a PR.
   - Ours: reusable → lib, page-specific → app; when in doubt, lib (an extra component costs nothing, a duplicate drifts).
   - Also common: apps own components, lib holds only tokens (small teams); copy-on-use (shadcn style) with no shared package.
   - Evidence: duplicates detect item and lib size.
   - Lands in: "Core rule"; anti-patterns.
2. **What is the decision test, and may the lib import routing/query/i18n?**
   - Ours: three yes/no questions (repeats in prototypes; no data/routing/store deps; props describable without the domain); the lib never imports router, query library, i18n or domain types, and strings arrive as props.
   - Also common: lib may use i18n for built-in labels (accept coupling); a looser "used on two pages" test with no prototype requirement.
   - Evidence: domain-leakage detect item; whether design prototypes exist (`git ls-files '*prototype*' '*.fig'`).
   - Lands in: "Decision test"; "What stays in the apps".
3. **How is web-specific tuning of a shared class done?** (skip with one app)
   - Ours: never edit the shared file; override under a web root class in the web-only tokens file; cross-surface additions go in shared files.
   - Also common: a separate web design system (when the surfaces genuinely diverge); forked theme tokens only.
   - Evidence: web layer detect item.
   - Lands in: "The web layer — one system, not two".
4. **Class prefix, token naming, and variant policy.**
   - Ours: illustrative prefix `ds-`; tokens only (no hardcoded colour/radius); one token per semantic meaning; one canonical variant of each shell component (e.g. bottom nav).
   - Also common: CSS-in-JS/Tailwind-only (no prefixed classes — rewrite "How to add a component" accordingly); CSS modules per component.
   - Evidence: tokens and prefix detect item.
   - Lands in: "Layout of the lib", "How to add a component", "One canonical variant".

**Web, on request:** the detected styling stack's known issues with CSS variables and layering (Tailwind version, `@layer`, `@import` order in the bundler); Storybook/visual-regression options only if the user asks for a component catalogue.

## guides/client-state-races.md — Client-side state races (auth worked case)

**Applies when:** the client awaits an SDK that notifies through listeners — `git grep -nE 'onAuthStateChange|onAuthStateChanged|addListener|\.subscribe\(' -- '{{FRONTEND_DIR}}/src' '{{MOBILE_DIR}}/src'` returns hits tied to sign-in/session code.
**Otherwise:** keep-as-reference — plain request/response auth (token in a cookie, no listeners) has none of this; offer deleting the auth sections but keeping the "sequence guard" rules if any "latest wins" counter exists.

**Detect, don't ask:**
- Auth provider/SDK — `git grep -hE '"(@supabase/supabase-js|firebase|@auth0/[a-z-]+|@clerk/[a-z-]+|next-auth|@azure/msal-[a-z]+|oidc-client-ts)"' -- '*package.json'`
- Login/logout implementation — `git grep -nE 'function (login|logout|signIn|signOut)|const (login|logout) ' -- '{{FRONTEND_DIR}}/src' '{{MOBILE_DIR}}/src'`
- Latest-wins counters — `git grep -nE 'useRef\(0\)|loadSeq|requestId|seqRef' -- '{{FRONTEND_DIR}}/src' '{{MOBILE_DIR}}/src'`
- Does logout clear state in `finally` — read the logout function found above.
- A "stashed waiter" (promise resolved from a listener) — `git grep -nE 'resolveRef|waiterRef|pendingResolve' -- '{{FRONTEND_DIR}}/src' '{{MOBILE_DIR}}/src'`

**Decide:**
1. **On logout failure (server revoke fails), what happens on this device?**
   - Ours: clear local state in `finally` regardless; a second press joins the in-flight promise; every logout control navigates with `replace` in its own `finally`; a notice at the app root says the device is signed out but the server was not reached.
   - Also common: block logout until the server confirms (high-security apps — then document the offline case); fire-and-forget revoke.
   - Evidence: logout implementation read.
   - Lands in: "Logout clears this device in `finally`".
2. **Do login rejections get distinct user messages?**
   - Ours: either distinguish (wrong password / account deleted / network) or record the collapse to one sentence as a deliberate UX choice where a reader will find it.
   - Also common: one generic message for anti-enumeration reasons (record that as the reason).
   - Evidence: the login screen's error mapping.
   - Lands in: "The widened rejection surface".

**Web, on request:** documented listener-timing behaviour of the detected auth SDK version (event dispatched inside the sign-in call, cross-tab session broadcast).

## guides/realtime-and-live-updates.md — Realtime and live updates on the client

**Applies when:** the client opens a push channel — `git grep -nE "(WebSocket|EventSource|socket\.io|@microsoft/signalr|\.channel\(|\.subscribe\(|pusher|ably)" -- '{{FRONTEND_DIR}}/src' '{{MOBILE_DIR}}/src' '*package.json'` returns hits.
**Otherwise:** prune — no realtime, no page. Also prune the realtime cross-links in client-state-races and api-contract ("a push channel that only says refetch").

**Detect, don't ask:**
- Transport and library — package.json hits above (database-change feed client, hub client, SSE, raw WebSocket).
- Subscriptions that bypass a refetching helper — bare `.subscribe(` calls: `git grep -n '\.subscribe(' -- '{{FRONTEND_DIR}}/src' '{{MOBILE_DIR}}/src'` versus a shared helper such as `useRealtime`/`subscribeWithRefetch`.
- Topic ownership — channel names: `git grep -nE "\.channel\(['\`\"]" -- '{{FRONTEND_DIR}}/src' '{{MOBILE_DIR}}/src'`; flag a name opened in more than one file.
- Polling kept for operations — `git grep -nE 'refetchInterval' -- '{{FRONTEND_DIR}}/src' '{{MOBILE_DIR}}/src'`
- Refetch on focus configured — `git grep -nE 'refetchOnWindowFocus' -- '{{FRONTEND_DIR}}/src' '{{MOBILE_DIR}}/src'`
- Feed opt-in in migrations (DB-change feeds) — `git grep -niE 'supabase_realtime|publication|replica identity' -- '{{BACKEND_DIR}}'`

**Decide:**
1. **May an event carry state into the UI, or only invalidate a query?**
   - Ours: events invalidate queries; no screen depends on an event arriving (delivery is fire-and-forget, gaps lose events).
   - Also common: events carry patches applied to the cache (high-frequency data like prices or presence) with a periodic full refetch as the backstop.
   - Evidence: how existing handlers update state (invalidate vs `setQueryData`/`setState`).
   - Lands in: "The governing rule"; the two subscription shapes.
2. **Does an operation settle by polling even when a push exists?**
   - Ours: yes — failed or rejected commands often emit no event.
   - Also common: push-only when the server guarantees an event for every terminal state, including failure.
   - Evidence: polling detect item and the transport's failure semantics.
   - Lands in: "The governing rule".
3. **Subscription shape per data kind: list invalidate or filtered direct update?**
   - Ours: list invalidate for lists other users can change; filtered direct update for the current user's own row, with a heal that reuses the same branch function.
   - Also common: invalidate everywhere (simplest); direct update everywhere (chat-like products).
   - Evidence: existing subscriptions.
   - Lands in: "Two subscription shapes".
4. **How is the socket authenticated?** (skip if the transport handles it)
   - Ours: token as a query parameter because browsers cannot set handshake headers; gateway reads it there; access logs strip it.
   - Also common: short-lived ticket exchanged over HTTP first; cookie auth on same site.
   - Evidence: where the client builds the socket URL.
   - Lands in: "Gotchas that look like client bugs".

**Web, on request:** the detected transport client's rejoin/heartbeat behaviour in backgrounded tabs and its documented status callbacks; per-topic channel limits.

## guides/native-webview-pitfalls.md — Native WebView pitfalls (Capacitor shell)

**Applies when:** the app ships inside a native shell — `git ls-files 'capacitor.config.*' '**/capacitor.config.*'` finds a file, or `git grep -E '"@capacitor/core"|"cordova"|"react-native-webview"' -- '*package.json'` hits.
**Otherwise:** prune — pure web projects have none of these. Prune third-party-sdk-bridge too unless an iframe bridge exists (see below).

**Detect, don't ask:**
- Shell and platforms — config file above; `test -d {{MOBILE_DIR}}/ios`, `test -d {{MOBILE_DIR}}/android`.
- Keyboard resize mode — `git grep -nE 'resize' -- '**/capacitor.config.*'` (rule expects `Native`).
- Safe-area handling — `git grep -c 'safe-area-inset' -- '{{MOBILE_DIR}}/src' '{{UI_LIB_DIR}}'`; check root element for insets as well as screens.
- Overlays portaled — `git grep -c 'createPortal' -- '{{MOBILE_DIR}}/src' '{{UI_LIB_DIR}}'`
- External links — `git grep -nE "window\.open|Browser\.open|target=\"_blank\"" -- '{{MOBILE_DIR}}/src'`
- Navigation allow-list — `git grep -nE 'allowNavigation' -- '**/capacitor.config.*'`
- Storage used for session — `git grep -nE '(localStorage|Preferences|SecureStorage|document\.cookie)' -- '{{MOBILE_DIR}}/src'`
- Native `<select>` in date fields — `git grep -nE 'appearance-none' -- '{{MOBILE_DIR}}/src' '{{UI_LIB_DIR}}'`

**Decide:**
1. **Is a device-checklist part of the release process, and who runs it?**
   - Ours: a short on-device checklist before each release (overlay stacking, insets, keyboard on the last field, external links, cold start after long background, sign-in surviving force-quit); the browser suite cannot stand in.
   - Also common: beta-channel soak instead of a checklist; device-farm automation for the same items.
   - Evidence: existing release checklist in docs/CI.
   - Lands in: "Process rule".
2. **Touch date fields: three selects or the native date input?**
   - Ours: three selects with `appearance-none` and `minmax(0, …fr)` tracks (the Android picker cannot jump years).
   - Also common: native date input (acceptable when dates are near-term only); a custom wheel/calendar component.
   - Evidence: date-field components and `<select` detect item.
   - Lands in: "A native `<select>` needs `appearance-none`".

**Web, on request:** the detected Capacitor major version's known WKWebView/Android WebView issues (keyboard plugin modes, `capacitor://`/`https://localhost` scheme settings, cookie persistence); iOS version-specific viewport and safe-area regressions.

## guides/third-party-sdk-bridge.md — Third-party SDK behind an iframe bridge

**Applies when:** an iframe + `postMessage` bridge exists or is planned — `git grep -nE "postMessage|<iframe|\.contentWindow" -- '{{FRONTEND_DIR}}/src' '{{MOBILE_DIR}}/src' '{{UI_LIB_DIR}}'` returns hits that are not the payments stand-in.
**Otherwise:** prune — no origin-restricted SDK problem. (Not tied to Capacitor: a browser-only app with an origin-locked key may still need it.)

**Detect, don't ask:**
- Bridge/frame modules — `git ls-files '*bridge*' '*frame*'`; whether a separate frame package/container exists — `git ls-files '**/Dockerfile' '**/docker-compose*.yml'`.
- Origin check on messages — `git grep -nE "event\.origin|e\.origin|postMessage\([^)]*'\*'" -- '{{FRONTEND_DIR}}/src' '{{MOBILE_DIR}}/src' '{{UI_LIB_DIR}}'`
- Frame URL configuration — `git grep -nE 'FRAME_URL|PARENT_ORIGINS|ALLOWED_HOSTS' -- '.env*' '*.yml' '*.ts'`
- Shell allow-list containing the frame host — `git grep -n 'allowNavigation' -- '**/capacitor.config.*'`
- `.dockerignore` next to each containerised module — `git ls-files '**/.dockerignore'` vs `**/Dockerfile`.

**Decide:**
1. **Bridge shape: a fixed verb set on opaque handles, or typed methods per feature?**
   - Ours: fixed verbs (`construct/invoke/get/set/query/release`) with host-allocated handles and buffered `flush()`; new vendor calls never touch the bridge.
   - Also common: a typed method API (`setZones`, `addPin`) for a small, stable surface; a generic proxy library when volume is low.
   - Evidence: existing bridge code, if any.
   - Lands in: "The bridge is a dumb pipe".
2. **Which parent origins may drive the frame, and where does the vendor key live?**
   - Ours: the key lives in the frame only; the frame answers `init` solely to allow-listed parent origins (own, shell, configured list; anyone in dev); origin verified in both directions.
   - Also common: key in the host bundle with Referer restriction (when no webview/iOS custom scheme is involved — then this page is moot).
   - Evidence: origin-check and configuration detect items.
   - Lands in: "Frame hardening"; "Configuration".
3. **Who owns the vendor-console allow-list step?**
   - Ours: listed in the environment-setup checklist, because it is invisible from the repo.
   - Also common: infrastructure-as-code for the vendor console where the vendor offers an API.
   - Evidence: environment setup docs.
   - Lands in: "Configuration".

**Web, on request:** the specific vendor's key-restriction options (Referer, bundle id, IP) and the current policy on custom-scheme origins; WKWebView iframe cookie/storage partitioning changes.

## guides/api-contract.md — API contract, shared types, mock parity

**Applies when:** the frontend talks to an HTTP API owned or described by this repo — `git ls-files '**/openapi*.y*ml' '**/swagger*.json' '**/*.graphql' '**/schema.prisma'` finds a contract, or `{{BACKEND_DIR}}`/`{{MOCK_SERVER_DIR}}` exists.
**Otherwise:** prune with api-version-migration. If only a third-party API is consumed, keep only "Reading what a gateway sends: never trust the union".

**Detect, don't ask:**
- Contract file(s) and format — the `git ls-files` above; fills `{{API_CONTRACT_FILE}}`.
- Code-first signals — `git grep -nE '@nestjs/swagger|fastapi|springdoc|swagger-jsdoc|tsoa|zod-to-openapi|trpc' -- '*package.json' '*.toml' '*.xml'`
- Codegen — `git grep -nE 'openapi-typescript|orval|openapi-generator|graphql-codegen|swagger-typescript-api' -- '*package.json'`
- Shared types lib and consumers — `git grep -l '{{TYPES_DIR}}' -- '*package.json'`; duplicate local interfaces: `git grep -nE '^(export )?interface [A-Z]' -- '{{FRONTEND_DIR}}/src' '{{MOBILE_DIR}}/src'`
- Mock server and its registration — `test -d {{MOCK_SERVER_DIR}}`; `git ls-files '{{MOCK_SERVER_DIR}}/src/routes'`; typed handlers — `git grep -cE 'Request<' -- '{{MOCK_SERVER_DIR}}/src/routes'`
- User scoping in the mock — `git grep -nE 'userId|req\.user' -- '{{MOCK_SERVER_DIR}}/src'`
- Transport conventions in the client — `git grep -niE 'traceparent|idempotency|problem\+json|application/problem' -- '{{FRONTEND_DIR}}/src' '{{MOBILE_DIR}}/src' '{{TYPES_DIR}}'`
- Exhaustive-switch helper and error boundaries — `git grep -nE 'unhandled\(|ErrorBoundary' -- '{{FRONTEND_DIR}}/src' '{{MOBILE_DIR}}/src'`

**Decide:**
1. **Contract-first or code-first, and where does the contract live?** — decides the order of every API change.
   - Ours: contract-first — edit `{{API_CONTRACT_FILE}}`, then shared types, then the handler, then the client; the contract is the only artifact both sides read.
   - Also common: code-first (annotations/schemas generate the spec; the spec is a build artifact — the order becomes handler, then regenerate, then types); schema-first with codegen (types generated from the contract, no hand-written types).
   - Evidence: code-first and codegen detect items.
   - Lands in: "The order is not negotiable"; "Anti-patterns".
2. **Do shared types live in one lib, hand-written or generated?**
   - Ours: one shared types lib, imported everywhere, never duplicated; requests and responses are separate named types.
   - Also common: generated client/types checked in or built on demand; types colocated with the backend and consumed through a package.
   - Evidence: shared types lib detect item; duplicate-interface count.
   - Lands in: step 2 of the order; "Shared types live in one lib, only".
3. **Is there a mock server, and how closely must it follow the contract?** (prune the mock section if none)
   - Ours: a typed stand-in with one route file per contract tag, fixtures separate from the user-scoped store, foreign ids answer 404 not 403, mock-only affordances marked `MOCK ONLY`, never more convenient than the real thing, suite re-run against the real backend when it exists.
   - Also common: MSW/Prism/contract-test doubles generated from the spec; no mock, tests hit a dev backend.
   - Evidence: mock server detect items.
   - Lands in: "Mock server: a stand-in with the contract's manners".
4. **Which transport conventions are required of the client?** — pick only the ones the backend asks for.
   - Ours: trace header on every request; idempotency key per user intent, reused across retries; `202` + request id with mandatory polling; `application/problem+json` with an error-type registry; a single state document; server time and server prices.
   - Also common: plain REST/JSON errors, optimistic mutations without idempotency keys (internal tools); GraphQL conventions.
   - Evidence: transport-convention detect item and the backend's published error format.
   - Lands in: "Transport conventions a modern backend may ask of the client".
5. **How does the client treat values the contract does not name?**
   - Ours: filter unknown items at the API-client boundary with a console warning; every `switch` over a server value ends in `default: return unhandled(value, fallback)`; an error boundary per screen.
   - Also common: runtime validation of every response (zod/valibot) rejecting unknown shapes; trust the generated types.
   - Evidence: unhandled/ErrorBoundary detect item.
   - Lands in: "Reading what a gateway sends: never trust the union".

**Web, on request:** OpenAPI diff tools suited to the detected contract version (3.0 vs 3.1) and framework; the detected codegen tool's known pitfalls with discriminated unions and nullable fields.

## guides/api-version-migration.md — Migrating the client to a new API version

**Applies when:** a second incompatible API contract is in play — `git ls-files '**/openapi*.y*ml' '**/v2/**'` shows two contracts or a parallel tree, or `git grep -nE 'API_VERSION' -- '.env*' '{{FRONTEND_DIR}}/src' '{{MOBILE_DIR}}/src'` hits.
**Otherwise:** keep-as-reference by default (it is a pattern for a future migration; costs nothing) — offer pruning if the backend is stable and owned by the same team.

**Detect, don't ask:**
- Existing parallel tree — `test -d {{FRONTEND_DIR}}/src/v2 || test -d {{MOBILE_DIR}}/src/v2`
- Version switch — `git grep -nE 'API_VERSION' -- '*.ts' '*.tsx' '.env*' '*.yml'` (verify the lever exists before the page documents it).
- Boundary lint — `git grep -n 'no-restricted-imports' -- '*eslint*'`
- Separate client lib — `git ls-files '**/*-client/package.json'`
- Multi-tenant base URL — `git grep -nE 'gateway|tenant' -- '{{FRONTEND_DIR}}/src' '{{MOBILE_DIR}}/src' '.env*'`

**Decide:**
1. **Migrate in a second tree, or in place?**
   - Ours: a second screen tree beside the old one, named after the API version, no adapter over two contracts, shared only API-ignorant things (design system, i18n, native shell).
   - Also common: big-bang cutover on a branch (small app, short migration); versioned endpoints behind one client when the new API is an evolution, not a replacement.
   - Evidence: parallel-tree and version-switch detect items; how different the two contracts are.
   - Lands in: "The one rule: two trees that never meet".
2. **How is the tree selected?**
   - Ours: one build/start-time env variable read once at app root, default old, fall back to old on anything unrecognised; no second lever.
   - Also common: remote feature flag per user (gradual rollout; adds a runtime switch the page does not cover); separate app builds.
   - Evidence: version-switch detect item.
   - Lands in: "Switching between trees".
3. **Is the tree boundary lint-enforced?**
   - Ours: two `no-restricted-imports` overrides; the app root is exempt.
   - Also common: workspace package boundaries or `eslint-plugin-boundaries`; review-only.
   - Evidence: boundary-lint detect item.
   - Lands in: "The boundary, enforced by lint".
4. **Is the backend multi-tenant by gateway?** (skip if single backend; delete the tenant section)
   - Ours: tenant is a derived base URL read per request; changing tenant ends the session.
   - Also common: tenant as a header or token claim.
   - Evidence: multi-tenant detect item.
   - Lands in: "The tenant is a gateway, not a parameter".

**Web, on request:** tooling for diffing two OpenAPI revisions; the bundler's env-inlining behaviour for the detected version (build-time vs runtime env).

## guides/payments-integration.md — Integrating a payment provider

**Applies when:** the product takes payments — `git grep -liE 'payment|checkout|webhook|stripe|adyen|paypal|invoice' -- '{{BACKEND_DIR}}' '{{MOCK_SERVER_DIR}}' '{{FRONTEND_DIR}}/src' '{{MOBILE_DIR}}/src' '*package.json'` returns more than comments.
**Otherwise:** prune — no payments, no page (also drop the payments link in api-contract and third-party-sdk-bridge).

**Detect, don't ask:**
- Provider and SDK — `git grep -hE '"(stripe|@stripe/[a-z-]+|@adyen/[a-z-]+|braintree[a-z-]*|@paypal/[a-z-]+|razorpay|mollie[a-z-]*)"' -- '*package.json'`; otherwise read the provider client file.
- Credential gating (real vs mock) — `git grep -nE '(SECRET_KEY|API_KEY|SHOP_ID|MERCHANT)' -- '.env*' '{{BACKEND_DIR}}' '{{MOCK_SERVER_DIR}}'`
- Webhook route and verification — `git grep -nE 'webhook' -- '{{BACKEND_DIR}}' '{{MOCK_SERVER_DIR}}'`; signature check — `git grep -niE 'signature|constructEvent|hmac' -- '{{BACKEND_DIR}}'`
- Confirmation modes in the init response — read the payment-init handler/type; which of URL / token / embedded appear.
- Settlement idempotency and reconciliation on read — read the settle function; `git grep -niE 'settle|reconcil' -- '{{BACKEND_DIR}}' '{{MOCK_SERVER_DIR}}'`
- Shell allow-list for widget hosts — `git grep -n 'allowNavigation' -- '**/capacitor.config.*'`

**Decide:**
1. **Embedded widget, redirect to hosted page, or both?**
   - Ours: embedded widget when the product allows (user stays in-app; completion event is a cue to poll); redirect only when forced, with the return URL settled early; the type is chosen at payment creation and is exclusive.
   - Also common: hosted checkout redirect only (least PCI scope, simplest); native in-app payment sheet.
   - Evidence: confirmation-mode detect item.
   - Lands in: "One contract, two modes"; "A provider's URL usually cannot be framed".
2. **How is the outcome settled?**
   - Ours: server-side and idempotent from two sources — webhook (fast path) and reconciliation on status read (the working path in dev); the client's widget event never is the answer.
   - Also common: webhook only (needs a public tunnel in dev); polling the provider only.
   - Evidence: webhook and settle detect items.
   - Lands in: "The outcome always comes from the server".
3. **Is there a credential-free mock mode?**
   - Ours: the default is a local simulation; real provider only when credentials are present, so dev/CI/e2e need none; mock throttles outbound calls per session.
   - Also common: provider sandbox in all non-prod environments; recorded fixtures.
   - Evidence: credential-gating detect item.
   - Lands in: "One contract, two modes"; "Rules the mock has to follow".
4. **What protects the webhook?**
   - Ours: restrict to provider source IPs at the proxy and/or verify a signature; never trust `metadata` alone; ignore unknown payments.
   - Also common: signature verification only (provider has no stable IPs).
   - Evidence: webhook verification detect item.
   - Lands in: "Security notes".
5. **Where is the known-gaps register kept?**
   - Ours: next to the integration — framing, receipts, webhook auth, prefix issue, cancel endpoint, outcome visibility.
   - Also common: the issue tracker.
   - Evidence: existing notes beside the payment code.
   - Lands in: "Known-gaps register".

**Web, on request:** the detected provider's current embedded-checkout requirements (allowed origins, frame headers, 3-D Secure/SCA return handling, sandbox test cards) and webhook source-IP list; tax/fiscal receipt requirements of the target jurisdiction.
