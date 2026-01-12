#!/usr/bin/env bash
# PostToolUse.sh - Claude Code Hook for Tool Completion Notifications
# This hook runs after each tool execution to show toast notifications
#
# Installation: Use this script as a command hook under hooks.PostToolUse[].hooks[].command
#
# Author: Claude Code TDD Implementation
# Version: 1.0.0

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
NOTIFY_SCRIPT="${PROJECT_ROOT}/scripts/notify.sh"
CONFIG_DIR="${HOME}/.wsl-toast"
CONFIG_FILE="${CONFIG_DIR}/config.json"

# Exit if notify script doesn't exist
if [ ! -f "$NOTIFY_SCRIPT" ]; then
    exit 0
fi

# Load language from config (default: English)
LANGUAGE="en"
if [ -f "$CONFIG_FILE" ]; then
    LANGUAGE="$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('language', 'en'))" 2>/dev/null || echo "en")"
fi

# Get hook data from stdin
HOOK_DATA=$(cat)

# Parse tool name and status
TOOL_NAME=$(echo "$HOOK_DATA" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('tool_name') or data.get('tool') or 'Unknown')" 2>/dev/null || echo "Tool")

# Determine if tool succeeded (check for common error indicators)
if echo "$HOOK_DATA" | grep -qi "error\|fail\|exception"; then
    STATUS="failed"
    NOTIFICATION_TYPE="Error"
    TEMPLATE_KEY="tool_failed"
else
    STATUS="completed"
    NOTIFICATION_TYPE="Success"
    TEMPLATE_KEY="tool_completed"
fi

# Get template based on language
TITLE="Tool $STATUS"
MESSAGE="The $TOOL_NAME has $STATUS"

if command -v python3 &>/dev/null; then
    TEMPLATE_JSON="${PROJECT_ROOT}/templates/notifications/${LANGUAGE}.json"
    if [ -f "$TEMPLATE_JSON" ]; then
        TEMPLATE_DATA=$(python3 -c "import json; data=json.load(open('$TEMPLATE_JSON')); print(data.get('$TEMPLATE_KEY', {}).get('title', '$TITLE')); print(data.get('$TEMPLATE_KEY', {}).get('message', '$MESSAGE'))" 2>/dev/null)
        if [ -n "$TEMPLATE_DATA" ]; then
            TITLE=$(echo "$TEMPLATE_DATA" | sed -n '1p')
            MESSAGE=$(echo "$TEMPLATE_DATA" | sed -n '2p')
        fi
    fi
fi

# Send notification in background (non-blocking)
"$NOTIFY_SCRIPT" \
    --title "$TITLE" \
    --message "$MESSAGE" \
    --type "$NOTIFICATION_TYPE" \
    --background \
    2>/dev/null || true

exit 0
