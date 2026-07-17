# PHP Security — Secondary Checks, Reporting & Pipeline

Companion to [`SKILL.md`](./SKILL.md). Covers the fast-pass secondary checks,
the security-reviewer output contract, and this skill's position in the agent
pipeline. The primary vulnerability classes live in `SKILL.md` (authorization)
and [`sql-injection-and-mass-assignment.md`](./sql-injection-and-mass-assignment.md)
(the other two).

## 4. Secondary checks (fast pass)

- **IDOR beyond models**: file download endpoints serving by
  filename/path from request → path traversal + cross-tenant reads.
  Require ID-based lookup + policy + `Storage` (never `file_get_contents`
  on a request-derived path).
- **Uploads**: validate MIME by content (`file` rule with `mimes:` uses
  the guessed extension; prefer `mimetypes:`), store outside public root
  with generated names, never trust `getClientOriginalName()` for the
  stored filename.
- **Information disclosure**: API resources returning whole models
  (`return $user;`) leak columns added later. Require explicit
  `JsonResource` field lists. Exceptions/stack traces in JSON responses
  (`APP_DEBUG` assumptions) — responses must not echo internal messages.
- **Auth flows**: OTP/2FA and password endpoints — no user enumeration via
  differing error messages/timing, rate limiting present
  (`ThrottleRequests`), OTP single-use and expiring.
- **Logging**: passwords, OTP codes, tokens must not reach logs — check
  `Log::` calls in auth Services.

## Output contract for the security-reviewer agent

Findings table:

| # | Severity | Class | Location (file:line) | Evidence (code excerpt) | Exploit sketch (1–2 lines) | Fix |

Severity: `critical` (exploitable now, cross-tenant or privilege
escalation), `high` (exploitable with authenticated account of any role),
`medium` (defense-in-depth gap), `low`/`info`.

Rules of engagement:

- Every `critical`/`high` must include the concrete exploit sketch — one
  sentence of "a Parent could ... by ...". If you cannot articulate the
  exploit, downgrade it and say why.
- No speculative findings without code evidence; "this pattern is often
  dangerous" is not a finding.
- Explicitly list what was checked and found clean (the authz matrix per
  reviewed endpoint), so absence of findings is distinguishable from
  absence of review.

## Pipeline position

Stage 6 of the agent pipeline (see the `agent-pipeline` skill — its rules
override this section on conflict). Gate to start: the previous applicable
stage's artifact has `status: pass` or all its blockers are resolved (stage
5 if migrations were in the diff, otherwise stage 4). Never skipped. Write
output to `.claude/pipeline/<ticket-id>/06-security-reviewer.md` with the
standard header. Finding IDs use `security-reviewer/<class>/<file>:<symbol>`.
Round-2 scope: verify prior findings + new issues in changed lines at
severity ≥ high only (rule L3). Never re-report `wontfix` findings.
Convention or migration issues noticed in passing are recorded as
`severity: info, route-to: <agent>` — never trigger that agent yourself.
