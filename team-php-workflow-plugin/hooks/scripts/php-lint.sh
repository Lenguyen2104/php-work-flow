#!/usr/bin/env bash
# PostToolUse hook: run Pint (--test) and PHPStan on the just-edited .php file.
# Exit 2 feeds stderr back to Claude so it fixes the file immediately.
set -uo pipefail

HOOK_INPUT=$(cat)
. "$(dirname "$0")/lib.sh"
file=$(hook_json_get tool_input.file_path)

[[ -z "$file" || "$file" != *.php ]] && exit 0

cwd=$(hook_json_get cwd)
cd "${cwd:-.}" 2>/dev/null || exit 0
[[ -f "$file" ]] || exit 0

errors=""

if [[ -x vendor/bin/pint ]]; then
  if ! out=$(vendor/bin/pint --test "$file" 2>&1); then
    errors+="[Pint] Formatting violations in $file:"$'\n'"$out"$'\n'
  fi
fi

if [[ -x vendor/bin/phpstan ]]; then
  if ! out=$(vendor/bin/phpstan analyse --no-progress --error-format=raw "$file" 2>&1); then
    errors+="[PHPStan] $out"$'\n'
  fi
fi

if [[ -n "$errors" ]]; then
  printf '%s\nFix these before continuing. Run vendor/bin/pint "%s" to auto-fix formatting.\n' "$errors" "$file" >&2
  exit 2
fi

exit 0
