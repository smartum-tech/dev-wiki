---
title: Embedding a third-party SDK behind a bridge (iframe + postMessage RPC)
class: compiled
covers: []                 # fill when adopting: the bridge lib, the frame module, the protocol types
last-verified: never
verified-by: boilerplate
sources: []
---

# Embedding a third-party SDK behind a bridge (iframe + postMessage RPC)

The pattern: when a vendor's browser SDK (a map, a payment form, a video player) cannot run directly
in your app's origin, render it inside an `<iframe>` served from an origin the vendor accepts, and
drive it from the app over a small generic `postMessage` RPC. The worked case is a rendering SDK
(canvas plus DOM markers) whose API key can only be restricted by HTTP Referer; the lessons apply to
any origin-restricted SDK.
Where the same constraint bites payments, see [`payments-integration.md`](./payments-integration.md);
the WebView side of the origin problem is on
[`native-webview-pitfalls.md`](./native-webview-pitfalls.md).

## When you need it: origin-restricted keys vs the packaged app

Vendors restrict keys by a few mechanisms: HTTP Referer, app bundle id/package, server IP. For a
browser SDK the Referer (the page's origin) is typically mandatory, and **script cannot forge the
host of the Referer** — a referrer policy can only strip it. So the origin the app actually produces
must be on the key's allow-list:

| Where the app runs | Origin the vendor sees | On a `localhost`-only allow-list? |
|---|---|---|
| Browser via `http://localhost:<port>` | `localhost` | yes |
| Browser via a LAN/VPN **IP** | `100.x.x.x` | no — vendors typically reject IPs |
| Android release WebView | `https://localhost` | yes |
| **iOS release WebView** | `capacitor://localhost` | **no** — a custom scheme cannot be put on a referer list |

The hard one is iOS: WKWebView reserves `http`/`https` for remote content, so the shell serves the
bundle under a custom scheme that no vendor console accepts. Options considered normally are: a
native SDK (different key type, requires a native renderer your stack may not have), hosting the
whole app remotely (loses offline), a proxy, or **an iframe on a real, allow-listed domain**. The
iframe wins when the rest of the app should stay in the offline bundle: the iframe's own origin
becomes the Referer for every SDK and tile request, independently of how the app is opened, so one
key works on iOS, Android and a browser opened by IP. Record the option analysis in the change record
— the next person will propose the native SDK again.

## Shape

```
Host app (any origin)                       <iframe src=FRAME_URL>  — an allow-listed origin
  page: all UI, data, business logic   ──►    runtime: object registry + verb runner + SDK loader
  bridge lib: mini-RPC client          ◄──    (the vendor key lives HERE, not in the app bundle)
        postMessage: exec / query / hello ──► ready / reply / event
```

The app keeps **all** logic, data and UI. Only the vendor canvas and its marker DOM live in the
frame. The key moves from the app bundle to the frame — acceptable, since a client-side JS key is
always exposed; the point is that it is restricted to the frame's domain.

## The bridge is a dumb pipe, not a set of methods

Do **not** write `setZones()` / `addPin()` that grows with every feature. Use a **fixed verb set**
operating on opaque handles, so a new vendor call never changes the bridge — only its composition
at the call site:

| Verb (host → frame) | Meaning |
|---|---|
| `construct(ref, args) → handle` | `new ref(...args)` |
| `invoke(target, method, args)` | `target.method(...args)`, fire-and-forget |
| `get(ref) → handle` | materialise a property path as a stable handle |
| `set(ref, value)` | `parent[last] = value` |
| `query(ref) → value` | round-trip read of plain JSON |
| `release({handles, callbacks})` | drop registry entries |

Value encoding: plain JSON passes by value; `{ h, p }` is a **handle ref** (registry id + property
path); `{ cb }` is a **host callback** the frame wraps in a real function (calling it posts an event
back). The frame seeds a few handles at boot (the SDK namespace, `document`, the container).
Protocol types are shared types, in the shared types lib.

Two choices make it fast on a fine-grained SDK with thousands of features:

1. **Host-allocated handle ids**, so the result of a `construct` is usable as an argument to the
   next op without waiting for a round trip (pipelining).
2. **Buffered ops + `flush()`**: a whole layer goes out in **one** `postMessage`, not two thousand.
   (This is why a hand-rolled mini-RPC beat a generic proxy library, which costs one round trip per
   property access with no batching.)

**Readiness is pull-based.** The host sends `hello` until the frame answers `ready`, so React
StrictMode's double-mount cannot miss a one-shot boot signal.

### Adding a vendor call — you do not touch the bridge or the frame

Compose verbs at the call site: `construct` the object off the namespace seed,
`invoke(parent, 'add…', …)`, `await query(…)` only where a value is needed, `flush()`.

### DOM markers

Marker elements must live in the frame's document, so the host cannot render React into them.
Build the element through the **same verbs** against the `document` seed (`createElement`, `set`
`style.cssText` / `innerHTML`, `addEventListener` with a `cb`). The marker's *look* lives in a CSS
file in the frame, a port of the design system's pin; the host supplies only data and class names.
No React in the frame. Shared geometry/markup helpers (viewport filtering, anchors, pin HTML) live in
a shared lib so every host places and draws identically.

## Frame hardening

- The frame holds a key, so it answers `init` **only from allowed parent origins** (its own origin,
  the shell origins, plus a configured list; anyone in dev) and boots the SDK only on such an
  `init`. A refused host gets an `error` naming its origin — that message is what makes a
  misconfigured environment diagnosable.
- Verify the origin on `message` events in **both** directions; never `postMessage(…, '*')` with
  anything sensitive.
- The shell's navigation allow-list must include the frame's host, or the WebView refuses it on
  device only.

## Configuration

| Variable | Where | Purpose |
|---|---|---|
| `FRAME_URL` | apps | the frame's URL; a dev-only override, otherwise derived from the environment's own origin |
| `VENDOR_API_KEY` | frame | the environment's own key, filled at **container start**, must be allow-listed for the serving domain |
| `PARENT_ORIGINS` | frame | extra origins allowed to drive it (comma-separated) |
| `ALLOWED_HOSTS` | frame / apps | extra dev-server hosts for opening over a real hostname |

**Required external step:** the frame's domain must be on the vendor key's referer allow-list (a dev
hostname for dev, the staging domain for staging). Without it the SDK is rejected and the frame
reports an `error` — the host shows its "map failed to load" screen. Vendors usually include
subdomains. Put this step in the environment-setup checklist, not just here: it is invisible from
the repo.

Serving: dev runs the frame as its own container on its own port (open the app over a real hostname
so the frame's origin is allow-listable); staging/prod serve the built frame under a path on each
environment's own domain, next to its API, so each stand uses its own key.

## Gotchas

- **Every new containerised module needs a `.dockerignore`.** Without it `COPY . .` copies the host's
  `node_modules` (symlinks into a store that does not exist in the image) over the freshly installed
  one → "module not found" at start.
- **"Frame did not become ready in time"** means the host got no `ready` within the timeout — nine
  times in ten the frame URL points at a host that is not serving it (a VPN dev box left in `.env`
  while containers run locally). `curl -m5 <FRAME_URL>`; for a browser on the same machine as the
  containers, `http://localhost:<port>` is both reachable and allow-listed. A container env block
  is read at creation, so a `.env` edit needs the service **recreated**, not restarted.
- **Event details do not cross the frame boundary for free**: a `stopPropagation` on a marker click
  is not forwarded to the host; if a stray map pan under a marker is observed, add a click shim in
  the frame runtime.
- **A second host reuses the bridge, it does not fork it** (a web landing's map strip beside the
  mobile map page). Mount long-lived maps once and never unmount; folding is a CSS change, so the
  camera survives.
