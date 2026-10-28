---
title: Native WebView pitfalls (Capacitor shell)
class: compiled
covers: []                 # fill when adopting: the capacitor config, the root CSS, the overlay components
last-verified: never
verified-by: boilerplate
sources: []
---

# Native WebView pitfalls (Capacitor shell)

When `{{MOBILE_DIR}}` also ships as a Capacitor app, the same bundle runs inside WKWebView (iOS) and
the Android WebView, usually on a custom origin (`capacitor://localhost` on iOS). Several browser
habits break there, **each silently, and all were found on a device**: an end-to-end suite that
drives desktop Chromium reproduces none of them. Treat "works in the browser build" as necessary,
not sufficient, for anything below. Session storage inside the shell is a security question, on
[`security-session-checklist.md`](./security-session-checklist.md).

## A `position: fixed` overlay inside a scrolling container is painted inside that container

On iOS a fixed descendant of an `overflow-y: auto` box is confined to that box's layer, so a bottom
sheet opened from a scrolling step area rendered *underneath* the page's own call-to-action footer —
sheet and button visible at once. The fix is structural, not a `z-index`: render the overlay with
`createPortal(…, document.body)`, which puts it above every page-level layer whatever scroll
container opened it. **Portal every new full-screen overlay**; a z-index war cannot win against a
separate stacking context.

## Safe-area insets are applied per screen, never also on the root

Give every header `padding-top: calc(env(safe-area-inset-top, 0px) + 12px)` and every footer the
bottom equivalent. If the root element *also* carries the inset, it is double-counted: a header
twice the height of the notch, and a white strip below the content where the root's own background
shows through its reserved padding. Left/right may stay on the root when no screen handles them.
Adding an inset at both levels is the recurring mistake.

## The keyboard must shrink the WebView frame, not scroll it

Set the keyboard plugin's resize mode to `Native`. With every screen `height: 100%`, a fixed header
and a `flex-1 overflow-y-auto` body, a shrunk frame keeps the header pinned and lets the inner
container scroll the focused field into view. Without the setting WKWebView scrolls its *own* outer
scroll view and drags the header off screen — the "two scrollbars" bug.

## Leaving the app needs one of two mechanisms; `window.open` after an `await` is neither

- A plain `<a href target="_blank" rel="noopener noreferrer">` is handed off to the system browser.
  A `<button onClick>` that opens a URL programmatically does nothing at all on-device — a "legal
  links" row built from buttons is dead for exactly this reason.
- For a URL known only *after* a request, use the browser plugin's `open()` (an in-app system
  browser on native, a new tab on the web), which needs no user-gesture tick.
- Do not pre-open a blank tab synchronously and set its `location` later: that popup-blocker
  workaround is blocked outright by WKWebView.

Remote hosts the shell must load (a payment widget's script and sub-frames, a map frame) belong in
the shell's navigation allow-list; otherwise the WebView refuses them on-device only.

## A native `<select>` needs `appearance-none` and a `minmax(0, …fr)` track

A `<select>` reports an intrinsic width from the OS chrome, so in a flex row it overflows the
viewport or collapses a sibling to nothing; plain `1fr` (and flex's `min-width: auto`) refuses to
shrink below the widest option ("September" pushed a date row past the screen edge). Stripped of
the chrome it respects the grid track and truncates, and the OS wheel picker still opens on tap.
This is the deliberate exception to "avoid the native select": a touch date field built from three
selects replaces the native date input because the Android picker cannot jump years — a birth
date decades back means hundreds of taps on "previous month".

## Storage and origin are not the browser's

- WKWebView does not persist `document.cookie` for a custom scheme, so a cookie-backed session
  survives only while the app stays warm.
- `localStorage` persists but is **not durable**: mobile OSs may clear it under storage pressure,
  signing the user out unpredictably.
- Anything keyed to the page origin (an API key restricted by HTTP Referer, a CORS allow-list, a
  payment provider's allowed-origin list) sees `capacitor://localhost` or `https://localhost`, which
  a vendor console may refuse. The map embedding page shows the standard workaround —
  [`third-party-sdk-bridge.md`](./third-party-sdk-bridge.md).

## Process rule

Keep a short on-device checklist for releases covering exactly these: overlay stacking, header and
footer insets, keyboard open on the last field, an external link from every place one exists, a
cold start after a long background, and the sign-in persisting across a force-quit. The browser
suite cannot stand in for it.
