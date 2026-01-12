# Configuration Guide

Complete reference for configuring the Windows Notification Framework for Claude Code CLI on WSL2.

## Configuration File Location

The framework stores configuration in `~/.wsl-toast/config.json`. This file is created automatically on first run with default values.

**Configuration Directory**:

```bash
~/.wsl-toast/
├── config.json          # Main configuration file
└── wsl-toast.ps1        # PowerShell toast script
```

## Configuration Structure

### Full Configuration Example

```json
{
  "enabled": true,
  "default_type": "Information",
  "default_duration": "Normal",
  "language": "en",
  "sound_enabled": true,
  "position": "top_right"
}
```

### Configuration Parameters

#### enabled

Type: `boolean`
Default: `true`

Enable or disable all notifications. When set to `false`, no notifications will be displayed.

```json
{
  "enabled": false
}
```

You can also control this via environment variable:

```bash
export WSL_TOAST_ENABLED=false
```

#### default_type

Type: `string`
Default: `"Information"`
Valid Values: `"Information"`, `"Warning"`, `"Error"`, `"Success"`

Sets the default notification type when no type is specified.

```json
{
  "default_type": "Success"
}
```

#### default_duration

Type: `string`
Default: `"Normal"`
Valid Values: `"Short"`, `"Normal"`, `"Long"`

Sets how long notifications are displayed.

- `"Short"` - 5 seconds
- `"Normal"` - 10 seconds
- `"Long"` - 20 seconds

```json
{
  "default_duration": "Long"
}
```

#### language

Type: `string`
Default: `"en"`
Valid Values: `"en"`, `"ko"`, `"ja"`, `"zh"`

Sets the language for notification templates. The framework will fall back to English if a template is not available in the selected language.

```json
{
  "language": "ko"
}
```

#### sound_enabled

Type: `boolean`
Default: `true`

Enable or disable notification sounds.

```json
{
  "sound_enabled": false
}
```

#### position

Type: `string`
Default: `"top_right"`
Valid Values: `"top_right"`, `"top_left"`, `"bottom_right"`, `"bottom_left"`

Sets the screen position for notifications. Note that Windows Action Center may override this setting.

```json
{
  "position": "bottom_right"
}
```

## Environment Variables

Environment variables provide a way to override configuration without modifying the configuration file.

### WSL_TOAST_ENABLED

Enable or disable notifications globally.

```bash
export WSL_TOAST_ENABLED=false
```

### WSL_TOAST_TYPE

Override the default notification type.

```bash
export WSL_TOAST_TYPE=Warning
```

### WSL_TOAST_DURATION

Override the default notification duration.

```bash
export WSL_TOAST_DURATION=Long
```

### WSL_TOAST_CONFIG

Specify a custom configuration file path.

```bash
export WSL_TOAST_CONFIG=/path/to/custom/config.json
```

### WSL_TOAST_LOG

Enable debug logging.

```bash
export WSL_TOAST_LOG=true
# Or for verbose output
export DEBUG=true
```

## Notification Types

### Information

Default blue notification for general information.

```bash
./scripts/notify.sh --type Information --title "Info" --message "General information"
```

### Warning

Yellow warning banner for important notices.

```bash
./scripts/notify.sh --type Warning --title "Warning" --message "Disk space is low"
```

### Error

Red error banner for failures and errors.

```bash
./scripts/notify.sh --type Error --title "Error" --message "Build failed"
```

### Success

Green success banner for successful operations.

```bash
./scripts/notify.sh --type Success --title "Success" --message "Build completed"
```

## Duration Settings

### Short

Display for 5 seconds. Best for quick, non-critical notifications.

```bash
./scripts/notify.sh --duration Short --title "Quick Update" --message "File saved"
```

### Normal

Display for 10 seconds. Default duration for most notifications.

```bash
./scripts/notify.sh --duration Normal --title "Normal Update" --message "Processing complete"
```

### Long

Display for 20 seconds. Best for important notifications that need attention.

```bash
./scripts/notify.sh --duration Long --title "Important Update" --message "Please review changes"
```

## Multi-Language Configuration

### Setting Language

Configure your preferred language in `~/.wsl-toast/config.json`:

```json
{
  "language": "ko"
}
```

### Supported Languages

| Language | Code | Template File |
|----------|------|---------------|
| English | `en` | `templates/notifications/en.json` |
| Korean | `ko` | `templates/notifications/ko.json` |
| Japanese | `ja` | `templates/notifications/ja.json` |
| Chinese | `zh` | `templates/notifications/zh.json` |

### Language Fallback

If a template is not available in your selected language, the framework automatically falls back to English. This ensures notifications always work, even for missing translations.

### Custom Templates

To create custom templates:

1. Create a new JSON file in `templates/notifications/`
2. Follow the template structure:

```json
{
  "tool_completed": {
    "title": "Tool Completed",
    "message": "The tool has finished execution successfully"
  },
  "error_occurred": {
    "title": "Error Occurred",
    "message": "An unexpected error has occurred"
  }
}
```

3. Add your language code to `src/template_loader.py`:

```python
SUPPORTED_LANGUAGES = ["en", "ko", "ja", "zh", "fr"]
```

## Claude Code Hooks Configuration

### Hook Configuration Format

Claude Code hooks are configured in `.claude/settings.json`:

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

### Hook Input

Hooks receive JSON via stdin with session and event data. The bundled hook
scripts read this input and extract fields like `tool_name` and `status`.

### PostToolUse Hook

Notifies after each tool execution:

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

### SessionStart Hook

Notifies when Claude Code session starts:

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

### SessionEnd Hook

Notifies when Claude Code session ends:

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

### Notification Hook

Direct notifications from Claude Code:

```json
{
  "hooks": {
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/your-notification-hook.sh",
            "timeout": 1000,
            "run_in_background": true
          }
        ]
      }
    ]
  }
}
```

## Python API Configuration

### Using Configuration Loader

The Python modules provide programmatic access to configuration:

```python
from src.config_loader import load_config, save_config, get_config_value

# Load configuration
config = load_config()

# Get a specific value
language = get_config_value("language", default="en")

# Set a value
from src.config_loader import set_config_value
set_config_value("default_type", "Success")

# Save configuration
from src.config_loader import save_config
save_config(config)
```

### Using Template Loader

Load and use notification templates:

```python
from src.template_loader import get_template_loader

# Get template loader
loader = get_template_loader()

# Get available languages
languages = loader.get_available_languages()

# Get a specific template
template = loader.get_template("tool_completed", language="en")
# Returns: {"title": "Tool Completed", "message": "The tool has finished..."}

# Get notification data with formatting
data = loader.get_notification_data(
    "build_complete",
    language="en",
    project_name="MyProject"
)
# Returns: {"title": "Build Complete", "message": "Your project has been built..."}
```

## Advanced Configuration

### Custom Notification Sound

Windows notification sounds are controlled by Windows settings. To customize:

1. Open Windows Settings > System > Notifications
2. Configure sounds for different notification types

### Custom Notification Icon

Specify a custom icon for notifications:

```bash
./scripts/notify.sh --logo /path/to/icon.png --title "Custom Icon" --message "With custom icon"
```

Supported formats: PNG, ICO, JPG

### Background Execution Mode

For Claude Code hooks, use background mode to prevent blocking:

```bash
./scripts/notify.sh --background --title "Non-blocking" --message "Runs in background"
```

### Mock Mode for Testing

Test notifications without displaying them:

```bash
./scripts/notify.sh --mock --title "Test" --message "This won't be displayed"
```

## Configuration Validation

The framework validates configuration values. Invalid values will be replaced with defaults:

```python
from src.config_loader import validate_config

config = {
    "enabled": "not_a_boolean",  # Invalid
    "default_type": "InvalidType",  # Invalid
    "language": "ko"  # Valid
}

is_valid, errors = validate_config(config)
# is_valid: False
# errors: ["enabled must be a boolean", "default_type must be one of [...]"]
```

## Configuration Tips

### Performance Optimization

For better performance with frequent notifications:

```json
{
  "default_duration": "Short",
  "sound_enabled": false
}
```

### Development Environment

For development, use verbose logging:

```bash
export DEBUG=true
./scripts/notify.sh --verbose --title "Debug" --message "With debug info"
```

### Production Environment

For production, use background mode and appropriate defaults:

```json
{
  "enabled": true,
  "default_type": "Information",
  "default_duration": "Normal",
  "language": "en",
  "sound_enabled": true
}
```

## Troubleshooting Configuration

### Reset to Defaults

Reset configuration to default values:

```python
from src.config_loader import reset_config
reset_config()
```

Or manually:

```bash
rm ~/.wsl-toast/config.json
./scripts/notify.sh --title "Reset" --message "Configuration reset to defaults"
```

### View Current Configuration

```bash
cat ~/.wsl-toast/config.json
```

Or use Python:

```python
from src.config_loader import load_config
import json

config = load_config()
print(json.dumps(config, indent=2))
```

### Check Configuration Validity

```python
from src.config_loader import validate_config, load_config

config = load_config()
is_valid, errors = validate_config(config)

if not is_valid:
    print("Configuration errors:")
    for error in errors:
        print(f"  - {error}")
```
