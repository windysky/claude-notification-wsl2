# Claude Code Hooks Integration Guide

Complete guide for integrating Windows notifications with Claude Code hooks.

## Table of Contents

- [Overview](#overview)
- [Hook Configuration](#hook-configuration)
- [Hook Types](#hook-types)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Overview

Claude Code hooks enable automatic notifications at specific events during your development workflow. The Windows Notification Framework provides seamless integration with Claude Code's hook system.

### What are Hooks?

Hooks are scripts that Claude Code executes at specific points:

- **SessionStart**: When you start a Claude Code session
- **SessionEnd**: When you end a Claude Code session
- **PostToolUse**: After any tool execution (Read, Write, Edit, Bash, etc.)
- **Notification**: When Claude Code sends a notification

### Benefits of Hook Integration

- Stay informed without switching windows
- Get notified of long-running operations
- Track your development session activity
- Receive build/test results automatically

## Hook Configuration

### Configuration File Location

Claude Code hooks are configured in `.claude/settings.json` at your project root.

### Configuration Format

```json
{
  "hooks": {
    "HookName": [
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
    ]
  }
}
```

### Configuration Parameters

#### matcher

Type: `string`
Required: Only for tool events (PreToolUse, PermissionRequest, PostToolUse)

Pattern to match tool names. Use `.*` to match all tools:

```json
{
  "matcher": "Write|Edit"
}
```

#### hooks

Type: `array`
Required: Yes

Hooks to execute when the matcher matches:

```json
{
  "hooks": [
    {
      "type": "command",
      "command": "$CLAUDE_PROJECT_DIR/hooks/PostToolUse.sh"
    }
  ]
}
```

#### type

Type: `string`
Required: Yes

Use `command` for shell scripts.

#### command

Type: `string`
Required: Yes

Shell command or script path to execute. Hook input JSON is provided on stdin.

#### timeout

Type: `number`
Required: No

Maximum time (in milliseconds) to wait for hook execution:

```json
{
  "timeout": 500
}
```

#### run_in_background

Type: `boolean`
Required: No

Run the command without blocking Claude Code:

```json
{
  "run_in_background": true
}
```

## Hook Types

### PostToolUse Hook

Triggered after any tool execution. Ideal for tracking operations and long-running tasks.

#### Configuration

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
    ]
  }
}
```

#### Hook Input

Claude Code passes hook data as JSON via stdin. The bundled
`hooks/PostToolUse.sh` script reads this input and extracts fields like
`tool_name` and status.

#### Advanced Examples

**Notify on Write Operations Only**

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
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

**Notify on Long Operations Only**

Add a duration check inside `hooks/PostToolUse.sh` before sending a notification.

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

### SessionStart Hook

Triggered when you start a Claude Code session. Perfect for welcome messages.

#### Configuration

```json
{
  "hooks": {
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
    ]
  }
}
```

#### Examples

Edit `templates/notifications/*.json` to customize the SessionStart message.

**Simple Welcome**

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/hooks/SessionStart.sh",
            "run_in_background": true
          }
        ]
      }
    ]
  }
}
```

**Welcome with Project Name**

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/hooks/SessionStart.sh",
            "run_in_background": true
          }
        ]
      }
    ]
  }
}
```

### SessionEnd Hook

Triggered when you end a Claude Code session. Useful for session summaries.

#### Configuration

```json
{
  "hooks": {
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

#### Hook Input

SessionEnd hook data is delivered via stdin. Update the templates or
`hooks/SessionEnd.sh` to change message content.

#### Examples

**Detailed Summary**

```json
{
  "hooks": {
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/hooks/SessionEnd.sh",
            "run_in_background": true
          }
        ]
      }
    ]
  }
}
```

### Notification Hook

Direct notifications from Claude Code.

#### Configuration

```json
{
  "hooks": {
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/your-notification-hook.sh",
            "timeout": 500,
            "run_in_background": true
          }
        ]
      }
    ]
  }
}
```

The Notification hook receives JSON via stdin. Create a small wrapper script
that parses the input and calls `scripts/notify.sh`.

## Best Practices

### Use Background Mode

If you want non-blocking hooks, set `run_in_background` to `true`:

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

### Set Appropriate Timeouts

Set shorter timeouts for frequent hooks (PostToolUse) and longer for session hooks:

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
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/hooks/SessionStart.sh",
            "timeout": 1000
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
            "timeout": 1000
          }
        ]
      }
    ]
  }
}
```

### Match Notification Types to Events

Use appropriate notification types for different events:

- **Success**: SessionStart, completed operations
- **Information**: General updates, summaries
- **Warning**: Long operations, warnings
- **Error**: Failed operations

### Use Duration Settings

Match notification duration to importance:

- **Short**: Frequent updates (PostToolUse)
- **Normal**: Session events (SessionStart, SessionEnd)
- **Long**: Important notifications

### Avoid Notification Spam

Don't enable PostToolUse for every operation if you have many. Consider:

1. Only notifying on specific tools
2. Only notifying on long operations
3. Using shorter durations

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
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

## Complete Hook Configuration Example

```json
{
  "hooks": {
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
    ],
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/your-notification-hook.sh",
            "timeout": 500,
            "run_in_background": true
          }
        ]
      }
    ]
  }
}
```

## Troubleshooting

### Hook Not Executing

**Problem**: Hook doesn't execute when expected.

**Solutions**:

1. Verify the path is correct:
```bash
# Check if the PowerShell script exists
test -f /home/yourusername/claude_notification_wsl2/windows/wsl-toast.ps1 && echo "Found" || echo "Not found"
```

2. Verify PowerShell is available:
```bash
powershell.exe -Command "Write-Host 'PowerShell works'"
```

3. Check Claude Code logs for errors

### Notification Not Appearing

**Problem**: Hook executes but notification doesn't appear.

**Solutions**:

1. Test the script manually:
```bash
powershell.exe -NoProfile -NonInteractive -File "$(wslpath -w /home/yourusername/claude_notification_wsl2/windows/wsl-toast.ps1)" -Title "Test" -Message "Manual test" -Type Information
```

2. Check PowerShell accessibility:
```bash
powershell.exe -Command "Write-Host 'PowerShell works'"
```

3. Check Windows notification settings:
- Windows Settings > System > Notifications
- Ensure notifications are enabled
- Check Focus Assist settings

### Hook Blocks Claude Code

**Problem**: Hook execution blocks Claude Code operations.

**Solution**: Set `run_in_background` to `true` for non-blocking execution:

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

**Problem**: Variables appear as literal text like `{tool_name}`.

**Solution**: Claude Code no longer interpolates `{...}` placeholders. Parse the
hook JSON from stdin inside your hook script.

### Timeout Errors

**Problem**: Hook times out before completion.

**Solution**: Increase timeout value:

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

Or use background mode for immediate return.

## Testing Hooks

### Test PostToolUse Hook

```bash
# Perform a simple Read operation
# This should trigger PostToolUse hook
echo "test" > test.txt
```

### Test SessionStart Hook

```bash
# Restart Claude Code
# SessionStart hook should execute automatically
```

### Test SessionEnd Hook

```bash
# Exit Claude Code gracefully
# SessionEnd hook should execute automatically
```

### Test Notification Hook

Trigger a notification from within Claude Code (if supported):

```
/notify "Test Title" "Test Message" "Information"
```

## Hook Performance Considerations

### Execution Time

Hooks should execute quickly to avoid impacting Claude Code responsiveness:

- Use background mode for non-blocking execution
- Keep timeout values low (500-1000ms)
- Avoid heavy processing in hooks

### Frequency

PostToolUse hooks execute frequently. Consider:

- Disabling for development if too frequent
- Only enabling for specific tools
- Using Short duration to avoid clutter

### Resource Usage

Monitor resource usage if hooks are very frequent:

```bash
# Check process count
ps aux | rg "wsl-toast.ps1" | wc -l
```

Background processes are automatically cleaned up, but monitoring is recommended for heavy usage.

## Disabling Hooks

To disable individual hooks, remove the entry or set it to an empty array:

```json
{
  "hooks": {
    "PostToolUse": []
  }
}
```

If you used `scripts/notify.sh`, you can also disable notifications globally:

```bash
export WSL_TOAST_ENABLED=false
```

Direct PowerShell hook commands ignore `WSL_TOAST_ENABLED`.
