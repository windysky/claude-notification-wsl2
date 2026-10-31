#!/usr/bin/env bash
# Stop.sh - Claude Code Hook for task completion notifications
# Runs when Claude finishes responding and waits for input
#
# This hook extracts the last assistant message from the transcript
# to provide detailed notifications similar to Codex CLI.

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

# Log raw hook data for debugging
mkdir -p "$LOG_DIR"
echo "=== Stop Hook $(date) ===" >> "$LOG_FILE"
cat > /tmp/stop_hook_input.json
cat /tmp/stop_hook_input.json >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Session id + project dir (v1.4.0): per-project toast titles and dedup keys.
SESSION_ID="" PROJECT_DIR=""
if command -v python3 &>/dev/null; then
    read -r SESSION_ID PROJECT_DIR <<< "$(python3 -c "import json; d=json.load(open('/tmp/stop_hook_input.json')); print(d.get('session_id',''), d.get('cwd',''))" 2>/dev/null)"
fi
PROJECT_NAME="$(basename "${PROJECT_DIR:-$PWD}")"

# Stop the terminal-title spinner before anything else so the title clears
# even if the toast path bails out below.
if [ -f "${SCRIPT_DIR}/_spinner.sh" ]; then
    # shellcheck disable=SC1091
    . "${SCRIPT_DIR}/_spinner.sh" && spinner_stop 2>/dev/null || true
fi

# Flash the Windows Terminal window that owns this session (taskbar pulse
# until focused). Runs even when the toast below is deduplicated - the
# window still needs the user's attention.
if [ -f "${SCRIPT_DIR}/_attention.sh" ]; then
    # shellcheck disable=SC1091
    . "${SCRIPT_DIR}/_attention.sh" && attention_flash "${PROJECT_DIR:-$PWD}" stop "${SESSION_ID}" 2>/dev/null || true
fi

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
    TEMPLATE_JSON=$(find_template "$LANGUAGE")
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

def truncate_message(text, max_len=180):
    """v1.4.5 banner-calibrated extract: two sentences / max_len chars, cut
    only at sentence boundaries (the toast banner clamps at ~5 lines and
    clips mid-character otherwise). Dash runs and markdown are stripped
    first (v1.4.2/v1.4.4)."""
    if not text:
        return ""
    text = re.sub(r'[\u2500\u2501\u2550\-\u2013\u2014~=]{3,}', ' ', text)
    text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'\1', text)
    text = re.sub(r'(\*\*|__)(?=\S)(.+?)(?<=\S)\1', r'\2', text)
    text = re.sub(r'(?<!\w)(\*|_)(?=\S)(.+?)(?<=\S)\1(?!\w)', r'\2', text)
    text = re.sub(r'`{1,3}([^`]*)`{1,3}', r'\1', text)
    text = re.sub(r'^\s{0,3}#{1,6}\s+', '', text, flags=re.M)
    text = re.sub(r'\s+', ' ', text).strip()
    sentences = re.split(r'(?<=[.!?])\s+', text)
    result = " ".join(sentences[:2])
    if len(result) > max_len:
        result = result[:max_len - 1].rstrip()
        cut = max(result.rfind('.'), result.rfind('!'), result.rfind('?'))
        if cut > 40:
            result = result[:cut + 1]
        else:
            result = result + "..."
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

# Per-project title (v1.4.0): concurrent sessions become distinguishable at
# a glance instead of all reading "Claude Code Ready".
TITLE="${TITLE} — ${PROJECT_NAME}"

# Suppress byte-identical repeats within 60s (double Stop fires carry the
# same last assistant message). Different messages always go through.
if [ -f "${SCRIPT_DIR}/_attention.sh" ]; then
    # shellcheck disable=SC1091
    . "${SCRIPT_DIR}/_attention.sh"
    if ! toast_dedup_check "stop|${SESSION_ID}|${TITLE}|${MESSAGE}"; then
        echo "[suppressed duplicate stop toast]" >> "$LOG_FILE"
        exit 0
    fi
fi

# Send notification
"$NOTIFY_SCRIPT" \
    --title "$TITLE" \
    --message "$MESSAGE" \
    --type "Success" \
    2>/dev/null || true

exit 0
