---
title: Integrating a payment provider
class: compiled
covers: []                 # fill when adopting: the provider client, the payments routes/handlers, the top-up screen
last-verified: never
verified-by: boilerplate
sources: []
---

# Integrating a payment provider

General lessons from wiring a card/wallet top-up flow to a hosted payment provider, with a built-in
mock for development. Provider specifics (field names, test cards, dashboards) belong in the
adopting project's own notes; the shape below is what repeats across providers.

## One contract, two modes, gated on credentials

The server is a thin proxy **gated on env credentials**: merchant/shop id + secret key present →
real provider; either absent → a local simulation (a hosted stand-in form served by the mock, shown
in an `<iframe>`). Same "provider key present → real, absent → offline fallback" switch as any
other third-party-backed route. The default is the mock, so dev, CI and e2e need no credentials.

The init response carries a confirmation type telling the client how to present the payment form;
exactly one of a URL or a token is present (field names below are illustrative — use your
provider's):

| Mode | When | Returned | App shows it |
|---|---|---|---|
| embedded (mock) | no credentials | `paymentUrl` | stand-in page in an `<iframe>` |
| widget | credentials set | `confirmationToken` | provider's embedded checkout widget, inline |
| redirect | credentials set, URL-style API | `checkoutUrl` | provider's own page, opened outside the app |

**The confirmation type is chosen at payment creation and the types are exclusive.** A provider
returns a URL only for its redirect type and a token only for embedded; there is no call that
returns both. Decide which the product needs *before* the contract is written, because a contract
that hands the client a URL silently selects redirect.

## A provider's URL usually cannot be framed

A hosted checkout page answers `X-Frame-Options: SAMEORIGIN` (measure it, do not assume): a frame
renders an empty box and **no load error is observable from script**. So the client decides by
**origin**: a provider URL gets a button that opens it outside the app; your own origin is framed.
Framing happens only without credentials, where the mock serves a stand-in. Redirect has a cost on a
phone — the user must find the way back — so settle the `return_url` early: a deep link into the
app puts the user where they started; a web page leaves them to find their way home. The hosted
page typically does *not* redirect there by itself; its success page has a "back to the website"
button carrying that URL.

Why a widget rather than a redirect, when the product allows: a redirect takes the user out, its
"cancel" dead-ends on a page you do not own, and the app cannot observe the outcome cleanly. An
embedded widget keeps the user in-app and emits a `complete` event.

## The outcome always comes from the server

Whatever the client sees — a widget `complete` event, a message from the stand-in page, a return
page — is **a cue to look sooner, never the answer.** The balance moves when the provider notifies
the server and the server records it. Client flow:

1. **init** with the amount (the provider needs it before the widget; fixed at init). The server
   calls the provider (credentials, an idempotency key, amount, capture mode, `metadata` carrying
   your top-up and user ids), stores the returned payment id, hands the client the confirmation
   data.
2. The client presents the form. Only **after** the widget's completion event does it start polling
   the status endpoint — it does not poll from mount.
3. **Settlement is server-side and idempotent, from two sources:**
   - **Webhook** — the provider POSTs a succeeded / canceled event; the handler finds
     the top-up by provider payment id and settles (credit + transaction row) or marks it failed.
     The fast path on staging/prod.
   - **Reconciliation on read** — while the session is pending, each status read also asks the
     provider for the payment and settles on the first `succeeded`. This is the **working path in
     development**, where the provider cannot reach a laptop.
   Both paths go through the **same idempotent settle function**. A payment completed while nobody
   is looking at that account then settles the moment someone looks — know that when debugging "the
   balance is late".

## Rules the mock has to follow to be a useful stand-in

- **Throttle outbound calls per session** (one per ~2 s, the timestamp stamped *before* the call).
  Without it, a session whose create failed retries on every read, and a few of those turn each
  state read into a burst the provider answers with timeouts.
- **Provider calls time out intermittently from some networks (corporate, geo-restricted).** Do
  not paper over it with a long timeout: a failed create leaves the session in `created` and the
  next read tries again — which is why that retry exists rather than a single attempt with an
  error state.
- **A webhook handler ignores payments it does not know**, so several environments (or two API
  generations) can register URLs at the same provider at once: it notifies every configured URL.
- **The return URL is configured, not derived.** A server behind a reverse proxy that strips a path
  prefix (`/api`) builds URLs from the request without the prefix, and they land on the SPA. Tell the
  container its public prefix (a base-path variable) or configure the absolute URL per environment.

## Provider-side setup is invisible from the repo

Put these in the environment checklist; each failure presents as "the widget does not render":

- enable the embedded scenario on the shop (else create-payment with that type fails);
- add the app's domains to the widget's allowed origins, per environment;
- register the webhook URL per environment, mindful of path prefixes;
- the native shell's navigation allow-list must contain the widget script host and sub-frame hosts,
  or WKWebView refuses them on-device only.

Use the provider's **free sandbox** (test shop, test secret key, test cards; specific numbers force
failures such as insufficient funds or failed 3-D Secure) for dev. No real money moves; keep the
test credentials in the gitignored root `.env`.

## Security notes

- The secret key is **server-side only**; never in a client bundle or a build-time env copy.
- The webhook endpoint trusts its caller unless you restrict it. In production restrict it to the
  provider's source IPs at the proxy and/or verify a signature; do not rely on `metadata` alone.
- Fiscal/tax receipts: a first version sends none. A production merchant in a jurisdiction that
  requires them must add a receipt object — record the gap.
- Full-page 3-D Secure return: a bank forcing a top-level redirect re-mounts the page and loses
  router state (the token). Webhook settlement still works; the in-app widget cannot re-render.
  Harden by persisting or re-fetching the token on return.

## Known-gaps register

Keep, next to the integration, a short list of what is deliberately unfinished (framing, receipts,
webhook auth, prefix issue, cancel endpoint, how a client learns the outcome of a finished session
when the API has no read endpoint — inferred today from a ledger row). It saves the next reader
from rediscovering each as a bug.
