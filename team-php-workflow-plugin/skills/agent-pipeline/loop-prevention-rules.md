# Loop-Prevention Rules (hard limits)

Companion to [`SKILL.md`](./SKILL.md). These are the hard limits that bound
review/fix cycles. They override ad-hoc judgment: when a bound is hit the
pipeline STOPS and escalates to the human — it never loops "one more time" on
its own.

**L1 — Retry budget for malformed output: 1.** If an agent's artifact fails
its output contract (missing findings table, no severity, etc.), re-run that
agent once with the contract violation quoted in the prompt. Second failure →
`status: blocked`, stop pipeline, report to human. Never retry a third time.

**L2 — Review round budget: 2 per reviewer per ticket.** Round 1 = full
review. Round 2 = re-review after fixes. If blockers remain after round 2,
STOP and hand the human the outstanding findings table. Do not run round 3;
two failed fix attempts means the problem needs human judgment, and
round 3+ is where agents historically start "fixing" each other's fixes.

**L3 — Round-2 scope freeze.** In round 2 a reviewer may only (a) verify its
own round-1 findings as resolved/unresolved and (b) flag NEW issues *in
lines changed since round 1* at severity ≥ major. It must not re-scan
unchanged code or report new minor findings. Scope creep across rounds is
the main source of infinite review cycles.

**L4 — Stable finding IDs + suppression list.** Findings are identified as
`<agent>/<rule>/<file>:<symbol>` (symbol, not line number — line numbers
shift). A human can mark a finding `wontfix` in the artifact; every later
round MUST carry the suppression forward and MUST NOT re-report it.
Re-reporting a wontfix finding is a contract violation (→ L1).

**L5 — No-progress detection.** Before re-running any reviewer, compare
`input-commit`: if the code has not changed since that reviewer's last run,
do not run it — the output is already known. If a round-2 artifact contains
the identical unresolved findings set as round 1 (no finding resolved, none
newly introduced), stop immediately and escalate: zero progress means the
fix loop is not converging.

**L6 — Cross-agent findings are routed, not chained.** If security-reviewer
notices a convention issue, it records it as `severity: info, route-to:
convention-reviewer` in its own artifact and moves on. The orchestrator
folds routed items into the next fix batch. An agent never triggers another
agent because of something it found.

**L7 — Escalation is a terminal state, not a pause.** `status: blocked` or a
hit budget ends the automated pipeline for this ticket. Resumption requires
an explicit human instruction, which resets round counters for the affected
reviewers only (not the whole pipeline).
