# team-php-workflow

Claude Code plugin for the team's Laravel workflow: ClickUp task → plan →
tests → implementation → four-stage review, with hard anti-loop rules.

## Installation

Set up in two places — **Claude Code** (the plugin) and the **Laravel repo**
(the tools the hooks and agents call). All one-time.

### 1. Install the plugin in Claude Code

The plugin is distributed through a **marketplace** — the parent repo that
holds `.claude-plugin/marketplace.json`. Layout:

```
stella-plan/                         ← marketplace root (a git repo)
├─ .claude-plugin/marketplace.json   ← lists the plugin, name "stella-plan"
└─ team-php-workflow-plugin/         ← the plugin (source: ./team-php-workflow-plugin)
   └─ .claude-plugin/plugin.json     ← name "team-php-workflow"
```

**Add the marketplace, then install** (run inside Claude Code):

```
# from the team git repo (normal path for everyone)
/plugin marketplace add <git-url-or-owner/repo-of-the-marketplace>

# …or from a local checkout, for testing before it's pushed
/plugin marketplace add /path/to/stella-plan

/plugin install team-php-workflow@stella-plan
```

The install target is always `<plugin-name>@<marketplace-name>` =
`team-php-workflow@stella-plan`. You can also open the interactive UI with
just `/plugin` and pick it from the list.

**Verify it loaded:**

```
/plugin list   # team-php-workflow shows enabled
/agents        # 6 agents: task-planner … api-verifier
/help          # 4 commands: /run, /plan-ticket, /review, /pipeline-status
```

**Manage it later:**

```
/plugin marketplace update stella-plan          # pull the latest plugin version
/plugin disable team-php-workflow@stella-plan    # turn off, keep installed
/plugin enable  team-php-workflow@stella-plan    # turn back on
```

### 2. Prerequisites in the Laravel repo

The hooks and agents shell out to these — install/confirm them in the target
project:

- `vendor/bin/pint` and `vendor/bin/phpstan` — used by the php-lint hook.
- `docs/openapi/openapi.yaml` — the canonical API spec; plus
  `hotmeteor/spectator` (contract tests) and `spectral` (spec lint).
- `scripts/regenerate-schema-snapshot.sh` — copy it from this plugin's
  `scripts/` into the repo. `docs/schema/` is generated on first run.

### 3. Install the CI gate (recommended)

Copy `ci/team-php-workflow-ci.yml` → `.github/workflows/` in the Laravel
repo, edit the `<<ADJUST>>` spots (PHP version, DB engine), and mark its
three jobs as required status checks. See `ci/README.md`. Hooks give local
feedback in seconds; CI is what a hand-edit or a plain push cannot bypass.

### 4. Authenticate ClickUp

Each person logs in once via OAuth — see the next section.

## Setup — authenticate ClickUp (one-time, per person)

The plugin talks to ClickUp through its **official remote MCP server**
(`https://mcp.clickup.com/mcp`, declared in `.mcp.json`). It uses **OAuth —
there is no API key to configure**. Each team member logs in with their own
ClickUp account through the browser; no shared token lives in the repo.

First run:

1. Open Claude Code in this project and run `/mcp`.
2. Select `clickup` → **Authenticate**. A browser tab opens.
3. Log in to ClickUp and approve workspace access. The token is stored
   locally and reused — you won't be asked again unless it's revoked.
4. Back in `/mcp`, confirm `clickup` shows **connected**.

Notes:

- Stage 1 (`task-planner`) gate "ClickUp task accessible" only passes once
  you're authenticated. If it fails, re-run `/mcp` and check the connection.
- No `CLICKUP_API_KEY` / `CLICKUP_TEAM_ID` env vars are needed anymore — the
  old personal-token setup has been removed.
- To switch accounts or fix a stale login: `/mcp` → `clickup` → re-authenticate.

## Usage — run a ticket end to end

Two ways to drive a ticket: **self-driving** (one command runs everything) or
**manual** (one command per segment, for when you want to inspect between
stages).

### Self-driving — `/team-php-workflow:run <ticket-id>`

```
/team-php-workflow:run ABC-123
```

Runs stages 1→7 on its own and **stops only once** — to let you approve the
plan after stage 1 — then goes hands-off: writes tests, implements until they
pass, runs all reviewers in order, auto-applies every `≥ major` fix, and
re-reviews (round 2) until it reaches a terminal state:

- **Done** — all applicable reviewers `status: pass`.
- **Blocked** — an anti-loop budget (L1/L2/L5) fired, or a finding needs a
  human call (an OpenAPI spec-vs-code conflict, or a security `critical` that
  needs new authorization design). It stops with one consolidated findings
  table + which rule fired + the exact next action. It never starts a round 3
  or auto-resumes; resuming is an explicit instruction from you.

The single plan checkpoint is deliberate — this system holds minors' data, so
you confirm *what* gets built before code and fixes flow automatically. The
loop is defined in `agent-pipeline/orchestrator-loop.md`; the same gates and
budgets apply as in manual mode.

### Manual — one command per segment

The commands standardize the entry points; the hooks keep you on the rails.
A full ticket:

| Step | You run | What happens |
|---|---|---|
| **1. Plan** | `/plan-ticket ABC-123` | task-planner reads the ClickUp task → writes `01-task-planner.md` → summarizes the plan |
| **⛔ Approve** | *review the plan, say "ok" or ask for changes* | **Human approval is required** before stage 2 — the pipeline does not auto-continue |
| **2. Tests** | `write tests from the plan` | test-writer → `02-test-writer.md` (tests derived from acceptance criteria) |
| **3. Implement** | `implement until tests pass` | main session writes the code; every `.php` edit triggers Pint + PHPStan |
| **4–7. Review** | `/review` | convention → migration → security → api-verifier, in order; returns one consolidated findings table |
| **Fix** | *approve, then* `fix the blockers` | fix in a single batch, commit |
| **Re-review** | `/review` | round 2 — only the reviewers that reported findings, scope frozen to changed lines |
| **Confirm** | `/pipeline-status` | Done / In progress / Blocked, plus the exact next action |

**Done** = stages 1–7 complete (legitimately skipped stages don't count),
every applicable reviewer `status: pass`, nothing above `minor` still open.
If a step is **Blocked**, `/pipeline-status` names the gate/budget that
fired and what you need to decide (anti-loop budgets live in the
`agent-pipeline` skill).

Quick start:

```
/plan-ticket ABC-123     # then approve the plan
write tests from the plan
implement until tests pass
/review                  # fix blockers, then /review again if needed
/pipeline-status         # until Done
```

## Skills (knowledge — rules live here, nowhere else)

| Skill | Owns | Primary consumer |
|---|---|---|
| `php-conventions` | PSR-12 + team rules | convention-reviewer |
| `project-architecture` | Layers, DI, no-Repository rule | convention-reviewer, task-planner |
| `api-standards` | REST conventions, error format, versioning, **OpenAPI governance** | api-verifier |
| `phpunit-testing` | Test taxonomy, criteria→test mapping, house style | test-writer |
| `db-migration-safety` | FK/index, NOT NULL backfill, breaking changes, locking | db-migration-reviewer |
| `php-security` | Authz two-layer rule, SQL injection, mass assignment | security-reviewer |
| `database-schema` | How to derive field names from live sources; generated snapshot | ALL agents (shared capability) |
| `stella-domain` | Product business rules (`invariants.md`) + undecided items (`open-questions.md`), distilled from the system-overview deck | task-planner (plan), security-reviewer (RBAC/authz), api-verifier (contract) |
| `agent-pipeline` | Stage order, handoff artifacts, loop budgets L1–L7 | orchestrator (main session) |

Design invariant: **agents contain workflow only; every rule lives in
exactly one skill.** Duplicating a rule into an agent file is version
drift and treated as a defect.

## Agents (workflow — thin wrappers over skills)

| Stage | Agent | Skill(s) read | Skipped when |
|---|---|---|---|
| 1 | task-planner | project-architecture, database-schema, stella-domain, agent-pipeline | never |
| 2 | test-writer | phpunit-testing, database-schema, agent-pipeline | no acceptance criteria → blocked, not skipped |
| 3 | (implementation — main session) | — | — |
| 4 | convention-reviewer | php-conventions, project-architecture, agent-pipeline | never |
| 5 | db-migration-reviewer | db-migration-safety, database-schema, agent-pipeline | no files under `database/migrations/` in diff |
| 6 | security-reviewer | php-security, database-schema, stella-domain, agent-pipeline | never |
| 7 | api-verifier | api-standards, phpunit-testing, stella-domain, agent-pipeline | no routes/controllers/resources in diff |

All agents write artifacts to `.claude/pipeline/<ticket-id>/<NN>-<agent>.md`
with the standard header (`ticket / agent / round / input-commit / status`).
Sequencing, retries, and re-review rounds are governed exclusively by the
`agent-pipeline` skill (budgets: 1 retry on malformed output, 2 review
rounds, round-2 scope freeze, no-progress halt, no agent-to-agent calls).

## Commands (entrypoints — thin wrappers over the pipeline)

| Command | Does | Notes |
|---|---|---|
| `/run <ticket-id>` | **Self-driving** — runs stages 1→7 end to end, stopping only to approve the plan (and on L-rule escalation) | Requires ClickUp OAuth; auto-applies `≥ major` fixes, obeys the 2-round budget |
| `/plan-ticket <ticket-id>` | Dispatches stage 1 (task-planner) for a ClickUp ticket, then stops for human approval of the plan | Requires ClickUp OAuth (see Setup) |
| `/review [ticket-id]` | Runs the review stages 4→7 in order on the current diff, honoring `pipeline-gate.sh`, and returns one consolidated findings table | Defaults to the newest ticket dir; enforces the 2-round budget |
| `/pipeline-status [ticket-id]` | Read-only report of which stages ran, their round/status, open blockers, and the next action | Never dispatches or edits |

For the step-by-step walkthrough see **Usage** above. Everything the
commands do is still governed by the `agent-pipeline` skill and the hooks —
the commands only standardize how a run is kicked off.

## Enforcement layers (tooling over prose)

Two enforcement points on purpose: **hooks** give per-edit feedback in
seconds on a dev machine; **CI** is the per-PR final authority a hand-edit,
a parser-less machine, or a plain push cannot slip past. Same logic, both
places.

| Check | Hook (per-edit) | CI (per-PR) |
|---|---|---|
| Pint + PHPStan on edited .php | `php-lint.sh` ✅ tested | — (run your existing test/lint job) |
| Pipeline gates + round budget L2 | `pipeline-gate.sh` ✅ tested | n/a (dispatch-time only) |
| OpenAPI drift (API-surface edit ⇒ spec edit) | `openapi-drift-guard.sh` ✅ tested | `openapi-drift` job ✅ |
| OpenAPI spec lint | api-verifier step 1 (`spectral lint`) | `spec-lint` job ✅ |
| Schema snapshot freshness | `migration-snapshot-reminder.sh` ✅ tested | `schema-snapshot` job ✅ |

All four hooks have functional tests in **`hooks/tests/run.sh`** (30 cases;
feeds JSON events on stdin, asserts exit code + stderr). Run after touching
any hook. The three CI jobs are a copy-in template under **`ci/`** — install
them in the Laravel repo (see `ci/README.md`); they replicate the same
verified logic at the PR boundary.

Hook scripts share `hooks/scripts/lib.sh` (JSON parsing with jq → python3 →
php fallback; a machine with none degrades to hooks-off, never hooks-broken).
Requirements in the target repo: `vendor/bin/pint`, `vendor/bin/phpstan`,
`docs/openapi/openapi.yaml`, and `hotmeteor/spectator` + `spectral` for
api-verifier.

## Sources of truth

- Schema: `database/migrations/` (only writer) → generated `docs/schema/`
- API contract: `docs/openapi/openapi.yaml` (hand-maintained, canonical)
- Rules: `skills/*/SKILL.md`
- Diagrams: draw.io files (per team convention)

Everything derived from these is generated, never hand-edited.
