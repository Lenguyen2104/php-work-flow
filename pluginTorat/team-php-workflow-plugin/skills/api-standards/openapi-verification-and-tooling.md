# API Standards — Contract verification & tooling

Companion to [`SKILL.md`](./SKILL.md) (REST conventions, error format, and the
OpenAPI governance rules). This file holds how contract compliance is
*proven* and *enforced* — the deterministic checks api-verifier relies on.

## Verification: Spectator is the contract truth

Contract compliance is proven by `hotmeteor/spectator` assertions in the
existing PHPUnit feature tests — deterministic, CI-runnable, no browser:

```php
Spectator::using('openapi.yaml');

$this->actingAs($teacher)
    ->getJson("/api/v1/ieps/{$iep->id}")
    ->assertValidRequest()
    ->assertValidResponse(200);
```

Minimum per endpoint: one `assertValidResponse(2xx)`, one 422 where input
is validated, one 401/403 — deliberately overlapping the authorization
tests required by the phpunit-testing skill; one test may assert both.
api-verifier generates missing coverage instead of only reporting it.

## Enforcement by tooling

1. Spec lint: `spectral lint docs/openapi/openapi.yaml` (CI + api-verifier
   step 1).
2. Drift guard: `hooks/scripts/openapi-drift-guard.sh` (live, per-edit)
   plus the same check in CI per-PR.
3. Coverage diff: `php artisan route:list --json` vs spec paths — route
   missing from spec = `blocker`; spec path with no route = `major`.

api-verifier's verdict comes from these deterministic checks only; agent
judgment is reserved for classifying findings and proposing fixes, never
for deciding whether a response "looks right".
