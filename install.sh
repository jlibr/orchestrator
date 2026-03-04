#!/usr/bin/env bash
# install.sh — Install the orchestrator plugin for Claude Code
#
# Copies commands to ~/.claude/commands/ and plugin to ~/.claude/plugins/
# Run from the repo root: bash install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"
COMMANDS_DIR="${CLAUDE_DIR}/commands"
PLUGINS_DIR="${CLAUDE_DIR}/plugins/orchestrator"

echo "Installing orchestrator plugin..."

# Ensure directories exist
mkdir -p "$COMMANDS_DIR"
mkdir -p "$PLUGINS_DIR"

# Copy plugin files (preserve structure)
cp -r "$SCRIPT_DIR"/.claude-plugin "$PLUGINS_DIR/"
cp -r "$SCRIPT_DIR"/agents "$PLUGINS_DIR/"
cp -r "$SCRIPT_DIR"/commands "$PLUGINS_DIR/"
cp -r "$SCRIPT_DIR"/hooks "$PLUGINS_DIR/"
cp -r "$SCRIPT_DIR"/knowledge "$PLUGINS_DIR/"
cp -r "$SCRIPT_DIR"/learning "$PLUGINS_DIR/"
cp -r "$SCRIPT_DIR"/scripts "$PLUGINS_DIR/"
cp -r "$SCRIPT_DIR"/templates "$PLUGINS_DIR/"
cp "$SCRIPT_DIR"/README.md "$PLUGINS_DIR/"

# Make scripts executable
chmod +x "$PLUGINS_DIR"/scripts/*.sh
chmod +x "$PLUGINS_DIR"/hooks/scripts/*.sh

# Install commands to Claude Code's discovery path
cp "$SCRIPT_DIR"/commands/pipe.md "$COMMANDS_DIR/pipe.md"
cp "$SCRIPT_DIR"/commands/pipe-status.md "$COMMANDS_DIR/pipe-status.md"
cp "$SCRIPT_DIR"/commands/pipe-cancel.md "$COMMANDS_DIR/pipe-cancel.md"

echo ""
echo "Installed:"
echo "  Plugin:   $PLUGINS_DIR/"
echo "  Commands: /pipe, /pipe-status, /pipe-cancel"
echo ""
echo "Usage: /pipe \"your idea here\""
echo "Docs:  $PLUGINS_DIR/README.md"
