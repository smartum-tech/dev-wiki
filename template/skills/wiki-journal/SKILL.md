---
name: wiki-journal
context: fork
disable-model-invocation: false
description: >
  Write up a session you were part of as wiki/journal/ entries — the incident, what was tried and
  rejected, what an external system actually does. Not a diff summary: most sessions produce no
  entry, and saying so is a correct outcome. Use when: "journal this", "write this up", at the
  end of an incident or a pairing session, a day or two later when writing it up properly, or
  when a diagnosis surfaced a root cause the diff cannot show.
---

# Wiki Journal Skill

You turn **a session you were part of** into the raw layer of the wiki. Read
`wiki/journal/CONTRIBUTING.md` and `wiki/journal/TEMPLATE.md` — they are the contract; this skill
is how you apply it to a live session.

## Settings

Read `wiki/dev-wiki.yml` first. This skill is copied byte-identical into several agent
directories, so every project-specific value comes from that file. The one this skill uses is the
code-query tool (`project.code-query-tool`) — `<code-query-tool>` below. If it is `~`, read it as
"reading and grepping the code"; nothing here needs a branch name, so no unset key stops this
skill.

## What authorizes you to write here

**Having been there.** That is the entire provenance rule for this folder, and it is the one
thing you cannot fake.

So, before anything else: **were you actually present for the work?** If you are reading this in
a fresh session and your knowledge of the event comes from `git log`, a PR body, or the user's
one-line description of something you did not participate in — **stop and say so.** Offer to help
the human write it, from what they remember, with them supplying the facts. Do not reconstruct.
An entry assembled from a diff contains only what the diff already says, which is precisely the
material this folder exists to hold *instead of*.

The one exception is a human dictating the event to you. Then they were there, you are the scribe,
and that is normal and correct. Say in the entry that it was dictated.

## Step 1: Decide whether there is an entry at all

**The threshold is: not derivable from the diff.** It is strict, and most sessions do not clear
it. A session that implemented a feature cleanly, however long it took, produces **no entry** —
what it did is in the diff, what shipped is in `change-log.md`, and an entry would be a second
change-log. Saying "nothing here clears the bar" is a successful run, not a failed one.

What clears it — set `type:` from the values `TEMPLATE.md` defines:

- **an investigation** — an incident: the symptom, what it actually turned out to be, what the
  external system really does under that condition, and what we now have to do differently. This
  is the main reason the folder exists.
- **a finding** — something durable learned while building: an approach tried and rejected and
  *why*, a vendor constraint discovered the hard way, a non-obvious invariant, a measurement that
  disproved something everyone believed.

Ask it concretely: *six months from now, with the code in front of them and `<code-query-tool>`
answering questions about it, what would somebody still not know?* That is the entry. Everything
else is already recorded somewhere better.

**One event, one file.** A session that fought an incident *and* separately discovered a vendor
quirk is two entries, not one with two headings — they will be cited, superseded and threaded
independently. Splitting is cheap now and impossible later.

## Step 2: Check for a thread

```bash
ls wiki/journal/
grep -rl '<symptom keyword>' wiki/journal/
```

Done when you have grepped for the symptom, the error string and the component name, and can say
which earlier entries, if any, this one continues.

A recurrence is **not** an edit to the earlier entry and **not** a supersession. It is a new dated
entry that cites its predecessors and says what is *new* — usually a different failure mode of the
same symptom. That thread is the highest-value structure in the folder and nothing else can hold
it: the fourth entry in a family is often the one that finally explains the first three.

If this is a recurrence, open with the blockquote form in `TEMPLATE.md`.

## Step 3: Write the entry

`wiki/journal/YYYY-MM-DD-<slug>.md`, from `TEMPLATE.md`. The date is **when the event happened**,
not when you are writing; `journaled:` carries today. Writing it up a day or two later is normal.

```bash
date +%F                                    # journaled:
git show -s --format=%cs <sha>              # date: — when it actually happened
```

Fill `commits:` / `pr:` with the realized change if there was one. **Both may be empty.** An
incident whose fix was a one-line hotfix, or which was resolved by restarting something, still
belongs here — in a family of recurring incidents, the entry that touched no application code at
all is often the one that explains the family.

Two things about how to write:

- **Write long.** Entries are never pushed into an agent's prompt, so the page budget does not
  apply. Under-recording is the failure mode. The detail you are about to leave out because it
  feels obvious right now is exactly what nobody can reconstruct later — the exact error string,
  the value you saw, the thing you assumed at 2am that turned out to be wrong.
- **Record the wrong turns.** What you believed at the start and why it was wrong is knowledge;
  a clean narrative that goes straight to the answer throws away the most expensive part of the
  session. If a hypothesis was disproved by measurement, say what was measured and what it showed.

`Findings` is the section that matters. `Context` and `What we actually did` orient a reader;
`Findings` is what `/wiki-ingest` mines into `modules/` gotchas and `target/` candidates.

English when you are writing it. A human's own words quoted verbatim keep their language.

## Step 4: Wiki impact — mandatory

End every entry with the unchecked checklist from `TEMPLATE.md`. This is not bookkeeping:

- an entry with no `- [ ]` items is invisible to `/wiki-lint`'s pending check and will never be
  picked up, so the knowledge lands nowhere and sits in an inbox forever;
- naming the target pages is you doing the routing while you still remember why, instead of
  leaving a later ingest to guess.

Be specific — `modules/payments.md — a refund cannot be re-issued once the payment is settled`
beats `update payments`.

## Step 5: Report

Say which entries you wrote and why each cleared the threshold; which candidates you considered
and **rejected**, with the reason (this is the most useful half for a human who was in the same
session and may disagree); and any thread you attached to.

If you wrote nothing, say that plainly and say what you considered.

## Rules

1. **Only `wiki/journal/`.** Never a compiled page, never `target/`, never `change-log.md`.
   `/wiki-ingest` is what carries this into the encyclopedia, on its own schedule, and it will
   read what you wrote.
2. **Append-only.** Never rewrite an existing entry (typos aside). New facts are a new entry
   citing the old one by filename. The folder's value is that it is a record, not a current view.
3. **Do not summarise the feature.** If you find yourself writing what the diff did, stop — that
   is the failure this folder is one bad month away from.
4. **Do not tick your own Wiki-impact boxes.** They are ingest's queue, and an entry that arrives
   pre-ticked is one nobody will process.
5. **Do not invent participation.** See the top of this page. The honest refusal is worth more
   than the entry.
