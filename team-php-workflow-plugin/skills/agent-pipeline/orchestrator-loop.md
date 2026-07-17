# Orchestrator Loop (self-driving mode)

Companion to [`SKILL.md`](./SKILL.md). Defines the auto-drive procedure the
`/team-php-workflow:run` command follows to take a ticket from planning to a
terminal state without a per-stage human prompt. The stage gates (SKILL.md
stage table) and the hard limits ([`loop-prevention-rules.md`](./loop-prevention-rules.md))
still apply unchanged — this file only says how the orchestrator advances
between them on its own.

## The one human checkpoint

After stage 1 produces the plan, the orchestrator STOPS once, shows the plan
summary, and waits for explicit human approval. This is the **only**
discretionary pause. After approval the pipeline runs to a terminal state
(Done or Blocked) without asking again. Escalation (below) is a stop, not a
question — it ends the run.

## Drive sequence for ticket `<id>`

1. **Stage 1 — task-planner.** Dispatch it. On return: summarize normalized
   acceptance criteria, affected tables/endpoints/screens, risk flags.
   **STOP for approval.** If the task has no acceptance criteria → write
   `status: blocked`, escalate, do not improvise them.
2. **Stage 2 — test-writer.** After approval, dispatch it (gate: `01` valid +
   approved). It writes tests + factories from the criteria matrix.
3. **Stage 3 — implementation (main session, not an agent).** Write the
   application code that makes the stage-2 tests pass. Run
   `./vendor/bin/phpunit` and iterate until green. PostToolUse hooks
   (phpcs/phpstan) run automatically on each edit; clear their blocks before
   moving on. If the criteria cannot be implemented as specified, stop and
   escalate — do not silently change behavior.
4. **Stages 4–7 — reviewers.** Dispatch in stage order, one at a time,
   respecting each gate and skip condition (no `database/migrations/` diff →
   skip 5; no route/controller/request/resource diff → skip 7). Each writes
   its artifact.
5. **Fix cycle (auto).** After stage 7, collect every `blocker`/`critical`/
   `major` finding across all artifacts. Apply them in ONE batch (see
   Auto-apply rules). Append `blockers-resolved: true` plus a one-line note
   per resolved finding ID to each affected artifact — never edit `status:`.
   Commit.
6. **Round 2.** Re-run ONLY the reviewers that reported those findings, in
   stage order, scope frozen per L3. Do not re-run a reviewer whose
   `input-commit` is unchanged (L5).
7. **Terminal.** Done → report the consolidated pass. Blocked (any L-rule) →
   stop and hand back (see Stop conditions).

## Auto-apply rules

- Auto-apply only severity ≥ `major` from reviewer findings tables.
  `minor`/`info` are logged and routed (L6) into the batch as context, not
  auto-fixed mid-loop.
- Apply the reviewer's provided fix when the findings table gives one. If a
  finding needs a judgment call the reviewer explicitly flagged, do NOT
  guess — treat it as an escalation:
  - **api-verifier** "spec vs code disagreement — human call": stop, present
    both sides. Changing a client-facing contract is not the orchestrator's
    decision.
  - **security-reviewer** `critical` with no safe mechanical fix (needs new
    authorization/policy design): stop. Never improvise auth logic on a
    system holding minors' data.
- Never touch `status:`; it records what the agent concluded. Gate
  satisfaction is the `blockers-resolved:` marker only.

## Stop conditions (hand back to human — terminal per L7)

- **L1** — an agent's output is malformed twice.
- **L2** — blockers survive round 2 (no round 3).
- **L5** — zero progress between rounds (fix loop not converging).
- A flagged human-call finding (api-verifier spec conflict, security design fix).
- A gate that stays closed after one retry.

On any stop: emit ONE consolidated findings table + which rule fired and why
+ the exact next action the human should take. The pipeline for this ticket
ends here. Resumption requires an explicit human instruction, which resets
round counters for the affected reviewers only (L7).

## What runs fully automatic (no prompt)

- Stage sequencing, gate checks, and skip conditions.
- Stage 3 implementation until tests are green.
- round-1 → fix batch → round-2 for mechanically-fixable findings ≥ major.
- Routing of cross-agent observations (L6) into the fix batch.
