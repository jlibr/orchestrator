---
name: pipe-status
description: "Show current pipeline state, progress, and any open issues"
---

# /pipe-status — Pipeline Status

Show the current state of the active pipeline.

## Steps

1. Read `.claude/pipeline/state.yaml`. If it doesn't exist, report "No pipeline initialized."

2. Display a formatted status report:

```
Pipeline: {session_name}
Status:   {status}
Phase:    {current_phase} (cycle {cycle}/{max_cycles})
Agent:    {current_agent}
Started:  {started_at}

Phases completed: {phases_completed}
Issues: {issues_open} open / {issues_resolved} resolved

Agent Status:
  {agent-1}: {status}
  {agent-2}: {status}

Gate Verdicts:
  {phase-1}: {verdict}
```

3. If there are open issues, list them with severity and target agent.

4. If a worktree is active, show the branch name and path.

5. If status is `done`, show the final verdict and any remaining findings from the last review cycle.

6. If status is `failed` or `cancelled`, show what completed before the stop and any error context.
