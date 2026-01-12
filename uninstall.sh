#!/usr/bin/env bash
# uninstall.sh - Uninstallation Script for WSL Toast Notifications
# Removes Windows toast notification system from WSL2
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
SYMLINK="${HOME}/.local/bin/wsl-toast"

# Exit codes
EXIT_SUCCESS=0
EXIT_ERROR=1

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
# Uninstallation Functions
#############################################################################

confirm_uninstallation() {
    log_warning "This will remove WSL Toast Notification from your system"
    echo
    echo "Items to be removed:"
    echo "  - Configuration directory: $CONFIG_DIR"
    echo "  - Configuration file: $CONFIG_FILE"
    echo "  - Symbolic link: $SYMLINK"
    echo
    echo "Items NOT removed (preserve your project):"
    echo "  - Project directory: $PROJECT_ROOT"
    echo "  - PowerShell scripts"
    echo "  - Templates and configuration"
    echo

    read -p "Do you want to continue? [y/N]: " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Uninstallation cancelled"
        return 1
    fi

    return 0
}

remove_symlink() {
    log_info "Removing symbolic link..."

    if [ -L "$SYMLINK" ]; then
        rm "$SYMLINK"
        log_success "Symbolic link removed: $SYMLINK"
    elif [ -e "$SYMLINK" ]; then
        log_warning "$SYMLINK exists but is not a symbolic link. Skipping."
    else
        log_info "Symbolic link not found: $SYMLINK"
    fi

    return 0
}

remove_config_directory() {
    log_info "Removing configuration directory..."

    if [ -d "$CONFIG_DIR" ]; then
        # Check if there are user-modified files
        local config_backup="${CONFIG_DIR}.backup"

        # Backup config before removal
        if [ -f "$CONFIG_FILE" ]; then
            cp -r "$CONFIG_DIR" "$config_backup"
            log_info "Configuration backed up to: $config_backup"
        fi

        # Remove directory
        rm -rf "$CONFIG_DIR"
        log_success "Configuration directory removed: $CONFIG_DIR"
    else
        log_info "Configuration directory not found: $CONFIG_DIR"
    fi

    return 0
}

uninstall_powershell_module() {
    log_info "PowerShell module removal..."
    log_info "BurntToast module is not automatically removed"
    log_info "To remove it manually, run in PowerShell:"
    echo "  Uninstall-Module -Name BurntToast"
    echo

    return 0
}

remove_from_path() {
    log_info "PATH configuration..."
    log_info "If you added ~/.local/bin to your PATH in your shell config,"
    log_info "you may want to remove that line manually from:"
    echo "  - ~/.bashrc"
    echo "  - ~/.zshrc"
    echo

    return 0
}

print_post_uninstall_info() {
    cat <<EOF

${GREEN}========================================${NC}
${GREEN}Uninstallation Complete!${NC}
${GREEN}========================================${NC}

${BLUE}Removed:${NC}
  - Configuration directory: ${CONFIG_DIR}
  - Symbolic link: ${SYMLINK}

${BLUE}Preserved:${NC}
  - Project directory: ${PROJECT_ROOT}
  - All source code and scripts
  - Configuration backup: ${CONFIG_DIR}.backup (if existed)

${BLUE}Optional Cleanup:${NC}
  1. Remove project directory if desired:
     rm -rf ${PROJECT_ROOT}
  2. Remove BurntToast module from PowerShell:
     powershell.exe -Command "Uninstall-Module -Name BurntToast"
  3. Remove PATH entry from ~/.bashrc or ~/.zshrc (if added)

${BLUE}Thank you for using WSL Toast Notifications!${NC}

EOF

    return 0
}

#############################################################################
# Main Uninstallation Process
#############################################################################

main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}WSL Toast Notification Uninstaller${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo

    # Confirm uninstallation
    if ! confirm_uninstallation; then
        exit $EXIT_SUCCESS
    fi

    echo

    # Remove symlink
    remove_symlink

    # Remove configuration directory
    remove_config_directory

    # PowerShell module info
    uninstall_powershell_module

    # PATH cleanup info
    remove_from_path

    # Print post-uninstall information
    print_post_uninstall_info

    exit $EXIT_SUCCESS
}

# Execute main function
main "$@"
