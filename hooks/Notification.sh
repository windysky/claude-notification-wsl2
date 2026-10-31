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

# Session id + project dir (v1.4.0): per-project toast titles and dedup keys.
SESSION_ID="" PROJECT_DIR=""
if command -v python3 &>/dev/null; then
    read -r SESSION_ID PROJECT_DIR <<< "$(python3 -c "import json; d=json.load(open('/tmp/notification_hook_input.json')); print(d.get('session_id',''), d.get('cwd',''))" 2>/dev/null)"
fi
PROJECT_NAME="$(basename "${PROJECT_DIR:-$PWD}")"

# Any Notification event means Claude is waiting on the user, so stop the
# working spinner immediately regardless of type.
if [ -f "${SCRIPT_DIR}/_spinner.sh" ]; then
    # shellcheck disable=SC1091
    . "${SCRIPT_DIR}/_spinner.sh" && spinner_stop 2>/dev/null || true
fi

# Flash the Windows Terminal window that owns this session (taskbar pulse
# until focused). permission_prompt is the main "user decision needed now"
# signal; idle_prompt was already suppressed above.
if [ -f "${SCRIPT_DIR}/_attention.sh" ]; then
    # shellcheck disable=SC1091
    . "${SCRIPT_DIR}/_attention.sh" && attention_flash "${PROJECT_DIR:-$PWD}" notification "${SESSION_ID}" "${NTYPE:-}" 2>/dev/null || true
fi

# Suppress idle_prompt to avoid duplicating the Stop hook toast.
# The Stop hook already announces completion with the last assistant message;
# idle_prompt fires ~10s later with the same semantic meaning ("waiting for input").
if command -v python3 &>/dev/null; then
    NTYPE=$(python3 -c "import json; print(json.load(open('/tmp/notification_hook_input.json')).get('notification_type',''))" 2>/dev/null || echo "")
    if [ "$NTYPE" = "idle_prompt" ]; then
        echo "[suppressed idle_prompt duplicate]" >> "$LOG_FILE"
        exit 0
    fi
fi

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
        # v1.4.2: strip banner-divider runs (3+ of ─ ━ — - = ~) that wrap
        # ugly inside the fixed-width toast, then normalize whitespace.
        msg = re.sub(r'[─━═\-–—~=]{3,}', ' ', msg)
        msg = re.sub(r'\s+', ' ', msg).strip()
        # Truncate to first two sentences or 300 chars (v1.4.1 taller toast)
        sentences = re.split(r'(?<=[.!?])\s+', msg)
        result = " ".join(sentences[:2])
        if len(result) > 300:
            result = result[:297] + "..."
        print(result)
except Exception:
    print("")
PY
)

    if [ -n "$PARSED" ]; then
        MESSAGE="$PARSED"
    fi
fi

# Per-project title (v1.4.0): concurrent sessions become distinguishable at
# a glance (two waiting terminals no longer look like one duplicated toast).
TITLE="${TITLE} — ${PROJECT_NAME}"

# Suppress byte-identical repeats within 60s. Different messages - or the
# same message from a different session - always go through.
if [ -f "${SCRIPT_DIR}/_attention.sh" ]; then
    # shellcheck disable=SC1091
    . "${SCRIPT_DIR}/_attention.sh"
    if ! toast_dedup_check "notification|${SESSION_ID}|${NTYPE:-}|${TITLE}|${MESSAGE}"; then
        echo "[suppressed duplicate notification toast]" >> "$LOG_FILE"
        exit 0
    fi
fi

# Send notification in background (non-blocking)
"$NOTIFY_SCRIPT" \
    --title "$TITLE" \
    --message "$MESSAGE" \
    --type "Information" \
    2>/dev/null || true

exit 0
