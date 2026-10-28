---
title: Scheduled jobs and the leader lock (example)
class: compiled
covers: []                 # fill when adopting: the leader-election service, the cron helper, the registrations spec
last-verified: never
verified-by: boilerplate
sources: []
---

# Scheduled jobs and the leader lock

> **Example — adapt to your backend.** NestJS `@Cron` jobs on several replicas, with a Redis lock
> choosing which replica decides that a tick happens. The decision that recurring work lives in the
> source (`@Cron`) rather than as repeatable jobs persisted in Redis is an architecture choice: schedules
> that live in a datastore survive a rename or removal in code and fire a job nobody owns any more.

## The shape every scheduled job has

A scheduled job is **two methods**, and the split is load-bearing:

```ts
@Cron(EXPRESSION, { name: JOB_NAME, disabled: process.env.NODE_ENV === 'test',
                    waitForCompletion: true })
async scheduledTick() { await this.leaderElection.runAsLeader(JOB_NAME, () => this.tick()); }

async tick(): Promise<SomeCounts> { /* the work */ }
```

- **The lock wraps the tick from outside, never from within.** `runAsLeader` resolves to nothing: on a
  replica that lost, there is no count to return. Tick bodies return counts that specs and dev
  controls assert on, so a lock pushed into the body destroys the only observable those callers have.
- **The tick body stays directly callable — a requirement, not a convenience.** Dev controls drive one
  cycle on demand and every spec reaches the body. Nothing that calls a tick directly passes the lock
  — which is also why the per-row claims below are not redundant with it.
- **One name per job**; it names the scheduler-registry entry *and* the lock. Two jobs sharing one
  name make each other's ticks vanish.
- **`disabled:` rather than an early return in `onModuleInit`.** The scheduler mounts decorators
  whatever `onModuleInit` does, so an early return leaves a live timer inside the test runner; with
  `disabled` the job is constructed and registered but never started.
- The lock service comes from an already-global module, so a module gains a scheduled job without
  gaining an import.

## What the lock promises, and what it does not

- **It guards the decision that now is the time, not the work.** Every replica may still process a
  queue job; only one may decide a tick happens.
- **It fails closed.** A caller that cannot reach the lock store cannot know whether somebody else is
  running, so an unreachable store skips the tick and logs at *error*. Losing the election is the
  normal state of every replica but one on every tick and logs at *debug* — anything louder makes the
  logs useless at the replica count this exists for.
- **It is released by a compare-and-delete script, never a `DEL`.** If our TTL expired mid-body,
  somebody else holds the key; a plain delete drops *their* lock and admits a third replica.
  `get`-then-`del` has the same hole, only narrower.
- ⚠️ **A tick can still run on two replicas.** The TTL can expire under a slow body; the lock lives
  only in the store, and a store with no volume drops every held lock on restart. A watchdog renewal
  is deliberately out of scope. What replaces it is **idempotent or claim-first writes on the ticks
  where a duplicate would do damage** — a billing tick claims its row before charging, a sweep claims
  every mutation that decides an outcome, an outbox claims its rows and enqueues under deterministic
  job ids. Read the lock as removing the *routine* duplicate, not as mutual exclusion you may rely on.
- **The TTL errs long on purpose.** Too short loses a live leader's lock to a replica whose own cron
  is firing right then; too long only delays work, because a crashed tick's successor runs the same
  query and picks up whatever is outstanding. Only few-minute schedules have a loser that comes back
  inside the window at all.
- **No `NODE_ENV` branch inside the lock service.** Specs about what a tick *does* substitute an
  always-win double through DI; a test-only branch in a scheduled path is the mechanism that later
  hides a real defect.

## The job that must not be gated

A flusher that drains an **in-process buffer** (a plain array of outgoing messages) is deliberately
not behind the lock: each replica has its own messages, and electing one replica to drain *its* queue
strands every other replica's messages for ever. Every other scheduled job decides something about
*shared* state; this one only pushes its own buffer out. Pin it inversely rather than by comment: a
spec asserts the lock service is **absent** from that class's constructor, so a future "you forgot the
lock" fails at the injection whatever the body is then written to say.

## A schedule that comes from the environment is read twice

`@Cron` needs its expression at class-definition time, before the config module has run. So a
configurable schedule is read **twice** — from `process.env` at module load for the decorator, and
through the config service — and `onModuleInit` **refuses the boot** when the two disagree.

- The only way to produce the mismatch is to set the variable in a `.env` file and nowhere else (the
  config service sees it, the decorator does not). So every such knob is forwarded by the compose
  files — a money timer running on a schedule nobody chose is worse than a failed boot.
- **Reading once and sharing the constant removes the mismatch instead of detecting it:** resolve the
  value at module load and feed both the decorator and the config reader. Prefer it; keep the
  cross-check anyway, it costs a line and it is what a third reader would trip over.
- Put the cross-check **above** the test-environment early return: it is a statement about
  configuration, not about whether a timer runs, and a guard no test can exercise is a guard nobody
  notices breaking.
- Refuse a malformed expression eagerly in the config provider so it fails the boot rather than the
  first tick; the shape check is only a shape check — the scheduler takes the process down on a bad
  expression, and that is right.
- ⚠️ **A cron expression cannot be written inside a block comment**: a step expression (`*/5`)
  contains the pair that ends one.
- **Reading a period back out of an expression is the part that bites.** Only a plain minute-step has
  a period a number can express; a 7-minute step wraps early at the hour and a 59-minute step is two
  firings an hour. A helper returns *nothing* for every other shape, and a caller that needs a number
  must say what it does without one. A poller whose stuck-row backoff divides a row's age by that
  period must refuse the boot rather than guess — a wrong number there freezes the residue and
  decides a row's fate once and for all.

## Why a spec asserts the registrations themselves

Every other spec calls the tick body directly, so a decorated method and an undecorated one look
identical to all of them: a `@Cron` lost while moving onto a new entry point leaves the suite green
and the job unscheduled. One spec reads the scheduler's own metadata off each entry point, asserts
the lock names, asserts **no** decorator was left on the body it wraps, and re-imports the
configurable ones under non-default values — a default inlined as a literal matches every check that
compares two readings of the environment.

When one table needs several lanes of work, prefer **one job with ordered lanes** (one table, one
schedule, one lock) to a second `@Cron`; the order within the tick is then load-bearing, so document
it where someone would reorder it.
