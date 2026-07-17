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

## 2. SQL injection

### The rule

User input may reach SQL **only** as a bound parameter. String
interpolation/concatenation into any of the following is a blocker:

- `DB::raw()`, `DB::select/statement/update/delete(...)`
- `whereRaw`, `orderByRaw`, `havingRaw`, `selectRaw`, `groupByRaw`

```php
// BLOCKER
->whereRaw("name LIKE '%{$request->q}%'")
->orderByRaw($request->sort)          // column names can't be bound — see below

// OK
->whereRaw('name LIKE ?', ['%' . $request->q . '%'])
```

### Non-bindable positions (the subtle cases)

Column names, sort directions, and table names cannot be parameterized.
Any of these coming from request input must go through a **whitelist**:

```php
$sortable = ['created_at', 'student_name', 'status'];
$column = in_array($request->sort, $sortable, true) ? $request->sort : 'created_at';
```

Flag `orderBy($request->input('sort'))` even without `Raw` — Laravel's
grammar quoting mitigates but does not justify passing user input as an
identifier.

### Also check

- LIKE wildcard injection: user-supplied `%`/`_` should be escaped
  (`addcslashes($q, '%_\\')`) when the input is meant as a literal — this
  is a correctness/DoS issue on large tables, lower severity.
- Raw SQL inside OneRoster CSV import paths: batch imports often use raw
  bulk statements for speed; every value must still be bound or generated
  server-side.

## 3. Mass assignment

- `$guarded = []` or `Model::unguard()` outside seeders/factories: blocker.
- `Model::create($request->all())` / `->update($request->all())` /
  `->fill($request->all())`: blocker even with `$fillable` set — review
  what's IN `$fillable`. Privilege-bearing attributes (`role`,
  `school_id`, `status`, `approved_by`, `is_active`, `lock_version`)
  must never be fillable-and-fed-from-request; set them explicitly in the
  Service.
- Required pattern: `$request->validated()` from a FormRequest, then pass
  only that. Verify the FormRequest rules don't themselves accept
  privilege-bearing fields.
- Nested/array input (`items.*.foo`) with `fill`: check each nested key
  against the same standard.

## Secondary checks, reporting & pipeline position

The fast-pass secondary checks (IDOR, uploads, information disclosure, auth
flows, logging), the security-reviewer **output contract**, and this skill's
**pipeline position** (stage 6) are documented in a companion file to keep
this file focused on the three primary vulnerability classes:

→ See [`reporting-and-secondary-checks.md`](./reporting-and-secondary-checks.md)
