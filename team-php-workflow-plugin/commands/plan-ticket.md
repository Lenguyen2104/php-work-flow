---
description: Start the pipeline for a ClickUp ticket — dispatch stage 1 (task-planner).
argument-hint: <ticket-id>
---

Begin the team pipeline for ClickUp ticket **$ARGUMENTS**.

First read `skills/agent-pipeline/SKILL.md` for the artifact header format,
stage order, and gate rules — they govern everything below.

Then dispatch the **task-planner** agent (stage 1) via the Task tool with
`subagent_type: task-planner`. Pass the ticket id `$ARGUMENTS` so it can
fetch the task through the ClickUp MCP server. The agent must write its
plan to `.claude/pipeline/$ARGUMENTS/01-task-planner.md` with the standard
header.

When it returns:

1. Show me a concise summary of the plan — normalized acceptance criteria,
   affected tables/endpoints/screens, and any risk flags.
2. **Stop and wait for my explicit approval.** Stage 2 (test-writer) is
   gated on human approval of the plan; do not dispatch it automatically.
3. If the task has no acceptance criteria, do not improvise — report it as
   `blocked` per the skill and ask me how to proceed.

If the ClickUp fetch fails, tell me to run `/mcp` → `clickup` →
Authenticate, then retry — do not fall back to guessing the task content.
