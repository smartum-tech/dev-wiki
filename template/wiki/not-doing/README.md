# not-doing/ — things we could build and decided against

One file per **concept**: a decision not to build something, and why. **Injected core**, read on
every task like `../target/` — the cheapest place to stop a bad idea is before it is designed.

## What lands here

| A statement that… | goes to | test |
|---|---|---|
| refuses a **thing we could build** | here | would a competent agent with a fresh brief propose it again, because it is the obvious answer? |
| constrains the **shape of the code** | `../target/`, proposed via `specs/drafts/` | it is a rule about how code is written, not about what exists |
| postpones something we intend to build | `specs/drafts/<feature>.md` | it has a "later", so it is a deferral |

**When a refusal and a rule about code shape are one statement, the rule owns it** — on a
`../target/` page, or on the curated page that already states it. The entry here stays, short,
and points at that page instead of repeating the reason. Both are in the injected core, so the
pointer costs the reader nothing.

**Failing the re-proposal test means leave it where it is** — an *alternatives considered* block
in a feature's research notes stays in that file. The bar is high on purpose: the overwhelming
majority of such records fail the test and stay where they are. And **never record something
already implemented**: it poisons the dedup check with a false rejection, telling the next
session we refused a thing we shipped.

## The shape of an entry

Skeleton: [`TEMPLATE.md`](./TEMPLATE.md).

Kebab-case filename, recognizable from the listing without opening it (`no-<thing>.md` reads
well). Then the decision in prose, `## Why this is out of scope`, and `## Prior requests` — where
it was decided, verified against the tree and cited by something that survives the next edit to
the file it points at: a filename, a symbol, a commit SHA, a PR number, a dated ruling, or a
quoted line the reader can grep. **Never `file:line`**: a rotted range still resolves, onto code
that has nothing to do with the claim, so it reads as corroboration and the next author believes
it. The reason must be **substantive** — not "we don't want this" but why — and **durable**: a
temporary circumstance ("we're too busy right now") is a deferral, not a rejection. Where the
refusal has a natural revisit trigger ("if X becomes a sold feature"), name it.

**15–25 lines, 40 at the outside.** The directory is core-loaded and it grows; an entry needing
more room is a sign the refusal is really a `../target/` rule or a deferral. Say nothing the
rest of the core already says.

## Using it

Match a proposal **by concept, not by keyword** — "night theme" matches `no-dark-mode.md`.
Surface a match rather than blocking silently: *we rejected this before because [reason]. Do you
still feel the same way?* **Confirm** → append to `## Prior requests`. **Reconsider** → delete
the entry. **Disagree** → related but distinct; record that, the decision stands.

A human decides and an agent takes dictation, exactly as for `../target/`; a machine that wants
a rejection recorded proposes it in `specs/drafts/`, never here (`../CONTRIBUTING.md` §5b).
