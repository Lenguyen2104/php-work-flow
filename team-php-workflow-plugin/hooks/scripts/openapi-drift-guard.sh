#!/usr/bin/env bash
# PostToolUse hook: the OpenAPI sync rule (api-standards skill).
# If an API-surface file was edited but docs/openapi/ has no working-tree
# change, remind Claude to update the spec in the same change.
set -uo pipefail

HOOK_INPUT=$(cat)
. "$(dirname "$0")/lib.sh"
file=$(hook_json_get tool_input.file_path)
[[ -z "$file" ]] && exit 0

# Leading "/" normalizes the match so a relative path (app/Http/...) and an
# absolute one (/repo/app/Http/...) both hit the same */... patterns.
case "/$file" in
  */app/Http/Requests/*.php|*/app/Http/Resources/*.php|*/app/Http/Controllers/*.php|*/routes/api.php) ;;
  *) exit 0 ;;
esac

cwd=$(hook_json_get cwd)
cd "${cwd:-.}" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Spec already touched in this working tree → sync rule satisfied for now.
if git status --porcelain -- docs/openapi/ 2>/dev/null | grep -q .; then
  exit 0
fi

cat >&2 <<EOF
[OpenAPI sync rule] $file is API surface, but docs/openapi/ has no changes in the working tree.
Per the api-standards skill: update docs/openapi/openapi.yaml in this SAME change
(requestBody/response schemas, status codes, security), or state a
'contract-invisible' justification if the wire format is truly unchanged.
EOF
exit 2
