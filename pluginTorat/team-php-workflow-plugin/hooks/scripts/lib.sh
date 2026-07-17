#!/usr/bin/env bash
# Shared helpers for hook scripts. Source this; do not execute.
#
# hook_json_get <dotted.path>
#   Extracts a string field from the JSON in $HOOK_INPUT.
#   Fallback chain: jq -> python3 -> php (a Laravel dev machine always has
#   php). If none exists, prints nothing — callers treat empty as "field
#   absent" and exit 0, so a machine with no parser degrades to hooks-off
#   rather than hooks-broken.

hook_json_get() {
  local path="$1"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$HOOK_INPUT" | jq -r ".${path} // empty"
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$HOOK_INPUT" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit()
for k in sys.argv[1].split("."):
    d = d.get(k) if isinstance(d, dict) else None
    if d is None:
        sys.exit()
if isinstance(d, str):
    sys.stdout.write(d)
' "$path"
  elif command -v php >/dev/null 2>&1; then
    printf '%s' "$HOOK_INPUT" | php -r '
$d = json_decode(stream_get_contents(STDIN), true);
foreach (explode(".", $argv[1]) as $k) {
    if (!is_array($d) || !array_key_exists($k, $d)) { exit; }
    $d = $d[$k];
}
if (is_string($d)) { echo $d; }
' "$path"
  fi
}
