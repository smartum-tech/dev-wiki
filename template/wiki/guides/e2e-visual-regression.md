---
title: E2E Visual Regression (Screenshots)
class: compiled
covers: []   # fill when adopting: playwright config (snapshot settings), the screenshot stylesheet, the snapshot helper
last-verified: never
verified-by: boilerplate
sources: []
---

# E2E Visual Regression (Screenshots)

Split off [e2e-testing.md](./e2e-testing.md), which owns the suite and how it is run; rules for the
test around the screenshot are in [e2e-writing.md](./e2e-writing.md). This page is
`toHaveScreenshot()` alone — everything about keeping a baseline stable.

Screenshot comparisons are folded into the ordinary functional scenarios, **not** a separate suite,
specifically to avoid clicking through every screen twice. A new UI state ships with its screenshot;
it is not optional for new specs. Global config sets a small `maxDiffPixels` (font anti-aliasing
slack) and a `stylePath` stylesheet that hides scrollbars; individual calls may add a diff ratio on
top.

## One platform produces the baselines

Fonts render differently on macOS and Linux, so **a baseline is only as stable as the platform that
shot it**. Pick one and say so:

- **Container only** (recommended when CI runs the suite in a container): snapshots are compared and
  recorded only where a visual-enable env flag is set (the runner container), carry no platform
  suffix, and are one committed set, reviewed in the HTML report's diff. Developer machines run the
  functional logic and skip comparison.
- **Developer-machine baselines**: every snapshot carries a platform suffix, there are none for the
  CI platform, and they are regenerated locally. Any advice built on a different platform premise is
  stale.

Either way, give functional iteration a switch that skips the comparison. A snapshot helper can be a
**soft** assertion — a changed pixel is reported and the scenario still checks its logic.

**Baselines are one viewport per project** (the mobile viewport, plus the desktop one). Small-screen
sweeps that re-run the mobile suite at smaller viewports must ignore snapshots: shooting two more
baseline sets triples the re-shoot cost of every UI change to catch what the sweep already catches
better as *reachability* failures (an element that cannot be scrolled to). So **a small-screen run
proves nothing about appearance**, and a layout regression visible only at that width is invisible to
this suite in both directions — caught by eye or not at all.

Update baselines with a scripted update command (whole suite, or scoped to a file/test/project);
record a new baseline with a "missing only" mode so existing ones are not rewritten.

## Five tools, and each one fails where the next begins

**1. Mask every generated value, or the comparison flakes on reseed.** Anything that changes across
runs — row UUIDs, invite links and QR codes, live-updating realtime panels, countdowns, version
strings — needs a `mask` locator array. Related, non-obvious: a paginated/sorted table needs a
**deterministic secondary sort key**. Ordering by one non-unique column lets the database return
ties in either order across requests, which shows up as an intermittent screenshot diff, not a query
bug. Add a tie-breaking order on a unique column to any list a screenshot covers.

**2. Mask the whole row, not the value span.** A date's rendered width changes day to day ("5 August"
versus "19 Aug"), so a mask box hugging the text is itself a diff between runs. The same applies
to anything whose *geometry* is time-derived: a progress bar drawn as shares of a remaining term
moves a sub-pixel for every second between fabrication and the shot, nothing on its own and
everything against a whole-page budget of a few dozen pixels. Mask it and pin what it says with locator
assertions instead.

**3. A mask cannot hide a HEIGHT change, so text whose width grows with the database has to be
normalised in the DOM before the shot.** A rendered number gains a digit as the table fills, a
subject that fitted on one line wraps to two, and everything below shifts — the mask sits inside the
row it cannot save. Overwrite the element's `textContent` with a fixed value of the longest plausible
width immediately before the shot, so the baseline stops depending on how many rows the database has
ever seen.

**4. For an inline date, masking is the wrong tool — freeze the element.** Where the date sits inside
a card there is no row to mask, and the mask inherits the text's varying width, so the comparison
fails on the mask's own edge on days the date renders shorter than in the baseline. A per-suite
stylesheet that gives every `<time>` a fixed invisible box (`visibility: hidden; display:
inline-block; width: …`) makes the geometry identical on every run. Two traps: the fixed width must be
a shade *under* what the longest real date measures, or a frozen box wider than the text can wrap a
row that never wraps for a user; and `stylePath` takes an **array** — pass the freeze sheet *alongside*
the base stylesheet, never instead of it, or scrollbars come back into every baseline.

**5. Hide third-party frames; clip around overlays.** A map or embed iframe is hidden by the
stylesheet, not masked, so your own controls on top of it stay in the shot. A mask is painted over
everything, modals included, and is only as wide as its text: for run-specific data behind a modal's
blurred scrim, `clip` the shot to the modal instead.

## See also

- [e2e-testing.md](./e2e-testing.md) — the suite, fixtures, config layers
- [frontend-testing.md](./frontend-testing.md) — client unit tests, which own localization coverage
  rather than screenshots
