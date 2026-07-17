# stella-plan — Claude Code plugin marketplace

This repo is a **plugin marketplace**. It ships one plugin:

| Plugin | Source | What it is |
|---|---|---|
| `team-php-workflow` | `./team-php-workflow-plugin` | Laravel team workflow: ClickUp task → plan → tests → four-stage review, with anti-loop gates. See its [README](./team-php-workflow-plugin/README.md). |

The marketplace itself is defined in
[`.claude-plugin/marketplace.json`](./.claude-plugin/marketplace.json)
(name: `stella-plan`).

## Use it (team members)

```
/plugin marketplace add <this-repo-git-url>     # or a local path for testing
/plugin install team-php-workflow@stella-plan
```

Full setup and usage — including the Laravel-repo prerequisites, ClickUp
OAuth, and the ticket workflow — are in the plugin's
[README](./team-php-workflow-plugin/README.md).

## Publish / maintain it (marketplace owner)

1. This directory is the marketplace root. Make it a git repo and push it
   somewhere the team can reach (GitHub/GitLab):
   ```
   git init && git add . && git commit -m "team-php-workflow marketplace"
   git remote add origin <url> && git push -u origin main
   ```
2. Share the repo URL; members run the two commands above.
3. To release a new plugin version: bump `version` in
   `team-php-workflow-plugin/.claude-plugin/plugin.json`, commit, push.
   Members pick it up with `/plugin marketplace update stella-plan`.

**Invariants:** the plugin entry `name` in `marketplace.json` must equal the
`name` in the plugin's `plugin.json` (both `team-php-workflow`); `source` is
a `./`-relative path resolved from this root.
