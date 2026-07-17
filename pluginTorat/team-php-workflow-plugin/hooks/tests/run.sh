#!/usr/bin/env bash
# Functional tests for the hook scripts in ../scripts.
#
# Each test builds a throwaway working tree under $WORK, feeds a JSON event
# to the hook on stdin (exactly as Claude Code's hook runner does), and
# asserts the exit code and stderr. Exit 2 = "block/remind Claude"; exit 0 =
# "let it pass". Run: bash hooks/tests/run.sh
#
# Requires the same JSON parser the hooks require (jq, or python3, or php).
set -uo pipefail

HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
WORK="$(mktemp -d)"
ERRFILE="$(mktemp)"
trap 'rm -rf "$WORK" "$ERRFILE"' EXIT

pass=0 fail=0

# mkinput_file <cwd> <file_path>  -> PostToolUse-style event JSON
mkinput_file() { jq -nc --arg cwd "$1" --arg fp "$2" \
  '{cwd:$cwd, tool_input:{file_path:$fp}}'; }
# mkinput_agent <cwd> <subagent_type>  -> Task event JSON
mkinput_agent() { jq -nc --arg cwd "$1" --arg st "$2" \
  '{cwd:$cwd, tool_input:{subagent_type:$st}}'; }

# run <script> <json>  -> sets RC and ERR
run() {
  printf '%s' "$2" | bash "$HOOKS_DIR/$1" >/dev/null 2>"$ERRFILE"
  RC=$?
  ERR="$(cat "$ERRFILE")"
}

# check <label> <expected_rc> [stderr_substring]
check() {
  local label="$1" exp="$2" sub="${3-}" ok=1 why=""
  if [[ "$RC" != "$exp" ]]; then ok=0; why="exit $RC != $exp"; fi
  if [[ -n "$sub" && "$ERR" != *"$sub"* ]]; then
    ok=0; why="${why:+$why; }stderr missing '$sub'"
  fi
  if [[ "$ok" == 1 ]]; then
    printf '  ok   %s\n' "$label"; ((pass++))
  else
    printf '  FAIL %s — %s\n' "$label" "$why"; ((fail++))
  fi
}

newrepo() { # newrepo <name> [--git]  -> echoes the dir path
  local d="$WORK/$1"; mkdir -p "$d"
  [[ "${2-}" == "--git" ]] && git -C "$d" init -q >/dev/null 2>&1
  printf '%s' "$d"
}

# ---------------------------------------------------------------------------
echo "== php-lint.sh =="
R="$(newrepo phplint)"
mkdir -p "$R/vendor/bin"; : >"$R/notes.txt"; : >"$R/src.php"

run php-lint.sh "$(mkinput_file "$R" "")"
check "empty file_path -> pass" 0

run php-lint.sh "$(mkinput_file "$R" "$R/notes.txt")"
check "non-.php file -> pass" 0

run php-lint.sh "$(mkinput_file "$R" "$R/ghost.php")"
check ".php not on disk -> pass" 0

run php-lint.sh "$(mkinput_file "$R" "$R/src.php")"
check ".php, no pint/phpstan installed -> pass" 0

# fake failing pint
printf '#!/bin/sh\necho "line too long"; exit 1\n' >"$R/vendor/bin/pint"
chmod +x "$R/vendor/bin/pint"
run php-lint.sh "$(mkinput_file "$R" "$R/src.php")"
check "pint reports violations -> block" 2 "[Pint]"

# pint passes, phpstan fails
printf '#!/bin/sh\nexit 0\n' >"$R/vendor/bin/pint"
printf '#!/bin/sh\necho "undefined variable"; exit 1\n' >"$R/vendor/bin/phpstan"
chmod +x "$R/vendor/bin/phpstan"
run php-lint.sh "$(mkinput_file "$R" "$R/src.php")"
check "phpstan reports errors -> block" 2 "[PHPStan]"

# both pass
printf '#!/bin/sh\nexit 0\n' >"$R/vendor/bin/phpstan"
run php-lint.sh "$(mkinput_file "$R" "$R/src.php")"
check "pint+phpstan both clean -> pass" 0

# ---------------------------------------------------------------------------
echo "== openapi-drift-guard.sh =="
run openapi-drift-guard.sh "$(mkinput_file "$WORK" "")"
check "empty file_path -> pass" 0

G="$(newrepo drift --git)"
run openapi-drift-guard.sh "$(mkinput_file "$G" "$G/app/Models/User.php")"
check "non-API-surface file -> pass" 0

NG="$(newrepo drift-nogit)"
run openapi-drift-guard.sh "$(mkinput_file "$NG" "$NG/app/Http/Controllers/IepController.php")"
check "API surface but not a git repo -> pass" 0

mkdir -p "$G/docs/openapi"; : >"$G/docs/openapi/openapi.yaml"   # untracked spec change
run openapi-drift-guard.sh "$(mkinput_file "$G" "$G/app/Http/Controllers/IepController.php")"
check "API surface + spec touched -> pass" 0

rm -rf "$G/docs"   # spec now clean
run openapi-drift-guard.sh "$(mkinput_file "$G" "$G/app/Http/Requests/StoreIepRequest.php")"
check "API surface + spec clean -> block" 2 "[OpenAPI sync rule]"

run openapi-drift-guard.sh "$(mkinput_file "$G" "$G/routes/api.php")"
check "routes/api.php + spec clean -> block" 2 "[OpenAPI sync rule]"

# relative path (Claude passes absolute, but the pattern must not silently miss)
run openapi-drift-guard.sh "$(mkinput_file "$G" "app/Http/Controllers/IepController.php")"
check "relative API path + spec clean -> block" 2 "[OpenAPI sync rule]"

# ---------------------------------------------------------------------------
echo "== migration-snapshot-reminder.sh =="
run migration-snapshot-reminder.sh "$(mkinput_file "$WORK" "")"
check "empty file_path -> pass" 0

M="$(newrepo migration --git)"
run migration-snapshot-reminder.sh "$(mkinput_file "$M" "$M/app/Models/User.php")"
check "non-migration file -> pass" 0

mkdir -p "$M/docs/schema"; : >"$M/docs/schema/tables.md"   # untracked snapshot change
run migration-snapshot-reminder.sh "$(mkinput_file "$M" "$M/database/migrations/2026_01_01_000000_x.php")"
check "migration + snapshot touched -> pass" 0

rm -rf "$M/docs"   # snapshot clean
run migration-snapshot-reminder.sh "$(mkinput_file "$M" "$M/database/migrations/2026_01_01_000000_x.php")"
check "migration + snapshot clean -> remind" 2 "[Schema snapshot]"

MNG="$(newrepo migration-nogit)"
run migration-snapshot-reminder.sh "$(mkinput_file "$MNG" "$MNG/database/migrations/2026_01_01_000000_x.php")"
check "migration + not a git repo -> remind" 2 "[Schema snapshot]"

run migration-snapshot-reminder.sh "$(mkinput_file "$M" "database/migrations/2026_01_01_000000_x.php")"
check "relative migration path + snapshot clean -> remind" 2 "[Schema snapshot]"

# ---------------------------------------------------------------------------
echo "== pipeline-gate.sh =="
P="$(newrepo pipeline)"; PD="$P/.claude/pipeline/ABC-123"; mkdir -p "$PD"
hdr() { printf 'ticket: ABC-123\nagent: %s\nround: %s\nstatus: %s\n' "$1" "$2" "$3"; }

run pipeline-gate.sh "$(mkinput_agent "$P" "")"
check "empty subagent_type -> pass" 0

run pipeline-gate.sh "$(mkinput_agent "$P" "general-purpose")"
check "non-pipeline agent -> pass" 0

run pipeline-gate.sh "$(mkinput_agent "$P" "task-planner")"
check "task-planner (stage 1, no predecessor) -> pass" 0

Pempty="$(newrepo pipeline-empty)"; mkdir -p "$Pempty/.claude/pipeline"
run pipeline-gate.sh "$(mkinput_agent "$Pempty" "test-writer")"
check "test-writer, no ticket dir -> block" 2 "task-planner"

hdr task-planner 1 pass >"$PD/01-task-planner.md"
run pipeline-gate.sh "$(mkinput_agent "$P" "test-writer")"
check "test-writer, 01 status:pass -> pass" 0

hdr task-planner 1 findings >"$PD/01-task-planner.md"
run pipeline-gate.sh "$(mkinput_agent "$P" "test-writer")"
check "test-writer, 01 status:findings -> block" 2

{ hdr task-planner 1 findings; echo "blockers-resolved: true"; } >"$PD/01-task-planner.md"
run pipeline-gate.sh "$(mkinput_agent "$P" "test-writer")"
check "test-writer, 01 blockers-resolved:true -> pass" 0

hdr convention-reviewer 1 pass >"$PD/04-convention-reviewer.md"
run pipeline-gate.sh "$(mkinput_agent "$P" "security-reviewer")"
check "security-reviewer, 04 pass, no 05 -> pass" 0

hdr db-migration-reviewer 1 findings >"$PD/05-db-migration-reviewer.md"
run pipeline-gate.sh "$(mkinput_agent "$P" "security-reviewer")"
check "security-reviewer, 05 exists but not passed -> block" 2

hdr convention-reviewer 2 findings >"$PD/04-convention-reviewer.md"
run pipeline-gate.sh "$(mkinput_agent "$P" "convention-reviewer")"
check "convention-reviewer at round 2 -> block (L2 budget)" 2 "round budget"

# ---------------------------------------------------------------------------
echo
echo "-------------------------------------"
printf 'passed: %d   failed: %d\n' "$pass" "$fail"
[[ "$fail" == 0 ]]
