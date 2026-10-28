---
title: Browser Automation for Agents
class: compiled
covers: []   # fill when adopting: MCP server config, agent settings, e2e spec/implement skill files, the CORS origin list
last-verified: never
verified-by: boilerplate
sources: []
---

# Browser Automation for Agents

Which browser an agent may drive, and the ways a browser tool returns a **wrong answer instead of an
error**. A tool that fails is cheap; a tool that answers plausibly about the wrong page costs a spec.
Skills and commands carry the procedure (handles, flags, call order); this page is what the procedure
cannot state.

## 1. One sanctioned browser: the isolated automation browser

Agents use the project's dedicated automation browser — `{{BROWSER_TOOL}}` (a Playwright-based MCP
server that launches its own browser instance). It does not touch anyone's session.

**Never drive the user's own browser without explicit permission.** A browser-extension tool that
acts in the browser the user is working in right now steals focus, navigates their tabs, and a
resize call physically resizes the window under their hands. The single exception is a page that
requires the user's own logged-in session (an authenticated dashboard, a service the automation
browser cannot sign into): ask first, then use the minimum number of calls. Never resize the user's
window at all; use the automation browser's own resize.

Screenshots taken by the tool go to a **gitignored folder** (pass an explicit filename with that
prefix); without it the file lands at the repo root and pollutes `git status`.

## 2. Other browsers may also be listening, and they do not say so

A session can expose several browser tool families — your own machine's, a remote gateway's, a
vendor agent's. Calling the wrong one does not give "tool not found"; it gives a well-formed
accessibility tree **of a different page on a different machine**. Name the sanctioned tool in the
spec/implement skills explicitly, and treat any spec written against another family as suspect.

## 3. MCP tools may arrive deferred

In some sessions every MCP tool is listed by name only; a direct call fails with a validation error
until a search call loads its schema. That is a property of the session, not of the browser: an agent
that reads the failure as "the browser is down" gives up on a browser that is running. Load the
needed tools in one search call, batching everything the task will need.

## 4. If the browser is not on your machine, `localhost` is not yours

A remote or containerised browser resolves `localhost` to *its own* host: you get connection refused,
or worse, a different service on that host. Use an address the browser can reach (VPN, LAN) and
expect three consequences:

- **The page may load and every backend call be blocked.** CORS origin allow-lists are usually
  exact-match — no wildcard, no pattern — and a preflight for a missing origin often still answers a
  success status, merely without the allow-origin header. Nothing errors; the console fills with
  blocked requests while the UI sits on a spinner. Probe the preflight directly from the browser's
  host before debugging the UI.
- **The working origin is deployed configuration, not repository content.** Committed defaults list
  `localhost` only; grepping the repo for the address that works finds docs, not the file the running
  backend reads.
- **A non-`localhost` plain-HTTP address is an insecure context.** Clipboard, service workers and
  other secure-context APIs are `undefined` there. Anything asserted about copying through such a
  browser exercises the fallback path, never the modern one.

## 5. Snapshots are not exhaustive; selectors are finished by tools, not discovered

- An accessibility snapshot does not carry test ids by default; ask for the attribute explicitly. Even
  then it can omit elements whose box is shared with a relative, and the omitted ones may be exactly
  those the spec wants. The failure mode is a spec that reaches for text "because the element had no
  id". One evaluation over `document.querySelectorAll('[data-testid]')` closes the gap in a single
  call.
- **Element refs renumber on every navigation.** Re-read them from the latest snapshot; never carry
  one across.
- **A locator generator finishes, it does not discover.** On a ref that has a stable attribute it
  adds the disambiguation the annotation cannot see (`.nth(2)`). On a ref without one it degrades
  **silently** to a text locator of the rendered string — the worst output concatenates a row's
  descendants into one literal, coupling the selector to the UI language *and* to the fixture user's
  display name. Snapshot first to learn which refs are annotated, call it only on those, and **never
  copy a tool's echoed code lines into a spec**: they are written in that same brittle form.
- Prove uniqueness on the live page (`document.querySelectorAll(sel).length === 1`) for every
  selector before writing it down. Selector precedence is in [e2e-writing.md](./e2e-writing.md).

## 6. Verify against the right stack

Drive the **dev** stack from the host (never the containerised one — see
[e2e-testing.md](./e2e-testing.md)); do not start a second dev server on a port a container already
publishes; and never kill a process by port — on a published container port the PID is the container
engine's forwarder, and killing it crashes every container. Kill your own process by command name.

## 7. State what was never exercised

Gaps are invisible from a green run. When a page or spec rests on a single measured run — one
surface, one login, one account without the right membership — say so in the page. Typical gaps: only
one of several apps was driven; the account used lacked the role the screen needs, so backend-backed parts of the
screen returned 403 while the shell still rendered; UI login was unreliable (an argument for
fabricating state through the API, as [e2e-testing.md](./e2e-testing.md) describes, instead of
clicking through).

## 8. Credentials in tool config

A bearer token committed in MCP config for a private, network-restricted gateway may be deliberate.
Say so on the page and in the config; otherwise the next reviewer "fixes" it, and rotating it is a
commit, not a configuration change.
