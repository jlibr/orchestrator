---
name: pipe-cancel
description: "Cancel the active pipeline and clean up state"
---

# /pipe-cancel — Cancel Pipeline

Cancel the currently running pipeline and perform cleanup.

## Steps

1. Read `.claude/pipeline/state.yaml`. If it doesn't exist or status is already terminal (`done`, `failed`, `cancelled`), report "No active pipeline to cancel." If status is `idle` but a session directory exists, treat it as cancellable (session was initialized but never started).

2. Confirm with the user: "Cancel pipeline '{session_name}' currently in phase '{current_phase}'? Session artifacts will be preserved."

3. On confirmation:
   - Update state.yaml: `status: cancelled`
   - Report what was completed and what was in progress

4. If a worktree was created:
   - Inform user: "Worktree at {worktree_path} (branch: {branch_name}) is still available. Remove it manually with `git worktree remove {path}` when ready."

5. Artifacts in `.claude/pipeline/sessions/{session}/` are NOT deleted. They can be inspected or resumed manually.

## Resume Note

To resume a cancelled pipeline, the user can manually edit state.yaml to set `status: idle` and re-run `/pipe` with the same config. The setup script will detect existing session directories and reuse them.
