# Stage 3: interview

This file belongs to the `wiki-bootstrap` skill. [`SKILL.md`](./SKILL.md) routes here for
stage 3, or for `interview <guide>` to redo a single guide.

Every shipped guide holds **defaults**: rules that worked in other projects, each with its reason.
The interview turns each into one of four things:

- this team's rule, kept;
- this team's rule, edited to fit;
- a rule dropped;
- a question left open on purpose.

The agent is the scribe, and the decision is the human's (`wiki/CONTRIBUTING.md` §1, curated).

## 1. The three sources, strongest first

For every decision, put these in front of the human, in this order:

1. **What this repository already does.** Run the bank's *Detect* commands and say what they
   found, in the form "your code does X in N of M places". A practice the team already follows
   is the best default there is: it is their reality, and the code proves it. When the evidence
   is unanimous, propose writing it down as the rule. When it is split, show the split. That is
   usually the most useful thing the interview can surface.
2. **The shipped default**: the page's current rule and its reason, word for word from the page.
   The reason matters more than the rule. A shipped rule exists because something went wrong
   without it, and the human should judge the reason, not the phrasing.
3. **What others do, only on request** (§5). It is never the opening offer. General "best
   practices" do not know this team, this stack or this product. Most of what they would add is
   noise in a page that has a token budget.

## 2. Order and pacing

- **Order:**
  1. guides recon marked *unsure*: settle keep or prune first;
  2. `guides/ai-*.md`, because they shape every agent's behaviour from the next task on;
  3. `coding-standards.md`;
  4. the testing group;
  5. the rest, in `wiki/index.md` order.

  Skip pruned pages. A human may name a guide to jump to (`interview <guide>`).
- **One guide is one sitting.** Open it with a three-line card:
  - what the guide is for;
  - what Detect found;
  - how many decisions it has.

  Then take the decisions **one per message**. Each message has the question, the evidence, the
  default with its reason, and the common alternatives as numbered options. Add a last option:
  "decide later".
- **Offer a fast path.** When Detect agrees with every default, offer "accept all N as written"
  before going through them one by one. On a pure checklist page (security), ask which sections
  apply, then only the bank's policy questions.
- **Accept answers in any form.** A number, a sentence, "like we do in X", or an argument back
  all count. When an answer is an argument, engage with it. The human may be right that the
  default does not fit, and that is the point of asking.
- **The human can stop at any moment.** Save state after every guide, and also mid-guide when
  they stop. Note which decisions in that guide are done.

## 3. Recording an answer

| Answer | What lands |
|---|---|
| keep the default | Nothing changes in the text. The rule is now the team's |
| keep, and the code agrees | Same, plus a `covers:` entry for the paths Detect looked at, if the page has none |
| edit | Rewrite the rule on the page in the team's terms: English, imperative, with a reason. If the human gave none, ask once: "why — so the next person doesn't undo it?". Show the final wording before saving |
| drop | Delete the rule and any example that exists only to support it. If the human says "we decided against this on purpose", offer a `not-doing/` entry (§4) |
| different from the code | When the human's rule contradicts what Detect found, the rule still lands. Also offer a `target/` entry (§4), because the code is now out of line with an intention |
| decide later | Nothing changes on the page. Add a line to `## Open` in `state.md`: guide, question, who could answer. Mark the guide `deferred` if nothing else in it is left |

Rules that hold for every row:

- **Edit the page in place**, in the section the bank's *Lands in* names. Keep the page's
  structure and voice. A page is never rewritten whole. Stay within its budget: an edit that
  grows a page past ~3k tokens has to cut something, and you ask what.
- **Placeholders in the banks** (`{{FRONTEND_DIR}}` and the like) mean the value recorded under
  `placeholders:` in `wiki/dev-wiki.yml`. Substitute before running a command, and confirm the
  path exists. A bank command for a directory the project does not have is skipped, not
  improvised.
- **When the guide is finished**, set `last-reviewed:` to today in its frontmatter. Leave
  `last-verified:`/`verified-at:` alone: they say when the *code* was checked, which is
  compile's business, or yours only if every claim on the page was checked against the code in
  this sitting (compile §4 rule 6).
- **Update `state.md`**: the guide's row, and a one-line *Changed* summary such as
  "2 edited, 1 dropped". Then update `wiki/index.md` if the guide's purpose changed.
- **Pages that carry a verbatim section** `## Project house rules — verbatim from …` from
  `run`: here the human finally reconciles the two rule sets. For every overlap the bootstrap
  report listed, ask which wording wins, merge, and delete the verbatim section once it is empty.

## 4. When an answer is a `target/` or `not-doing/` entry

Only an explicit human statement creates one. Write it from the folder's `TEMPLATE.md`, with
the reason in the human's words, translated to English. Show the entry before saving. Apply the
admission test in `wiki/not-doing/README.md` and in `wiki/CONTRIBUTING.md` §5:

- **`not-doing/`**: something deliberately refused, which an agent would otherwise propose,
  with a reason.
- **`target/`**: a rule the code currently violates, where the team has decided to move the code
  towards the rule. It needs a *where the code disagrees* paragraph with the Detect evidence.

An item that fails the test stays a sentence on the guide.

## 5. Looking outward, on request

Offer it once, at the start of the interview. Repeat the offer only on a guide whose bank has a
*Web, on request* line and where the human seems unsure. Say plainly what it is: "I can search
for known problems in the versions you use, and for topics teams usually settle here. Results
come with links, and nothing goes into the wiki unless you accept it."

Rules:

- **Look up specifics, not generalities.**
  - Search for the detected tools at their detected versions (from the lockfile): release
    notes, migration guides, and known issues in their trackers.
  - Search for the bank's suggested topics.
  - Do not search for "best practices for X". The answers are generic, and generic is what the
    shipped defaults already are.
- **Every finding carries its link**, and stays marked `(unverified)` until the human accepts it.
  A finding that cannot be traced to a page is dropped, not paraphrased from memory.
- **Findings are proposals.** Present them like the bank's decisions: one at a time, with the
  link and why it matters here. Write an accepted one onto the page, and add its URL to the
  page's `sources:` frontmatter. Leave a rejected one out.
- **Several findings are worth keeping, but not now?** Write them to
  `specs/drafts/wiki-web-findings-<guide>.md`, with links, marked as undecided.
- **No web tool in this agent?** Say so once, and carry on without it.

## 6. Ending the interview

The interview is done when no row in `state.md` is `pending`. Say how many guides were reviewed,
how many rules changed, and what is still deferred. Then propose `finish`.
