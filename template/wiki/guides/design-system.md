---
title: Design system — one lib shared by web and mobile
class: compiled
covers: []                 # fill when adopting: {{UI_LIB_DIR}}/src (styles/, components/, web/, icons/)
last-verified: never
verified-by: boilerplate
sources: []
---

# Design system — one lib shared by web and mobile

The design system lives in one workspace lib (`{{UI_LIB_DIR}}`, imported as `{{UI_LIB_IMPORT}}`). Any reusable
visual primitive — button, card, tag, list row, icon, bottom navigation — belongs there, **not** in
`{{MOBILE_DIR}}/src/components/` or `{{FRONTEND_DIR}}/src/components/`. Both apps consume it. The
goal is to stop the same visual pattern from being copied across features and drifting: if a second
screen needs the same card, it pulls it from the lib.

Class names below use an illustrative prefix `ds-` (`ds-btn`, `ds-card`); use your own.

## Core rule

**Reusable → the lib. Page-specific → the app.** When in doubt, put it in the lib: an "extra"
component sitting there costs nothing, while a duplicate in an app is two places to change and a
"the button looks different on this page" bug. Because of that bias, the lib needs a way to keep
domain logic out — the decision test below.

## Decision test: where does the component go

Before creating the file, answer three questions:

1. Does the visual pattern repeat in the design prototypes more than once? (card, button, list row,
   chip, status badge)
2. Is it free of data, routing and store dependencies? (no `useNavigate`, no query hook, no business
   logic)
3. Can its API be described through props without knowing the domain? (`title`, `price`, `tags` —
   not `vehicle: Vehicle`)

**All three yes → the lib. Any no → the app.** A fourth consequence: the lib never imports the
router, the query library, the i18n library, or the shared domain types. Localised strings arrive as
props (`label`, `children`), not as `t('key')` — so the system survives API refactors and
translation changes.

**What stays in the apps:** pages, query hooks, *connected* wrappers (a `<ProductCard>` takes
`name`/`price`/`tags` in the lib; a `<ProductCardWithFavorite>` that calls `useToggleFavorite` is
the app's), anything tied to the router/store/i18n keys, view-models mapping API → props, locales.
The split to reach for is **container + presentational**: the lib owns the presentational half, the
app owns a thin connected component that picks a domain helper and passes primitives down.

Signs a component is in the wrong place:

- *Should move into the lib:* two pages import it; similar markup with the same classes shows up in
  two places; a design-system class is defined only in an app stylesheet or an inline `<style>`; its
  props are all primitives.
- *Should move out of the lib:* it imports the router/query/i18n library; it takes domain types as
  props; it uses translation keys.

## Layout of the lib

```
{{UI_LIB_DIR}}/src/
├── styles/
│   ├── tokens.css        CSS variables --ds-* (colours, radii, shadows, spacing)
│   ├── base.css          fonts, focus/tap resets
│   ├── components.css    BARREL: @import './components/*.css' in cascade order
│   ├── components/       one file per section (buttons.css, bottom-sheet.css, …)
│   ├── utilities.css     text, stack, icon-size, sr-only helpers
│   ├── index.css         entry for mobile
│   ├── index.web.css     entry for web — the same layers plus web/
│   └── web/              WEB-ONLY layer (below)
├── components/           React wrappers around ds-* classes (SHARED), index.ts re-exports
├── web/                  React wrappers for web-only surfaces, imported as '{{UI_LIB_IMPORT}}/web'
└── icons/index.tsx       outline icons, one file, named exports (tree-shaking)
```

Each app pulls its entry stylesheet once in its own `src/index.css`. **The two entries differ only by
the web-only last layer; everything before it is the same file**, so a fix in the shared layers
lands on both surfaces. React imports split the same way: `{{UI_LIB_IMPORT}}` (shared, both apps)
and `{{UI_LIB_IMPORT}}/web` (web only). The root export never re-exports the web folder — the mobile app must
never pull desktop chrome.

## How to add a component

1. **CSS class first.** Add `.ds-<name>` to the matching file under `styles/components/` (or a new
   file and its `@import` in the barrel — import order is the cascade order). Use tokens only; no
   hardcoded `#3366FF` / `12px`.
2. **New token?** Add it to `tokens.css`, not to a component file. One token per semantic meaning,
   not per usage site.
3. **React wrapper**, thin, no hooks, no effects, no store access, no `console.log`. Props extend the
   HTML attributes (`Omit<…, 'title'>` on a clash). `className` is always merged through a `cn()`
   helper so the consumer can append utilities.
4. **Re-export** from the components index. **Icons** go in the one icons file with the same
   defaults (`stroke=currentColor`, a shared `strokeWidth`, `width/height='1em'`).
5. **Type-check both apps** if you touched anything outside the web-only folders.
6. **Record the change** in the project's change record.

Never clone an icon or component under a new name because "this one is slightly different" — fix
the original, or add a variant prop.

## Utility classes on top of the system

Utility CSS (Tailwind) may override design-system classes for one-off tweaks — `<Button className="mt-4
w-full">`. Do not rebuild an existing component from utilities (`bg-[#3366FF] text-white h-11 px-6
rounded-xl` is just `ds-btn ds-btn-primary`); if a pattern appears twice, make it a component. Note
the alpha-modifier trap with CSS-variable colours in
[`frontend-ui-patterns.md`](./frontend-ui-patterns.md).

## The web layer — one system, not two

The web app is desktop-shaped but **not a second design system.** Shared stylesheet layers
(tokens, base, components, utilities) are the exact same files both apps load; the web-only folder
holds desktop chrome: header, hero, layout wrapper, forms, drawer, modal, and the private-area shell.

- Web-only React wrappers (in the lib's `web/` folder) follow the same rules as shared ones: thin
  wrappers over classes, primitive props, `cn` merging, **no hooks, no effects, no router, no
  i18n, no domain types.** Anything stateful — scroll reveal, accordion state, a map bridge — is
  composed in the app's own components, with only its CSS class in the lib.
- **When web needs a shared class to behave differently, do not edit the shared file.** Add the
  override to the web-only tokens file, scoped under a root class the web app puts on its root
  element:

  ```css
  /* Desktop runs buttons one weight heavier: they sit next to 40px headlines. */
  .app-web .ds-btn { font-weight: 700; padding: 0 20px; white-space: nowrap; }
  ```

  That keeps every divergence in one reviewable block and makes it provable that the mobile bundle
  is unaffected. If you write more than a handful of these, the shared class is probably wrong —
  fix it for both.
- Genuinely cross-surface additions (a new button variant, an icon, a size utility) go in the
  shared files, not the web layer.
- Adding from web follows the steps above, with the CSS file under `styles/web/` (and its import in
  that folder's barrel), the wrapper under `web/`, and a type-check in **both** apps when anything
  outside the web-only folders changed.

## One canonical variant of each shell component

A component with a single sanctioned look — the bottom navigation is the standard case — exists once,
in the lib, with no "temporary" alternative in an app. A second variant is how two navigations end
up in one product. The component takes `label` as a prop; localisation stays with the consumer.

## Anti-patterns

- A copy of a lib component under an app's `components/` with the same classes.
- A design-system class defined in an app stylesheet or an inline `<style>`.
- Hardcoded colours/radii/shadows instead of tokens.
- Router, query or domain-type imports inside the lib; `t()` inside a lib component.
- Copying a shared rule into the web layer to tweak it, instead of overriding under the web root
  class or fixing the shared rule.
- Exporting web components from the root `index.ts`.
- Asking confirmations inline on web instead of in a centred modal
  ([`frontend-ui-patterns.md`](./frontend-ui-patterns.md)).
