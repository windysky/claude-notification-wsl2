# Installation Guide

Complete installation instructions for the Windows Notification Framework for Claude Code CLI on WSL2.

## Prerequisites

### Windows Host Requirements

- Windows 10 version 1903+ or Windows 11
- Windows PowerShell 5.1+ (built into Windows)
- PowerShell execution policy allowing script execution
- Windows Notification Center enabled

### WSL2 Guest Requirements

- WSL2 running a supported Linux distribution (Ubuntu, Debian, etc.)
- Bash 4.0 or higher
- Python 3.10 or higher (for configuration modules)
- Basic Unix utilities (sed, grep, find)

## Installation Methods

### Method 1: Automated Installation (Recommended)

The automated installation script handles setup steps including PowerShell module installation.

```bash
# Clone the repository
git clone https://github.com/yourusername/claude_notification_wsl2.git
cd claude_notification_wsl2

# Run installation script
chmod +x setup.sh
./setup.sh
```

The installation script will:

1. Verify prerequisites (PowerShell availability, WSL2 connectivity)
2. Install the BurntToast PowerShell module (optional)
3. Create the configuration directory (`~/.wsl-toast/`)
4. Create default configuration file
5. Make the notify script executable
6. Create a symlink at `~/.local/bin/wsl-toast`
7. Optionally configure Claude Code hooks (interactive prompts)
8. Run a mock notification test

### Method 2: Manual Installation

For advanced users who prefer manual setup:

#### Step 1: Create Configuration Directory

```bash
mkdir -p ~/.wsl-toast
```

#### Step 2: Copy PowerShell Script

```bash
# From project root
cp windows/wsl-toast.ps1 ~/.wsl-toast/

# Verify the script is accessible from Windows
ls -la ~/.wsl-toast/wsl-toast.ps1
```

#### Step 3: Install BurntToast Module

The BurntToast module is required for modern Windows toast notifications.

**Option A: Automatic Installation via PowerShell**

```bash
# From WSL2, invoke Windows PowerShell
powershell.exe -Command "Install-Module -Name BurntToast -Force -Scope CurrentUser"
```

**Option B: Manual Installation in Windows PowerShell**

Open Windows PowerShell (not WSL2):

```powershell
# Open PowerShell as Administrator (optional)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Install BurntToast from PowerShell Gallery
Install-Module -Name BurntToast -Force -Scope CurrentUser

# Verify installation
Get-Module -ListAvailable -Name BurntToast
```

#### Step 4: Make Bridge Script Executable

```bash
chmod +x scripts/notify.sh
```

#### Step 5: Test Installation

```bash
# Test notification
./scripts/notify.sh --title "Installation Test" --message "If you see this, installation is successful!" --type Success

# Test with mock mode (no actual notification)
./scripts/notify.sh --mock --title "Mock Test" --message "Testing notification system"
```

## Claude Code Hooks Integration

### Manual Hook Configuration

Edit your Claude Code settings file at `.claude/settings.json`:

**Note:** `$CLAUDE_PROJECT_DIR` is provided by Claude Code and points to your project root.

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/hooks/PostToolUse.sh",
            "timeout": 500,
            "run_in_background": true
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/hooks/SessionStart.sh",
            "timeout": 1000,
            "run_in_background": true
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/hooks/SessionEnd.sh",
            "timeout": 1000,
            "run_in_background": true
          }
        ]
      }
    ]
  }
}
```

### Available Hook Templates

The framework provides templates for common Claude Code events:

- **PostToolUse**: Notifications after tool execution (Read, Write, Edit, Bash, etc.)
- **SessionStart**: Welcome notification when starting Claude Code
- **SessionEnd**: Summary notification when ending a session
- **Notification**: Direct notifications from Claude Code

## Verification Steps

After installation, verify each component:

### 1. Verify PowerShell Accessibility

```bash
# Check PowerShell is accessible
powershell.exe -Command "Write-Host 'PowerShell is working'"

# Expected output: PowerShell is working
```

### 2. Verify BurntToast Module

```bash
# Check if BurntToast is installed
powershell.exe -Command "Get-Module -ListAvailable -Name BurntToast"

# Expected output: Module information (version, name, etc.)
```

### 3. Verify Bridge Script

```bash
# Test the bridge script
./scripts/notify.sh --help

# Expected output: Usage information
```

### 4. Verify Notification Delivery

```bash
# Send a test notification
./scripts/notify.sh --title "Test" --message "Installation verification" --type Success

# Expected: A Windows toast notification should appear
```

## Post-Installation Configuration

### Set Preferred Language

Edit `~/.wsl-toast/config.json`:

```json
{
  "language": "ko"
}
```

Supported languages: `en`, `ko`, `ja`, `zh`

### Configure Default Notification Type

```json
{
  "default_type": "Information"
}
```

Valid types: `Information`, `Warning`, `Error`, `Success`

### Set Default Duration

```json
{
  "default_duration": "Normal"
}
```

Valid durations: `Short`, `Normal`, `Long`

## Uninstallation

To completely remove the notification framework:

```bash
# Run the uninstallation script
chmod +x uninstall.sh
./uninstall.sh
```

The uninstallation script will:

1. Remove configuration directory (`~/.wsl-toast/`)
2. Remove the `~/.local/bin/wsl-toast` symlink
3. Provide optional cleanup steps for BurntToast and PATH entries

### Manual Uninstallation

If you prefer manual removal:

```bash
# Remove hooks from .claude/settings.json
# (Edit the file and remove the hooks section)

# Remove configuration directory
rm -rf ~/.wsl-toast

# Remove BurntToast module (optional)
powershell.exe -Command "Uninstall-Module -Name BurntToast -Force"

# Remove project directory
rm -rf /path/to/claude_notification_wsl2
```

## Troubleshooting Installation

### Issue: PowerShell Execution Policy

**Problem**: Script execution is disabled on this system.

**Solution**:

```bash
# From WSL2, run PowerShell with Bypass policy
powershell.exe -ExecutionPolicy Bypass -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
```

### Issue: BurntToast Installation Fails

**Problem**: Cannot install BurntToast module.

**Solution**: Ensure PowerShell Gallery is accessible and NuGet provider is installed:

```powershell
# In Windows PowerShell
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name BurntToast -Force -Scope CurrentUser
```

### Issue: Windows Firewall Blocks WSL2

**Problem**: WSL2 cannot access Windows PowerShell.

**Solution**: Add firewall rules:

```powershell
# In Windows PowerShell (as Administrator)
New-NetFirewallRule -DisplayName "WSL2" -Direction Inbound -Action Allow
```

### Issue: Wrong Path in Hooks

**Problem**: Claude Code cannot find the notify.sh script.

**Solution**: Update the path in `.claude/settings.json` with your actual project path:

```bash
# Get the absolute path
pwd
# Output: $PROJECT_ROOT

# Use this path in settings.json
```

## Installation Checklist

Use this checklist to ensure complete installation:

- [ ] WSL2 is properly configured
- [ ] PowerShell is accessible from WSL2
- [ ] BurntToast module is installed
- [ ] Configuration directory exists (`~/.wsl-toast/`)
- [ ] PowerShell script is copied to Windows-accessible location
- [ ] Bridge script is executable
- [ ] Test notification appears successfully
- [ ] Claude Code hooks are configured (if using hooks)
- [ ] Multi-language templates are present
- [ ] Configuration file exists with preferred settings

## Next Steps

After successful installation:

1. Configure your preferred language
2. Set up Claude Code hooks for automatic notifications
3. Customize notification templates if needed
4. Read the [Configuration Guide](CONFIGURATION.md) for advanced options
5. Refer to [API Documentation](API.md) for programmatic usage
