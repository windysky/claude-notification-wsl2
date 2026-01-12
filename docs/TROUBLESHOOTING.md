# Troubleshooting Guide

Common issues and solutions for the Windows Notification Framework for Claude Code CLI on WSL2.

## Table of Contents

- [Installation Issues](#installation-issues)
- [Notification Issues](#notification-issues)
- [Hook Integration Issues](#hook-integration-issues)
- [Multi-Language Issues](#multi-language-issues)
- [Performance Issues](#performance-issues)
- [Debugging Tools](#debugging-tools)

## Installation Issues

### PowerShell Not Found

**Symptom**: `PowerShell not found` error message.

**Diagnosis**:

```bash
# Check if PowerShell is accessible
which powershell.exe

# Expected output: /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
# If not found, you have a WSL2/Windows integration issue
```

**Solutions**:

1. Verify WSL2 is properly installed and running:

```bash
# Check WSL version
wsl.exe --version

# If WSL2 is not installed, install it from Microsoft Store
```

2. Check Windows accessibility from WSL2:

```bash
# Test Windows mount
ls /mnt/c/Windows/System32/WindowsPowerShell/v1.0/
```

3. Try different PowerShell paths:

```bash
# Check for PowerShell in different locations
ls /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
ls /mnt/c/WINDOWS/System32/WindowsPowerShell/v1.0/powershell.exe
```

### BurntToast Module Not Installed

**Symptom**: Notifications don't appear or BurntToast errors.

**Diagnosis**:

```bash
# Check if BurntToast is installed
powershell.exe -Command "Get-Module -ListAvailable -Name BurntToast"

# If empty output, BurntToast is not installed
```

**Solutions**:

1. Install BurntToast automatically:

```bash
# From WSL2
powershell.exe -Command "Install-Module -Name BurntToast -Force -Scope CurrentUser"
```

2. Manual installation in Windows PowerShell:

```powershell
# Open Windows PowerShell (not WSL2)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Install-Module -Name BurntToast -Force -Scope CurrentUser

# Verify installation
Get-Module -ListAvailable -Name BurntToast
```

3. If installation fails due to network issues:

```powershell
# Check PowerShell Gallery connectivity
Find-Module -Name BurntToast

# If this fails, you may need to configure a proxy or use offline installation
```

### Execution Policy Error

**Symptom**: `cannot be loaded because running scripts is disabled on this system`.

**Diagnosis**:

```bash
# Check execution policy
powershell.exe -Command "Get-ExecutionPolicy -List"
```

**Solutions**:

```bash
# Set execution policy for current user
powershell.exe -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"

# Or bypass for specific command
powershell.exe -ExecutionPolicy Bypass -File /path/to/script.ps1
```

### Script Not Executable

**Symptom**: `Permission denied` when running notify.sh.

**Solution**:

```bash
# Make the script executable
chmod +x scripts/notify.sh

# Verify
ls -la scripts/notify.sh
# Should show: -rwxr-xr-x (executable)
```

## Notification Issues

### Notifications Not Appearing

**Symptom**: Script runs but no Windows notification appears.

**Diagnosis**:

```bash
# Run in verbose mode
./scripts/notify.sh --verbose --title "Test" --message "Test message"

# Check if PowerShell command executes
powershell.exe -Command "Write-Host 'PowerShell is working'"

# Test with mock mode
./scripts/notify.sh --mock --title "Test" --message "Testing"
```

**Solutions**:

1. Check Windows notification settings:

- Windows Settings > System > Notifications
- Ensure "Get notifications from apps and other senders" is ON
- Check Focus Assist is not blocking notifications

2. Check Windows Action Center:

- Click the notification icon in system tray
- Verify notifications are not being filtered

3. Test PowerShell script directly:

```powershell
# In Windows PowerShell
.\wsl-toast.ps1 -Title "Test" -Message "Test message"
```

4. Check for Windows notification quota issues:

```powershell
# Clear notification history
Clear-Notification
```

### UTF-8 Character Issues

**Symptom**: Korean, Japanese, or Chinese characters appear as squares or question marks.

**Diagnosis**:

```bash
# Test UTF-8 encoding
./scripts/notify.sh --title "테스트" --message "한글 알림" --type Success
```

**Solutions**:

1. Ensure UTF-8 locale is set:

```bash
# Check locale
locale

# Set UTF-8 locale
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Add to ~/.bashrc for persistence
echo 'export LANG=en_US.UTF-8' >> ~/.bashrc
echo 'export LC_ALL=en_US.UTF-8' >> ~/.bashrc
```

2. Verify PowerShell UTF-8 encoding:

```bash
# Test PowerShell encoding
powershell.exe -Command "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; Write-Host '한글'"
```

3. Check template file encoding:

```bash
# Verify template files are UTF-8 encoded
file templates/notifications/ko.json
# Should show: UTF-8 Unicode text
```

### Wrong Notification Type

**Symptom**: Always shows as Information regardless of specified type.

**Diagnosis**:

```bash
# Test different types
./scripts/notify.sh --type Warning --title "Test" --message "Should be warning"
./scripts/notify.sh --type Error --title "Test" --message "Should be error"
```

**Solution**: Verify BurntToast is installed. Without BurntToast, the framework falls back to Windows Forms BalloonTip which only supports Info and Error icons.

### Notification Position Incorrect

**Symptom**: Notifications appear in wrong screen position.

**Solution**: Windows Action Center controls notification position. The `position` configuration option may not work on all Windows versions. Use Windows Settings to adjust notification position.

## Hook Integration Issues

### Hook Not Executing

**Symptom**: Hook configured but not executing on expected events.

**Diagnosis**:

```bash
# Verify hook configuration
cat .claude/settings.json | grep -A 10 "hooks"

# Check script path
ls -la ./hooks/PostToolUse.sh
```

**Solutions**:

1. Verify path is correct in `.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/hooks/PostToolUse.sh"
          }
        ]
      }
    ]
  }
}
```

2. Get correct project path:

```bash
# Get absolute path
pwd
# Use this exact path in settings.json
```

3. Check file permissions:

```bash
chmod +x scripts/notify.sh
```

4. Check Claude Code logs for hook execution errors.

### Hook Blocks Claude Code

**Symptom**: Claude Code becomes unresponsive when hooks execute.

**Diagnosis**: Hook is running in foreground mode.

**Solution**: Use `run_in_background` or keep `--background` in the hook script:

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
            "run_in_background": true
          }
        ]
      }
    ]
  }
}
```

### Variables Not Substituted

**Symptom**: Variables appear as literal text like `{tool_name}`.

**Diagnosis**: Claude Code no longer interpolates `{...}` placeholders in hook
commands.

**Solution**: Parse the hook JSON on stdin inside your hook script (see
`hooks/PostToolUse.sh` for an example).

### Hook Timeout

**Symptom**: Hook times out before completion.

**Diagnosis**: Hook execution exceeds configured timeout.

**Solutions**:

1. Increase timeout in `.claude/settings.json`:

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
            "timeout": 2000
          }
        ]
      }
    ]
  }
}
```

2. Use background mode for immediate return:

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
            "run_in_background": true
          }
        ]
      }
    ]
  }
}
```

## Multi-Language Issues

### Language Not Supported

**Symptom**: `Unsupported language: xx` error.

**Solution**: Check supported languages:

```python
from src.template_loader import TemplateLoader

loader = TemplateLoader()
print(loader.get_available_languages())
# Output: ['en', 'ko', 'ja', 'zh']
```

Only `en`, `ko`, `ja`, `zh` are supported by default.

### Template File Missing

**Symptom**: Fallback to English even when language is configured.

**Diagnosis**:

```bash
# Check if template file exists
ls templates/notifications/ko.json
```

**Solution**: Ensure template files exist:

```bash
ls -la templates/notifications/
# Should show: en.json, ko.json, ja.json, zh.json
```

### Template Not Found for Key

**Symptom**: `Template key not found: xxx` error.

**Solution**: Verify the key exists in the template file:

```bash
# Check template content
cat templates/notifications/en.json | grep "your_key"
```

Use only predefined template keys:
- `tool_completed`
- `tool_failed`
- `error_occurred`
- `session_start`
- `session_end`
- `build_complete`
- `build_failed`
- `test_complete`
- `test_failed`

## Performance Issues

### Too Many Notifications

**Symptom**: Notification spam from frequent PostToolUse hooks.

**Solutions**:

1. Disable PostToolUse hook:

```json
{
  "hooks": {
    "PostToolUse": []
  }
}
```

2. Use shorter duration:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "bash -lc '$CLAUDE_PROJECT_DIR/scripts/notify.sh --duration Short --title \"Tool\" --message \"Short\"'",
            "run_in_background": true
          }
        ]
      }
    ]
  }
}
```

3. Only notify on specific tools (requires custom script):

```bash
# In custom wrapper script
if [[ "$TOOL_NAME" == "Write" ]]; then
    ./scripts/notify.sh "$@"
fi
```

### Slow Hook Execution

**Symptom**: Hooks take too long to execute.

**Solutions**:

1. Use background mode:

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
            "run_in_background": true
          }
        ]
      }
    ]
  }
}
```

2. Reduce timeout:

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
            "timeout": 500
          }
        ]
      }
    ]
  }
}
```

3. Test script performance:

```bash
# Time the script execution
time ./scripts/notify.sh --mock --title "Test" --message "Test"
```

### High Memory Usage

**Symptom**: Memory usage increases over time.

**Diagnosis**: Check for orphaned background processes:

```bash
# Check for notify.sh processes
ps aux | grep notify.sh
```

**Solution**: Background processes should automatically terminate. If they don't, there may be an issue with PowerShell execution. Kill orphaned processes:

```bash
# Kill orphaned processes
pkill -f notify.sh
```

## Debugging Tools

### Verbose Mode

Enable detailed logging:

```bash
# Set debug environment variable
export DEBUG=true

# Or use verbose flag
./scripts/notify.sh --verbose --title "Test" --message "Debug info"
```

### Mock Mode

Test without displaying notifications:

```bash
./scripts/notify.sh --mock --title "Test" --message "Testing framework"
```

### Check Configuration

```bash
# View configuration
cat ~/.wsl-toast/config.json

# Or use Python
python3 -c "from src.config_loader import load_config; import json; print(json.dumps(load_config(), indent=2))"
```

### Test PowerShell Directly

```bash
# Test PowerShell connectivity
powershell.exe -Command "Write-Host 'PowerShell works'"

# Test BurntToast availability
powershell.exe -Command "Get-Module -ListAvailable -Name BurntToast"

# Test toast script directly
powershell.exe -ExecutionPolicy Bypass -File ~/.wsl-toast/wsl-toast.ps1 -Title "Test" -Message "Test message"
```

### Check Logs

```bash
# Check for error messages
./scripts/notify.sh --title "Test" --message "Test" 2>&1 | tee notification.log

# View Claude Code logs
# Location varies by installation
```

### Validate Configuration

```python
from src.config_loader import load_config, validate_config

config = load_config()
is_valid, errors = validate_config(config)

if not is_valid:
    print("Configuration errors:")
    for error in errors:
        print(f"  - {error}")
```

### Test Templates

```python
from src.template_loader import get_template_loader

loader = get_template_loader()

# Check available languages
print("Languages:", loader.get_available_languages())

# Test specific template
try:
    template = loader.get_template("tool_completed", language="en")
    print("Template:", template)
except KeyError as e:
    print("Template not found:", e)
except ValueError as e:
    print("Invalid language:", e)
```

## Getting Help

If you continue to experience issues:

1. Check the [GitHub Issues](https://github.com/yourusername/claude_notification_wsl2/issues)
2. Create a new issue with:
   - Windows version
   - WSL2 distribution and version
   - Python version
   - Full error message
   - Steps to reproduce
   - Debug output (from verbose mode)

3. Include diagnostic information:

```bash
# System information
uname -a
wsl.exe --version

# PowerShell version
powershell.exe -Command "$PSVersionTable"

# Python version
python3 --version

# Test results
./scripts/notify.sh --verbose --mock --title "Test" --message "Diagnostic"
```

## Common Error Messages

### "PowerShell not found"

PowerShell executable is not accessible from WSL2. See [PowerShell Not Found](#powershell-not-found).

### "BurntToast module not installed"

BurntToast PowerShell module is missing. See [BurntToast Module Not Installed](#burnttoast-module-not-installed).

### "Configuration file not found"

Configuration will use defaults. To customize, create `~/.wsl-toast/config.json`.

### "Invalid notification type"

Type must be one of: Information, Warning, Error, Success.

### "Invalid duration"

Duration must be one of: Short, Normal, Long.

### "Unsupported language"

Language must be one of: en, ko, ja, zh.

### "Template key not found"

The requested template key does not exist in the template file.

### "Missing required parameters"

Both `--title` and `--message` are required.
