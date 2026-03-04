#!/usr/bin/env bash
# guard-state.sh — PreToolUse hook for Write/Edit
# Blocks direct writes to state.yaml during active pipelines.
# Agents must use write-state.sh for atomic updates.
#
# Exit codes:
#   0 = Allow the write
#   2 = Block the write (state.yaml protection)

STATE_FILE=".claude/pipeline/state.yaml"
TOOL_INPUT="${1:-}"

# No state file = no active pipeline = allow all writes
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# Check if pipeline is active
STATUS=$(grep '^status:' "$STATE_FILE" | awk '{print $2}' | sed 's/"//g')
case "$STATUS" in
  idle|done|failed|cancelled)
    exit 0  # No active pipeline, allow all writes
    ;;
esac

# Check if the write target is state.yaml
if echo "$TOOL_INPUT" | grep -q "state\.yaml"; then
  echo "BLOCKED: Direct writes to state.yaml are not allowed during active pipelines."
  echo "Use: bash \"\${CLAUDE_PLUGIN_ROOT}/scripts/write-state.sh\" key=value"
  exit 2
fi

# Allow all other writes
exit 0
