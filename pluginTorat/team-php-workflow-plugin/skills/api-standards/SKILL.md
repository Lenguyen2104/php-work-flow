---
name: api-standards
description: >
  REST conventions, unified error format, versioning, and OpenAPI
  governance for this project's API. Use this skill whenever creating or
  modifying any API endpoint, FormRequest, JsonResource, or API route —
  and whenever a diff touches request/response shapes, because the OpenAPI
  spec MUST be updated in the same change. Also the rulebook for the
  api-verifier agent (stage 7).
---

# API Standards

## REST conventions

- Base path `/api/v1/...`; version bumps only for breaking changes
  (removing/renaming fields, changing types, tightening validation).
  Additive changes (new optional field, new endpoint) do not bump.
- Resource nouns, plural, kebab-free snake где applicable to match DB:
  `/api/v1/ieps/{iep}/approvals`. Actions that don't map to CRUD are
  sub-resources or verbs as a last resort (`/ieps/{iep}/submit`), and
  every such verb endpoint must be justified in the spec description.
- Status codes: 200/201/204 by effect; 401 unauthenticated, 403
  unauthorized, 404 not-found-or-cross-tenant (never reveal existence of
  another school's record via 403 — return 404), 409 optimistic-lock
  conflict, 422 validation.
- Pagination: Laravel paginator shape, documented once as a shared
  component and `$ref`'d.

## Unified error format

Exactly one error schema, `components/schemas/Error`, used by every
4xx/5xx response:

```json
{
  "message": "human-readable, safe to display",
  "errors": { "field": ["validation detail"] }
}
```

- `errors` present only on 422.
- Never leak internals: no exception class names, SQL, stack traces, or
  file paths in `message` regardless of APP_DEBUG.
- Optimistic-lock conflicts return 409 with a stable machine-readable
  `message` the frontend can key on.

## OpenAPI Governance

### The spec is canonical (spec-first)

`docs/openapi/openapi.yaml` is the single source of truth for the API
contract. Code conforms to the spec, never the reverse. The spec is
hand-maintained — do NOT introduce annotation-based generation
(swagger-php etc.); a spec generated from code makes contract
verification circular (code validated against itself proves nothing).

- **Every endpoint exists in the spec before it exists in code.** If the
  ClickUp task lacks detail to write the spec entry, that is a `blocked`
  finding, not a license to improvise.
- **No undocumented endpoints.** A route in `routes/api.php` with no spec
  path is a `blocker` for api-verifier.

### The sync rule (non-negotiable)

Any of the following changes MUST update `docs/openapi/openapi.yaml`
**in the same commit/PR** (the openapi-drift-guard hook enforces this):

| Code change | Spec change required |
|---|---|
| Route added/removed in `routes/api.php` | Path item added/removed |
| FormRequest `rules()` change | `requestBody` schema updated |
| `JsonResource` field added/removed/renamed/retyped | Response schema updated |
| New status code returned | Response entry added |
| Error payload change | Shared `Error` component updated |
| Auth requirement change | `security` entry updated |

The only escape hatch is an explicit `contract-invisible` justification
(internal refactor, identical wire format) recorded in the commit/PR.

### Spec conventions

- Bodies defined in `components/schemas`, one schema per resource
  representation, reused via `$ref`; no repeated inline object schemas.
- Every property has an explicit `type`; fields that can be absent
  (`whenLoaded`, conditionals) are not listed as `required`; nullable
  fields use `nullable: true` matching what the JsonResource emits.
- Enum-like fields (status, role) are OpenAPI `enum`s kept in sync with
  PHP backed enums — name the PHP source in a spec comment.

### Verification & enforcement

How contract compliance is *proven* (Spectator assertions in feature tests,
the minimum per endpoint) and *enforced* (spec lint, drift guard, coverage
diff — the deterministic checks api-verifier relies on) are in a companion
file:

→ See [`openapi-verification-and-tooling.md`](./openapi-verification-and-tooling.md)
