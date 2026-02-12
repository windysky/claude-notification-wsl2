# Claude Code Hooks Integration Guide

Complete guide for integrating Windows notifications with Claude Code hooks.

## Table of Contents

- [Overview](#overview)
- [Hook Configuration](#hook-configuration)
- [Hook Types](#hook-types)
- [Detailed Notifications](#detailed-notifications)
- [Avoiding Duplicate Notifications](#avoiding-duplicate-notifications)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Overview

Claude Code hooks enable automatic notifications at specific events during your development workflow. The Windows Notification Framework provides seamless integration with Claude Code's hook system.

### What are Hooks?

Hooks are scripts that Claude Code executes at specific points:

- **Stop**: When Claude finishes responding and waits for input
- **Notification**: When Claude Code sends a notification (e.g., idle prompt)
- **PermissionRequest**: When Claude requests permission to use a tool

### Benefits of Hook Integration

- Stay informed without switching windows
- Get notified when Claude is waiting for your input
- See detailed messages showing what Claude actually did (like Codex CLI)
- Receive permission request alerts

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

### Stop Hook

Triggered when Claude finishes responding and waits for your input. This is the primary notification hook that shows you when Claude is ready.

#### Configuration

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/hooks/Stop.sh",
            "timeout": 500
          }
        ]
      }
    ]
  }
}
```

#### Hook Input

Claude Code passes hook data as JSON via stdin:

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/current/working/directory",
  "hook_event_name": "Stop"
}
```

The bundled `hooks/Stop.sh` script reads the transcript file and extracts the last assistant message to display in the notification.

### Notification Hook

Triggered when Claude Code sends a notification (e.g., idle prompt, waiting for input).

#### Configuration

```json
{
  "hooks": {
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/hooks/Notification.sh",
            "timeout": 500
          }
        ]
      }
    ]
  }
}
```

#### Hook Input

```json
{
  "session_id": "abc123",
  "hook_event_name": "Notification",
  "message": "Claude is waiting for your input",
  "notification_type": "idle_prompt"
}
```

### PermissionRequest Hook

Triggered when Claude requests permission to use a tool.

#### Configuration

```json
{
  "hooks": {
    "PermissionRequest": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/hooks/PermissionRequest.sh",
            "timeout": 500
          }
        ]
      }
    ]
  }
}
```

The `matcher` field is required for PermissionRequest hooks. Use `.*` to match all permission requests.

## Detailed Notifications

### Like Codex CLI

The Stop hook provides detailed notifications similar to Codex CLI's `last-assistant-message` feature:

1. Reads the `transcript_path` from the hook payload
2. Parses the transcript JSONL file
3. Extracts the last assistant text message
4. Displays it in the Windows toast notification

This shows you what Claude actually did instead of a generic "Claude is ready" message.

### How It Works

```bash
# The Stop hook receives this payload:
{
  "transcript_path": "/path/to/transcript.jsonl"
}

# It then:
# 1. Reads the transcript file
# 2. Finds the last message with role="assistant"
# 3. Extracts text content from the content array
# 4. Truncates to first sentence (max 150 chars)
# 5. Shows in Windows toast notification
```

## Avoiding Duplicate Notifications

### Problem

If you see duplicate notifications, you may have hooks configured in multiple places:

1. **Project-level**: `.claude/settings.json` in your project
2. **User-level**: `~/.claude/settings.json` in your home directory

### Solution

Configure hooks in **only one location**. For project-specific notifications, use project-level settings only.

To check for duplicate configurations:

```bash
# Check project-level hooks
cat .claude/settings.json | grep -A 20 "hooks"

# Check user-level hooks
cat ~/.claude/settings.json | grep -A 20 "hooks"
```

If both have hooks configured, remove them from `~/.claude/settings.json`:

```json
{
  "alwaysThinkingEnabled": true,
  "enabledPlugins": {...}
  // Remove the "hooks" section
}
```

## Best Practices

### Keep Timeout Values Low

Set reasonable timeouts (500ms is usually sufficient):

```json
{
  "timeout": 500
}
```

### Match Notification Types to Events

- **Success**: Stop hook (Claude finished successfully)
- **Information**: Notification hook (idle prompts)
- **Warning**: PermissionRequest hook (needs user action)

### Check Logs for Debugging

Hooks log to `logs/hooks.log` in the project directory:

```bash
tail -f logs/hooks.log
```

## Troubleshooting

### Hook Not Executing

**Problem**: Hook doesn't execute when expected.

**Solutions**:

1. Verify the script path is correct:
```bash
test -f hooks/Stop.sh && echo "Found" || echo "Not found"
```

2. Verify PowerShell is available:
```bash
powershell.exe -Command "Write-Host 'PowerShell works'"
```

3. Check the logs:
```bash
cat logs/hooks.log
```

### Duplicate Notifications

**Problem**: Receiving duplicate notifications.

**Solution**: Check for hooks configured in multiple locations:

```bash
# Check project-level
cat .claude/settings.json | grep -A 10 "hooks"

# Check user-level
cat ~/.claude/settings.json | grep -A 10 "hooks"
```

Remove hooks from `~/.claude/settings.json` if both have them.

### Notification Not Appearing

**Problem**: Hook executes but notification doesn't appear.

**Solutions**:

1. Test the notify script manually:
```bash
./scripts/notify.sh --title "Test" --message "Manual test" --type Success
```

2. Check Windows notification settings:
- Windows Settings > System > Notifications
- Ensure notifications are enabled
- Check Focus Assist settings

### Timeout Errors

**Problem**: Hook times out before completion.

**Solution**: Increase timeout value:

```json
{
  "timeout": 1000
}
```

## Testing Hooks

### Test Stop Hook

```bash
# Simulate a Stop hook call
echo '{"session_id":"test","transcript_path":"/path/to/transcript.jsonl","hook_event_name":"Stop"}' | bash hooks/Stop.sh
```

### Test Notification Hook

```bash
# Simulate a Notification hook call
echo '{"message":"Test notification","notification_type":"test"}' | bash hooks/Notification.sh
```

## Disabling Hooks

To disable individual hooks, remove the entry from `.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": []
  }
}
```

Or disable notifications globally:

```bash
export WSL_TOAST_ENABLED=false
```
