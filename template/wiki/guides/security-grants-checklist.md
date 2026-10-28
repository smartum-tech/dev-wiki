---
title: Security checklist — table and column write privileges (example)
class: compiled
covers: []                 # fill when adopting: the migrations folder
last-verified: never
verified-by: boilerplate
sources: []
---

# Security checklist — table and column write privileges

> **Example — adapt to your backend.** Postgres grants for client roles (`anon`, `authenticated`) on a
> platform whose default privileges hand new tables to them. The catalog facts are Postgres's; the role
> names are the platform's.

Read before letting a client role write a table, and before adding a column to a table one can already
write. The policy half is [`security-rls-checklist.md`](./security-rls-checklist.md); functions are
[`security-database-checklist.md`](./security-database-checklist.md).

**A privilege and a policy are different layers, and only one of them fails closed.** RLS decides which
rows; the grant decides which columns, and it is the layer *below* both RLS and triggers. A table with a
permissive policy and no grant is unwritable; a table with a grant and a sloppy policy is the shape every
escalation has taken.

## Taking write access away from a client role

**`information_schema.column_privileges` cannot answer "is there a column-level grant?"** It expands a
**table**-level grant into one row per column, so it reports column privileges that do not exist — and
convincingly, over a live connection; a false "this column is granted" claim can spread through code
comments from this one query. The authoritative pair is
`pg_class.relacl` (the table grant) and `pg_attribute.attacl` (real column ACLs, empty unless one was
issued). **Filter `attisdropped` out of any `attacl` scan** (a dropped column keeps its ACL entries under
a mangled name) and keep `attnum > 0`.

It follows that **on a table with a table-level UPDATE grant, every column you add is writable by a
client from the moment it exists.** Two mechanisms close that, and a writer must clear both:

1. **A column-level GRANT — the primary fix.** `REVOKE UPDATE … FROM anon, authenticated`, then grant
   back only the columns a client legitimately writes. Default-**deny**: a column added later is
   unwritable until somebody grants it, and it fails closed below RLS and below triggers. Its trap is
   enumerating the safe set wrong and bricking a real screen — establish the set by **reading the
   clients**, and keep a negative-control test green before and after.
2. **A `BEFORE UPDATE` trigger — the survival layer**, because a GRANT is exactly what gets silently
   restored: a hand-written `GRANT`, or a re-run of the bootstrap's `GRANT ALL ON ALL TABLES …`,
   re-opens layer 1 with no error and no diff. Write the body as a **diff**, not a freeze list —
   `to_jsonb(NEW) - <writable columns>` against the same subtraction on `OLD` — so it needs no
   maintenance when a column is added and cannot drift from layer 1. An enumerated freeze list goes
   stale and leaves new input columns unguarded.

Apply the pair identically each time (copy it; do not invent a third shape).

### ⚠ A table-level `REVOKE UPDATE` also deletes that role's column grants

Revoking a privilege at table level revokes the same privilege at column level with it. A blanket
"revoke UPDATE from the client roles everywhere" strips an already column-scoped table bare, bricking
every screen that was granted deliberately (profile edit, settings). Measure it in a rolled-back
transaction first. **A sweep must revoke only where `relacl` actually holds a
table-level entry for that role**, never unconditionally — which also makes it re-runnable as an exact
no-op.

### Default ACLs decide what a table is born holding

`pg_default_acl` rules (per owner role, per namespace) granting the client roles table-level UPDATE on
**every table created there** are why every table is born client-updatable and why the exposure kept
coming back one new table at a time. `ALTER DEFAULT PRIVILEGES` attaches only to objects created *after*
it is set and never touches an existing table: it is not a fix for what is already there. One owner's
rule may be out of reach from the migration role (not superuser, not a member of the platform's admin
role) — then the statement is exception-guarded down to a `WARNING`, the residue is bounded (app tables
are created by the migration role), and clearing it needs one superuser session.

### A partition does not inherit its parent's RLS, and the API layer is not the boundary

Partitions of a log table can carry direct client grants with `relrowsecurity = f`. They are
unreachable only because the REST layer does not expose a partition by name — a property of the API
server's configuration, not of the schema. Put both belts on every partition: `ENABLE ROW LEVEL SECURITY` (zero
policies is deny-all for non-bypass roles; the parent's policies still govern queries *through* the
parent) plus `REVOKE ALL` from the client roles. ⚠ **A future partition-creating migration must repeat
both**; enumerate from `pg_inherits`, never from a name list (a guessed list undercounts).

### Verify both polarities at apply time, from the live catalog

A grant migration has two ways to be wrong and only one is loud. Over-revoking bricks a screen silently —
a typo in the keep-list, and an admin UI stops saving with a `42501`. The apply-time `DO`
block asserts **both**: no stray client grant survived, *and* every deliberately kept grant is still
present, every partition has RLS on, the default ACL is clean, the column grants read exactly the
intended set. A bricked keep-list then fails at migration time, loudly, where somebody is watching.

**Find every client write by reading the client, not by grepping `.update(`.** `.upsert()` is
`INSERT … ON CONFLICT DO UPDATE` and needs UPDATE privilege **at plan time** whether or not a row
conflicts; the REST layer also emits the primary key in the `ON CONFLICT … DO UPDATE SET` list whenever
the client sends one, so `id` needs the grant too. A column that is only a pass-through in a payload
(`updated_at`, recomputed by a trigger but sent by the client anyway) needs the grant just the same.
Budget time for diagnosing: the error names the **table** — `42501 permission denied for table <t>` — not
the column, so it reads like a missing table grant and sends you looking in the wrong place.

Two corrections, each once believed in the opposite direction:

- **A trigger's escape is `current_user`, and nothing else.** Neither `rolbypassrls` nor table ownership
  exempts anything from a trigger. `SECURITY DEFINER` matters only because it *sets* `current_user` —
  which is why a guard trigger must stay `SECURITY INVOKER` (with `DEFINER` it runs as its owner and
  passes everyone), and why a definer function owned by the DB owner clears the guard from inside its
  body.
- **The privileged backend role is not a superuser** (`rolsuper = false`, `rolbypassrls = true`), so
  column-level grants *would* bind it. Name the client roles in the REVOKE and nobody else; the
  privileged role holds its UPDATE as its own aclitem, not by inheritance.

### Closing a table to clients leaves exactly one writer, and its grants are the ones to audit

A table written only by the backend gets the strongest form: `REVOKE ALL` from the client roles, RLS on,
write policies spelled `WITH CHECK (false)`. That closes both layers against **client sessions only**. A
definer function owned by the DB owner runs above the grant, and the privileged role bypasses RLS anyway;
neither the revoke nor the literal `false` is what stops it. So on such a table the write surface is
**the set of definer functions that INSERT into it**, which move under the definer checklist:

- auditing the table's grants tells you nothing about who writes it — enumerate the writers from
  `pg_proc.prosrc`;
- **a re-signed definer is born with client EXECUTE again** — `DROP` + `CREATE` takes the old ACL with it
  and default privileges hand the replacement a fresh pair, so every re-sign owes its own `REVOKE` and its
  own live-catalog post-condition. A table locked down once and a function re-signed repeatedly is the
  shape where this is missed.

**Checklist**
- [ ] Column-write claims are checked against `relacl` + `attacl`, never `column_privileges`
- [ ] On a table closed to client writes, the definer functions that write it were enumerated from
      `prosrc`, each with its own REVOKE/GRANT and live-catalog assertion
- [ ] A new column on a table with a table-level UPDATE grant is safe for a participant to write, or
      covered by a column GRANT **and** a guard trigger in the same migration
- [ ] The client-writable column set was established by reading the clients (`.upsert()` and
      pass-through columns included), and a negative-control test proves the legitimate write still works
- [ ] A blanket `REVOKE UPDATE` is conditional on `relacl` holding the entry
- [ ] Guard triggers are `SECURITY INVOKER` and test `current_user`
- [ ] A migration creating a partition enables RLS on it and revokes the client grants
- [ ] The migration's apply-time verification asserts the kept grants as well as the removed ones
