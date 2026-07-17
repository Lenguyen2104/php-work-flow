# PHPUnit Testing — Reporting & pipeline position

Companion to [`SKILL.md`](./SKILL.md) (taxonomy, criteria→test mapping, house
style, class structure). This file holds the test-writer output contract and
the skill's place in the pipeline.

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
