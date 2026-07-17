---
name: database-schema
description: >
  How to obtain accurate, current database schema information (tables,
  columns, types, indexes, fillable fields) in this Laravel codebase. Use
  this skill whenever any agent or task needs to reference a column or field
  name — writing tests, factories, JsonResources, FormRequests, policies,
  queries, or reviewing migrations. NEVER guess or recall field names from
  memory; always derive them per this skill. Also use it when schema changes
  to regenerate the snapshot.
---

# Database Schema Access

## Core rule

**Field names are never guessed, remembered, or copied from old code —
they are derived from a live source, every time.** A wrong column name in
a test or resource is not a typo; it is a contract violation with the
schema.

## Source-of-truth chain (one-way)

```
migrations  →  actual DB schema  →  generated snapshot / IDE helper
(only writer)   (ground truth)       (derived, regenerated, read-only)
```

Two prohibitions follow:

1. **Nothing writes schema except migrations.** No agent, hook, or script
   ever alters the database directly. "Code changed, so sync the DB" is
   expressed exclusively as a new migration (which then goes through
   db-migration-reviewer, stage 5).
2. **No hand-maintained schema document.** Any field list written by hand
   is a drift liability. The snapshot below is generated; editing it
   manually is a defect.

## How to look up schema (in order of preference)

| Need | Command |
|---|---|
| Columns, types, attributes of a model | `php artisan model:show App\\Models\\Student` |
| Raw table structure incl. indexes/FKs | `php artisan db:table students` |
| All tables overview | `php artisan db:show` |
| Machine-readable (for scripting) | `php artisan model:show App\\Models\\Student --json` |
| Fillable / guarded / casts / relations | `model:show` output, cross-checked against the model file |

If no live DB is available in the current environment, fall back to the
generated snapshot (below); if that is also missing/stale, read the
migration files in chronological order — never fall back to guessing.

## Generated snapshot

`docs/schema/` holds one generated file per model
(`php artisan model:show --json` output, committed to the repo) so that
agents and humans can reference fields without a running database.

Regeneration is mechanical, not a human habit:

- A hook regenerates the snapshot whenever a file under
  `database/migrations/` is created or modified (after `php artisan
  migrate:fresh --seed` in the dev environment).
- CI freshness check: regenerate → `git diff --exit-code docs/schema/`.
  A dirty diff fails the build with the message "schema snapshot is
  stale — run the regenerate script and commit."

Optionally, `barryvdh/laravel-ide-helper` (`ide-helper:models --nowrite`)
maintains `_ide_helper_models.php` for IDE autocompletion; treat it the
same way — generated, never hand-edited, refreshed by the same hook.

## Consumers and their obligations

| Agent | Must use this skill for |
|---|---|
| test-writer | Factory definitions and `assertDatabaseHas` column names |
| api-verifier | Mapping JsonResource fields ↔ real columns when diagnosing contract failures |
| security-reviewer | Auditing `$fillable` against actual privilege-bearing columns |
| db-migration-reviewer | Establishing current state of a table before judging an ALTER |
| task-planner | Grounding implementation plans in existing tables instead of inventing them |

Each of these, when citing a column in its output artifact, cites the
source (`model:show` run or snapshot file + commit). "Field X exists"
without a source is an unverified claim and fails the agent's output
contract.

## Pipeline position

This skill has no pipeline stage — it is a shared capability, consulted
inside other stages. It never dispatches agents and owns no artifact
except the generated `docs/schema/` snapshot, whose regeneration is
triggered by hooks, not by an agent.
