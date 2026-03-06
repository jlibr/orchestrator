#!/usr/bin/env bash
# setup-pipeline.sh — Initialize a pipeline session
# Usage: setup-pipeline.sh <session-name> [pipeline-config-path] [--worktree]
#
# Mode 1 (from idea): config-path is optional. Dirs are created, config will be
#   auto-generated later by the orchestrator in Phase 4.
# Mode 2 (from config): config-path is required and must exist.
#
# Exit codes: 0=success, 1=error, 2=pipeline already running

set -euo pipefail

SESSION_NAME="${1:-}"
PIPELINE_CONFIG="${2:-}"
USE_WORKTREE="${3:-}"

# Handle --worktree as second arg (no config provided)
if [[ "$PIPELINE_CONFIG" == "--worktree" ]]; then
  USE_WORKTREE="--worktree"
  PIPELINE_CONFIG=""
fi

if [[ -z "$SESSION_NAME" ]]; then
  echo "Usage: setup-pipeline.sh <session-name> [pipeline-config-path] [--worktree]"
  exit 1
fi

# If config path provided, validate it exists
if [[ -n "$PIPELINE_CONFIG" && ! -f "$PIPELINE_CONFIG" ]]; then
  echo "Error: Pipeline config not found: $PIPELINE_CONFIG"
  exit 1
fi

PIPELINE_DIR=".claude/pipeline"
STATE_FILE="$PIPELINE_DIR/state.yaml"
SESSION_DIR="$PIPELINE_DIR/sessions/$SESSION_NAME"

# Check for existing active pipeline
if [[ -f "$STATE_FILE" ]]; then
  CURRENT_STATUS=$(grep '^status:' "$STATE_FILE" | awk '{print $2}' | sed 's/"//g')
  case "$CURRENT_STATUS" in
    idle|done|failed|cancelled)
      # Safe to proceed — previous pipeline is terminal
      ;;
    *)
      echo "Error: Pipeline already active (status: $CURRENT_STATUS)"
      echo "Run /pipe-cancel to abort, or wait for completion."
      exit 2
      ;;
  esac
fi

# Read max_cycles from pipeline config if available (default 3)
MAX_CYCLES=3
if [[ -n "$PIPELINE_CONFIG" && -f "$PIPELINE_CONFIG" ]]; then
  PARSED_MAX=$(grep '^max_cycles:' "$PIPELINE_CONFIG" 2>/dev/null | awk '{print $2}')
  MAX_CYCLES="${PARSED_MAX:-3}"
fi

# Create session directories — includes agents/ and knowledge/ for auto-generation
# design/ and qa/ are for standing agents (ui-architect, qa-tester)
mkdir -p "$SESSION_DIR"/{spec,context,artifacts/{issues,design,qa/screenshots,qa/videos},reviews,agents,knowledge}

# Handle worktree creation
WORKTREE_PATH=""
BRANCH_NAME=""
if [[ "$USE_WORKTREE" == "--worktree" ]]; then
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    BRANCH_NAME="pipe/$SESSION_NAME"
    WORKTREE_PATH=".claude/worktrees/$SESSION_NAME"
    git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME" HEAD 2>/dev/null || {
      echo "Warning: Could not create worktree. Continuing without isolation."
      WORKTREE_PATH=""
      BRANCH_NAME=""
    }
  else
    echo "Warning: Not in a git repo. Skipping worktree creation."
  fi
fi

# Get current timestamp
STARTED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Config path: use provided path, or set to session-local path for auto-generation
CONFIG_PATH="${PIPELINE_CONFIG:-.claude/pipeline/sessions/$SESSION_NAME/pipeline.yaml}"

# Read max_duration from pipeline config if available (default 60 minutes)
MAX_DURATION=60
if [[ -n "$PIPELINE_CONFIG" && -f "$PIPELINE_CONFIG" ]]; then
  PARSED_DURATION=$(grep '^max_duration:' "$PIPELINE_CONFIG" 2>/dev/null | awk '{print $2}')
  MAX_DURATION="${PARSED_DURATION:-60}"
fi

# Write state file atomically
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cat << EOF | bash "$PLUGIN_ROOT/scripts/write-state.sh"
status: idle
session_name: $SESSION_NAME
pipeline_config: $CONFIG_PATH
cycle: 0
max_cycles: $MAX_CYCLES
max_duration: $MAX_DURATION
current_phase: ""
current_agent: ""
started_at: $STARTED_AT
phases_completed: []
agent_status: {}
gate_verdicts: {}
redispatch_count: {}
issues_open: 0
issues_resolved: 0
tokens_used: 0
worktree_path: $WORKTREE_PATH
branch_name: $BRANCH_NAME
pr_url: ""
pr_number: ""
EOF

echo "Pipeline session initialized:"
echo "  Session: $SESSION_NAME"
[[ -n "$PIPELINE_CONFIG" ]] && echo "  Config:  $PIPELINE_CONFIG" || echo "  Config:  (auto-generate in Phase 4)"
echo "  State:   $STATE_FILE"
echo "  Dir:     $SESSION_DIR"
[[ -n "$WORKTREE_PATH" ]] && echo "  Worktree: $WORKTREE_PATH ($BRANCH_NAME)"
echo "Ready to run."
