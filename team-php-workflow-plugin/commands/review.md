---
description: Run the review stages (4→7) on the current implementation diff, in pipeline order.
argument-hint: [ticket-id]
---

Run the review pipeline on the current implementation diff for ticket
**$ARGUMENTS** (if omitted, use the newest `.claude/pipeline/<ticket>/`).

Read `skills/agent-pipeline/SKILL.md` first. Then dispatch the reviewers
**in stage order**, one at a time, each via the Task tool. The
`pipeline-gate.sh` hook enforces the gates — respect its blocks, never work
around them:

1. **Stage 4 — convention-reviewer** (always). Only after the PostToolUse
   php-lint hook (Pint + PHPStan) passes mechanically.
2. **Stage 5 — db-migration-reviewer** — skip if the diff has no files
   under `database/migrations/`.
3. **Stage 6 — security-reviewer** (always).
4. **Stage 7 — api-verifier** — skip if the diff touches no
   routes/controllers/FormRequests/JsonResources.

Each agent writes `.claude/pipeline/<ticket>/NN-<agent>.md` with the
standard header and its findings table. Do not advance to the next stage
until the current stage's artifact is `status: pass` or its blockers are
resolved.

After stage 7, collect every `blocker`/`critical`/`major` finding across
all artifacts and present them to me as ONE consolidated table. Do not fix
anything yet — wait for my go-ahead, then apply fixes in a single batch and
use `/pipeline-status` before any re-review.

Enforce the loop budget: **max 2 rounds per reviewer** (rule L2). If
blockers survive round 2, STOP and hand me the outstanding findings plus
which budget was exhausted — do not start a round 3.
