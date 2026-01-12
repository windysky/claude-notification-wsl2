---
id: SPEC-NOTIF-002
version: "1.0.0"
status: "draft"
created: "2026-01-11"
updated: "2026-01-11"
author: "Junguk Hur"
priority: "HIGH"
---

## HISTORY

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2026-01-11 | Junguk Hur | Initial SPEC creation for complete Windows notification framework |

---

## SPECIFICATION: Complete Windows Notification Framework for Claude Code CLI on WSL2

### Environment

**Operating System**: Windows 10/11 (host) with WSL2 (guest)
**PowerShell Version**: 5.1+ (Windows built-in)
**Python Version**: 3.10+ (WSL2)
**Notification Module**: BurntToast 0.8.0+
**Hook Events**: PostToolUse, SessionEnd, Notification
**Configuration**: MoAI-ADK settings.json

### Assumptions

1. **PowerShell Execution Policy**: Users can execute PowerShell scripts from WSL2 via `powershell.exe -File`
2. **BurntToast Module Availability**: BurntToast module can be installed via PowerShell Gallery
3. **Character Encoding**: Windows and WSL2 can communicate using UTF-8 encoding for multi-language support
4. **Hook Availability**: Claude Code supports hook events for PostToolUse, SessionEnd, and Notification
5. **Non-Blocking Requirement**: Notifications must never block or delay Claude Code operations
6. **Graceful Degradation**: System should fail silently when notification delivery fails

### Requirements (EARS Format)

#### NOTIF-CORE: Core Notification Delivery

**Ubiquitous Requirements:**

- The system **shall** always deliver notifications to Windows Action Center without blocking Claude Code CLI operations
- The system **shall** always validate notification content length before delivery to prevent truncation
- The system **shall** always use UTF-8 encoding for notification content to support international characters

**Event-Driven Requirements:**

- **WHEN** a PostToolUse event occurs **THEN** the system **shall** deliver a toast notification with tool execution result summary
- **WHEN** a SessionEnd event occurs **THEN** the system **shall** deliver a summary notification with session statistics
- **WHEN** a Notification hook is triggered **THEN** the system **shall** deliver the notification payload to Windows

**State-Driven Requirements:**

- **IF** BurntToast module is not installed **THEN** the system **shall** attempt auto-installation and fall back to silent failure if unsuccessful
- **IF** PowerShell execution policy blocks script execution **THEN** the system **shall** use `-ExecutionPolicy Bypass` flag
- **IF** notification content exceeds 200 characters **THEN** the system **shall** truncate with ellipsis and append "..." suffix

**Unwanted Requirements:**

- The system **shall not** block or delay Claude Code CLI operations for notification delivery
- The system **shall not** display error messages to user when notification delivery fails
- The system **shall not** require manual configuration for basic notification functionality

**Optional Requirements:**

- **WHERE** possible, the system **shall** support custom notification sounds based on event type
- **WHERE** possible, the system **shall** support notification grouping by session or tool type
- **WHERE** possible, the system **shall** support clickable notification actions (e.g., "View Logs")

#### NOTIF-HOOK: Hook Integration

**Ubiquitous Requirements:**

- The system **shall** always execute hooks asynchronously to prevent blocking Claude Code operations
- The system **shall** always provide structured context data to hook handlers (event type, timestamp, metadata)

**Event-Driven Requirements:**

- **WHEN** PostToolUse hook fires **THEN** the system **shall** extract tool name, execution status, and duration for notification
- **WHEN** SessionEnd hook fires **THEN** the system **shall** calculate session duration, tools used, and operations completed
- **WHEN** Notification hook fires **THEN** the system **shall** pass notification payload directly to Windows toast handler

**State-Driven Requirements:**

- **IF** hook execution fails **THEN** the system **shall** log error without affecting Claude Code operation
- **IF** hook execution exceeds 500ms **THEN** the system **shall** timeout and skip notification delivery

**Unwanted Requirements:**

- Hook failures **shall not** propagate exceptions to Claude Code CLI
- Hook handlers **shall not** modify Claude Code behavior or state

#### NOTIF-BRIDGE: WSL2-to-Windows Communication

**Ubiquitous Requirements:**

- The system **shall** always use `powershell.exe` command from WSL2 to invoke Windows PowerShell scripts
- The system **shall** always pass notification data via command-line arguments with proper escaping

**Event-Driven Requirements:**

- **WHEN** invoking bridge script **THEN** the system **shall** execute `powershell.exe -ExecutionPolicy Bypass -File`
- **WHEN** passing multi-language text **THEN** the system **shall** properly escape special characters for PowerShell

**State-Driven Requirements:**

- **IF** powershell.exe is not found **THEN** the system **shall** silently skip notification delivery
- **IF** Windows host is unreachable **THEN** the system **shall** timeout after 1 second and return

**Unwanted Requirements:**

- The bridge **shall not** require network configuration or additional services
- The bridge **shall not** create persistent processes or background services

#### NOTIF-CONFIG: Configuration Management

**Ubiquitous Requirements:**

- The system **shall** store notification configuration in MoAI-ADK settings.json under hooks section
- The system **shall** provide sensible defaults for all configuration options

**Event-Driven Requirements:**

- **WHEN** configuration is missing **THEN** the system **shall** use default values (enabled: true, throttle: 1000ms)
- **WHEN** user disables notifications **THEN** the system **shall** skip all notification delivery

**State-Driven Requirements:**

- **IF** custom notification rules exist **THEN** the system **shall** evaluate rules before delivery
- **IF** throttle period is configured **THEN** the system **shall** skip duplicate notifications within throttle window

**Optional Requirements:**

- **WHERE** possible, the system **shall** support per-tool notification filtering (e.g., only notify on Write operations)
- **WHERE** possible, the system **shall** support quiet hours configuration

#### NOTIF-DEPLOY: Deployment Automation

**Ubiquitous Requirements:**

- The deployment script **shall** be idempotent and safe to run multiple times
- The deployment script **shall** verify prerequisites before installation

**Event-Driven Requirements:**

- **WHEN** installation script runs **THEN** the system **shall** install BurntToast module if not present
- **WHEN** installation script runs **THEN** the system **shall** configure Claude Code hooks automatically
- **WHEN** uninstallation script runs **THEN** the system **shall** remove all installed files and hooks

**State-Driven Requirements:**

- **IF** PowerShell Gallery is inaccessible **THEN** the installation script **shall** provide clear error message with manual instructions
- **IF** Claude Code config is locked **THEN** the installation script **shall** request user to close Claude Code

#### NOTIF-I18N: Multi-Language Support

**Ubiquitous Requirements:**

- The system **shall** support English (EN), Korean (KO), Japanese (JA), and Chinese (ZH) languages
- The system **shall** detect user language from MoAI config or system locale

**Event-Driven Requirements:**

- **WHEN** notification template is loaded **THEN** the system **shall** use user's conversation_language
- **WHEN** template is missing for language **THEN** the system **shall** fall back to English template

**State-Driven Requirements:**

- **IF** user language is not supported **THEN** the system **shall** use English with warning log
- **IF** character encoding fails **THEN** the system **shall** use ASCII-safe fallback

**Optional Requirements:**

- **WHERE** possible, the system **shall** support right-to-left languages (e.g., Arabic)
- **WHERE** possible, the system **shall** use localized notification sounds

### Specifications

#### 1. PowerShell Toast Notification Script (`wsl-toast.ps1`)

**Location**: Windows accessible path (e.g., `%USERPROFILE%\.wsl-toast\wsl-toast.ps1`)

**Parameters**:
- `Title` (string): Notification title
- `Message` (string): Notification body
- `Type` (string): Notification type (info, success, warning, error)
- `Duration` (int): Display duration in milliseconds (default: 5000)

**Functionality**:
```powershell
param(
    [Parameter(Mandatory=$true)]
    [string]$Title,

    [Parameter(Mandatory=$true)]
    [string]$Message,

    [Parameter(Mandatory=$false)]
    [ValidateSet('info', 'success', 'warning', 'error')]
    [string]$Type = 'info',

    [Parameter(Mandatory=$false)]
    [int]$Duration = 5000
)

# Import BurntToast module
if (-not (Get-Module -ListAvailable -Name BurntToast)) {
    Install-Module -Name BurntToast -Force -Scope CurrentUser -ErrorAction SilentlyContinue
}

# Send toast notification
$toastParams = @{
    Text = $Title, $Message
}

switch ($Type) {
    'success' { $toastParams['AppLogo'] = 'success-icon.png' }
    'warning' { $toastParams['AppLogo'] = 'warning-icon.png' }
    'error'   { $toastParams['AppLogo'] = 'error-icon.png' }
    default   { $toastParams['AppLogo'] = 'info-icon.png' }
}

New-BurntToastNotification @toastParams
```

#### 2. WSL2 Bridge Script (`scripts/notify.sh`)

**Location**: WSL2 filesystem at project root

**Parameters**:
- `TITLE`: Notification title
- `MESSAGE`: Notification message
- `TYPE`: Notification type (optional, default: info)

**Functionality**:
```bash
#!/bin/bash

TITLE="${1:-Claude Code}"
MESSAGE="${2:-Notification from Claude Code}"
TYPE="${3:-info}"

# Escape special characters for PowerShell
escape_ps() {
    echo "$1" | sed 's/"/\\"/g' | sed "s/'/\\'/g"
}

# Invoke Windows PowerShell
powershell.exe -ExecutionPolicy Bypass -File "$HOME/.wsl-toast/wsl-toast.ps1" \
    -Title "$(escape_ps "$TITLE")" \
    -Message "$(escape_ps "$MESSAGE")" \
    -Type "$TYPE" \
    -Duration 5000 \
    >/dev/null 2>&1 &

# Background the process to avoid blocking
disown %1 2>/dev/null || true
```

#### 3. Hook Configuration (`settings.json`)

```json
{
  "hooks": {
    "PostToolUse": {
      "command": "/home/juhur/PROJECTS/claude_notification_wsl2/scripts/notify.sh",
      "args": [
        "Claude Code: {tool_name}",
        "{status} - Duration: {duration_ms}ms",
        "{type}"
      ],
      "enabled": true,
      "timeout": 500
    },
    "SessionEnd": {
      "command": "/home/juhur/PROJECTS/claude_notification_wsl2/scripts/notify.sh",
      "args": [
        "Claude Code Session Complete",
        "Session: {duration}, Tools: {tool_count}, Ops: {op_count}",
        "success"
      ],
      "enabled": true,
      "timeout": 1000
    },
    "Notification": {
      "command": "/home/juhur/PROJECTS/claude_notification_wsl2/scripts/notify.sh",
      "args": [
        "{title}",
        "{message}",
        "{type}"
      ],
      "enabled": true,
      "timeout": 500
    }
  },
  "notifications": {
    "enabled": true,
    "throttle_ms": 1000,
    "language": "en",
    "quiet_hours": {
      "enabled": false,
      "start": "22:00",
      "end": "08:00"
    }
  }
}
```

#### 4. Multi-Language Templates

**Template Format**: `templates/notifications/{language}.json`

**English Template** (`en.json`):
```json
{
  "PostToolUse": {
    "title": "Claude Code: {tool_name}",
    "message": "Status: {status}, Duration: {duration_ms}ms",
    "types": {
      "Read": "info",
      "Write": "success",
      "Edit": "success",
      "Bash": "warning",
      "default": "info"
    }
  },
  "SessionEnd": {
    "title": "Claude Code Session Complete",
    "message": "Duration: {duration}, Tools: {tool_count}, Operations: {op_count}",
    "type": "success"
  }
}
```

**Korean Template** (`ko.json`):
```json
{
  "PostToolUse": {
    "title": "Claude Code: {tool_name}",
    "message": "상태: {status}, 소요 시간: {duration_ms}ms",
    "types": {
      "Read": "info",
      "Write": "success",
      "Edit": "success",
      "Bash": "warning",
      "default": "info"
    }
  },
  "SessionEnd": {
    "title": "Claude Code 세션 완료",
    "message": "기간: {duration}, 도구: {tool_count}, 작업: {op_count}",
    "type": "success"
  }
}
```

#### 5. Deployment Automation

**Installation Script** (`scripts/install-notifications.sh`):
```bash
#!/bin/bash

set -e

INSTALL_DIR="$HOME/.wsl-toast"
SCRIPT_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/wsl-toast.ps1"

echo "Installing Windows Notification Framework for Claude Code CLI..."

# Create installation directory
mkdir -p "$INSTALL_DIR"

# Copy PowerShell script to Windows accessible location
cp "$SCRIPT_SOURCE" "$INSTALL_DIR/"

# Install BurntToast module
echo "Installing BurntToast PowerShell module..."
powershell.exe -Command "Install-Module -Name BurntToast -Force -Scope CurrentUser" 2>/dev/null || {
    echo "Warning: BurntToast installation failed. Please run manually in PowerShell:"
    echo "  Install-Module -Name BurntToast -Force -Scope CurrentUser"
}

# Configure Claude Code hooks
echo "Configuring Claude Code hooks..."
# (Hook configuration logic)

echo "Installation complete!"
echo "Restart Claude Code to enable notifications."
```

### Traceability Tags

- **NOTIF-CORE**: Core notification delivery functionality
- **NOTIF-HOOK**: Hook integration with Claude Code
- **NOTIF-BRIDGE**: WSL2-to-Windows communication bridge
- **NOTIF-CONFIG**: Configuration management
- **NOTIF-DEPLOY**: Deployment and installation automation
- **NOTIF-I18N**: Multi-language support and localization
