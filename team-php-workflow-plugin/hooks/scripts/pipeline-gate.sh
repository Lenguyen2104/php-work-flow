#!/usr/bin/env bash
# PreToolUse hook on the Task tool: mechanical enforcement of the
# agent-pipeline skill's gates (stage order + round budget L2).
#
# Gate = predecessor artifact exists in the newest .claude/pipeline/<ticket>/
# directory AND contains `status: pass` or `blockers-resolved: true`.
# Round budget: an agent whose artifact already shows `round: 2` may not be
# dispatched again (rule L2 — escalate to human instead).
#
# Exit 2 blocks the Task call; stderr explains why.
set -uo pipefail

HOOK_INPUT=$(cat)
. "$(dirname "$0")/lib.sh"
agent=$(hook_json_get tool_input.subagent_type)
[[ -z "$agent" ]] && exit 0

case "$agent" in
  task-planner) exit 0 ;;  # stage 1: no predecessor
  test-writer|convention-reviewer|db-migration-reviewer|security-reviewer|api-verifier) ;;
  *) exit 0 ;;             # not a pipeline agent: don't interfere
esac

cwd=$(hook_json_get cwd)
cd "${cwd:-.}" 2>/dev/null || exit 0

pipedir=$(ls -td .claude/pipeline/*/ 2>/dev/null | head -1)
if [[ -z "$pipedir" ]]; then
  echo "pipeline-gate: no .claude/pipeline/<ticket>/ directory exists. Stage 1 (task-planner) must run first and create the ticket workspace." >&2
  exit 2
fi

ok() { # ok <artifact-basename-without-ext>
  local f="$pipedir$1.md"
  [[ -f "$f" ]] || return 1
  grep -Eq '^status:[[:space:]]*pass' "$f" && return 0
  grep -Eq '^blockers-resolved:[[:space:]]*true' "$f" && return 0
  return 1
}

require() { # require <artifact> <human-readable-stage>
  if ! ok "$1"; then
    echo "pipeline-gate: cannot dispatch '$agent' — gate not satisfied. Required: $pipedir$1.md with 'status: pass' (or 'blockers-resolved: true'). $2" >&2
    exit 2
  fi
}

# Round budget (L2): if this agent already produced a round-2 artifact, stop.
self_artifact=$(ls "$pipedir" 2>/dev/null | grep -E "^[0-9]{2}-$agent\.md$" | head -1)
if [[ -n "$self_artifact" ]] && grep -Eq '^round:[[:space:]]*2' "$pipedir$self_artifact"; then
  echo "pipeline-gate: '$agent' has exhausted its round budget (2) for this ticket. Rule L2: stop and escalate the outstanding findings to the human. To resume after human review, they must remove or amend $pipedir$self_artifact." >&2
  exit 2
fi

case "$agent" in
  test-writer)
    require "01-task-planner" "Human approval of the plan is also required (see agent-pipeline skill)."
    ;;
  convention-reviewer)
    : # gate is 'linters pass', enforced by the php-lint PostToolUse hook
    ;;
  db-migration-reviewer)
    require "04-convention-reviewer" "Stage 4 must pass before stage 5."
    ;;
  security-reviewer)
    require "04-convention-reviewer" "Stage 4 must pass before stage 6."
    # stage 5 is conditional: enforce only if its artifact exists (migrations were in the diff)
    if [[ -f "${pipedir}05-db-migration-reviewer.md" ]] && ! ok "05-db-migration-reviewer"; then
      echo "pipeline-gate: cannot dispatch 'security-reviewer' — 05-db-migration-reviewer.md exists but is not passed/resolved." >&2
      exit 2
    fi
    ;;
  api-verifier)
    require "06-security-reviewer" "Stage 6 must pass before stage 7."
    ;;
esac

exit 0
