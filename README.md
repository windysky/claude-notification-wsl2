# Windows Notification Framework for Claude Code CLI on WSL2

A complete notification framework that enables Windows toast notifications from WSL2 for Claude Code CLI. Supports multi-language (EN, KO, JA, ZH) with non-blocking execution and comprehensive configuration options.

[![Tests](https://img.shields.io/badge/tests-63%2F63%20passed-success)](#)
[![Coverage](https://img.shields.io/badge/coverage-92%25-brightgreen)](#)
[![TRUST](https://img.shields.io/badge/TRUST%205-5%2F5%20PASS-blue)](#)
[![Security](https://img.shields.io/badge/security-0%20vulnerabilities-success)](#)

## Features

- Non-blocking toast notifications to Windows Action Center from WSL2
- **Silent-by-default** toasts (no Windows notification ding); `--sound` to re-enable
- **Flicker-free busy indicator** — sets a static shell-style title (`user@host: ~/path`) and pulses the Windows Terminal taskbar icon (OSC 9;4;3) while Claude is processing your prompt. State is keyed per-tty so concurrent CC sessions stay independent.
- **Dedup hook logic** - suppresses Claude Code's `idle_prompt` notification so you only get one toast per turn
- Multi-language support with UTF-8 encoding (English, Korean, Japanese, Chinese)
- Configurable notification types (Information, Warning, Error, Success)
- Claude Code hooks integration (UserPromptSubmit, Stop, Notification, PermissionRequest)
- **Detailed notifications** - Extracts last assistant message from transcript (like Codex CLI)
- Graceful fallback to Windows Forms Balloon Tip
- Background execution mode for hooks
- Template-based notification system
- Comprehensive configuration management
- Full test coverage (92%)

## Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/claude_notification_wsl2.git
cd claude_notification_wsl2

# Run the installation script
./setup.sh

# Optional: configure Claude Code hooks when prompted
```

### Basic Usage

```bash
# Send a simple notification
./scripts/notify.sh --title "Hello" --message "World"

# Send a notification with type
./scripts/notify.sh --title "Build Complete" --message "Project built successfully" --type Success

# Send in background (for hooks)
./scripts/notify.sh --background --title "Tool Completed" --message "Read operation finished"
```

## Architecture

The notification framework consists of three main components:

### 1. PowerShell Toast Script (`windows/wsl-toast.ps1`)

Windows-side script that displays toast notifications using BurntToast module with graceful fallback to Windows Forms.

### 2. WSL2 Bridge Script (`scripts/notify.sh`)

Bash script that bridges WSL2 to Windows PowerShell. Handles command-line parsing, configuration loading, and executes PowerShell in background mode.

### 3. Python Modules (`src/`)

Configuration and template management with caching and validation support.

## Configuration

### Default Configuration

Notifications use sensible defaults by default. Configuration is stored in `~/.wsl-toast/config.json`:

```json
{
  "enabled": true,
  "default_type": "Information",
  "default_duration": "Normal",
  "language": "en",
  "silent": true,
  "sound_enabled": false,
  "position": "top_right"
}
```

`silent: true` (the v1.3+ default) suppresses the Windows notification ding. Set `silent: false` if you want the ding back. `sound_enabled` is honored for backward compatibility.

### Claude Code Hooks Integration

Add to your `.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/wsl-toast/UserPromptSubmit.sh",
            "timeout": 1000
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/wsl-toast/Stop.sh",
            "timeout": 1000
          }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/wsl-toast/Notification.sh",
            "timeout": 1000
          }
        ]
      }
    ],
    "PermissionRequest": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/wsl-toast/PermissionRequest.sh",
            "timeout": 1000
          }
        ]
      }
    ]
  }
}
```

### Detailed Notifications (Like Codex CLI)

The Stop hook extracts the last assistant message from the transcript file to provide detailed notifications, similar to Codex CLI's `last-assistant-message` feature. This shows you what Claude actually did in the notification instead of a generic message.

### Notification Types

- `Information` - Default blue notification
- `Warning` - Yellow warning banner
- `Error` - Red error banner
- `Success` - Green success banner

### Duration Options

- `Short` - 5 seconds
- `Normal` - 10 seconds (default)
- `Long` - 20 seconds

## Multi-Language Support

The framework supports four languages with automatic template fallback:

- English (en)
- Korean (ko)
- Japanese (ja)
- Chinese (zh)

Templates are located in `templates/notifications/{language}.json`. Set your preferred language in `~/.wsl-toast/config.json`:

```json
{
  "language": "ko"
}
```

## Command Reference

```bash
notify.sh [OPTIONS]

OPTIONS:
    -t, --title <title>          Notification title (required)
    -m, --message <message>      Notification message (required)
    -T, --type <type>            Information, Warning, Error, Success (default: Information)
    -d, --duration <duration>    Short, Normal, Long (default: Normal)
    -l, --logo <path>            Path to custom icon/image
    -b, --background             Run in background (non-blocking)
    -s, --silent                 Suppress the Windows notification ding (default)
    --sound                      Play the Windows notification ding
    --mock                       Mock mode: don't display notification
    -h, --help                   Show help message
    -v, --verbose                Enable verbose output
```

## Testing

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=src --cov-report=html

# Run PowerShell tests
powershell.exe -ExecutionPolicy Bypass -File tests/powershell/wsl-toast.Tests.ps1

# Run Bash tests
bats tests/bash/notify.bats
```

## Requirements

### Windows Host

- Windows 10/11
- PowerShell 5.1+ (built-in)
- BurntToast module (auto-installed or manual via `Install-Module -Name BurntToast`)

### WSL2 Guest

- Bash 4.0+
- Python 3.10+ (for configuration modules)

## Troubleshooting

### PowerShell Not Found

If you see "PowerShell not found" error, ensure WSL2 has access to Windows PowerShell:

```bash
# Check PowerShell availability
which powershell.exe

# Expected output: /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
```

### BurntToast Module Not Installed

The framework will attempt auto-installation. For manual installation:

```powershell
# In Windows PowerShell
Install-Module -Name BurntToast -Force -Scope CurrentUser
```

### UTF-8 Character Issues

For international characters, ensure UTF-8 encoding is configured:

```bash
# In WSL2, set locale
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
```

### Notifications Not Appearing

Check Windows notification settings:

1. Open Windows Settings > System > Notifications
2. Ensure notifications are enabled
3. Check Focus Assist settings

## Documentation

- [Installation Guide](docs/INSTALLATION.md) - Detailed installation instructions
- [Configuration Guide](docs/CONFIGURATION.md) - Complete configuration reference
- [API Documentation](docs/API.md) - Python module API reference
- [Hooks Integration](docs/HOOKS.md) - Claude Code hooks setup guide
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions

## Development

### Project Structure

```
claude_notification_wsl2/
├── windows/              # PowerShell scripts
│   └── wsl-toast.ps1    # Main toast notification script
├── scripts/              # Bash scripts
│   └── notify.sh        # WSL2 bridge script
├── setup.sh             # Installation script
├── uninstall.sh         # Uninstallation script
├── src/                  # Python modules
│   ├── config_loader.py # Configuration management
│   └── template_loader.py # Template system
├── templates/            # Notification templates
│   └── notifications/   # Multi-language templates
│       ├── en.json
│       ├── ko.json
│       ├── ja.json
│       └── zh.json
├── tests/                # Test suites
│   ├── python/          # Python tests
│   ├── powershell/      # PowerShell tests
│   └── bash/            # Bash tests
└── docs/                 # Documentation
```

### Contributing

Contributions are welcome. Please read our contributing guidelines and submit pull requests.

### License

MIT License - see LICENSE file for details

## Version

Version 1.3.0 (2026-04-16)

### Changelog

- **1.3.0** (2026-04-16):
  - Silent-by-default toasts (BurntToast `-Silent`); `--sound` / `silent: false` to opt back in
  - Suppress Claude Code `idle_prompt` notifications to kill the duplicate toast ~10s after Stop
  - New `UserPromptSubmit` hook sets a static shell-style title (`user@host: ~/path`) and activates Windows Terminal indeterminate taskbar progress (OSC 9;4;3) so you can tell at a glance when Claude is working — fully flicker-free, no title animation loop
  - Per-tty state files (`~/.wsl-toast/spinner-<tty>.*`) so concurrent CC sessions don't clobber each other
  - Requires `"spinnerTipsEnabled": false` in `~/.claude/settings.json` to prevent CC's built-in title updates from overwriting ours
  - Shared helper `hooks/_spinner.sh` handles start/stop, parent-TTY discovery, and title composition
- **1.2.2** (2026-02-14): Hooks now installed to `~/.claude/hooks/wsl-toast/` for cleaner separation from project directory
- **1.2.1** (2026-02-14): Fixed global hook paths to use `$HOME` for portability across different usernames
- **1.2.0** (2026-02-11): Added detailed notifications (Codex CLI style), extracts last assistant message from transcript
- **1.1.0** (2026-01-12): Added multi-language support (EN, KO, JA, ZH), hook scripts for Stop/Notification/PermissionRequest
- **1.0.0** (2026-01-10): Initial release with PowerShell BurntToast integration

## Authors

Junguk Hur

## Acknowledgments

- [BurntToast](https://github.com/Windos/BurntToast) - PowerShell module for Windows notifications
- [Claude Code](https://claude.ai/code) - AI-powered CLI tool
