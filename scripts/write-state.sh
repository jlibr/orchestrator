#!/usr/bin/env bash
# write-state.sh — Atomic state file writer
# Writes to a temp file then moves into place to prevent partial reads.
#
# Usage: write-state.sh [key=value ...]
#   No args: reads state from stdin, writes atomically
#   With args: updates specific keys in existing state.yaml
#
# Examples:
#   echo "$NEW_STATE" | bash write-state.sh
#   bash write-state.sh status=building current_phase=build cycle=1

set -euo pipefail

STATE_FILE=".claude/pipeline/state.yaml"
TEMP_FILE="${STATE_FILE}.tmp.$$"

# Ensure directory exists
mkdir -p "$(dirname "$STATE_FILE")"

if [[ $# -eq 0 ]]; then
  # Full write mode: read from stdin, write atomically
  cat > "$TEMP_FILE"
else
  # Partial update mode: patch specific keys
  if [[ ! -f "$STATE_FILE" ]]; then
    echo "Error: state.yaml does not exist. Cannot update."
    exit 1
  fi

  cp "$STATE_FILE" "$TEMP_FILE"

  for arg in "$@"; do
    KEY="${arg%%=*}"
    VALUE="${arg#*=}"
    if grep -q "^${KEY}:" "$TEMP_FILE"; then
      sed -i "s|^${KEY}:.*|${KEY}: ${VALUE}|" "$TEMP_FILE"
    else
      echo "${KEY}: ${VALUE}" >> "$TEMP_FILE"
    fi
  done
fi

# Atomic move — on same filesystem, mv is atomic
mv "$TEMP_FILE" "$STATE_FILE"
