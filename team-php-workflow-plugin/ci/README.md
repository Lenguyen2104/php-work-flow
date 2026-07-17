# CI template — server-side gate

`team-php-workflow-ci.yml` re-enforces three rules at the one point every PR
must pass, so they can't be skipped by a hand-edit outside Claude Code, a
machine with no JSON parser (hooks degrade to off), or a plain
commit-and-push. Hooks = fast local feedback; CI = final authority. The
overlap is intentional.

| Job | Mirrors hook | Fails the PR when |
|---|---|---|
| `openapi-drift` | `openapi-drift-guard.sh` | PR changes `app/Http/{Requests,Resources,Controllers}` or `routes/api.php` but not `docs/openapi/`, and no `contract-invisible` justification is in a commit message or the PR body |
| `spec-lint` | api-verifier step 1 | `spectral lint docs/openapi/openapi.yaml` reports errors |
| `schema-snapshot` | `migration-snapshot-reminder.sh` | migrating a fresh DB + `regenerate-schema-snapshot.sh` leaves `docs/schema/` dirty (snapshot stale) |

## Install (in the Laravel repo, not the plugin)

1. Copy this file to `.github/workflows/team-php-workflow-ci.yml` in the
   Laravel repo.
2. Ensure `scripts/regenerate-schema-snapshot.sh` exists there (ships with
   this plugin under `scripts/`).
3. Edit the `<<ADJUST>>` spots: PHP version and the DB engine/credentials
   (the template uses MySQL 8; swap the `services` block and `DB_*` env for
   Postgres if needed).
4. Mark the three jobs as required status checks on the protected branch so
   a red run actually blocks merge.

The check logic is covered by the plugin's own hook tests
(`hooks/tests/run.sh`) — the CI jobs replicate that verified logic at the
PR boundary; keep the two in sync when a rule changes.
