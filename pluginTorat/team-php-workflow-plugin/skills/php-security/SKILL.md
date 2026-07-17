---
name: php-security
description: >
  PHP/Laravel security review rules focused on the three vulnerability
  classes that actually occur in this stack: SQL injection through raw
  queries, mass assignment, and missing authorization checks on endpoints.
  Use this skill whenever reviewing code for security, whenever a diff
  touches controllers, form requests, raw SQL, model $fillable/$guarded,
  routes, or policies — and whenever the security-reviewer agent is invoked.
  Consult it even for "small" changes; missing authz checks ship in small
  diffs.
---

# PHP Security Review

## Scope and priority

Review in this order — it matches both real-world frequency and blast radius
for a school system holding minors' personal and disability-related data:

1. Missing/incorrect authorization (per-endpoint AND per-object)
2. SQL injection via raw queries
3. Mass assignment
4. Secondary: IDOR patterns, file upload handling, information disclosure

This is a system with five roles (School Admin, Teacher, Student, Parent,
Principal) and strict tenant boundaries (school). Most real vulnerabilities
here are authorization mistakes, not exotic exploits.

## 1. Authorization

### The two-layer rule

Every state-changing or data-returning endpoint needs BOTH:

- **Authentication + role gate**: middleware (`auth`, role middleware) or
  policy `viewAny`/`create` — answers "may this *type* of user hit this
  route at all?"
- **Object-level authorization**: policy check against the *specific* model
  — answers "may this user act on *this* record?"

Route middleware alone is the classic half-fix: a teacher-only route still
lets Teacher A modify Teacher B's (or another school's) IEP if the
controller loads by raw ID.

### What to flag

- Controller actions retrieving a model by ID from route/request without a
  subsequent `$this->authorize(...)` / `Gate::` / policy call.
- Queries missing tenant scope: `Iep::findOrFail($id)` instead of a
  school-scoped query or global scope. Verify the model actually has a
  tenant global scope before accepting `findOrFail` as safe — do not assume.
- Authorization derived from client input (`$request->role`,
  `$request->school_id`) instead of the authenticated user.
- `Route::resource` exposing actions the spec doesn't grant (e.g., destroy)
  without `only([...])`.
- Read endpoints treated as harmless: listing students, viewing another
  student's IEP, or questionnaire answers is a privacy breach in this domain
  — same severity as writes.
- Status-based authorization gaps: spec says an IEP is immutable after 確定
  (finalization) — an update endpoint that checks role but not document
  state is a finding, not a nitpick.

## 2 & 3. SQL injection and mass assignment

The rules for the other two primary classes — SQL injection (bound params,
non-bindable-position whitelists, LIKE/OneRoster import cases) and mass
assignment (`$guarded`/`unguard`, `$request->all()`, privilege-bearing
attributes, nested input) — are in a companion file:

→ See [`sql-injection-and-mass-assignment.md`](./sql-injection-and-mass-assignment.md)

## Secondary checks, reporting & pipeline position

The fast-pass secondary checks (IDOR, uploads, information disclosure, auth
flows, logging), the security-reviewer **output contract**, and this skill's
**pipeline position** (stage 6) are documented in a companion file to keep
this file focused on the three primary vulnerability classes:

→ See [`reporting-and-secondary-checks.md`](./reporting-and-secondary-checks.md)
