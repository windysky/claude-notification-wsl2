# API Documentation

Complete API reference for the Windows Notification Framework Python modules and command-line interface.

## Table of Contents

- [Command-Line API](#command-line-api)
- [Python API](#python-api)
  - [config_loader Module](#config_loader-module)
  - [template_loader Module](#template_loader-module)
- [PowerShell API](#powershell-api)
- [Hook Integration API](#hook-integration-api)

## Command-Line API

### notify.sh

Main bridge script for sending notifications from WSL2 to Windows.

#### Usage

```bash
./scripts/notify.sh [OPTIONS]
```

#### Options

| Short | Long | Argument | Description |
|-------|------|----------|-------------|
| `-t` | `--title` | `<title>` | Notification title (required) |
| `-m` | `--message` | `<message>` | Notification message (required) |
| `-T` | `--type` | `<type>` | Notification type: Information, Warning, Error, Success |
| `-d` | `--duration` | `<duration>` | Display duration: Short, Normal, Long |
| `-l` | `--logo` | `<path>` | Path to custom icon/image |
| `-b` | `--background` | - | Run in background (non-blocking) |
| | `--mock` | - | Mock mode: don't display actual notification |
| `-h` | `--help` | - | Show help message |
| `-v` | `--verbose` | - | Enable verbose output |

#### Exit Codes

| Code | Description |
|------|-------------|
| `0` | Success |
| `1` | General error |
| `2` | Missing required parameters |
| `3` | PowerShell not found |
| `4` | PowerShell script not found |

#### Examples

```bash
# Basic notification
./scripts/notify.sh --title "Hello" --message "World"

# With type
./scripts/notify.sh --title "Build Complete" --message "Project built successfully" --type Success

# Background mode for hooks
./scripts/notify.sh --background --title "Tool Completed" --message "Read operation finished"

# Custom duration
./scripts/notify.sh --title "Important" --message "Please review" --duration Long

# Mock mode for testing
./scripts/notify.sh --mock --title "Test" --message "Testing notification system"

# With custom icon
./scripts/notify.sh --logo /path/to/icon.png --title "Custom Icon" --message "With custom icon"
```

## Python API

### config_loader Module

Configuration management with defaults, validation, and caching.

#### Functions

##### get_default_config()

Get default configuration values.

**Returns:** `Dict[str, Any]` - Dictionary with default configuration

**Example:**

```python
from src.config_loader import get_default_config

defaults = get_default_config()
# Returns: {
#     "enabled": True,
#     "default_type": "Information",
#     "default_duration": "Normal",
#     "language": "en",
#     "sound_enabled": True,
#     "position": "top_right"
# }
```

##### load_config(config_dir=None)

Load configuration from file, falling back to defaults.

**Parameters:**

- `config_dir` (Optional[str]): Configuration directory path (default: `~/.wsl-toast`)

**Returns:** `Dict[str, Any]` - Dictionary with configuration values

**Example:**

```python
from src.config_loader import load_config

# Load from default location
config = load_config()

# Load from custom location
config = load_config("/path/to/config/dir")
```

##### save_config(config, config_dir=None)

Save configuration to file.

**Parameters:**

- `config` (Dict[str, Any]): Configuration dictionary to save
- `config_dir` (Optional[str]): Configuration directory path

**Example:**

```python
from src.config_loader import save_config

config = {
    "enabled": True,
    "language": "ko",
    "default_type": "Success"
}
save_config(config)
```

##### get_config_value(key, config_dir=None, default=None)

Get a specific configuration value.

**Parameters:**

- `key` (str): Configuration key
- `config_dir` (Optional[str]): Configuration directory path
- `default` (Any): Default value if key doesn't exist

**Returns:** `Any` - Configuration value or default

**Example:**

```python
from src.config_loader import get_config_value

language = get_config_value("language", default="en")
# Returns: "en" or configured language
```

##### set_config_value(key, value, config_dir=None)

Set a configuration value.

**Parameters:**

- `key` (str): Configuration key
- `value` (Any): Value to set
- `config_dir` (Optional[str]): Configuration directory path

**Example:**

```python
from src.config_loader import set_config_value

set_config_value("default_type", "Success")
```

##### validate_config(config)

Validate configuration values.

**Parameters:**

- `config` (Dict[str, Any]): Configuration dictionary to validate

**Returns:** `Tuple[bool, List[str]]` - (is_valid, list_of_errors)

**Example:**

```python
from src.config_loader import validate_config

config = {
    "enabled": True,
    "default_type": "InvalidType"
}

is_valid, errors = validate_config(config)
# Returns: (False, ["default_type must be one of [...]"])
```

##### get_config_path(config_dir=None)

Get the configuration file path.

**Parameters:**

- `config_dir` (Optional[str]): Configuration directory path

**Returns:** `Path` - Path to configuration file

**Example:**

```python
from src.config_loader import get_config_path

path = get_config_path()
# Returns: PosixPath('/home/user/.wsl-toast/config.json')
```

##### config_exists(config_dir=None)

Check if configuration file exists.

**Parameters:**

- `config_dir` (Optional[str]): Configuration directory path

**Returns:** `bool` - True if configuration file exists

**Example:**

```python
from src.config_loader import config_exists

exists = config_exists()
# Returns: True or False
```

##### reset_config(config_dir=None)

Reset configuration to defaults.

**Parameters:**

- `config_dir` (Optional[str]): Configuration directory path

**Example:**

```python
from src.config_loader import reset_config

reset_config()
```

##### merge_config(base_config, override_config)

Merge two configuration dictionaries.

**Parameters:**

- `base_config` (Dict[str, Any]): Base configuration
- `override_config` (Dict[str, Any]): Override configuration (takes precedence)

**Returns:** `Dict[str, Any]` - Merged configuration dictionary

**Example:**

```python
from src.config_loader import merge_config

base = {"enabled": True, "language": "en"}
override = {"language": "ko"}
merged = merge_config(base, override)
# Returns: {"enabled": True, "language": "ko"}
```

### template_loader Module

Multi-language notification template loader with fallback support.

#### TemplateLoader Class

##### __init__(templates_dir=None)

Initialize the template loader.

**Parameters:**

- `templates_dir` (Optional[Path]): Custom templates directory path

**Example:**

```python
from src.template_loader import TemplateLoader

loader = TemplateLoader()
```

##### get_available_languages()

Get list of available template languages.

**Returns:** `list[str]` - List of language codes with available templates

**Example:**

```python
languages = loader.get_available_languages()
# Returns: ["en", "ko", "ja", "zh"]
```

##### get_template(key, language="en")

Get a specific template with language fallback.

**Parameters:**

- `key` (str): Template key (e.g., 'tool_completed', 'error_occurred')
- `language` (str): Preferred language code (default: 'en')

**Returns:** `Dict[str, str]` - Dictionary with 'title' and 'message' keys

**Raises:**

- `KeyError`: If template key doesn't exist in any language
- `ValueError`: If language is not supported

**Example:**

```python
template = loader.get_template("tool_completed", language="ko")
# Returns: {"title": "도구 완료", "message": "도구가 성공적으로 실행을 완료했습니다"}
```

##### get_title(key, language="en")

Get template title.

**Parameters:**

- `key` (str): Template key
- `language` (str): Language code

**Returns:** `str` - Template title string

**Example:**

```python
title = loader.get_title("error_occurred", language="en")
# Returns: "Error Occurred"
```

##### get_message(key, language="en")

Get template message.

**Parameters:**

- `key` (str): Template key
- `language` (str): Language code

**Returns:** `str` - Template message string

**Example:**

```python
message = loader.get_message("tool_completed", language="en")
# Returns: "The tool has finished execution successfully"
```

##### get_notification_data(key, language="en", **kwargs)

Get notification data with optional message formatting.

**Parameters:**

- `key` (str): Template key
- `language` (str): Language code
- **kwargs**: Optional parameters for message formatting

**Returns:** `Dict[str, str]` - Dictionary with 'title' and 'message' keys

**Example:**

```python
data = loader.get_notification_data("build_complete", language="en", project_name="MyProject")
# Returns: {"title": "Build Complete", "message": "Your project has been built successfully"}
```

##### clear_cache()

Clear the template cache.

**Example:**

```python
loader.clear_cache()
```

#### Module Functions

##### get_template_loader(templates_dir=None)

Get or create the global template loader instance.

**Parameters:**

- `templates_dir` (Optional[Path]): Custom templates directory

**Returns:** `TemplateLoader` - TemplateLoader instance

**Example:**

```python
from src.template_loader import get_template_loader

loader = get_template_loader()
```

##### get_template(key, language="en")

Convenience function to get a template.

**Parameters:**

- `key` (str): Template key
- `language` (str): Language code

**Returns:** `Dict[str, str]` - Dictionary with 'title' and 'message' keys

**Example:**

```python
from src.template_loader import get_template

template = get_template("session_start", language="ko")
# Returns: {"title": "Claude Code 세션 시작", "message": "환영합니다! 세션이 시작되었습니다"}
```

##### get_notification_data(key, language="en", **kwargs)

Convenience function to get notification data.

**Parameters:**

- `key` (str): Template key
- `language` (str): Language code
- **kwargs**: Optional parameters for message formatting

**Returns:** `Dict[str, str]` - Dictionary with 'title' and 'message' keys

**Example:**

```python
from src.template_loader import get_notification_data

data = get_notification_data("test_complete", language="en", test_count="42")
# Returns: {"title": "Tests Complete", "message": "All tests have been executed"}
```

## PowerShell API

### Send-WSLToast

Main PowerShell function to send toast notifications.

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `Title` | String | Yes | The notification title |
| `Message` | String | Yes | The notification message |
| `Type` | String | No | Notification type: Information, Warning, Error, Success |
| `Duration` | String | No | Display duration: Short, Normal, Long |
| `AppLogo` | String | No | Path to custom icon/image |
| `MockMode` | Switch | No | Testing mode that doesn't display actual notifications |

#### Returns

`PSObject` with operation result:

```powershell
@{
    Success = $true
    Title = "Notification Title"
    Message = "Notification message"
    Type = "Information"
    Duration = "Normal"
    Timestamp = Get-Date
    DisplayMethod = "BurntToast"
    DisplayMessage = "Notification displayed using BurntToast"
}
```

#### Example Usage

```powershell
# Basic notification
$result = Send-WSLToast -Title "Test" -Message "Test message"

# With type
$result = Send-WSLToast -Title "Success" -Message "Operation completed" -Type Success

# With duration
$result = Send-WSLToast -Title "Important" -Message "Please review" -Duration Long

# Mock mode for testing
$result = Send-WSLToast -Title "Test" -Message "Testing" -MockMode

# Check result
if ($result.Success) {
    Write-Host "Notification sent successfully"
} else {
    Write-Host "Error: $($result.Error)"
}
```

### Helper Functions

#### Test-BurntToastAvailability

Tests if the BurntToast module is available.

**Returns:** `System.Boolean`

```powershell
if (Test-BurntToastAvailability) {
    Write-Host "BurntToast is available"
}
```

#### Test-UTF8Encoding

Tests UTF-8 encoding for international characters.

**Parameters:**

- `Title` (String): The title to test
- `Message` (String): The message to test

**Returns:** `System.Boolean`

```powershell
if (Test-UTF8Encoding -Title "테스트" -Message "한글") {
    Write-Host "UTF-8 encoding is valid"
}
```

## Hook Integration API

### Claude Code Hook Format

Hooks are configured in `.claude/settings.json` with the following format:

```json
{
  "hooks": {
    "HookName": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/hook-script.sh",
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

Hook scripts receive JSON via stdin with session and event data. Parse the
JSON to extract fields like `tool_name`, `hook_event_name`, and `tool_input`.

### Example Hook Configurations

#### PostToolUse Hook

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

#### SessionStart Hook

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

#### SessionEnd Hook

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

## Complete Usage Example

```python
#!/usr/bin/env python3
"""
Complete example using the notification framework API
"""

from src.config_loader import load_config, set_config_value, validate_config
from src.template_loader import get_template_loader
import subprocess
import sys

def send_notification(title, message, notification_type="Information", background=True):
    """
    Send a notification using the bridge script

    Args:
        title: Notification title
        message: Notification message
        notification_type: Type (Information, Warning, Error, Success)
        background: Run in background mode
    """
    cmd = [
        "./scripts/notify.sh",
        "--title", title,
        "--message", message,
        "--type", notification_type
    ]

    if background:
        cmd.append("--background")

    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.returncode == 0

def main():
    # Load current configuration
    config = load_config()

    # Validate configuration
    is_valid, errors = validate_config(config)
    if not is_valid:
        print("Configuration errors:")
        for error in errors:
            print(f"  - {error}")
        return 1

    # Get template loader
    loader = get_template_loader()

    # Get available languages
    languages = loader.get_available_languages()
    print(f"Available languages: {', '.join(languages)}")

    # Get a template
    try:
        template = loader.get_template("build_complete", language=config["language"])
        print(f"Template: {template}")

        # Send notification using template
        success = send_notification(
            title=template["title"],
            message=template["message"],
            notification_type="Success"
        )

        if success:
            print("Notification sent successfully")
            return 0
        else:
            print("Failed to send notification")
            return 1

    except KeyError as e:
        print(f"Template not found: {e}")
        return 1
    except ValueError as e:
        print(f"Invalid language: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main())
```
