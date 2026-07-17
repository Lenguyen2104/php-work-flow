---
name: agent-pipeline
description: >
  Orchestration rules for the team's sub-agent pipeline (task-planner,
  test-writer, convention-reviewer, db-migration-reviewer, security-reviewer,
  api-verifier). Use this skill whenever dispatching, sequencing, or re-running
  any sub-agent, whenever a review/fix cycle is about to repeat, or whenever
  deciding which agent runs next. Consult it BEFORE invoking any agent — it
  defines hard gates and loop budgets that override ad-hoc judgment.
---

# Agent Pipeline & Loop Prevention

## Purpose

Sub-agents run in a strict sequence. An agent may start only after the
previous agent has produced a valid output artifact. Review/fix cycles are
bounded. When a bound is hit, the pipeline STOPS and escalates to the human
— it never loops "one more time" on its own.

## Topology

Only the main session (orchestrator) dispatches agents. **Agents never
invoke other agents** and never decide what runs next; they read their
input artifact, produce their output artifact, and terminate. All
sequencing decisions live here, in one place.

## Handoff artifacts

Every agent writes its output (per its skill's Output Contract) to:

```
.claude/pipeline/<ticket-id>/<NN>-<agent-name>.md
```

The gate for stage N+1 is: **the stage-N file exists AND conforms to the
stage-N output contract** (has the required table/sections). A missing or
malformed artifact means the gate is closed.

Each artifact carries a header:

```
ticket: <id>
agent: <name>
round: <n>          # 1 = first run, 2 = re-review, ...
input-commit: <sha> # the code state that was reviewed/generated against
status: pass | findings | blocked
```

`input-commit` matters: a reviewer's findings are only valid for the commit
they reviewed. Re-running against the same commit is a no-op by definition
(see Rule L5).

When the orchestrator fixes all blockers from an artifact whose status is
`findings`, it appends `blockers-resolved: true` to that artifact's header
(with a one-line note per resolved finding ID). The pipeline-gate hook
accepts either `status: pass` or this marker as gate satisfaction — never
edit `status` itself; it records what the agent concluded.

## Stage order

| Stage | Agent | Gate (input required) | Skip condition |
|-------|-------|----------------------|----------------|
| 1 | task-planner | ClickUp task accessible | never |
| 2 | test-writer | 01-task-planner.md valid; human approved the plan | task has no acceptance criteria → escalate instead |
| 3 | (implementation — main session, not an agent) | 02-test-writer.md valid | — |
| 4 | convention-reviewer | implementation diff exists; hooks (phpcs/phpstan) pass | never — always runs |
| 5 | db-migration-reviewer | 04 artifact `status: pass` or all its blockers resolved | diff contains no files under database/migrations/ |
| 6 | security-reviewer | previous stage gate passed | never — always runs |
| 7 | api-verifier | previous stage gate passed | diff touches no routes/controllers/resources |

Stage 4–7 order is fixed on purpose: mechanical → structural → security →
contract. A convention fix can invalidate a security review; the reverse is
rarer. Fixed order means one direction of invalidation, not ping-pong.

## The fix cycle

After stage 7, the orchestrator collects all `blocker`/`critical`/`major`
findings, fixes them in ONE batch, commits, then re-runs **only the
reviewers that reported those findings**, in stage order, as round 2.

## Loop-prevention rules (hard limits)

The seven hard limits (L1–L7) that bound review/fix cycles — retry budgets,
round budgets, scope freeze, stable finding IDs, no-progress detection,
cross-agent routing, and terminal escalation — are documented in a companion
file. Consult it BEFORE re-running any agent; these rules override ad-hoc
judgment:

→ See [`loop-prevention-rules.md`](./loop-prevention-rules.md)

## Terminal states

- **Done**: stages 1–7 complete, latest round of every applicable reviewer
  reports `status: pass` (no unresolved findings above `minor`).
- **Blocked**: any L-rule triggered. Deliverable to human: the outstanding
  findings tables + which budget was exhausted + the orchestrator's
  one-paragraph diagnosis of why fixes aren't converging.

There is no third state. "Keep trying" is not a state.
