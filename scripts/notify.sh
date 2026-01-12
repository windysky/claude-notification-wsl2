#!/usr/bin/env bash
# notify.sh - WSL2 Bridge Script for Windows Toast Notifications
# Connects WSL2 to Windows PowerShell toast notifications
#
# Usage: notify.sh [--title=<title>] [--message=<message>] [--type=<type>] [--duration=<duration>] [--mock]
#
# Author: Claude Code TDD Implementation
# Version: 1.0.0
# License: MIT

set -euo pipefail

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_DIR="${HOME}/.wsl-toast"
CONFIG_FILE="${CONFIG_DIR}/config.json"

# PowerShell script path (Windows side)
PS_SCRIPT_DIR="$(wslpath -w "${PROJECT_ROOT}/windows" 2>/dev/null || echo "C:\\Users\\$USER\\.wsl-toast")"
PS_SCRIPT_PATH="${PS_SCRIPT_DIR}\\wsl-toast.ps1"

# Default values
DEFAULT_TYPE="Information"
DEFAULT_DURATION="Normal"
MOCK_MODE=false
BACKGROUND_MODE=false

# Exit codes
EXIT_SUCCESS=0
EXIT_ERROR=1
EXIT_MISSING_PARAMS=2
EXIT_POWERSHELL_NOT_FOUND=3
EXIT_SCRIPT_NOT_FOUND=4

#############################################################################
# Helper Functions
#############################################################################

# Log informational message
log_info() {
    echo "[INFO] $*" >&2
}

# Log error message
log_error() {
    echo "[ERROR] $*" >&2
}

# Log warning message
log_warning() {
    echo "[WARNING] $*" >&2
}

# Log debug message (only if DEBUG is set)
log_debug() {
    if [[ "${DEBUG:-}" == "true" ]]; then
        echo "[DEBUG] $*" >&2
    fi
}

# Show usage information
show_usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Display Windows toast notifications from WSL2 using PowerShell.

OPTIONS:
    -t, --title <title>          Notification title (required)
    -m, --message <message>      Notification message (required)
    -T, --type <type>            Notification type: Information, Warning, Error, Success
                                (default: Information)
    -d, --duration <duration>    Display duration: Short, Normal, Long
                                (default: Normal)
    -l, --logo <path>            Path to custom icon/image
    -b, --background             Run in background (non-blocking, for hooks)
    --mock                       Mock mode: don't display actual notification
    -h, --help                   Show this help message
    -v, --verbose                Enable verbose output

ENVIRONMENT VARIABLES:
    WSL_TOAST_ENABLED            Enable/disable notifications (default: true)
    WSL_TOAST_TYPE               Default notification type
    WSL_TOAST_DURATION           Default notification duration
    WSL_TOAST_CONFIG             Path to config file (default: ~/.wsl-toast/config.json)

EXAMPLES:
    $(basename "$0") --title "Build Complete" --message "Your project built successfully"
    $(basename "$0") -t "Warning" -m "Low disk space" -T Warning -d Long
    $(basename "$0") --title "테스트" --message "한글 알림" --type Success
    $(basename "$0") --mock --title "Test" --message "Testing notification system"

EXIT CODES:
    0    Success
    1    General error
    2    Missing required parameters
    3    PowerShell not found
    4    PowerShell script not found
EOF
}

#############################################################################
# Configuration Functions
#############################################################################

# Load configuration from file
load_config() {
    local config_file="${WSL_TOAST_CONFIG:-$CONFIG_FILE}"

    if [[ ! -f "$config_file" ]]; then
        log_debug "Config file not found: $config_file"
        return
    fi

    log_debug "Loading config from: $config_file"

    # Use Python to parse JSON if available, otherwise use basic grep
    if command -v python3 &>/dev/null; then
        python3 -c "
import json, sys
try:
    with open('$config_file', 'r') as f:
        config = json.load(f)
    for key, value in config.items():
        print(f'{key}={value}')
except Exception as e:
    sys.stderr.write(f'Error loading config: {e}\n')
" 2>/dev/null || true
    fi
}

# Apply configuration to variables
apply_config() {
    local config_output
    config_output="$(load_config)"

    if [[ -n "$config_output" ]]; then
        while IFS='=' read -r key value; do
            case "$key" in
                enabled)
                    if [[ "$value" == "false" ]]; then
                        log_info "Notifications are disabled in config"
                        exit $EXIT_SUCCESS
                    fi
                    ;;
                default_type)
                    DEFAULT_TYPE="${value:-$DEFAULT_TYPE}"
                    ;;
                default_duration)
                    DEFAULT_DURATION="${value:-$DEFAULT_DURATION}"
                    ;;
            esac
        done <<< "$config_output"
    fi
}

#############################################################################
# PowerShell Detection
#############################################################################

# Find PowerShell executable
find_powershell() {
    local powershell_paths=(
        "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
        "/mnt/c/WINDOWS/System32/WindowsPowerShell/v1.0/powershell.exe"
        "/mnt/c/Windows/SysWOW64/WindowsPowerShell/v1.0/powershell.exe"
        "powershell.exe"
    )

    for path in "${powershell_paths[@]}"; do
        if command -v "$path" &>/dev/null || [[ -x "$path" ]]; then
            echo "$path"
            return 0
        fi
    done

    return 1
}

#############################################################################
# Notification Functions
#############################################################################

# Validate notification type
validate_type() {
    local type="$1"
    local valid_types=("Information" "Warning" "Error" "Success")

    for valid_type in "${valid_types[@]}"; do
        if [[ "$type" == "$valid_type" ]]; then
            echo "$type"
            return 0
        fi
    done

    log_warning "Invalid type: $type, using default: $DEFAULT_TYPE"
    echo "$DEFAULT_TYPE"
}

# Validate duration
validate_duration() {
    local duration="$1"
    local valid_durations=("Short" "Normal" "Long")

    for valid_duration in "${valid_durations[@]}"; do
        if [[ "$duration" == "$valid_duration" ]]; then
            echo "$duration"
            return 0
        fi
    done

    log_warning "Invalid duration: $duration, using default: $DEFAULT_DURATION"
    echo "$DEFAULT_DURATION"
}

# Build PowerShell command
build_powershell_command() {
    local title="$1"
    local message="$2"
    local type="$3"
    local duration="$4"
    local logo="${5:-}"

    # Escape special characters for PowerShell
    local escaped_title escaped_message
    escaped_title="$(printf '%s' "$title" | sed 's/"/\\"/g')"
    escaped_message="$(printf '%s' "$message" | sed 's/"/\\"/g')"

    local cmd_args=()
    cmd_args+=("-Title" "\"${escaped_title}\"")
    cmd_args+=("-Message" "\"${escaped_message}\"")
    cmd_args+=("-Type" "$type")
    cmd_args+=("-Duration" "$duration")

    if [[ -n "$logo" ]]; then
        local logo_win
        logo_win="$(wslpath -w "$logo" 2>/dev/null || echo "$logo")"
        cmd_args+=("-AppLogo" "\"${logo_win}\"")
    fi

    if [[ "$MOCK_MODE" == "true" ]]; then
        cmd_args+=("-MockMode")
    fi

    # Build the command
    echo "& '${PS_SCRIPT_PATH}' ${cmd_args[*]}"
}

# Execute PowerShell command in background (non-blocking)
execute_powershell_background() {
    local powershell_cmd="$1"
    local powershell_exe

    # Find PowerShell
    powershell_exe="$(find_powershell)"

    if [[ -z "$powershell_exe" ]]; then
        log_error "PowerShell not found"
        return $EXIT_POWERSHELL_NOT_FOUND
    fi

    log_debug "Running notification in background"

    # Execute PowerShell command in background with nohup
    # Redirect all output to /dev/null to prevent blocking
    nohup "$powershell_exe" \
        -NoProfile \
        -NonInteractive \
        -Command "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; $powershell_cmd" \
        >/dev/null 2>&1 &

    # Return immediately
    return 0
}

# Execute PowerShell command
execute_powershell() {
    local powershell_cmd="$1"
    local powershell_exe
    local output exit_code

    # Find PowerShell
    powershell_exe="$(find_powershell)"

    if [[ -z "$powershell_exe" ]]; then
        log_error "PowerShell not found"
        return $EXIT_POWERSHELL_NOT_FOUND
    fi

    log_debug "Using PowerShell: $powershell_exe"
    log_debug "Executing: $powershell_exe -NoProfile -NonInteractive -Command \"\$output = $powershell_cmd; \$output\""

    # Execute PowerShell command with UTF-8 encoding
    output="$(
        LC_ALL=en_US.UTF-8 \
        "$powershell_exe" \
            -NoProfile \
            -NonInteractive \
            -Command "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; \$output = $powershell_cmd; \$output" \
            2>&1
    )"
    exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_info "Notification sent successfully"
        if [[ "$MOCK_MODE" == "true" ]]; then
            log_info "Mock mode output: $output"
        fi
    else
        log_error "PowerShell command failed (exit code: $exit_code)"
        log_error "Output: $output"
    fi

    return $exit_code
}

#############################################################################
# Main Notification Function
#############################################################################

# Send notification
send_notification() {
    local title="$1"
    local message="$2"
    local type="${3:-$DEFAULT_TYPE}"
    local duration="${4:-$DEFAULT_DURATION}"
    local logo="${5:-}"

    # Validate parameters
    type="$(validate_type "$type")"
    duration="$(validate_duration "$duration")"

    log_info "Sending notification: [$type] $title"

    # Build PowerShell command
    local ps_cmd
    ps_cmd="$(build_powershell_command "$title" "$message" "$type" "$duration" "$logo")"

    # Execute in background or foreground
    if [[ "$BACKGROUND_MODE" == "true" ]]; then
        execute_powershell_background "$ps_cmd"
    else
        execute_powershell "$ps_cmd"
    fi
}

#############################################################################
# Main Script
#############################################################################

main() {
    local title=""
    local message=""
    local type="$DEFAULT_TYPE"
    local duration="$DEFAULT_DURATION"
    local logo=""
    local verbose=false
    local background=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t|--title)
                title="$2"
                shift 2
                ;;
            --title=*)
                title="${1#*=}"
                shift
                ;;
            -m|--message)
                message="$2"
                shift 2
                ;;
            --message=*)
                message="${1#*=}"
                shift
                ;;
            -T|--type)
                type="$2"
                shift 2
                ;;
            --type=*)
                type="${1#*=}"
                shift
                ;;
            -d|--duration)
                duration="$2"
                shift 2
                ;;
            --duration=*)
                duration="${1#*=}"
                shift
                ;;
            -l|--logo)
                logo="$2"
                shift 2
                ;;
            --logo=*)
                logo="${1#*=}"
                shift
                ;;
            --mock)
                MOCK_MODE=true
                shift
                ;;
            -b|--background)
                background=true
                BACKGROUND_MODE=true
                shift
                ;;
            -h|--help)
                show_usage
                exit $EXIT_SUCCESS
                ;;
            -v|--verbose)
                verbose=true
                DEBUG=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit $EXIT_ERROR
                ;;
        esac
    done

    # Enable verbose if requested
    if [[ "$verbose" == "true" ]]; then
        set -x
    fi

    # Load configuration
    apply_config

    # Validate required parameters
    if [[ -z "$title" ]] || [[ -z "$message" ]]; then
        log_error "Missing required parameters: title and message are required"
        show_usage
        exit $EXIT_MISSING_PARAMS
    fi

    # Check if notifications are disabled via environment variable
    if [[ "${WSL_TOAST_ENABLED:-true}" == "false" ]]; then
        log_info "Notifications are disabled via WSL_TOAST_ENABLED"
        exit $EXIT_SUCCESS
    fi

    # Send notification
    send_notification "$title" "$message" "$type" "$duration" "$logo"
}

# Execute main function
main "$@"
