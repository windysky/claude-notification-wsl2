# config_loader.py
# Configuration loader with defaults and validation
#
# Author: Claude Code TDD Implementation
# Version: 1.0.0

import json
from pathlib import Path
from typing import Dict, Any, Optional, Tuple, List


def get_default_config() -> Dict[str, Any]:
    """
    Get default configuration values

    Returns:
        Dictionary with default configuration
    """
    return {
        "enabled": True,
        "default_type": "Information",
        "default_duration": "Normal",
        "language": "en",
        "sound_enabled": True,
        "position": "top_right",
    }


# Configuration cache
_config_cache: Dict[str, Dict[str, Any]] = {}


def clear_config_cache() -> None:
    """Clear the configuration cache"""
    global _config_cache
    _config_cache.clear()


def load_config(config_dir: Optional[str] = None) -> Dict[str, Any]:
    """
    Load configuration from file, falling back to defaults

    Args:
        config_dir: Configuration directory path (default: ~/.wsl-toast)

    Returns:
        Dictionary with configuration values
    """
    # Determine config directory
    if config_dir is None:
        config_dir = str(Path.home() / ".wsl-toast")

    config_path = Path(config_dir) / "config.json"

    # Check cache first
    cache_key = str(config_path)
    if cache_key in _config_cache:
        return _config_cache[cache_key]

    # Start with defaults
    config = get_default_config()

    # Try to load from file
    if config_path.exists():
        try:
            with open(config_path, "r", encoding="utf-8") as f:
                file_config = json.load(f)
                # Merge with defaults (file takes precedence)
                config.update(file_config)
        except (json.JSONDecodeError, IOError):
            # If file is invalid, use defaults
            pass

    # Cache the result
    _config_cache[cache_key] = config

    return config


def save_config(config: Dict[str, Any], config_dir: Optional[str] = None) -> None:
    """
    Save configuration to file

    Args:
        config: Configuration dictionary to save
        config_dir: Configuration directory path
    """
    if config_dir is None:
        config_dir = str(Path.home() / ".wsl-toast")

    config_path = Path(config_dir)
    config_path.mkdir(parents=True, exist_ok=True)

    config_file = config_path / "config.json"

    with open(config_file, "w", encoding="utf-8") as f:
        json.dump(config, f, indent=2, ensure_ascii=False)

    # Clear cache to force reload
    cache_key = str(config_file)
    if cache_key in _config_cache:
        del _config_cache[cache_key]


def get_config_value(
    key: str, config_dir: Optional[str] = None, default: Any = None
) -> Any:
    """
    Get a specific configuration value

    Args:
        key: Configuration key
        config_dir: Configuration directory path
        default: Default value if key doesn't exist

    Returns:
        Configuration value or default
    """
    config = load_config(config_dir)

    if key not in config and default is not None:
        return default

    return config.get(key, default)


def set_config_value(key: str, value: Any, config_dir: Optional[str] = None) -> None:
    """
    Set a configuration value

    Args:
        key: Configuration key
        value: Value to set
        config_dir: Configuration directory path
    """
    config = load_config(config_dir)
    config[key] = value
    save_config(config, config_dir)


def validate_config(config: Dict[str, Any]) -> Tuple[bool, List[str]]:
    """
    Validate configuration values

    Args:
        config: Configuration dictionary to validate

    Returns:
        Tuple of (is_valid, list_of_errors)
    """
    errors = []

    # Valid notification types
    valid_types = ["Information", "Warning", "Error", "Success"]

    # Valid durations
    valid_durations = ["Short", "Normal", "Long"]

    # Valid languages
    valid_languages = ["en", "ko", "ja", "zh"]

    # Valid positions
    valid_positions = ["top_right", "top_left", "bottom_right", "bottom_left"]

    # Validate enabled
    if "enabled" in config:
        if not isinstance(config["enabled"], bool):
            errors.append("enabled must be a boolean")

    # Validate default_type
    if "default_type" in config:
        if config["default_type"] not in valid_types:
            errors.append(
                f"default_type must be one of {valid_types}, got '{config['default_type']}'"
            )

    # Validate default_duration
    if "default_duration" in config:
        if config["default_duration"] not in valid_durations:
            errors.append(
                f"default_duration must be one of {valid_durations}, got '{config['default_duration']}'"
            )

    # Validate language
    if "language" in config:
        if config["language"] not in valid_languages:
            errors.append(
                f"language must be one of {valid_languages}, got '{config['language']}'"
            )

    # Validate sound_enabled
    if "sound_enabled" in config:
        if not isinstance(config["sound_enabled"], bool):
            errors.append("sound_enabled must be a boolean")

    # Validate position
    if "position" in config:
        if config["position"] not in valid_positions:
            errors.append(
                f"position must be one of {valid_positions}, got '{config['position']}'"
            )

    return len(errors) == 0, errors


def get_config_path(config_dir: Optional[str] = None) -> Path:
    """
    Get the configuration file path

    Args:
        config_dir: Configuration directory path

    Returns:
        Path to configuration file
    """
    if config_dir is None:
        config_dir = str(Path.home() / ".wsl-toast")

    return Path(config_dir) / "config.json"


def config_exists(config_dir: Optional[str] = None) -> bool:
    """
    Check if configuration file exists

    Args:
        config_dir: Configuration directory path

    Returns:
        True if configuration file exists
    """
    config_path = get_config_path(config_dir)
    return config_path.exists()


def reset_config(config_dir: Optional[str] = None) -> None:
    """
    Reset configuration to defaults

    Args:
        config_dir: Configuration directory path
    """
    save_config(get_default_config(), config_dir)


def merge_config(
    base_config: Dict[str, Any], override_config: Dict[str, Any]
) -> Dict[str, Any]:
    """
    Merge two configuration dictionaries

    Args:
        base_config: Base configuration
        override_config: Override configuration (takes precedence)

    Returns:
        Merged configuration dictionary
    """
    merged = base_config.copy()
    merged.update(override_config)
    return merged
