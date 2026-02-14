#!/usr/bin/env bash
# Notification.sh - Claude Code Hook for direct notifications
# This hook runs when Claude Code sends a notification
#
# Claude Code Notification payload includes:
# - message: The notification message text
# - notification_type: Type of notification (e.g., "idle_prompt")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${HOME}/.wsl-toast"
CONFIG_FILE="${CONFIG_DIR}/config.json"
LOG_DIR="${CONFIG_DIR}/logs"
LOG_FILE="${LOG_DIR}/hooks.log"

# Find notify.sh - check same directory first (installed), then project directory
if [ -f "${SCRIPT_DIR}/notify.sh" ]; then
    NOTIFY_SCRIPT="${SCRIPT_DIR}/notify.sh"
else
    PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
    NOTIFY_SCRIPT="${PROJECT_ROOT}/scripts/notify.sh"
fi

# Find templates - check same directory first (installed), then project directory
find_template() {
    local language="$1"
    if [ -f "${SCRIPT_DIR}/templates/${language}.json" ]; then
        echo "${SCRIPT_DIR}/templates/${language}.json"
    else
        PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
        echo "${PROJECT_ROOT}/templates/notifications/${language}.json"
    fi
}

# Log the raw hook data for debugging
mkdir -p "$LOG_DIR"
echo "=== Notification Hook $(date) ===" >> "$LOG_FILE"
cat > /tmp/notification_hook_input.json
cat /tmp/notification_hook_input.json >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Exit if notify script doesn't exist
if [ ! -f "$NOTIFY_SCRIPT" ]; then
    exit 0
fi

# Load language from config (default: English)
LANGUAGE="en"
if [ -f "$CONFIG_FILE" ]; then
    LANGUAGE="$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('language', 'en'))" 2>/dev/null || echo "en")"
fi

TITLE="Claude Code Notification"
MESSAGE="Claude Code sent a notification"

if command -v python3 &>/dev/null; then
    # Load template
    TEMPLATE_JSON=$(find_template "$LANGUAGE")
    if [ -f "$TEMPLATE_JSON" ]; then
        TEMPLATE_DATA=$(python3 -c "import json; data=json.load(open('$TEMPLATE_JSON')); print(data.get('notification', {}).get('title', '$TITLE')); print(data.get('notification', {}).get('message', '$MESSAGE'))" 2>/dev/null)
        if [ -n "$TEMPLATE_DATA" ]; then
            TITLE=$(echo "$TEMPLATE_DATA" | sed -n '1p')
            DEFAULT_MESSAGE=$(echo "$TEMPLATE_DATA" | sed -n '2p')
        fi
    fi

    # Extract message from Notification hook payload
    PARSED=$(python3 - <<'PY'
import json
import re

try:
    data = json.load(open('/tmp/notification_hook_input.json'))

    # Claude Code Notification hook has a 'message' field
    msg = data.get("message", "")

    # Also check notification_type for context
    notification_type = data.get("notification_type", "")

    if msg:
        # Truncate to first sentence or 150 chars
        sentences = re.split(r'(?<=[.!?])\s+', msg, maxsplit=1)
        result = sentences[0]
        if len(result) > 150:
            result = result[:147] + "..."
        print(result)
except Exception:
    print("")
PY
)

    if [ -n "$PARSED" ]; then
        MESSAGE="$PARSED"
    fi
fi

# Send notification in background (non-blocking)
"$NOTIFY_SCRIPT" \
    --title "$TITLE" \
    --message "$MESSAGE" \
    --type "Information" \
    2>/dev/null || true

exit 0
