---
description: Self-driving pipeline — run all stages (1→7) for a ClickUp ticket, stopping only to approve the plan.
argument-hint: <ticket-id>
---

Drive the **entire** team pipeline for ClickUp ticket **$ARGUMENTS** end to
end, self-managed. You are the sole orchestrator; agents never dispatch each
other.

Before doing anything, read — they govern every decision below and override
ad-hoc judgment:

- `skills/agent-pipeline/SKILL.md` — artifact header, stage order, gates.
- `skills/agent-pipeline/orchestrator-loop.md` — the self-driving procedure.
- `skills/agent-pipeline/loop-prevention-rules.md` — the hard limits L1–L7.

Then follow the **Drive sequence** in `orchestrator-loop.md` exactly:

1. Dispatch **task-planner** (stage 1) via the Task tool
   (`subagent_type: task-planner`), passing `$ARGUMENTS` so it fetches the
   task through the ClickUp MCP. It writes
   `.claude/pipeline/$ARGUMENTS/01-task-planner.md`.
2. Summarize the plan and **STOP for my approval.** This is the ONLY pause —
   do not ask me anything else until the pipeline reaches a terminal state.
3. After I approve: run stage 2 (test-writer) → stage 3 (you implement until
   the tests pass) → stages 4–7 (reviewers, in order, honoring gates and skip
   conditions) → the auto fix cycle → round 2 for the reviewers that reported
   `≥ major` findings. Apply fixes per the **Auto-apply rules**.
4. End in one terminal state only:
   - **Done** — all applicable reviewers `status: pass`; report the
     consolidated result.
   - **Blocked** — an L-rule or a flagged human-call finding fired; STOP,
     give me one consolidated findings table + which budget/rule was hit +
     your one-paragraph diagnosis + the exact next action. Do not start a
     round 3 or auto-resume.

Respect the `pipeline-gate.sh` hook's blocks — never work around a gate.

If the ClickUp fetch fails, tell me to run `/mcp` → `clickup` → Authenticate,
then retry — never fall back to guessing the task content.
