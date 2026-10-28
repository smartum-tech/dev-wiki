---
title: Frontend UI patterns
class: compiled
covers: []                 # fill when adopting: the dialog/drawer/banner components, the back-button component
last-verified: never
verified-by: boilerplate
sources: []
---

# Frontend UI patterns

Decisions a React feature keeps re-making: which surface carries a form or a message, how feedback
reaches the user, and the handful of hand-rolled-primitive traps that pass review because they look
like design mistakes. Rules that only matter inside the Capacitor WebView are on
[`native-webview-pitfalls.md`](./native-webview-pitfalls.md); where a primitive lives is
[`design-system.md`](./design-system.md).

## Which surface: the decision rule

Chosen by what the interaction needs, not by preference:

| Need | Pattern | Why this one |
|---|---|---|
| Create/edit an entity, several fields | **Drawer** (side panel) | Keeps the list visible and in context; more room than a modal without leaving the page |
| Yes/no confirmation, single-field input, alert | **Modal** (centred dialog) | Interrupts deliberately — must be resolved before anything else; caps usable width, so wrong for anything bigger |
| Multi-step workflow, many fields, tabs | **Separate page** | A drawer that scrolls past one screen loses progress; a page carries step indicators and its own URL |
| Non-blocking feedback | **Banner / toast** | Must never block the way `alert()` does; feedback that needs no action should not demand attention |

A component outgrowing its container — a modal accumulating fields, a drawer growing sections — is
the signal to promote it (Modal → Drawer → Page), not to cram more into the smaller pattern.

**Drawer action buttons live inside the form**, immediately after the last field, not in a fixed
footer (see [`frontend-howto.md`](./frontend-howto.md)).

## Feedback: two channels, one per event

Mixing channels produces the inconsistency teams eventually clean up (a banner on one page, an
inline box on another, text under the field on a third — for the same kind of event).

**Field validation → inline, directly under the input.** Use when the user fixes the problem by
editing that input. Set `aria-invalid="true"` and `aria-describedby` to the message id; auto-clear on
the next keystroke or paste (fixing the input *is* the dismiss action). Never also fire a banner for
the same problem.

**Action result → a page-scoped banner.** Use when the user did something and the outcome lives on
the server or outside the form ("Saved", "Could not send the code"). Each page owns its banner
state through one hook and renders it through one slot component, sitting **in the content flow**
(it takes space, never overlays content). Rules that earned their place:

- Banners are page-scoped, not a global queue: a new page mount starts clean unless a banner was
  passed through router state. An app-level toast provider is one more thing to mount, and a queue
  invites stale messages.
- Cross-page handoff goes through router state (`navigate(url, { state: { banner } })`); the hook
  reads it on mount and clears the history entry so a refresh does not re-show it. Query params
  are for *inputs* to a page (a deep link), never for "I just did X".
- `navigate(-1)` cannot carry state — the delta overload takes no options. When a form must
  surface a result on the page it came from, navigate to the explicit URL.
- Opaque tints, not alpha-blended ones: translucent backgrounds let content bleed through and read
  as washed out. No auto-dismiss — the banner takes flow space, so it competes with nothing.
- Wording: past tense for results ("Saved"), no exclamation marks (colour and icon carry urgency),
  errors hint at the next step, no raw HTTP codes, short enough not to wrap at a 360 px viewport.
- Changing the look means editing the banner class in the design-system lib, never re-skinning with
  utilities at the call site.

## Confirmations: a centred modal, never inline

A question that guards an action — delete, stop, revoke — is asked in a **centred modal** over
whatever opened it (drawer, table, page). Asking inline (swapping a drawer footer for "Delete? Yes /
Cancel", turning a table row's actions into a question, "click again to confirm") makes the question
read as one more line of the form, puts it where the eye is not, and in a table row it reflows the
table under the cursor. Mechanics worth copying:

- The modal gets its **own dialog-behaviour registration**; the hook keeps a stack of open dialogs
  so Escape closes only the top layer. Toggling the drawer's behaviour off while the modal is up is
  wrong — it rewinds the drawer's scroll.
- It is its own layer (z-index above the drawer and its scrim) with its own scrim: a click inside
  never closes the drawer, the modal's scrim closes the question alone.
- Title is the question, description names the thing, footer holds the danger button (pending label
  while the command runs, both buttons disabled) and Cancel. After a refusal (409, 5xx) the modal
  closes and the error shows in the surface that asked.
- A native shell may use a bottom-sheet confirm instead; a sheet that is already a dialog needs no
  second one.

## Navigation: a back affordance pops history and never pushes

Use one shared back-button component for every header back arrow; never hand-roll
`<button onClick={() => navigate('/some-route')}>`. Its single rule — `navigate(-1)`, never a fixed
destination — makes a back-navigation loop structurally impossible, because a loop needs a "back"
that adds a *forward* entry (screen B reachable from A and C, whose back goes to A, whose forward
leads to B again).

The rule covers every return, not just the arrow: **drill-in pushes; going back to the origin pops
or replaces — never pushes.** A save or section-back that `navigate`s to the parent leaves
`[parent, edit, parent]`, and the parent's back then pops into edit. Use `{ replace: true }`, and
expect that after a save, back takes two steps (a replace swaps edit for a *second* parent entry).
One case needs a guard: React Router's `history.state.idx === 0` means a first entry (deep link,
hard reload) where `navigate(-1)` would leave the app — replace to a `fallback` route instead. If
a migration to the shared component is unfinished, convert screens rather than copying the
hand-rolled arrow.

## Layout: reserve space for fixed chrome in one place

An absolutely positioned bottom navigation takes no flex space, so any scrolling page that does not
reserve its height hides its last rows under it. Pages must not hand-roll the reserve: the shared
page layout appends the bottom padding/margin by default (a `reserveBottomNav` prop defaulting to
true, composed separately from any custom `mainClassName` so overriding the class keeps the
reserve). Standalone full-viewport routes opt out; pages outside the layout offset by the CSS
variable manually.

## Hand-rolled interactive primitives

Prefer an unstyled accessible library (Headless UI, Radix) for dialog, menu, listbox and
transition — focus trapping, ARIA and keyboard navigation are the parts that are subtly wrong
by hand. Where you must hand-roll:

**A `role="radio"` button without a roving `tabIndex` and an arrow-key handler is a radio in name
only.** Role plus `aria-checked` announces a radio to assistive tech and then leaves N independent
buttons: a keyboard user tabs through every option and the arrows do nothing — worse than plain
buttons, because the announcement promises behaviour that is not there. The fix is the WAI-ARIA
radiogroup pattern, about fifteen lines: **one** tab stop for the group (the checked option, or the
first while none is checked), arrows moving selection and focus *together*, wrapping at both ends,
both directions of an axis accepted (Up/Left, Down/Right). Selection follows focus as in a native
radio, so anything gated on the choice must react to an arrow press. Do not copy an existing
component "as the local precedent" without checking it has the handler — a copy reproduces the
defect one screen further on.

**A composite input whose partial state the parent cannot represent must hold that state itself.**
A date field emitting `''` upward until day, month and year are all set (the validators want
"empty") makes three selects derived from `value` reset each pick the moment it is made — the field
cannot be filled. Keep the partial pick in local state and re-sync from `value` only on a real
external change (prefill, reset), recognised by comparing against the last value the component
emitted itself.

**Native `<select>`**: avoid it in browser UI (renders inconsistently, cannot be restyled; use the
styled select), with one deliberate exception for touch date pickers — see the WebView page.

## Tailwind: an `/alpha` modifier on a bare CSS-variable colour is silently dropped

`ring-brand/20` does not render a 20% glow if `brand` is `var(--brand)` — it renders a **solid** pale
band. Tailwind synthesises an alpha channel only for a colour it can decompose; a bare `var()` it
cannot, so it emits the opaque colour and drops the modifier. No build warning, no lint error, and
no visual resemblance to what was written — it reads as a design mistake rather than a broken
idiom, which is why it survives review. Fix it at the token: declare colours in a decomposable
form (`rgb(var(--brand-rgb) / <alpha-value>)`), or use a stock-palette colour where the
translucency matters. If every token is a bare `var()`, no `/opacity` modifier works on any of them.

## End-to-end hooks (non-negotiable on any new interactive element)

`data-testid` on elements a test must locate; a `name` on every form input. Not style preferences.
