---
name: db-migration-safety
description: >
  Database migration safety rules for Laravel/MySQL. Use this skill whenever
  a migration file is created, modified, or reviewed — including when the user
  says "review this migration", "add a column", "change the schema", mentions
  ALTER TABLE, indexes, foreign keys, or when the db-migration-reviewer agent
  is invoked. Also consult it before writing any new migration, not only when
  reviewing existing ones. These are the errors that pass human code review
  but cause production incidents.
---

# DB Migration Safety

## Purpose

Catch the class of migration bugs that are invisible in code review because
the migration "works" on an empty dev database and fails only against
production data volume or production traffic.

## Review checklist (apply to every migration, in order)

### 1. Foreign keys and indexes

- Every FK column MUST have an index. MySQL InnoDB creates one automatically
  for `foreignId()->constrained()`, but a manually declared
  `unsignedBigInteger` + separate `foreign()` still gets one — the real trap
  is **columns used as join/filter keys without an FK constraint** (e.g.,
  `school_id` kept constraint-free for import performance). Those need an
  explicit `index()`.
- Columns appearing in `WHERE` of known hot queries (status, type,
  soft-delete + tenant combinations) should be indexed, usually as a
  **composite index with the tenant/school column first**.
- Flag redundant indexes: an index on `(a)` is redundant if `(a, b)` exists.

### 2. NOT NULL columns on existing tables

Adding a non-nullable column without a default to a table that already has
rows **fails outright on MySQL** (or backfills implicitly with the type's
zero-value under loose SQL modes — worse, because it corrupts silently).

Required pattern for large/production tables:

1. Add column as `nullable()`.
2. Backfill in chunked updates (separate migration or command —
   `DB::table(...)->orderBy('id')->chunkById(1000, ...)`), never one
   `UPDATE table SET ...` on a large table inside a migration.
3. A later migration adds the `NOT NULL` constraint (`->nullable(false)->change()`).

Flag any single-step `->default(...)->nullable(false)` add on a table
suspected to be large; the default makes it *run*, but the ALTER may still
lock the table (see §4).

### 3. Breaking changes against existing data and code

- **Renames** (column or table) break running application code during deploy:
  old code + new schema or new code + old schema will coexist for some
  window. Required pattern: add new → dual-write/backfill → switch reads →
  drop old, across separate releases. Flag any `renameColumn` /
  `renameTable` targeting a table the running app reads.
- **Type narrowing** (`string(255)` → `string(50)`, `bigInteger` →
  `integer`, dropping unsigned): require proof no existing data exceeds the
  new bound (a verification query in the PR description at minimum).
- **Enum changes**: MySQL enum ALTER rewrites the table; removing a value
  with existing rows using it fails or corrupts. Prefer a lookup/const
  approach; if enum must change, verify removal targets are unused.
- Dropping columns/tables: verify no code references remain (grep model
  `$fillable`, casts, queries, and any raw SQL) AND that the data does not
  need archival first.

### 4. Locking and online-DDL awareness (MySQL)

- Most `ALTER TABLE` on InnoDB are `INPLACE` since MySQL 5.7/8.0, but some
  still `COPY` (changing column type, adding a column to a table with
  full-text index, charset changes). A COPY alter on a big table = full-table
  lock for the duration = incident.
- Adding an index is online but IO-heavy; schedule for low-traffic windows on
  big tables and say so in the PR.
- Rule of thumb to state in reviews: **any ALTER on a table over ~1M rows
  needs an explicit statement of expected lock behavior and duration**.

### 5. Transactionality and rollback

- MySQL DDL causes implicit commits — a migration with multiple DDL
  statements is NOT atomic. If step 3 of 5 fails, steps 1–2 are applied.
  Prefer one logical change per migration file.
- `down()` must actually reverse `up()`, or explicitly throw/document why
  irreversible (data-destructive backfills usually are). An empty `down()`
  that silently does nothing is a defect.
- Data migrations mixed into schema migrations: flag. Data moves belong in
  chunked commands or separate migrations so they can be retried
  independently.

### 6. Project-specific rules

- Tables participating in the IEP workflow use **optimistic locking**: any
  new mutable workflow table needs a `lock_version` (unsigned int, default 0)
  column — flag its absence.
- Multi-tenant scoping: new tables holding school data need `school_id`
  (FK, indexed, and part of relevant composite unique keys — a plain
  `unique(email)` is wrong if uniqueness is per-school).
- Timestamps + soft deletes follow existing table conventions; a new table
  deviating (no `deleted_at` where siblings have it) needs justification.

## Output contract for the db-migration-reviewer agent

Produce a findings table:

| # | Severity | Location | Issue | Why it passes review but breaks prod | Fix |

Severity levels: `blocker` (will fail or lock in prod), `major` (data
integrity / performance risk), `minor` (convention). Include the concrete
corrected migration code for every blocker and major. If table sizes are
unknown, state the assumption ("assuming `students` exceeds 100k rows in
production") rather than guessing silently.

## Pipeline position

Stage 5 of the agent pipeline (see the `agent-pipeline` skill — its rules
override this section on conflict). Gate to start: convention-reviewer's
artifact (`04-*.md`) has `status: pass` or all its blockers are marked
resolved. Skipped entirely when the diff contains no files under
`database/migrations/`. Write output to
`.claude/pipeline/<ticket-id>/05-db-migration-reviewer.md` with the standard
header. Finding IDs use `db-migration-reviewer/<rule>/<file>:<symbol>`.
Round-2 runs verify prior findings and newly changed lines only (rule L3);
never re-report `wontfix` findings. Do not invoke any other agent — issues
outside migration scope get `severity: info, route-to: <agent>`.
