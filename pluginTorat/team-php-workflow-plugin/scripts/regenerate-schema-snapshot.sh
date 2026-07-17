#!/usr/bin/env bash
# Regenerates docs/schema/ from the live (migrated) dev database.
# Run from the Laravel project root AFTER `php artisan migrate`.
# CI freshness check: run this script, then `git diff --exit-code docs/schema/`.
set -euo pipefail

if [[ ! -f artisan ]]; then
  echo "Run from the Laravel project root (artisan not found)." >&2
  exit 1
fi

mkdir -p docs/schema

shopt -s nullglob
for f in app/Models/*.php; do
  model=$(basename "$f" .php)
  if php artisan model:show "App\\Models\\${model}" --json > "docs/schema/${model}.json" 2>/dev/null; then
    echo "ok   ${model}"
  else
    rm -f "docs/schema/${model}.json"
    echo "skip ${model} (not a showable model)" >&2
  fi
done

echo "Snapshot regenerated. Commit docs/schema/ together with the migration."
