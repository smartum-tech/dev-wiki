---
title: Reference artifacts — index
class: reference
origin: index page authored for this wiki; the artifacts it points to are external, this page is not.
---

# Reference artifacts

Everything in this directory is an **external artifact, copied verbatim** — a vendor's
documentation, a national standard, or a legal instrument. Nobody on this project may edit the
bodies of these files, including to translate, summarise, or "clean up" formatting
(`../CONTRIBUTING.md` §1). If a file here is wrong or stale, the fix is a fresh copy from the
source, not an edit to this copy. Commentary and our own interpretation belong in `guides/` or
`modules/`, as separate pages that link here.

Every artifact keeps the language of its source.

**This page is reading guidance, which is why it is a `README.md`.** For each artifact it says
what it is authoritative for, roughly how large it is, and whether to read it whole or grep it.
Add the row in the same commit that adds the file: an artifact with no row here is an orphan.

<!-- One section per source (a vendor product, a standards body, legal). Per artifact:

## <Vendor> — <product>

- **`<vendor>-<product>-api.md`** (~NN KB) — what it is. Authoritative for <which questions>.
  Read whole for orientation / **grep for a specific method or field** — say which, and why.
-->

## Anything too large to open

<!-- If an artifact is too large to read at all (a full OpenAPI spec, a regulation), give it its
     own entry here:

- **`<file>`** (~NN MB) — what it is, and what it settles when the prose pages disagree with
  it. **Never read this file whole** — no tool call, no sub-agent prompt, no "let me just skim
  it". Always grep for the specific path, schema name, or identifier you need, and read only
  the matched region.

  Bring a file this size into the repository by `git mv`, never by copy: a copy doubles it in
  the repository's history for ever.

Delete this section if nothing qualifies. -->

## General rule for this folder

Small files (overview docs, a short standard) are cheap to read whole for orientation. Anything
shaped like a reference table or an enumerated list — an API reference, a list of prohibited
categories, a legal offer, and above all a machine-readable spec — is meant to be **grepped for
the specific term you need**, not read start to finish.
