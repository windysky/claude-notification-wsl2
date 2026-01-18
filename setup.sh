#!/usr/bin/env bash
# setup.sh - Installation Script for WSL Toast Notifications
# Installs Windows toast notification system for Claude Code CLI on WSL2
#
# Author: Claude Code TDD Implementation
# Version: 1.1.0
# License: MIT

set -euo pipefail

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}" && pwd)"
CONFIG_DIR="${HOME}/.wsl-toast"
CONFIG_FILE="${CONFIG_DIR}/config.json"
CLAUDE_SETTINGS_DIR="${HOME}/.claude"
CLAUDE_SETTINGS_FILE="${CLAUDE_SETTINGS_DIR}/settings.json"
FORCE_OVERWRITE=false
DRY_RUN=false
POWERSHELL_CMD=""
POWERSHELL_TIMEOUT_SEC=15
POWERSHELL_ARGS=("-NoProfile" "-NonInteractive" "-NoLogo" "-ExecutionPolicy" "Bypass")

# Exit codes
EXIT_SUCCESS=0
EXIT_ERROR=1
EXIT_MISSING_DEPS=2

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Disable colors when stdout isn't a TTY or NO_COLOR is set
if [[ ! -t 1 || -n "${NO_COLOR:-}" || "${TERM:-}" == "dumb" ]]; then
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    NC=""
fi

#############################################################################
# Logging Functions
#############################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

prompt_yes_no() {
    local prompt="$1"
    local default="$2"
    local reply

    read -p "$prompt" -r reply
    if [[ -z "$reply" ]]; then
        reply="$default"
    fi

    if [[ "$reply" =~ ^[Yy]$ ]]; then
        return 0
    fi

    return 1
}

prompt_value() {
    local prompt="$1"
    local default="$2"
    local reply

    read -p "$prompt" -r reply
    if [[ -z "$reply" ]]; then
        reply="$default"
    fi

    echo "$reply"
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --force     Overwrite existing configuration files without prompting
  --dry-run   Show what would change without writing files
  -h, --help  Show this help message
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)
                FORCE_OVERWRITE=true
                ;;
            --dry-run)
                DRY_RUN=true
                ;;
            -h|--help)
                usage
                exit $EXIT_SUCCESS
                ;;
            *)
                log_error "Unknown argument: $1"
                usage
                exit $EXIT_ERROR
                ;;
        esac
        shift
    done
}

run_powershell() {
    local command="$1"

    if [[ -z "$POWERSHELL_CMD" ]]; then
        return 127
    fi

    if command -v timeout &>/dev/null; then
        timeout "${POWERSHELL_TIMEOUT_SEC}s" "$POWERSHELL_CMD" "${POWERSHELL_ARGS[@]}" -Command "$command"
    else
        "$POWERSHELL_CMD" "${POWERSHELL_ARGS[@]}" -Command "$command"
    fi
}

#############################################################################
# Prerequisite Checking
#############################################################################

check_prerequisites() {
    log_info "Checking prerequisites..."

    local missing_deps=()

    # Check for PowerShell
    if command -v powershell.exe &>/dev/null; then
        POWERSHELL_CMD="powershell.exe"
    elif command -v pwsh.exe &>/dev/null; then
        POWERSHELL_CMD="pwsh.exe"
    else
        missing_deps+=("PowerShell (powershell.exe or pwsh.exe)")
    fi

    # Check for wslpath
    if ! command -v wslpath &>/dev/null; then
        missing_deps+=("wslpath (WSL2 core utility)")
    fi

    # Check for Python (optional, for template loader)
    if ! command -v python3 &>/dev/null; then
        log_warning "Python 3 not found. Template loader will not be available."
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing required dependencies:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        return $EXIT_MISSING_DEPS
    fi

    log_success "All prerequisites met"

    # Show PowerShell version
    if [[ -n "$POWERSHELL_CMD" ]]; then
        local ps_version
        if ps_version="$(run_powershell 'Write-Host $PSVersionTable.PSVersion' 2>/dev/null | tr -d '\r')"; then
            log_info "PowerShell version: $ps_version"
        else
            log_warning "Unable to read PowerShell version (command timed out or failed)"
        fi
    fi

    return 0
}

check_wsl2() {
    log_info "Verifying WSL environment..."

    # Check if running in WSL
    if [ ! -f /proc/version ] || ! grep -qi "microsoft" /proc/version; then
        log_warning "Not running in WSL environment. Some features may not work."
        return 0
    fi

    log_success "WSL environment detected"

    return 0
}

check_existing_installation() {
    log_info "Checking for existing installation..."

    if [ -f "$CONFIG_FILE" ]; then
        log_warning "Existing configuration found at: $CONFIG_FILE"
        if [[ "$FORCE_OVERWRITE" == "true" ]]; then
            log_info "Force overwrite enabled for existing configuration."
        else
            log_info "You will be prompted before overwriting. Use --force to overwrite automatically."
        fi
        # Return success to continue - hooks may still need updating
        return 0
    fi

    return 0
}

#############################################################################
# Installation Functions
#############################################################################

install_powershell_module() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Dry run: skipping BurntToast module check/install"
        return 0
    fi

    log_info "Checking BurntToast PowerShell module..."

    # Check if BurntToast is installed
    local module_check
    if ! module_check="$(run_powershell "
        if (Get-Module -ListAvailable -Name BurntToast -ErrorAction SilentlyContinue) {
            Write-Host 'INSTALLED'
        } else {
            Write-Host 'NOT_INSTALLED'
        }
    " 2>/dev/null | tr -d '\r')"; then
        log_warning "BurntToast module check failed or timed out; skipping installation prompt"
        return 0
    fi

    if [ "$module_check" = "INSTALLED" ]; then
        log_success "BurntToast module is already installed"
        return 0
    fi

    log_info "Installing BurntToast module..."
    log_info "Note: This may require administrator privileges"

    read -p "Install BurntToast module from PowerShell Gallery? [Y/n]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_warning "Skipping BurntToast installation. Notifications will use fallback method."
        return 0
    fi

    # Attempt to install BurntToast
    if run_powershell "Install-Module -Name BurntToast -Force -Scope CurrentUser" 2>&1; then
        log_success "BurntToast module installed successfully"
    else
        log_warning "Failed to install BurntToast. Notifications will use Windows Forms fallback."
        log_warning "You can install it manually later: Install-Module -Name BurntToast"
    fi

    return 0
}

create_config_directory() {
    log_info "Creating configuration directory: $CONFIG_DIR"

    if [ ! -d "$CONFIG_DIR" ]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "Dry run: would create configuration directory at ${CONFIG_DIR}"
        else
            mkdir -p "$CONFIG_DIR"
            log_success "Configuration directory created"
        fi
    else
        log_info "Configuration directory already exists"
    fi

    return 0
}

create_default_config() {
    local existed_before=false
    if [ -f "$CONFIG_FILE" ]; then
        existed_before=true
    fi

    if [ -f "$CONFIG_FILE" ]; then
        if [[ "$FORCE_OVERWRITE" != "true" ]]; then
            if ! prompt_yes_no "Config file exists at ${CONFIG_FILE}. Overwrite with defaults? [y/N]: " "N"; then
                log_info "Configuration unchanged at ${CONFIG_FILE}. Re-run with --force to overwrite."
                return 0
            fi
        fi
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "Dry run: would overwrite configuration at ${CONFIG_FILE}"
            return 0
        fi
        log_warning "Overwriting existing configuration at ${CONFIG_FILE}"
    elif [[ "$DRY_RUN" == "true" ]]; then
        log_info "Dry run: would create configuration at ${CONFIG_FILE}"
        return 0
    fi

    log_info "Creating default configuration..."

    cat > "$CONFIG_FILE" <<EOF
{
  "enabled": true,
  "default_type": "Information",
  "default_duration": "Normal",
  "language": "en",
  "sound_enabled": true,
  "position": "top_right"
}
EOF

    if [[ "$existed_before" == "true" ]]; then
        log_success "Configuration updated at ${CONFIG_FILE}"
    else
        log_success "Configuration created at ${CONFIG_FILE}"
    fi

    return 0
}

install_notify_script() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Dry run: skipping notify.sh installation"
        return 0
    fi

    log_info "Installing notify.sh script..."

    local notify_script="${PROJECT_ROOT}/scripts/notify.sh"

    if [ ! -f "$notify_script" ]; then
        log_error "notify.sh not found at: $notify_script"
        return $EXIT_ERROR
    fi

    # Make executable
    chmod +x "$notify_script"

    log_success "notify.sh script is executable"

    return 0
}

create_symlink() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Dry run: would create symbolic link at ${HOME}/.local/bin/wsl-toast"
        return 0
    fi

    log_info "Creating symbolic link in user bin directory..."

    local bin_dir="${HOME}/.local/bin"
    local symlink="${bin_dir}/wsl-toast"

    # Create bin directory if it doesn't exist
    if [ ! -d "$bin_dir" ]; then
        mkdir -p "$bin_dir"
    fi

    # Remove existing symlink
    if [ -L "$symlink" ]; then
        rm "$symlink"
    fi

    # Create new symlink
    ln -s "${PROJECT_ROOT}/scripts/notify.sh" "$symlink"

    log_success "Symbolic link created: $symlink"

    # Check if bin directory is in PATH
    if [[ ":$PATH:" != *":${bin_dir}:"* ]]; then
        log_warning "${bin_dir} is not in PATH"
        log_warning "Add the following to your ~/.bashrc or ~/.zshrc:"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi

    return 0
}

configure_claude_hooks() {
    if ! command -v python3 &>/dev/null; then
        log_warning "Python 3 not found. Skipping Claude Code hook configuration."
        return 0
    fi

    if ! prompt_yes_no "Configure Claude Code hooks in ${CLAUDE_SETTINGS_FILE}? [Y/n]: " "Y"; then
        log_info "Skipping Claude Code hook configuration. Re-run with --force to overwrite automatically."
        return 0
    fi
    if [ -f "$CLAUDE_SETTINGS_FILE" ] && [[ "$FORCE_OVERWRITE" != "true" ]]; then
        if ! prompt_yes_no "Existing Claude settings found at ${CLAUDE_SETTINGS_FILE}. Overwrite selected hooks? [y/N]: " "N"; then
            log_info "Skipping Claude Code hook configuration. Re-run with --force to overwrite."
            return 0
        fi
    fi

    local enable_notification enable_permissionrequest enable_stop enable_subagentstop
    enable_notification=false
    enable_permissionrequest=false
    enable_stop=false
    enable_subagentstop=false

    if prompt_yes_no "Enable Notification hook? [Y/n]: " "Y"; then
        enable_notification=true
    fi
    if prompt_yes_no "Enable PermissionRequest hook? [Y/n]: " "Y"; then
        enable_permissionrequest=true
    fi
    if prompt_yes_no "Enable Stop hook? [Y/n]: " "Y"; then
        enable_stop=true
    fi
    if prompt_yes_no "Enable SubagentStop hook? [y/N]: " "N"; then
        enable_subagentstop=true
    fi

    if [[ "$enable_notification" != "true" && "$enable_permissionrequest" != "true" && "$enable_stop" != "true" && "$enable_subagentstop" != "true" ]]; then
        log_info "No hooks selected. Skipping Claude Code hook configuration."
        return 0
    fi

    local notification_timeout permission_timeout stop_timeout subagent_timeout
    if [[ "$enable_notification" == "true" ]]; then
        notification_timeout="$(prompt_value "Notification timeout in ms (default: 1000): " "1000")"
    fi
    if [[ "$enable_permissionrequest" == "true" ]]; then
        permission_timeout="$(prompt_value "PermissionRequest timeout in ms (default: 1000): " "1000")"
    fi
    if [[ "$enable_stop" == "true" ]]; then
        stop_timeout="$(prompt_value "Stop timeout in ms (default: 1000): " "1000")"
    fi
    if [[ "$enable_subagentstop" == "true" ]]; then
        subagent_timeout="$(prompt_value "SubagentStop timeout in ms (default: 1000): " "1000")"
    fi

    export CLAUDE_SETTINGS_FILE
    export CLAUDE_PROJECT_ROOT="${PROJECT_ROOT}"
    export HOOK_NOTIFICATION_TIMEOUT="${notification_timeout:-1000}"
    export HOOK_PERMISSION_TIMEOUT="${permission_timeout:-1000}"
    export HOOK_STOP_TIMEOUT="${stop_timeout:-1000}"
    export HOOK_SUBAGENTSTOP_TIMEOUT="${subagent_timeout:-1000}"
    export HOOK_ENABLE_NOTIFICATION="$enable_notification"
    export HOOK_ENABLE_PERMISSIONREQUEST="$enable_permissionrequest"
    export HOOK_ENABLE_STOP="$enable_stop"
    export HOOK_ENABLE_SUBAGENTSTOP="$enable_subagentstop"
    export DRY_RUN

    local hook_status
    if ! hook_status="$(python3 - <<'PY'
import json
import os
import shutil
import sys

settings_file = os.environ["CLAUDE_SETTINGS_FILE"]
project_root = os.environ["CLAUDE_PROJECT_ROOT"]
dry_run = os.environ.get("DRY_RUN", "false").lower() == "true"

def parse_timeout(value, default):
    try:
        if value is None:
            return default
        return int(value)
    except (TypeError, ValueError):
        return default

notification_timeout = parse_timeout(os.environ.get("HOOK_NOTIFICATION_TIMEOUT"), 1000)
permission_timeout = parse_timeout(os.environ.get("HOOK_PERMISSION_TIMEOUT"), 1000)
stop_timeout = parse_timeout(os.environ.get("HOOK_STOP_TIMEOUT"), 1000)
subagent_timeout = parse_timeout(os.environ.get("HOOK_SUBAGENTSTOP_TIMEOUT"), 1000)

def load_settings():
    if not os.path.exists(settings_file):
        return {}
    try:
        with open(settings_file, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        if not dry_run:
            backup = settings_file + ".bak"
            shutil.copy(settings_file, backup)
        sys.stderr.write(f"Warning: Invalid JSON in {settings_file}. Using empty settings.\n")
        return {}

settings = load_settings()
if not isinstance(settings, dict):
    sys.stderr.write("Existing settings file is not a JSON object. Aborting hook update.\n")
    sys.exit(2)

hooks = settings.get("hooks")
if hooks is None:
    hooks = {}
elif not isinstance(hooks, dict):
    sys.stderr.write("Existing hooks setting is not a JSON object. Aborting hook update.\n")
    sys.exit(2)

def build_hook(command, timeout, matcher=None):
    hook = {
        "hooks": [
            {
                "type": "command",
                "command": command,
                "timeout": parse_timeout(timeout, 1000),
                "run_in_background": True,
            }
        ]
    }
    if matcher is not None:
        hook["matcher"] = matcher
    return [hook]

def set_hook(name, hook_value):
    current = hooks.get(name)
    if current != hook_value:
        hooks[name] = hook_value
        return True
    return False

file_exists = os.path.exists(settings_file)
changed = False

for legacy_hook in ("PostToolUse", "SessionStart", "SessionEnd"):
    if legacy_hook in hooks:
        hooks.pop(legacy_hook, None)
        changed = True

if os.environ.get("HOOK_ENABLE_NOTIFICATION") == "true":
    if set_hook(
        "Notification",
        build_hook(f"{project_root}/hooks/Notification.sh", notification_timeout),
    ):
        changed = True
if os.environ.get("HOOK_ENABLE_PERMISSIONREQUEST") == "true":
    if set_hook(
        "PermissionRequest",
        build_hook(f"{project_root}/hooks/PermissionRequest.sh", permission_timeout, ".*"),
    ):
        changed = True
if os.environ.get("HOOK_ENABLE_STOP") == "true":
    if set_hook(
        "Stop",
        build_hook(f"{project_root}/hooks/Stop.sh", stop_timeout),
    ):
        changed = True
if os.environ.get("HOOK_ENABLE_SUBAGENTSTOP") == "true":
    if set_hook(
        "SubagentStop",
        build_hook(f"{project_root}/hooks/SubagentStop.sh", subagent_timeout),
    ):
        changed = True

if dry_run:
    if changed:
        status = "dry_run_create" if not file_exists else "dry_run_update"
    else:
        status = "dry_run_unchanged"
    print(f"CLAUDE_HOOKS_STATUS={status}")
    sys.exit(0)

if changed:
    settings["hooks"] = hooks
    os.makedirs(os.path.dirname(settings_file), exist_ok=True)
    with open(settings_file, "w", encoding="utf-8") as f:
        json.dump(settings, f, indent=2)
    status = "created" if not file_exists else "updated"
else:
    status = "unchanged"

print(f"CLAUDE_HOOKS_STATUS={status}")
PY
    )"; then
        log_warning "Failed to update Claude Code hooks. Please update ${CLAUDE_SETTINGS_FILE} manually."
        return 0
    fi

    case "$hook_status" in
        CLAUDE_HOOKS_STATUS=created)
            log_success "Claude Code hooks created in ${CLAUDE_SETTINGS_FILE}"
            ;;
        CLAUDE_HOOKS_STATUS=updated)
            log_success "Claude Code hooks updated in ${CLAUDE_SETTINGS_FILE}"
            ;;
        CLAUDE_HOOKS_STATUS=unchanged)
            log_info "Claude Code hooks already up to date in ${CLAUDE_SETTINGS_FILE}"
            ;;
        CLAUDE_HOOKS_STATUS=dry_run_create)
            log_info "Dry run: would create Claude Code hooks in ${CLAUDE_SETTINGS_FILE}"
            ;;
        CLAUDE_HOOKS_STATUS=dry_run_update)
            log_info "Dry run: would update Claude Code hooks in ${CLAUDE_SETTINGS_FILE}"
            ;;
        CLAUDE_HOOKS_STATUS=dry_run_unchanged)
            log_info "Dry run: Claude Code hooks already up to date in ${CLAUDE_SETTINGS_FILE}"
            ;;
        *)
            log_warning "Unknown Claude hook status: ${hook_status}"
            ;;
    esac

    return 0
}

test_installation() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Dry run: skipping installation test"
        return 0
    fi

    log_info "Testing installation..."

    local notify_script="${PROJECT_ROOT}/scripts/notify.sh"

    # Test with mock mode
    if "$notify_script" --title "Installation Test" --message "WSL Toast has been installed successfully!" --type "Success" --mock; then
        log_success "Installation test passed"
    else
        log_warning "Installation test had issues, but setup is complete"
        log_warning "You can test notifications manually with:"
        echo "  $notify_script --title 'Test' --message 'Test message' --mock"
    fi

    return 0
}

print_post_install_info() {
    printf '%b' "

${GREEN}========================================${NC}
${GREEN}Installation Complete!${NC}
${GREEN}========================================${NC}

${BLUE}Configuration:${NC}
  Config file: ${CONFIG_FILE}
  Notify script: ${PROJECT_ROOT}/scripts/notify.sh
  Symlink: ${HOME}/.local/bin/wsl-toast

${BLUE}Usage:${NC}
  wsl-toast --title "Title" --message "Message"
  wsl-toast -t "Title" -m "Message" -type Success

${BLUE}Configuration:${NC}
  Edit config: nano ${CONFIG_FILE}
  Disable notifications: Set "enabled" to false

${BLUE}Languages:${NC}
  Set "language" to: en, ko, ja, or zh

${BLUE}Next Steps:${NC}
  1. Restart your shell or run: source ~/.bashrc
  2. Test notifications: wsl-toast --title "Test" --message "Hello!" --mock
  3. Configure Claude Code hooks (optional)

${BLUE}Claude Code Integration (Optional):${NC}
  See README.md for hook configuration

"

    return 0
}

#############################################################################
# Main Installation Process
#############################################################################

main() {
    parse_args "$@"

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}WSL Toast Notification Installer${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo

    # Check prerequisites
    if ! check_prerequisites; then
        log_error "Prerequisites check failed. Please install missing dependencies."
        exit $EXIT_MISSING_DEPS
    fi

    # Check WSL2 environment
    check_wsl2

    # Check existing installation (continues even if config exists - hooks may need updating)
    check_existing_installation

    echo

    # Install PowerShell module (optional)
    install_powershell_module

    echo

    # Create configuration directory
    if ! create_config_directory; then
        log_error "Failed to create configuration directory"
        exit $EXIT_ERROR
    fi

    # Create default configuration
    if ! create_default_config; then
        log_error "Failed to create default configuration"
        exit $EXIT_ERROR
    fi

    # Install notify script
    if ! install_notify_script; then
        log_error "Failed to install notify script"
        exit $EXIT_ERROR
    fi

    # Create symlink
    if ! create_symlink; then
        log_warning "Failed to create symbolic link"
    fi

    echo

    # Configure Claude Code hooks
    configure_claude_hooks

    echo

    # Test installation
    test_installation

    # Print post-install information
    print_post_install_info

    exit $EXIT_SUCCESS
}

# Execute main function
main "$@"
