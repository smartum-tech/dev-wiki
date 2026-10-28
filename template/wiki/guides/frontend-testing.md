---
title: Frontend Unit and Component Testing
class: compiled
covers: []   # fill when adopting: the test-runner configs and setup files of each client workspace
last-verified: never
verified-by: boilerplate
sources: []
---

# Frontend Unit and Component Testing

Unit/component tests for the client workspaces (`{{FRONTEND_DIR}}`, `{{MOBILE_DIR}}`, shared UI
libraries). For the browser suite that drives the full stack see [e2e-testing.md](./e2e-testing.md).
The boundary is deliberate: **unit tests own localization and component logic; E2E owns
cross-service flows and visual regression.**

The assumed stack is Vitest + Testing Library in a jsdom environment. A shared UI library with no
`test` script has no harness of its own — it is exercised only through client specs; say so in the
workspace README rather than leaving people to look for one.

## One harness per workspace, and do not assume one exists

Web and mobile workspaces drift apart in test infrastructure, and merging them is not a goal. One may
carry a provider wrapper (`renderWithProviders`, a language list); the other may have a setup file of
one line and per-file local wrappers. **Do not assume a helper exists in a workspace because its
twin has it** — the import looks plausible and fails at collection. Write the local wrapper the way
that workspace's existing hook specs do.

Config notes that explain most "cannot find module" errors:

- Path aliases (`@` → `./src`) are usually declared twice — once for the dev server, once in the
  test block. A mismatch between the two declarations is the usual cause of `Cannot find module
  '@/…'`. Cross-package aliases (shared libs) have to be declared per workspace for the test
  resolver too: a *value* import from a shared package may fail to resolve where only a *type*
  import (erased at compile) works.
- `ReferenceError: document is not defined` means the jsdom environment is missing or overridden;
  check for a per-file environment comment.
- Package-level test scripts differ per workspace; the root may wire one and not the other.

## Localization

A component that calls `t()` renders its **keys**, not text, unless the spec supplies an i18n
instance — the library's default `t` returns the key. Localising a page therefore turns every
assertion on its text red at once. The convention is a per-file `createInstance()` backed by the
app's real bundle, passed in a provider as `render`'s `wrapper` (so `rerender` keeps it); find
elements by the bundle's values, the label a user actually sees. A spec that mocks the i18n library
with a key-returning `t` asserts keys, and is not the one to copy.

For every bilingual page, assert **each language**: one `it` per language asserting literal text, and
a loop over the supported-language list for what must render in all of them. This is why unit tests
own localization — speed, and the only practical way to cover every key in every language.

**A locale spec makes the bundle itself the subject.** A render test that reads its expected strings
out of the bundle is vacuous about what those strings say: mutate a translation and both sides of the
comparison move. A locale spec builds a throwaway i18n instance per bundle and writes the expected
sentences out a second time — that duplication is the assertion, not an oversight. Two details:

- **Disable fallback** (`fallbackLng: false`). With the default chain a key missing from one language
  resolves through another and comes back in the wrong language, so a presence check passes while a
  user reads the wrong text.
- Where a wording was changed **because it was false**, say so in the spec. The pinned string is the
  only thing between a future tidy-up and the defect coming back.

## Mocks

Mock hooks and contexts at module level with `vi.mock(...)` before the imports, and provide **every
runtime export** the real module has — not only what the component calls today.

**A partial factory is latent, not broken, and that is what makes it expensive.** Writing one fails
nothing; neither does importing a name it omits. It fails on a *reach*, and where the reach sits
decides the blast radius: reached inside a test, one test goes red; reached at **module scope**,
collection dies — the file reports `(0 test)` under a message naming the *module*, not the factory.
The cost lands on whoever later adds an unrelated import somewhere in that module graph: a spec they
never touched takes its whole file down and points them at the wrong file. The runner's tally shows
**no failure** — the lost tests simply drop out of the total.

A related trap: a shared helper that imports an app-level module whose module scope initialises a
library or constructs a client drags that init into every spec's graph. **A helper that only needs
the translation function imports the bare i18n singleton**, not the app's init module — the same
instance at runtime, no init in the spec's graph. Patching one spec's mock leaves the trap for the
next one.

**A spec dies at collection with a "URL (or key) is required" error and no failing assertion** — a
module that constructs a backend client at module scope. The fix is to define placeholder values for the
client's env in the test config once, not to add a per-spec mock, which spreads the workaround. Where
the config cannot carry them, mock the module reaching the client whole, from one shared stand-in.

Compile-time constants substituted by the bundler's `define:` reach specs for free, since the test
runner shares the config. The trap is on the other side: if the dev server runs in a container that
does not restart on a config edit, a new constant is undefined *in the browser* long after the specs
are green.

Native plugins (Capacitor and similar) are mocked at the module boundary, like any other platform
API. Their real behaviour is not covered by jsdom or by a browser E2E: see the native-shell note in
[e2e-testing.md](./e2e-testing.md).

## What to assert

Prefer role/label queries over text so translation changes don't silently break selectors:
`getByRole('heading' | 'button', …)`, `getByLabelText`, `getByPlaceholderText`. Reach for a test id
only when no semantic role or label distinguishes the element. Functional tests assert real
component state (a disabled save button, a pre-filled read-only field) using mocked data shaped like
the real API response — see [mock-server.md](./mock-server.md) for keeping that shape honest.

**A defect that lives for ONE commit is invisible to an assertion made after `rerender` returns.**
React has run the passive effects by then, so a component whose reset is an effect has already
repaired itself and the spec is green against the bug it was written for. Render a probe *beside* the
component that records the property on **every** commit — a layout effect with no dependency array
(it runs after the DOM commit and *before* the passive effect that hides the frame) — and assert over
the recorded list rather than the final DOM. The test must be red with the fix reverted; an
ordinary post-`rerender` assertion is not.

**Reading state inside the `.then` of the promise under test is timing, not evidence.** A state write
is committed on a *later* render than the promise callback that observes it. Record the settlement
in the `.then`, let everything flush, then read the state, and assert **both**: "it resolved" and
"something is loaded" are the pair a settlement bug conflates.

**To pin an interleaving rather than hope for it, park one side:** give the read under test a mock
returning a promise you resolve by hand, fire the competing event, release, flush. Nothing fires
after the `act` block, so a hang stays hung and `settled === false` is the assertion — the symptom
itself, not a proxy for it.

## Troubleshooting

- **Mock silently ignored** — `vi.mock()` calls are hoisted, but only within the same file; the mock
  must precede any import of the mocked module in that file.
- **A back-button click under a memory router navigates to `/` instead of popping.** Components that
  pop only when `window.history.state.idx > 0` never see it set, since the memory router does not
  write `window.history`. Seed `window.history.replaceState({ idx: 1 }, '')` for the pop case and
  reset it in `beforeEach`.
- **A run is green with an "Errors 1" line and nothing points at a spec.** jsdom implements no
  `ResizeObserver`, and headless-UI listboxes construct one while closing; the throw lands outside
  React's render and is reported as unhandled *after* the test passed. Install a no-op class in the
  shared setup file — deliberately not a mock anything asserts on. It appears the first time a spec
  *selects an option* rather than merely rendering a closed select.
