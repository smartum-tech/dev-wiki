---
title: Security checklist — RLS policies (example)
class: compiled
covers: []                 # fill when adopting: the migrations folder
last-verified: never
verified-by: boilerplate
sources: []
---

# Security checklist — RLS policies

> **Example — adapt to your backend.** Postgres row-level security with client roles reaching the
> database through a REST/RPC layer. Policy semantics are Postgres facts and carry over to any use of
> RLS; role names (`anon`, `authenticated`, `service_role`) are the platform's.

Read before writing or changing an RLS policy. A policy without the matching **grant** is inert, and
the grant is the layer that fails closed — [`security-grants-checklist.md`](./security-grants-checklist.md).
Definer functions are [`security-database-checklist.md`](./security-database-checklist.md); guards and
sessions are [`security-app-checklist.md`](./security-app-checklist.md).

**Risk:** a missing or wrong policy exposes another tenant's or another user's rows.

```sql
-- Tables without RLS enabled
SELECT schemaname, tablename FROM pg_tables
WHERE schemaname = 'public' AND tablename NOT IN (
  SELECT tablename FROM pg_tables t JOIN pg_class c ON c.relname = t.tablename
  WHERE c.relrowsecurity = true);
-- All policies, for manual review
SELECT schemaname, tablename, policyname, cmd, qual, with_check
FROM pg_policies WHERE schemaname = 'public' ORDER BY tablename, policyname;
```

**The privileged role bypasses RLS.** If a suite isolates its test rows with an RLS clause, that clause
has a hole shaped like the backend's privileged role: it bypasses RLS on reads and its INSERTs carry no
marker unless the caller forwards one. Read the test-isolation guidance before adding the clause.

## `USING` and `WITH CHECK` are different questions

`USING` chooses which rows an UPDATE may **touch**; `WITH CHECK` decides what a row is allowed to
**become**. `WITH CHECK (true)` therefore reads as "…and then set it to anything." Copied from one
template into several policies, it is a live escalation: a plain `PATCH` on one's own row with the
public key and one's own bearer token can rewrite `role` (which an `is_admin()` helper reads, gating
policies everywhere) or stored balances. Three things the fix has to account for that a policy
listing does not show:

- **Tightening one of two permissive policies on the same table is a no-op.** Postgres ORs permissive
  policies on `WITH CHECK` as well as `USING`; the admin policy's `true` would have kept blessing every
  row reached through the user policy. Fix them all. The forward-looking half: the *next* policy ORs in
  beside yours, so an exclusion yours achieves only as a **side effect** (a join that happens to
  dereference NULL on the other ownership kind) is one its author cannot copy or grep for. Where a table
  holds rows of more than one ownership kind, say in every arm which kind it admits.
- **A policy cannot reference `OLD`.** "This column is unchanged", or any rule about the pair
  `(OLD, NEW)`, is inexpressible: `USING` sees only the old row, `WITH CHECK` only the new. Two escapes:
  a `BEFORE UPDATE` trigger, or gating `USING` on a **server-owned column of another table**, reached
  through a definer helper.
- **Close the sibling verb in the same migration — the grant as well as the policy.** Constraining
  `status` on UPDATE alone left the same bypass fully reachable by INSERTing a row **born** in the
  target status. `REVOKE UPDATE` + `GRANT UPDATE (…)` binds one verb too: INSERT keeps its table-level
  grant and every column with it.

A mirror of `USING` into `WITH CHECK` is the *minimum* correction, not a security layer: it stops a
user moving a row out of their own scope, not rewriting any column inside it.

## A storage policy whose object belongs to a relationship, not to a person

Object policies often key on a path segment holding the **uploader's** user id. A file attached to a
*relationship* (an order, a shared document) is not owned by one person: several parties and an
administrator must read it. That policy joins the relationship table on the leading path segment, and
the path (`<relationshipId>/<itemId>/<fileId>.<ext>`) is chosen to make the join possible — the id all
readers reach through leads. Do not copy the shape to a bucket whose objects have one owner.

- ⚠️ **Compare `rel.id::text` against the segment; never cast the segment to `uuid`.** A policy on the
  objects table is evaluated for rows in **every** bucket, and the `bucket_id` term sits in the same
  `AND` expression rather than in front of it, so the planner may order the two either way. The day
  somebody creates a bucket not filed under a UUID folder, the cast raises `22P02` and takes down every
  storage read for every user, in a policy nobody edited. The text comparison makes the subquery a scan;
  fine here, since the storage API narrows by bucket and name first — if it bites, add a functional
  index, not a cast.
- **Omitting INSERT/UPDATE/DELETE policies expresses write-once.** RLS with no policy for a command is
  deny-all for every role without `BYPASSRLS`, and the privileged role bypasses it — so a bucket the
  backend writes and nobody else touches needs *no* write policy, and there is no client-write hole to
  close because none was opened.

## An isolation test with no positive control proves nothing

A suite of refusals — a foreign tenant cannot read it, an anonymous session cannot, a signed URL is
required — is satisfied **unconditionally** by a policy that admits nobody. The trivial implementation
passes, so the stronger the suite the more confidently it certifies a broken bucket. **Every isolation assertion set needs at least one positive control, named as such: the owner
CAN read their own object.** The same shape applies to grants, guards and any authorization test written
as refusals.

- ⚠️ **Inside a policy subquery, an unqualified `name` binds to the joined table.** A bucket policy that
  wrote `(storage.foldername(name))[1]` inside `EXISTS (SELECT 1 FROM tenants t …)` resolved `name` to
  `t.name` — a tenant's UUID compared with the first path segment of its own display name — and admits
  nobody. A copied precedent can be right only by luck (its table had no `name` column). Check the
  joined table for the column before copying, and qualify (`objects.name`) regardless.
- **`pg_policies.qual` is the artifact of record.** The text you wrote and the expression Postgres
  stored are different things, and only the second is evidence. A migration creating a policy should
  re-read its own stored `qual` in the same transaction and refuse if it does not say what was meant.

## A policy cannot reference its own table, and the workaround is load-bearing

An `EXISTS (SELECT … FROM t …)` inside a policy **on** `t` aborts with `42P17 infinite recursion
detected in policy`. It bites late: a table can carry self-referencing INSERT/UPDATE/DELETE policies for
years, because their subquery re-enters the table through the **SELECT** policy — they work only while
that one predicate does not self-reference. Rewriting the SELECT policy to check membership inline then
breaks all of them at once, from statements nobody edited.

The escape is a `SECURITY DEFINER` helper owned by the DB owner, which reads the table as its owner and
never re-enters RLS. Two properties are not optional. **Grant EXECUTE to the client roles** — a policy
expression is evaluated *as the querying role*, so an ungranted helper turns every SELECT into
`permission denied for function`, and `REVOKE … FROM PUBLIC` alone does not undo the platform's per-role
grants. **Key it off `auth.uid()`** — a helper taking a row's owning id and returning a boolean is an
oracle unless the caller's identity is in the predicate. Keep the cheap own-row arm
(`user_id = auth.uid()`) in front of the call.

## A token claim is not a membership, and the difference is a token lifetime

`tenant_id = <claim from the token>` grants access for as long as the token lives, not for as long as
the relationship does. Policies written that way let a removed member keep reading their former tenant's
data until the token turns over, because the removal soft-deletes the row and clears no token. **Prefer a live `EXISTS (… FROM memberships …)` to any claim baked into the JWT**; that the
claim is signed attests who issued it, never that what it says is still true. Converting one **widens
the visibility set** (from "the claimed tenant" to "every tenant the caller is a live member of") — a
correction, but a behaviour change: check what the clients filter by first. Retiring the helper the
claim came from is a separate decision from retiring its uses.

## A `WITH CHECK` binds the client, not the server

RLS does not apply to the privileged role, so a birth constraint like `status = 'draft'` constrains what
a *client session* may insert and says nothing about the backend's own writer. Do not read such a policy
as a statement about the column's legal values. ⚠ **The trap is the day that writer moves onto a user
token** — every branch the policy does not admit starts failing `42501`, in code that did not change.
When you add a birth constraint, name in its own comment which server writer it does not bind.

**Checklist**
- [ ] All tables holding user/tenant data have RLS enabled
- [ ] No UPDATE or INSERT policy uses `WITH CHECK (true)`; each states what the row may *become*
- [ ] Where a table carries more than one permissive policy for a command, all are tightened
- [ ] On a table with rows of more than one ownership kind, each arm names the kind it admits
- [ ] A `status`-style constraint on UPDATE is added to INSERT in the same migration; column
      REVOKE/GRANT is checked against what INSERT still grants
- [ ] No policy trusts a tenant id read out of the JWT where a live membership could be checked
- [ ] No policy expression selects from its own table (`42P17`); where it must, it goes through an
      `auth.uid()`-keyed definer helper the client roles hold EXECUTE on
- [ ] A birth constraint's comment names the server writer it does not bind
- [ ] Every isolation assertion set carries a named **positive control**
- [ ] A new policy's stored `pg_policies.qual` was read back and says what was meant
- [ ] No `USING (true)` without a written justification
- [ ] Any new privileged-role endpoint that **reads and displays** RLS-gated data is checked for the
      test-data leak; prefer the RLS client for reads
