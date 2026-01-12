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
    "HookName": {
      "command": "/path/to/notify.sh",
      "args": ["--arg1", "value1"],
      "enabled": true,
      "timeout": 500
    }
  }
}
```

### Configuration Parameters

#### command

Type: `string`
Required: Yes

**Path Options:**

**Option 1: Relative paths (recommended)** - Use relative paths when running Claude Code from the project root:

```json
{
  "command": "./scripts/notify.sh"
}
```

**Option 2: Absolute paths** - Use absolute paths when running Claude Code from any directory. Replace `$PROJECT_ROOT` with your actual project path (e.g., `/home/yourusername/claude_notification_wsl2`):

```json
{
  "command": "$PROJECT_ROOT/scripts/notify.sh"
}
```

To find your project path:

```bash
pwd
# Output: /home/yourusername/claude_notification_wsl2
```

#### args

Type: `array of strings`
Required: No

Command-line arguments to pass to the notification script. Supports variable substitution:

```json
{
  "args": ["--title", "Tool: {tool_name}", "--message", "{status} - {duration_ms}ms"]
}
```

#### enabled

Type: `boolean`
Required: No
Default: `true`

Enable or disable the hook:

```json
{
  "enabled": true
}
```

#### timeout

Type: `number`
Required: No
Default: `5000`

Maximum time (in milliseconds) to wait for hook execution:

```json
{
  "timeout": 500
}
```

## Hook Types

### PostToolUse Hook

Triggered after any tool execution. Ideal for tracking operations and long-running tasks.

#### Configuration

```json
{
  "hooks": {
    "PostToolUse": {
      "command": "$PROJECT_ROOT/scripts/notify.sh",
      "args": [
        "--background",
        "--title", "Claude Code: {tool_name}",
        "--message", "Status: {status}, Duration: {duration_ms}ms",
        "--type", "Information"
      ],
      "enabled": true,
      "timeout": 500
    }
  }
}
```

#### Available Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `{tool_name}` | Name of the tool | `Read`, `Write`, `Edit`, `Bash` |
| `{status}` | Execution status | `success`, `error` |
| `{duration_ms}` | Duration in milliseconds | `1234` |
| `{op_count}` | Total operations in session | `42` |
| `{tool_count}` | Total tools used in session | `15` |

#### Advanced Examples

**Notify on Write Operations Only**

```json
{
  "hooks": {
    "PostToolUse": {
      "command": "$PROJECT_ROOT/scripts/notify.sh",
      "args": [
        "--background",
        "--title", "File Modified",
        "--message", "{tool_name} completed in {duration_ms}ms",
        "--type", "Success"
      ],
      "enabled": true
    }
  }
}
```

**Notify on Long Operations Only**

```json
{
  "hooks": {
    "PostToolUse": {
      "command": "$PROJECT_ROOT/scripts/notify.sh",
      "args": [
        "--background",
        "--title", "Long Operation",
        "--message", "{tool_name} took {duration_ms}ms",
        "--type", "Warning"
      ],
      "enabled": true
    }
  }
}
```

### SessionStart Hook

Triggered when you start a Claude Code session. Perfect for welcome messages.

#### Configuration

```json
{
  "hooks": {
    "SessionStart": {
      "command": "$PROJECT_ROOT/scripts/notify.sh",
      "args": [
        "--title", "Claude Code Session Started",
        "--message", "Welcome back! Ready to assist.",
        "--type", "Success",
        "--duration", "Short"
      ],
      "enabled": true,
      "timeout": 1000
    }
  }
}
```

#### Examples

**Simple Welcome**

```json
{
  "hooks": {
    "SessionStart": {
      "command": "$PROJECT_ROOT/scripts/notify.sh",
      "args": [
        "--title", "Claude Code",
        "--message", "Session started",
        "--type", "Success"
      ],
      "enabled": true
    }
  }
}
```

**Welcome with Project Name**

```json
{
  "hooks": {
    "SessionStart": {
      "command": "$PROJECT_ROOT/scripts/notify.sh",
      "args": [
        "--title", "Claude Code",
        "--message", "Working on: claude_notification_wsl2",
        "--type", "Information"
      ],
      "enabled": true
    }
  }
}
```

### SessionEnd Hook

Triggered when you end a Claude Code session. Useful for session summaries.

#### Configuration

```json
{
  "hooks": {
    "SessionEnd": {
      "command": "$PROJECT_ROOT/scripts/notify.sh",
      "args": [
        "--title", "Session Summary",
        "--message", "Tools: {tool_count}, Operations: {op_count}",
        "--type", "Information",
        "--duration", "Normal"
      ],
      "enabled": true,
      "timeout": 1000
    }
  }
}
```

#### Available Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `{tool_count}` | Number of tools used | `15` |
| `{op_count}` | Number of operations | `42` |
| `{duration}` | Session duration | `1h 30m` |

#### Examples

**Detailed Summary**

```json
{
  "hooks": {
    "SessionEnd": {
      "command": "$PROJECT_ROOT/scripts/notify.sh",
      "args": [
        "--title", "Session Complete",
        "--message", "You used {tool_count} tools and completed {op_count} operations. Great work!",
        "--type", "Success"
      ],
      "enabled": true
    }
  }
}
```

### Notification Hook

Direct notifications from Claude Code.

#### Configuration

```json
{
  "hooks": {
    "Notification": {
      "command": "$PROJECT_ROOT/scripts/notify.sh",
      "args": [
        "--title", "{title}",
        "--message", "{message}",
        "--type", "{type}"
      ],
      "enabled": true,
      "timeout": 500
    }
  }
}
```

#### Available Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `{title}` | Notification title | `Custom Title` |
| `{message}` | Notification message | `Custom message` |
| `{type}` | Notification type | `Information` |

## Best Practices

### Use Background Mode

Always use `--background` flag for PostToolUse and Notification hooks to prevent blocking:

```json
{
  "args": ["--background", "--title", "Non-blocking", "--message", "Runs in background"]
}
```

### Set Appropriate Timeouts

Set shorter timeouts for frequent hooks (PostToolUse) and longer for session hooks:

```json
{
  "PostToolUse": {
    "timeout": 500
  },
  "SessionStart": {
    "timeout": 1000
  },
  "SessionEnd": {
    "timeout": 1000
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
    "PostToolUse": {
      "command": "$PROJECT_ROOT/scripts/notify.sh",
      "args": [
        "--background",
        "--title", "Long Operation",
        "--message", "{tool_name}: {duration_ms}ms",
        "--type", "Warning",
        "--duration", "Short"
      ],
      "enabled": true
    }
  }
}
```

## Complete Hook Configuration Example

```json
{
  "hooks": {
    "SessionStart": {
      "command": "$PROJECT_ROOT/scripts/notify.sh",
      "args": [
        "--title", "Claude Code Session Started",
        "--message", "Welcome back! Ready to assist.",
        "--type", "Success",
        "--duration", "Short"
      ],
      "enabled": true,
      "timeout": 1000
    },
    "PostToolUse": {
      "command": "$PROJECT_ROOT/scripts/notify.sh",
      "args": [
        "--background",
        "--title", "Claude: {tool_name}",
        "--message", "{status} - {duration_ms}ms",
        "--type", "Information",
        "--duration", "Short"
      ],
      "enabled": true,
      "timeout": 500
    },
    "SessionEnd": {
      "command": "$PROJECT_ROOT/scripts/notify.sh",
      "args": [
        "--title", "Session Summary",
        "--message", "Tools used: {tool_count}, Operations: {op_count}",
        "--type", "Information",
        "--duration", "Normal"
      ],
      "enabled": true,
      "timeout": 1000
    },
    "Notification": {
      "command": "$PROJECT_ROOT/scripts/notify.sh",
      "args": [
        "--background",
        "--title", "{title}",
        "--message", "{message}",
        "--type", "{type}"
      ],
      "enabled": true,
      "timeout": 500
    }
  }
}
```

## Troubleshooting

### Hook Not Executing

**Problem**: Hook doesn't execute when expected.

**Solutions**:

1. Verify the path is correct:
```bash
# Check if the script exists
test -f $PROJECT_ROOT/scripts/notify.sh && echo "Found" || echo "Not found"
```

2. Verify the script is executable:
```bash
chmod +x scripts/notify.sh
```

3. Check Claude Code logs for errors

### Notification Not Appearing

**Problem**: Hook executes but notification doesn't appear.

**Solutions**:

1. Test the script manually:
```bash
./scripts/notify.sh --title "Test" --message "Manual test"
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

**Solution**: Always use `--background` flag:

```json
{
  "args": ["--background", "--title", "Non-blocking", "--message", "Runs in background"]
}
```

### Variables Not Substituted

**Problem**: Variables appear as literal text like `{tool_name}`.

**Solution**: Verify variable names match Claude Code documentation. Some variables may not be available for all hook types.

### Timeout Errors

**Problem**: Hook times out before completion.

**Solution**: Increase timeout value:

```json
{
  "timeout": 2000
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
ps aux | grep notify.sh | wc -l
```

Background processes are automatically cleaned up, but monitoring is recommended for heavy usage.

## Disabling Hooks

To disable individual hooks, set `enabled` to `false`:

```json
{
  "hooks": {
    "PostToolUse": {
      "enabled": false
    }
  }
}
```

To disable all hooks temporarily:

```bash
export WSL_TOAST_ENABLED=false
```

This is useful for debugging or when you need quiet operation.
