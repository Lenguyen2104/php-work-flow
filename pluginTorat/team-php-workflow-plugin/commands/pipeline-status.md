---
description: Show the pipeline state for the current (or named) ticket — stages, findings, round budgets.
argument-hint: [ticket-id]
allowed-tools: Bash(ls:*), Bash(cat:*), Read, Glob, Grep
---

Report the pipeline state for ticket **$ARGUMENTS** (if omitted, use the
newest directory under `.claude/pipeline/`). This is read-only — do NOT
dispatch any agent, edit any file, or fix anything.

Inspect the artifacts in `.claude/pipeline/<ticket>/` and produce a table:

| Stage | Agent | Artifact | Round | Status | Open blockers/criticals/majors |
|-------|-------|----------|-------|--------|-------------------------------|

For each stage 1–7:

- If the artifact file is missing, mark it **not run** (and note whether it
  is legitimately *skipped* — no migrations for stage 5, no API surface for
  stage 7 — vs simply pending).
- Read the header for `round` and `status`, and count unresolved findings
  at severity ≥ major from the findings table.
- Flag any artifact that shows `round: 2` — that reviewer has exhausted its
  budget (rule L2); if blockers remain it means **escalate to human**.

Then give a one-line verdict:

- **Done** — stages 1–7 complete (applicable stages), every reviewer
  `status: pass`, nothing above minor open.
- **In progress** — name the next stage that should run and its gate.
- **Blocked** — an L-rule fired; state which and what I need to decide.

End with the exact next action I should take (e.g. "approve the plan then
run `/review`", or "resolve these 2 blockers, then re-review stage 6").
