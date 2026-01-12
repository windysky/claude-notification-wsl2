#!/usr/bin/env bash
# SessionEnd.sh - Claude Code Hook for Session End Notifications
# This hook runs when a Claude Code session ends
#
# Installation: Use this script as a command hook under hooks.SessionEnd[].hooks[].command
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

# Get template based on language
TITLE="Session Ended"
MESSAGE="Your Claude Code session has ended"

if command -v python3 &>/dev/null; then
    TEMPLATE_JSON="${PROJECT_ROOT}/templates/notifications/${LANGUAGE}.json"
    if [ -f "$TEMPLATE_JSON" ]; then
        TEMPLATE_DATA=$(python3 -c "import json; data=json.load(open('$TEMPLATE_JSON')); print(data.get('session_end', {}).get('title', '$TITLE')); print(data.get('session_end', {}).get('message', '$MESSAGE'))" 2>/dev/null)
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
    --type "Information" \
    --background \
    2>/dev/null || true

exit 0
