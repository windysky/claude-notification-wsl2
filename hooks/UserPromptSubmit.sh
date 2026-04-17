#!/usr/bin/env bash
# UserPromptSubmit.sh - Claude Code Hook
# Fires when the user submits a prompt. Starts a terminal-title spinner so
# the user sees a "Claude working..." indicator in their terminal/taskbar
# while Claude processes the turn. Cleared by Stop / Notification hooks.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${HOME}/.wsl-toast"
LOG_DIR="${CONFIG_DIR}/logs"
LOG_FILE="${LOG_DIR}/hooks.log"

mkdir -p "$LOG_DIR"
echo "=== UserPromptSubmit Hook $(date) ===" >> "$LOG_FILE"

# Drain stdin (Claude Code sends a JSON payload). We don't need it here;
# record just its size so the hook never blocks on a half-read pipe.
if [ ! -t 0 ]; then
    wc -c </dev/stdin >> "$LOG_FILE" 2>/dev/null || true
fi

# Load spinner helper and start the animator.
if [ -f "${SCRIPT_DIR}/_spinner.sh" ]; then
    # shellcheck disable=SC1091
    . "${SCRIPT_DIR}/_spinner.sh"
    spinner_start 2>/dev/null || true
fi

exit 0
