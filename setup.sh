#!/usr/bin/env bash
# setup.sh - Installation Script for WSL Toast Notifications
# Installs Windows toast notification system for Claude Code CLI on WSL2
#
# Author: Claude Code TDD Implementation
# Version: 1.0.0
# License: MIT

set -euo pipefail

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}" && pwd)"
CONFIG_DIR="${HOME}/.wsl-toast"
CONFIG_FILE="${CONFIG_DIR}/config.json"

# Exit codes
EXIT_SUCCESS=0
EXIT_ERROR=1
EXIT_MISSING_DEPS=2
EXIT_ALREADY_INSTALLED=3

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

#############################################################################
# Prerequisite Checking
#############################################################################

check_prerequisites() {
    log_info "Checking prerequisites..."

    local missing_deps=()

    # Check for PowerShell
    if ! command -v powershell.exe &>/dev/null && ! command -v pwsh.exe &>/dev/null; then
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
    if command -v powershell.exe &>/dev/null; then
        local ps_version
        ps_version="$(powershell.exe -Command 'Write-Host $PSVersionTable.PSVersion' 2>/dev/null | tr -d '\r')"
        log_info "PowerShell version: $ps_version"
    fi

    return 0
}

check_wsl2() {
    log_info "Verifying WSL2 environment..."

    # Check if running in WSL
    if [ ! -f /proc/version ] || ! grep -qi "microsoft" /proc/version; then
        log_warning "Not running in WSL environment. Some features may not work."
        return 0
    fi

    # Check WSL version
    local wsl_version
    wsl_version="$(grep -m1 "Microsoft" /proc/version || true)"

    if [[ "$wsl_version" == *"WSL2"* ]] || [[ "$wsl_version" == *"wsl2"* ]]; then
        log_success "WSL2 environment detected"
    else
        log_warning "WSL version could not be determined. Assuming WSL2."
    fi

    return 0
}

check_existing_installation() {
    log_info "Checking for existing installation..."

    if [ -f "$CONFIG_FILE" ]; then
        log_warning "Existing configuration found at: $CONFIG_FILE"
        read -p "Overwrite existing configuration? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled by user"
            return $EXIT_ALREADY_INSTALLED
        fi
    fi

    return 0
}

#############################################################################
# Installation Functions
#############################################################################

install_powershell_module() {
    log_info "Checking BurntToast PowerShell module..."

    # Check if BurntToast is installed
    local module_check
    module_check="$(powershell.exe -Command "
        if (Get-Module -ListAvailable -Name BurntToast -ErrorAction SilentlyContinue) {
            Write-Host 'INSTALLED'
        } else {
            Write-Host 'NOT_INSTALLED'
        }
    " 2>/dev/null | tr -d '\r')"

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
    if powershell.exe -Command "Install-Module -Name BurntToast -Force -Scope CurrentUser" 2>&1; then
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
        mkdir -p "$CONFIG_DIR"
        log_success "Configuration directory created"
    else
        log_info "Configuration directory already exists"
    fi

    return 0
}

create_default_config() {
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

    log_success "Default configuration created"

    return 0
}

install_notify_script() {
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

test_installation() {
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
    cat <<EOF

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

EOF

    return 0
}

#############################################################################
# Main Installation Process
#############################################################################

main() {
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

    # Check existing installation
    if ! check_existing_installation; then
        exit $EXIT_ALREADY_INSTALLED
    fi

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

    # Test installation
    test_installation

    # Print post-install information
    print_post_install_info

    exit $EXIT_SUCCESS
}

# Execute main function
main "$@"
