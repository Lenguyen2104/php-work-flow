---
name: implementation
description: >
  Rules for stage 3 (implementation — main session, not an agent). Use this
  skill whenever writing or modifying application code to make the stage-2
  tests pass: it forbids code comments and requires API documentation
  (OpenAPI spec, and Swagger annotations where the project already uses
  them) to ship in the same change as any endpoint work.
---

# Implementation Rules (stage 3)

## No code comments

Implementation code contains **no comments**. Names carry the meaning:
if a block needs a comment to be understood, extract it into a method or
variable whose name says the same thing.

Forbidden:

- Inline comments (`// loop over students`, `# check permission`).
- Narrative docblocks that restate the signature (`/** Gets the user. */`).
- Commented-out code — delete it; git history is the archive.
- TODO/FIXME markers — unfinished work goes to the ticket or a finding,
  not the source.

Allowed (only these):

- PHPDoc that phpstan needs and native types cannot express:
  generics, array shapes (`@param array<int, ScoreDto>`,
  `@return Collection<int, Student>`).
- Attributes/annotations the framework or tooling consumes at runtime
  (`#[Override]`, existing Swagger annotations — see below).
- The one-line justifications `php-conventions` explicitly demands
  (`mixed` usage, multibyte test fixtures) — as PHPDoc, not inline.
- A license header if the file already had one.

convention-reviewer (stage 4) treats any other comment in the diff as a
`major` finding.

## API documentation ships with the endpoint

Whenever the diff adds or changes an endpoint's request or response —
route, controller action, FormRequest `rules()`, JsonResource shape,
status codes, auth requirement — the API documentation is updated **in
the same commit**, never "later":

1. **OpenAPI spec** — update `docs/openapi/openapi.yaml` per the sync
   table in the `api-standards` skill. That skill is canonical for spec
   conventions (shared `Error` component, `$ref` reuse, nullable rules);
   this rule only fixes *when*: same commit as the code change. The
   openapi-drift-guard hook blocks the commit otherwise.
2. **Swagger, if the project already uses it** — when the target project
   has an existing Swagger/annotation setup (l5-swagger, swagger-php
   attributes on controllers), keep those annotations in sync with the
   same change: request body, parameters, every response status the
   action can return, and the schema of each response. Do NOT introduce
   annotation-based generation into a project that doesn't have it —
   spec-first governance (`api-standards`) forbids that.

Definition of done for any endpoint work: tests green **and** the
request/response documented. An endpoint whose docs are missing or stale
is not implemented; api-verifier (stage 7) reports it as a `blocker`.
