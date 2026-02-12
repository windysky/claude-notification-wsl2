#!/usr/bin/env bash
# Stop.sh - Claude Code Hook for task completion notifications
# Runs when Claude finishes responding and waits for input
#
# This hook extracts the last assistant message from the transcript
# to provide detailed notifications similar to Codex CLI.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
NOTIFY_SCRIPT="${PROJECT_ROOT}/scripts/notify.sh"
CONFIG_DIR="${HOME}/.wsl-toast"
CONFIG_FILE="${CONFIG_DIR}/config.json"
LOG_FILE="${PROJECT_ROOT}/logs/hooks.log"

# Log raw hook data for debugging
mkdir -p "${PROJECT_ROOT}/logs"
echo "=== Stop Hook $(date) ===" >> "$LOG_FILE"
cat > /tmp/stop_hook_input.json
cat /tmp/stop_hook_input.json >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Exit if notify script doesn't exist
if [ ! -f "$NOTIFY_SCRIPT" ]; then
    exit 0
fi

# Load language from config
LANGUAGE="en"
if [ -f "$CONFIG_FILE" ]; then
    LANGUAGE="$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('language', 'en'))" 2>/dev/null || echo "en")"
fi

TITLE="Claude Code Ready"
MESSAGE="Claude has finished and is waiting for your next instruction"

if command -v python3 &>/dev/null; then
    # Load template
    TEMPLATE_JSON="${PROJECT_ROOT}/templates/notifications/${LANGUAGE}.json"
    if [ -f "$TEMPLATE_JSON" ]; then
        TEMPLATE_DATA=$(python3 -c "import json; data=json.load(open('$TEMPLATE_JSON')); print(data.get('stop', {}).get('title', '$TITLE')); print(data.get('stop', {}).get('message', '$MESSAGE'))" 2>/dev/null)
        if [ -n "$TEMPLATE_DATA" ]; then
            TITLE=$(echo "$TEMPLATE_DATA" | sed -n '1p')
            MESSAGE=$(echo "$TEMPLATE_DATA" | sed -n '2p')
        fi
    fi

    # Extract last assistant message from transcript (like Codex CLI does)
    PARSED=$(python3 - <<'PY'
import json
import sys
import os
import re

def extract_text_from_content(content):
    """Extract text from assistant message content array."""
    if not content or not isinstance(content, list):
        return ""

    # Look for text content (skip thinking and tool_use blocks)
    for block in reversed(content):
        if isinstance(block, dict):
            block_type = block.get("type", "")
            if block_type == "text" and block.get("text"):
                return block["text"].strip()

    # Fallback: try to get any meaningful text
    for block in reversed(content):
        if isinstance(block, dict):
            if block.get("text"):
                return block["text"].strip()
            if block.get("thinking"):
                return block["thinking"].strip()
    return ""

def get_last_assistant_message(transcript_path):
    """Read transcript and extract last assistant message."""
    if not transcript_path or not os.path.exists(transcript_path):
        return ""

    try:
        last_text = ""
        with open(transcript_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                    # Check if this is an assistant message
                    msg = entry.get("message", {})
                    if msg.get("role") == "assistant":
                        content = msg.get("content", [])
                        text = extract_text_from_content(content)
                        if text:
                            last_text = text
                except json.JSONDecodeError:
                    continue
        return last_text
    except Exception:
        return ""

def truncate_message(text, max_len=150):
    """Truncate to first sentence or max_len chars."""
    if not text:
        return ""
    # Try to get first sentence
    sentences = re.split(r'(?<=[.!?])\s+', text, maxsplit=1)
    result = sentences[0]
    if len(result) > max_len:
        result = result[:max_len - 3].rstrip() + "..."
    return result

try:
    # Read hook payload
    data = json.load(open('/tmp/stop_hook_input.json'))

    # Get transcript path from payload
    transcript_path = data.get("transcript_path", "")

    # Extract last assistant message from transcript
    msg = get_last_assistant_message(transcript_path)

    if msg:
        print(truncate_message(msg))
except Exception as e:
    print("", file=sys.stderr)
PY
)

    if [ -n "$PARSED" ]; then
        MESSAGE="$PARSED"
    fi
fi

# Send notification
"$NOTIFY_SCRIPT" \
    --title "$TITLE" \
    --message "$MESSAGE" \
    --type "Success" \
    2>/dev/null || true

exit 0
