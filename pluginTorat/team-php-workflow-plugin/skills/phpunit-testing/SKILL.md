---
name: phpunit-testing
description: >
  PHPUnit test conventions and generation rules for this Laravel codebase.
  Use this skill whenever writing, generating, or reviewing tests — including
  when the user asks to "add tests", "cover this feature", "write tests from
  the ClickUp task", mentions acceptance criteria, TDD, coverage, or when the
  test-writer agent is invoked. Also consult it before modifying existing
  test files so new tests match house style.
---

# PHPUnit Testing Conventions

## Purpose

Turn acceptance criteria (usually from a ClickUp task) into a complete,
maintainable PHPUnit test suite. The goal is not line coverage — it is
**behavioral coverage of the acceptance criteria plus the failure paths the
criteria imply but do not state**.

## Test taxonomy (choose deliberately)

| Type | Directory | When to use |
|------|-----------|-------------|
| Feature test | `tests/Feature/` | HTTP endpoints, full request→response cycle, authorization, validation. Default for anything user-facing. |
| Unit test | `tests/Unit/` | Pure logic in `app/Utils/`, value objects, calculations. No DB, no container. |
| Service test | `tests/Feature/Services/` | Service classes that touch Eloquent. Uses `RefreshDatabase`. NOT mocked repositories — this codebase has no Repository layer; Services call Eloquent directly, so test them against a real (SQLite/MySQL test) database. |

Do NOT mock Eloquent models or the query builder. Mock only true external
boundaries: HTTP clients, mail, queues, storage, time (`Carbon::setTestNow`).

## Mapping acceptance criteria → tests

For each acceptance criterion, generate:

1. **One happy-path test** named after the criterion behavior, not the method.
   `test_teacher_can_submit_iep_for_approval()` — good.
   `test_submit()` — bad.
2. **The inverse authorization test.** If a role CAN do X, at least one other
   role MUST be tested as forbidden (403), and an unauthenticated request as
   401. Never skip this — missing authorization tests are the most common gap.
3. **Validation boundary tests** for every input mentioned in the criterion:
   required-missing, wrong type, over max length, and one valid edge
   (exactly at the limit).
4. **State-transition guards** if the criterion involves a workflow status
   (draft → submitted → approved …): test that illegal transitions are
   rejected, not just that legal ones succeed.
5. **Concurrency test when the model uses optimistic locking**: two updates
   with the same stale version — second one must fail with the expected
   exception/response, not silently overwrite.

If an acceptance criterion is ambiguous, generate the test for the most
restrictive interpretation and add a `// TODO: confirm with spec —` comment
citing the ambiguity. Do not silently pick the permissive reading.

## House style

- `declare(strict_types=1);` at the top of every test file.
- English only in test names, comments, and data. No Vietnamese/Japanese in
  code (fixture display strings that intentionally test multibyte/Japanese
  input are the exception — mark them with a comment).
- One assertion concept per test. Multiple `assert*` calls are fine when they
  verify one behavior (e.g., response status + DB row), but do not chain
  unrelated behaviors into one test.
- Use model factories for all setup. If a factory or state is missing, create
  it as part of the deliverable — do not hand-build models with `create([...])`
  containing 15 attributes inline.
- Use `assertDatabaseHas` / `assertDatabaseMissing` for persistence claims;
  never re-query and compare manually.
- Freeze time with `Carbon::setTestNow()` in any test involving dates,
  deadlines, or academic-year logic. Reset is automatic per-test via Laravel,
  but be explicit in `setUp()` when a whole class needs it.
- Name data providers after the scenario dimension:
  `provideInvalidPasswords`, not `dataProvider1`.

## Structure of a generated test class

```php
<?php

declare(strict_types=1);

namespace Tests\Feature\Iep;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

final class SubmitIepTest extends TestCase
{
    use RefreshDatabase;

    // 1. Happy path(s)
    // 2. Authorization matrix (each role that must be denied)
    // 3. Validation failures
    // 4. State-transition guards
    // 5. Edge cases (concurrency, soft-deleted parents, etc.)
}
```

Keep this ordering. Reviewers scan top-down expecting it.

## Output contract for the test-writer agent

When generating tests from a ClickUp task, always produce:

1. A short **criteria → test matrix** (table: criterion, test method(s),
   type) so the reviewer can verify nothing was dropped.
2. The test file(s).
3. Any new/updated factories.
4. A list of **untestable or ambiguous criteria** that need clarification —
   never fabricate behavior to make a criterion testable.

Run `./vendor/bin/phpunit --filter <NewClass>` before presenting results if
an executable environment is available; include failures verbatim.

## Pipeline position

Stage 2 of the agent pipeline (see the `agent-pipeline` skill — its rules
override this section on conflict). Gate to start: `01-task-planner.md`
exists, conforms to the task-planner output contract, and the human has
approved the plan. Write output to
`.claude/pipeline/<ticket-id>/02-test-writer.md` with the standard header
(`ticket / agent / round / input-commit / status`). Do not invoke any other
agent; if acceptance criteria are missing or contradictory, set
`status: blocked` and stop — do not fabricate criteria to keep the pipeline
moving.
