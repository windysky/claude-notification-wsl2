#!/usr/bin/env bash
# PermissionRequest.sh - Claude Code Hook for permission prompts
# This hook runs when Claude Code requests permission to use a tool
#
# Installation: Use this script as a command hook under hooks.PermissionRequest[].hooks[].command
#
# Author: Claude Code TDD Implementation
# Version: 1.0.0

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${HOME}/.wsl-toast"
CONFIG_FILE="${CONFIG_DIR}/config.json"

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

TITLE="Permission Required"
MESSAGE="Claude needs your permission to continue"
DETAIL=""
TOOL_NAME=""

if command -v python3 &>/dev/null; then
    TEMPLATE_JSON=$(find_template "$LANGUAGE")
    if [ -f "$TEMPLATE_JSON" ]; then
        TEMPLATE_DATA=$(python3 -c "import json; data=json.load(open('$TEMPLATE_JSON')); print(data.get('permission_request', {}).get('title', '$TITLE')); print(data.get('permission_request', {}).get('message', '$MESSAGE'))" 2>/dev/null)
        if [ -n "$TEMPLATE_DATA" ]; then
            TITLE=$(echo "$TEMPLATE_DATA" | sed -n '1p')
            MESSAGE=$(echo "$TEMPLATE_DATA" | sed -n '2p')
        fi
    fi

    PARSED=$(printf '%s' "$HOOK_DATA" | python3 - <<'PY'
import json
import re
import sys

def first_sentence(text):
    text = (text or "").strip()
    if not text:
        return ""
    parts = re.split(r"(?<=[.!?])\s+", text, maxsplit=1)
    sentence = parts[0]
    if len(sentence) > 200:
        return sentence[:197].rstrip() + "..."
    return sentence

def extract_text(value):
    if value is None:
        return ""
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        preferred_keys = (
            "text",
            "message",
            "content",
            "summary",
            "body",
            "detail",
            "reason",
            "prompt",
            "description",
            "command",
        )
        for key in preferred_keys:
            if key in value:
                text = extract_text(value.get(key))
                if text:
                    return text
        for val in value.values():
            text = extract_text(val)
            if text:
                return text
        return ""
    if isinstance(value, list):
        parts = [extract_text(item) for item in value]
        return " ".join([part for part in parts if part])
    return str(value)

raw = sys.stdin.read()
data = {}
try:
    data = json.loads(raw) if raw.strip() else {}
except Exception:
    data = {}

tool_name = extract_text(data.get("tool_name") or data.get("tool") or data.get("name") or "")
detail = extract_text(
    data.get("reason")
    or data.get("message")
    or data.get("description")
    or data.get("prompt")
    or data.get("tool_input")
    or data.get("arguments")
    or data.get("params")
    or data.get("input")
)
if not detail:
    detail = extract_text(data)
if not detail:
    detail = raw.strip()
detail = first_sentence(detail)

print(tool_name)
print(detail)
PY
)
    if [ -n "$PARSED" ]; then
        PARSED_TOOL=$(echo "$PARSED" | sed -n '1p')
        PARSED_DETAIL=$(echo "$PARSED" | sed -n '2p')
        if [ -n "$PARSED_TOOL" ]; then
            TOOL_NAME="$PARSED_TOOL"
        fi
        if [ -n "$PARSED_DETAIL" ]; then
            DETAIL="$PARSED_DETAIL"
        fi
    fi
fi

if [ -n "$DETAIL" ]; then
    MESSAGE="$DETAIL"
elif [ -n "$TOOL_NAME" ]; then
    MESSAGE="Claude needs your permission to use ${TOOL_NAME}"
fi

# Send notification in background (non-blocking)
"$NOTIFY_SCRIPT" \
    --title "$TITLE" \
    --message "$MESSAGE" \
    --type "Warning" \
    2>/dev/null || true

exit 0
