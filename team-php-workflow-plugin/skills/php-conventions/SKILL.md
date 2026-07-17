---
name: php-conventions
description: >
  Team PHP coding conventions: PSR-12 via Pint plus tier-2 semantic rules
  that linters cannot enforce. Use this skill whenever writing, editing, or
  reviewing any PHP code in this project — naming, comments, types,
  formatting — and whenever the convention-reviewer agent runs. The
  authoritative long-form document is CODING_STANDARDS.md in the project
  repo; this skill is its enforcement summary.
---

# PHP Conventions

> The canonical long-form document is `CODING_STANDARDS.md` in the project
> repo. On conflict, `CODING_STANDARDS.md` wins; keep this skill in sync.

Structure mirrors the five-section standard:
(1) Naming, (2) Directory structure, (3) Formatting, (4) Lint, (5) Dev rules.

## 1. Naming (命名規則)

- Classes/Enums: StudlyCase. Methods/variables: camelCase. Constants:
  SCREAMING_SNAKE. DB tables/columns: snake_case, tables plural.
- Names state behavior truthfully — a method named `getX()` must not
  mutate state; `updateX()` must not silently create. Lying names are a
  convention-reviewer finding.
- Suffixes by role: `*Controller`, `*Service`, `*Request` (FormRequest),
  `*Resource` (JsonResource). Utils classes are nouns, not `*Helper`.

## 2. Directory structure (ディレクトリ構成)

See the `project-architecture` skill for layer semantics. Placement here:

- `app/Services/` — business logic, calls Eloquent directly (no
  Repository layer, confirmed decision).
- `app/Utils/` — pure, business-agnostic, static helpers. No Eloquent,
  no container, no config access.
- `app/Http/Requests|Resources|Controllers` — HTTP layer only.

## 3. Formatting (ソースコードフォーマット)

- `declare(strict_types=1);` in every PHP file, no exceptions.
- Formatting is whatever `pint.json` says — never argue style in review;
  the php-lint hook runs `pint --test` on every edit. Change style by
  changing `pint.json`, not per-file.

## 4. Lint

- Pint (`pint.json`) + PHPStan must pass before any code review begins;
  the convention-reviewer's gate requires clean linters.
- Baseline additions to silence PHPStan require justification in the PR.

## 5. Development rules (開発ルール)

- **English only** in code: identifiers, comments, commit-facing strings.
  Vietnamese/Japanese appear only in user-facing translation files and in
  test fixtures that deliberately test multibyte input (marked with a
  comment). Pipeline artifacts and plan/review prose are NOT code — they
  are written in Vietnamese per the `agent-pipeline` skill's "Output
  language" section. This rule applies to the standards documents' own examples —
  self-consistency is checked.
- Explicit return types and parameter types everywhere; `mixed` requires
  a comment explaining why.
- `env()` is called ONLY inside `config/` files; everywhere else uses
  `config()`.
- Multi-table writes are wrapped in `DB::transaction()`.
- Mutable workflow entities use optimistic locking (`lock_version`);
  update paths must check-and-increment it.
- No dead code, no commented-out code committed.
- **No code comments** beyond the exceptions listed in the
  `implementation` skill (phpstan-required PHPDoc, runtime attributes,
  the justifications this file demands). That skill owns the rule; a
  comment outside its allowed list is a `major` finding.
