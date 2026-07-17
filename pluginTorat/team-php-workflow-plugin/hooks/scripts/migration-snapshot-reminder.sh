#!/usr/bin/env bash
# PostToolUse hook: when a migration file is created/edited, remind Claude to
# refresh the generated schema snapshot (database-schema skill). The snapshot
# regeneration itself requires a migrated dev DB, so it is not auto-run here.
set -uo pipefail

HOOK_INPUT=$(cat)
. "$(dirname "$0")/lib.sh"
file=$(hook_json_get tool_input.file_path)
[[ -z "$file" ]] && exit 0

# Leading "/" normalizes the match so a relative path (database/migrations/..)
# and an absolute one (/repo/database/migrations/..) both match.
case "/$file" in
  */database/migrations/*.php) ;;
  *) exit 0 ;;
esac

cwd=$(hook_json_get cwd)
cd "${cwd:-.}" 2>/dev/null || exit 0

# If snapshot already changed in this working tree, assume it's being handled.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
   && git status --porcelain -- docs/schema/ 2>/dev/null | grep -q .; then
  exit 0
fi

cat >&2 <<EOF
[Schema snapshot] $file changes the schema. After migrating the dev database,
regenerate the snapshot so docs/schema/ stays in sync (database-schema skill):
  bash scripts/regenerate-schema-snapshot.sh
Commit the regenerated files together with this migration. CI fails on a stale snapshot.
EOF
exit 2
