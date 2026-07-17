# PHP Security — SQL injection & mass assignment

Companion to [`SKILL.md`](./SKILL.md), which covers scope/priority and the #1
class (authorization). This file holds the other two primary vulnerability
classes. Review order is unchanged: authorization → SQL injection → mass
assignment → secondary.

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
