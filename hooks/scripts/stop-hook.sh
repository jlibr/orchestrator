#!/usr/bin/env bash
# stop-hook.sh — Pipeline iteration control
# Coexists with taskmaster: exits 0 immediately when no pipeline is active.
# Only intervenes when a pipeline is mid-execution.
#
# Exit codes:
#   0 = Allow exit (no active pipeline, or pipeline reached terminal state)
#   2 = Block exit, continue iteration (pipeline still has work)

STATE_FILE=".claude/pipeline/state.yaml"

# No state file = no pipeline = allow exit
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# Strip quotes defensively — handles both `status: idle` and `status: "idle"`
STATUS=$(grep '^status:' "$STATE_FILE" | awk '{print $2}' | sed 's/"//g')

# Terminal states — allow exit
case "$STATUS" in
  idle|done|failed|cancelled)
    exit 0
    ;;
esac

WRITE_STATE="$(dirname "$0")/../../scripts/write-state.sh"

CYCLE=$(grep '^cycle:' "$STATE_FILE" | awk '{print $2}' | sed 's/"//g')
MAX=$(grep '^max_cycles:' "$STATE_FILE" | awk '{print $2}' | sed 's/"//g')
CYCLE="${CYCLE:-0}"
MAX="${MAX:-3}"

# Wall-clock timeout check (before review logic)
STARTED_AT=$(grep '^started_at:' "$STATE_FILE" | sed 's/^started_at: *//; s/"//g')
MAX_DURATION=$(grep '^max_duration:' "$STATE_FILE" | awk '{print $2}' | sed 's/"//g')
MAX_DURATION="${MAX_DURATION:-60}"

if [[ -n "$STARTED_AT" ]]; then
  START_EPOCH=$(date -d "$STARTED_AT" +%s 2>/dev/null || echo "0")
  NOW_EPOCH=$(date +%s)
  ELAPSED_MIN=$(( (NOW_EPOCH - START_EPOCH) / 60 ))

  if [[ "$ELAPSED_MIN" -ge "$MAX_DURATION" ]]; then
    bash "$WRITE_STATE" status=done
    echo "PIPELINE: Timeout after ${ELAPSED_MIN}m (max: ${MAX_DURATION}m). Marking done."
    exit 0
  fi
fi

# Find the latest review file
SESSION_NAME=$(grep '^session_name:' "$STATE_FILE" | sed 's/^session_name: *//; s/"//g')
REVIEWS_DIR=".claude/pipeline/sessions/$SESSION_NAME/reviews"

# Check for review verdicts
if [[ -d "$REVIEWS_DIR" ]]; then
  LATEST_REVIEW=$(ls -t "$REVIEWS_DIR"/cycle-*.md 2>/dev/null | head -1)
  if [[ -n "$LATEST_REVIEW" ]]; then
    VERDICT=$(grep '^VERDICT:' "$LATEST_REVIEW" | awk '{print $2}' | sed 's/"//g')

    if [[ "$VERDICT" == "PASS" ]]; then
      bash "$WRITE_STATE" status=done
      exit 0
    fi

    if [[ "$CYCLE" -ge "$MAX" ]]; then
      bash "$WRITE_STATE" status=done
      echo "PIPELINE: Max cycles ($MAX) reached. Stopping with verdict: ${VERDICT:-UNKNOWN}"
      exit 0
    fi

    NEW_CYCLE=$((CYCLE + 1))
    bash "$WRITE_STATE" cycle="$NEW_CYCLE"
    echo "PIPELINE: Review FAIL. Starting cycle $NEW_CYCLE of $MAX."
    exit 2
  fi
fi

# No review exists yet — pipeline is mid-execution (exploring, designing, building, testing, etc.).
# Block exit so the orchestrator can continue dispatching work.
# Do NOT increment cycle — cycle only increments after a review FAIL.
case "$STATUS" in
  exploring|designing|building|testing|reviewing|specifying|generating)
    echo "PIPELINE: Active (status: $STATUS). Continuing."
    exit 2
    ;;
  *)
    # Unknown status — allow exit rather than trapping indefinitely
    echo "PIPELINE: Unknown status '$STATUS'. Allowing exit."
    exit 0
    ;;
esac
