---
title: Security checklist — application (authz, secrets, validation, headers)
class: compiled
covers: []                 # fill when adopting: guards, main.ts (CORS), the client-side data-client module
last-verified: never
verified-by: boilerplate
sources: []
---

# Security checklist — the application half

> **Example — adapt to your backend.** Written against a NestJS backend with a hosted auth/data
> provider; the risks and their reasons carry over, the grep patterns need your names.

Run before a major release and periodically; read when adding an endpoint, a guard, a file upload or
anything touching sessions. Neighbouring pages: sessions are
[`security-session-checklist.md`](./security-session-checklist.md); the database half —
`SECURITY DEFINER` functions, RLS, table/column grants — is
[`security-database-checklist.md`](./security-database-checklist.md),
[`security-rls-checklist.md`](./security-rls-checklist.md) and
[`security-grants-checklist.md`](./security-grants-checklist.md).

## 1. API authorization

**Risk:** an endpoint reachable without the guard it needs.

If there is **no global auth guard and no `@Public()` marker**, authorization is opt-in per
controller, and a guardless controller is reachable by anyone — deliberate for health checks and
webhooks. So the audit question is never "is `@Public()` present", it is **"is the absence of a guard
here intentional?"** (A global guard with an explicit public marker inverts the question; pick one
and say which.)

Guards compose and depend on order: a role/ownership guard that reads `request.user` assumes the
auth guard already ran — listed first or alone, it throws on a field that was never set.

**Where an authorization input comes from decides whether it is one.** In hosted auth providers
there are usually two metadata blobs: one writable only through the admin API (`app_metadata`) and
one writable **by the user themselves** through a public client call with their own token
(`user_metadata`). If guards resolve the caller by fetching the live user row rather than reading
token claims, a self-written value takes effect on the very next request with no refresh and no
re-login. **Never read an authorization input out of a caller-writable field.** A guard that prefers
`user_metadata.tenant_id` to the server-written value makes every tenant-scoped endpoint
impersonable by anyone with a login.

**A server-written claim is still not authorization on its own.** It must be backed by a live row at
the moment it is used, or it outlives the fact it names: a soft-deleted membership leaves the claim
naming the tenant the user was just removed from, and they keep acting for it.

```bash
grep -rn "@Controller\|@UseGuards" {{BACKEND_DIR}}/src --include="*.controller.ts"
grep -rn "user_metadata" {{BACKEND_DIR}}/src {{MOBILE_DIR}}/src {{FRONTEND_DIR}}/src   # every hit is a finding until proven otherwise
```

**Checklist**
- [ ] Every controller has the auth guard (class or method level), or its guardless state is
      deliberate and documented (webhook, health check, public auth entry point)
- [ ] Ownership/role guards are listed *after* the auth guard
- [ ] No authorization input is read from a caller-writable field
- [ ] Every claim that grants access is re-checked against a live row on the request that uses it
- [ ] Admin-only routes have an explicit role check, not just "requires login"
- [ ] Dev-only endpoints are excluded from production builds, not just guarded
- [ ] Webhook endpoints verify the caller (signature or source IP) — an open webhook is a write API

## 2. Secrets and frontend exposure

**Risk:** a leaked secret, or a privileged key shipped to a client, compromises the whole app.

```bash
grep -rE "(password|secret|apikey|api_key|private_key|token).*=.*['\"][^'\"]{8,}['\"]" \
  --include="*.ts" --include="*.tsx" --include="*.js" | grep -v node_modules | grep -v "\.spec\."
grep -r "SERVICE_ROLE\|service_role" {{FRONTEND_DIR}}/src {{MOBILE_DIR}}/src
grep -r "dangerouslySetInnerHTML\|innerHTML" {{FRONTEND_DIR}}/src {{MOBILE_DIR}}/src
grep -rn "console\.log" {{FRONTEND_DIR}}/src --include="*.ts" --include="*.tsx" | grep -v "\.spec\."
grep -E "\.env|secret|credential" .gitignore
```

Client data modules must be built from the **public** key only; the privileged key exists only in the
backend's env. Anything prefixed for client exposure by the bundler (`VITE_*`) is **public** — a
build-time copy of a vendor key in the bundle is exposed by construction, which is acceptable only for
keys designed to be public and restricted by origin
([`third-party-sdk-bridge.md`](./third-party-sdk-bridge.md)). Payment-provider secret keys are
server-side only ([`payments-integration.md`](./payments-integration.md)).

**Checklist**
- [ ] `.env*` is gitignored; no secret file is tracked; no key or password literal in source
- [ ] Only the public key appears in client code; the privileged key exists only in the backend env
- [ ] No `dangerouslySetInnerHTML`/`innerHTML` fed by unsanitised user input; no stray `console.log`
      leaking data in production builds
- [ ] API responses don't carry fields a client has no business seeing (password hashes, internal ids)
- [ ] Production secrets differ from development/sandbox ones
- [ ] Record whether a secret scanner runs in CI — if not, that is a gap, not a pass

## 3. Input validation

**Risk:** an unvalidated field reaches the database or a downstream API untyped.

If the application registers **no global validation pipe**, then validation is per handler: every
mutating handler binds its own (`new ValidationPipe({ transform: true, whitelist: true })`), and
"is validation enabled" means checking each handler, not `main.ts`
([`backend-howto.md`](./backend-howto.md) for why decorators alone do nothing).

```bash
grep -rn "@Body(" {{BACKEND_DIR}}/src --include="*.controller.ts" | grep -v "ValidationPipe"
```

**Checklist**
- [ ] Every `@Body()` on a mutating route binds the validation pipe (inline or via the DTO class)
- [ ] `whitelist: true` where unknown fields must be rejected (defence against mass-assignment)
- [ ] DTOs use validator decorators (`@IsEmail`, `@Length`, `@IsEnum`), not bare TS types
- [ ] Monetary integers are bounded (`@Max(Number.MAX_SAFE_INTEGER)` at least)
- [ ] No raw SQL built by string interpolation; parameterised queries only

## 4. Dependency vulnerabilities

`{{PACKAGE_MANAGER}} audit` per workspace and an outdated check. **Do not assume a modern repository
already has a CI job or Dependabot-equivalent doing it** — record whether one exists; if not, it is a
manual, periodic check.

## 5. Object storage

**Risk:** a misconfigured bucket or object policy exposes private files. Bucket-level flags (public,
size limit, allowed MIME types) and object-level access are two different things; both need checking.
On Postgres-backed storage, object access is **ordinary RLS on the objects table** — there is no
separate policies table, which is what people look for and do not find — so the RLS checklist applies
verbatim, including the trap that made a storage policy admit nobody
([`security-rls-checklist.md`](./security-rls-checklist.md)).

## 6. Authentication and session

Own page: [`security-session-checklist.md`](./security-session-checklist.md).

## 7. CORS and headers

Build the CORS allow-list from an env list (`ALLOWED_ORIGINS`) with **exact** matching — not a
prefix, not a suffix — so one address for the app works and a second that resolves to the same server
does not. Confirm it is a list and not `*` in production, and that `credentials: true` is never paired
with `*`.

**Security headers may live in the reverse proxy, not the framework.** If there is no Helmet and no
manual header code, grepping the backend for CSP or `X-Frame-Options` always comes back empty and
that is not evidence they are missing — check the deployed proxy configuration, which is the one that
counts.

## Cadence

Functions/RLS/API/frontend — per release; dependencies — weekly; storage — monthly. Whatever is not
automated is a manual row: write down which is which, and treat nothing as already done.
