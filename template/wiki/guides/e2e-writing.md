---
title: Writing E2E Tests
class: compiled
covers: []   # fill when adopting: the extended test fixture, page objects, nav helpers, the request layer
last-verified: never
verified-by: boilerplate
sources: []
---

# Writing E2E Tests

Architecture, running and test data: [e2e-testing.md](./e2e-testing.md). This page is the rules that
cost a day each. General rules for specs that prove something: [writing-tests.md](./writing-tests.md).

## Spec first, then code

Two steps, in order, with a human between them:

1. **Spec**: prose a person approves — a checklist of scenarios, each with what it arranges and what
   it asserts, written after reading the feature's spec and *verifying the real app in a browser*.
2. **Implement**: working tests from the approved spec, with every selector verified in a real
   browser first (see [browser-automation.md](./browser-automation.md)).

The split exists because reviewing test code checks selectors, while the argument worth having is
about coverage; prose makes disagreement cheap. Implementation does not add, remove or reorder
scenarios and does not change what one asserts. **If the app does not behave as the spec says, stop
and ask** — a silently "corrected" expectation is how a test ends up asserting the bug. A recording
from codegen is raw input to the spec step, never a test.

## The shape of a test

Import the project's **extended `test`**, never `@playwright/test` directly: it carries the sign-in,
arranging and request-layer fixtures. A typical test arranges through the API as an account, signs
in, enters at `/`, and clicks through.

- **Sign-in is per call.** If the dev access token is short-lived and refresh tokens are single-use,
  a shared token pair goes stale the moment the app refreshes it in one test. Sign in afresh on
  every call, and give each API session of the same account its own sign-in ("another device").
- **Seed tokens on the first navigation only.** Written on every navigation they come back after a
  sign-out or a switch, and a later `reload` would test the server, not the app.
- **Proving a sign-out.** The sign-in screen is not proof: a token the app forgot to drop gets a
  401, the app drops it then, and the same screen appears. Assert that **nothing went out with a
  token afterwards** (mark the request log at the sign-out, then assert on calls after the mark).
- **Raise the timeout inside the hook.** A describe-level `test.setTimeout()` does not cover
  `beforeAll`, which runs on the default budget however generous the block is; a fixture doing
  several real registrations dies on a busy queue and reads as a product timeout.
- An app without test ids keeps it that way unless a case genuinely needs one (below).

## Selectors

Verified in a real browser, in this order, and **proved unique** (a strict-mode failure names the
locator, never the duplicate):

1. role + accessible name (`getByRole('button', { name })`), headings, labelled inputs
   (`getByLabel`);
2. a test id, **if the project uses them** — and then it ranks above role/name where the accessible
   name is a translated string, because that binds the selector to a language file;
3. exact text as a last resort.

Decide once, project-wide, between "role and name" (couples tests to copy; accepted when copy is the
contract with the user — a broken test on a changed label is a fair alarm) and "test ids" (survives
copy changes, costs markup). Do not mix by accident, and do not add ids to dodge a single awkward
selector. Resolve every quoted string against the locale bundle: a retyped string with the wrong dash
or a missing diacritic fails at run time and reads as a missing element. Prefer **adding a test id to
the component** over reaching for text when an element is genuinely unaddressable.

Components can lie to the role system: an *alert dialog* is not a *dialog* to `getByRole('dialog')`,
and the failure is a 30-second timeout that says nothing about roles. Check the role on the live
page.

A list item that renders twice (an attention card above its list card, same text and status) breaks
strict mode on any locator keyed by subject alone. Anchor on the element that only one of them
carries, and put that locator in the shared page object rather than re-deriving it per test.

## Rules worth the day they cost

1. **Never `page.goto('/route')` in-app.** Enter at `/` and click through via navigation helpers.
   Seeded tokens make a deep link work, which is not the same as it being right: navigating by click
   is a free assertion that the route still exists. The cost (a nav change breaks many tests) is the
   trade. Exceptions, commented where they occur: the route guard itself, and screens with no
   navigation to click.
2. **Assert what the user sees, not the database.** `toHaveURL`, `toBeVisible`, `toHaveText`.
   Data-level assertions belong in backend integration tests.
3. **Assert on the list, not the toast.** Commands that settle asynchronously (202, then polling)
   make a toast a moment, and a moment is a race. A pending label ("Saving…") is asserted only with
   the command **held** in the request layer: hold, click, assert, release. Otherwise the label is
   gone before a slow run (the Inspector, every time) looks.
4. **Park the observer before the trigger, never reload after it.** When the other party (an API
   call, a sweep) initiates the transition, the observing page sits on the target screen *before* the
   trigger fires, and assertions run on that page with no reload. Asserting after a navigation tests
   a fresh load, which passes against completely broken realtime delivery. Different screens listen
   on different channels, so one parked screen does not stand in for the others. Notification
   counters are asserted as "+1 copy" (counted), never as presence: texts repeat across entities, so
   a presence check passes with delivery switched off.
5. **A park that is too old is as broken as no park, and it fails as a flake.** A page left on a
   screen since an earlier test has had its timers throttled while unfocused; a heartbeat slips, the
   server drops the socket, and an event fired during the reconnect gap is lost for ever. Re-park
   seconds before the trigger; raising the timeout treats it as lag, which it is not. Client-side
   self-heal contours (refresh on refocus or rejoin) do not retire this: they run on events the test
   does not control.
6. **Time is the browser's only.** Install the fake clock and advance it for countdowns (a
   "fast-forward" does not fire a chain of timers). Pause the clock after navigation before asserting
   an exact countdown: an installed clock still runs in real time, and the Inspector spends seconds
   between steps. **Jump the clock only after the screen has armed its timer** — a drawer that waits
   for a server session before starting its clock shows the same spinner meanwhile, and jumping too
   early fires its other, shorter clock; wait for the state response first. The server clock cannot
   be moved on a real stand, so nothing waits on it, and server-side rate limits are counted on the
   server: moving the browser clock does not get around a "one live code per phone, 30 s" throttle.
   A test that stops at the code step leaves the code live; use a janitor fixture that verifies such
   codes at teardown.
7. **Charges and time-based pricing follow the server clock.** A scenario that needs a charge or a
   refund asks for an item that charges *at this hour* and skips when there is none; one that only
   needs a record takes any. Top up an account from a test checkout when it runs low.
8. **Navigations wait for the document, not `load`.** `load` includes third-party frames and tiles;
   one hanging request held a `goto` for the whole test timeout. Make `domcontentloaded` the default
   in the `page` fixture and wait for what the test checks.
9. **A third party's checkout is driven only through one helper.** Open it in a new tab, type slowly,
   read every field back, retry when the sandbox answers a transient failure; skip scenarios when the
   stand has no sandbox keys. An open payment cannot be cancelled and changes screens, so a test
   touching money settles the account's open payments before and after. Screen reactions (not ready,
   failed, never appeared) use a fake payment that exists only in the browser.
10. **Map and canvas content is asserted by pixels with measured thresholds.** Count a region's colour
    in a canvas inside an iframe against the base layer's own colour; open an item by finding a point
    by colour, making sure the frame (not one of your controls) is under it, and retrying the next
    point if the expected panel did not open. A test that needs a *particular* item goes through its
    accessible control instead.
11. **No made-up data.** For each screen a slice covers, assert that every identifier visible in the
    region's accessibility tree (order number, invoice number) appears in some API answer the page
    received. It catches hardcoded rows — a landing page rendering a record from a sample constant
    on a clean environment — which "an identifier is shown" would happily pass. Decorative mock-ups must be
    `aria-hidden`. Use it in the empty state and with one known record.
12. **History is the ledger, not the live-state endpoint.** If the state endpoint keeps only the last
    N minutes of finished items, arrange finished items over the API or substitute the ledger
    response, and remember a cached ledger is re-read by a `reload`, not by leaving the screen and
    coming back.
13. **Scenarios sharing a Playwright project must not share mutable fixtures** across files; scope
    cleanup to the file's own marker.
14. **Keep a request layer, not route mocks sprinkled through tests**: patch/fail/delay/hang/record on
    contract paths, so a test behaves identically on the mock and on the real stand, and a
    "nothing went out with a token" assertion has a log to read.
