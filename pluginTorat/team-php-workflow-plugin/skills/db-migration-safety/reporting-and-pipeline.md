# DB Migration Safety — Reporting & pipeline position

Companion to [`SKILL.md`](./SKILL.md) (the 6-point review checklist). This
file holds the db-migration-reviewer output contract and the skill's place in
the pipeline.

## Output contract for the db-migration-reviewer agent

Produce a findings table:

| # | Severity | Location | Issue | Why it passes review but breaks prod | Fix |

Severity levels: `blocker` (will fail or lock in prod), `major` (data
integrity / performance risk), `minor` (convention). Include the concrete
corrected migration code for every blocker and major. If table sizes are
unknown, state the assumption ("assuming `students` exceeds 100k rows in
production") rather than guessing silently.

## Pipeline position

Stage 5 of the agent pipeline (see the `agent-pipeline` skill — its rules
override this section on conflict). Gate to start: convention-reviewer's
artifact (`04-*.md`) has `status: pass` or all its blockers are marked
resolved. Skipped entirely when the diff contains no files under
`database/migrations/`. Write output to
`.claude/pipeline/<ticket-id>/05-db-migration-reviewer.md` with the standard
header. Finding IDs use `db-migration-reviewer/<rule>/<file>:<symbol>`.
Round-2 runs verify prior findings and newly changed lines only (rule L3);
never re-report `wontfix` findings. Do not invoke any other agent — issues
outside migration scope get `severity: info, route-to: <agent>`.
